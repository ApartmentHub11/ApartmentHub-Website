-- Migration: Sync tenant booking details to accounts.current_bookings
-- When a tenant is inserted/updated, match by whatsapp_number and update
-- the account's current_bookings with meeting date, time, apartment, etc.

-- 1. Add or alter current_bookings column (may exist as text[] from elsewhere)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'accounts' AND column_name = 'current_bookings'
  ) THEN
    -- Column exists but is not jsonb (e.g. text[]); convert to jsonb
    IF (SELECT data_type FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'accounts' AND column_name = 'current_bookings') IS DISTINCT FROM 'jsonb' THEN
      ALTER TABLE public.accounts
        ALTER COLUMN current_bookings TYPE jsonb USING '[]'::jsonb;
      ALTER TABLE public.accounts
        ALTER COLUMN current_bookings SET DEFAULT '[]'::jsonb;
    END IF;
  ELSE
    ALTER TABLE public.accounts ADD COLUMN current_bookings JSONB DEFAULT '[]'::jsonb;
  END IF;
END $$;

COMMENT ON COLUMN public.accounts.current_bookings IS
'Array of current/upcoming bookings synced from tenants table. Matched by whatsapp_number.';

-- 2. Function to build a booking object from tenant (safe for optional columns via to_jsonb)
CREATE OR REPLACE FUNCTION public.build_booking_from_tenant(p_tenant public.tenants)
RETURNS jsonb AS $$
DECLARE
  v_row jsonb;
  v_apt_address text;
BEGIN
  v_row := to_jsonb(p_tenant);
  SELECT a."Full Address" INTO v_apt_address
  FROM public.apartments a
  WHERE a.id = p_tenant.apartment_id
  LIMIT 1;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant.id,
    'apartment_id', p_tenant.apartment_id,
    'apartment_address', v_apt_address,
    'name', p_tenant.name,
    'whatsapp_number', p_tenant.whatsapp_number,
    'booking_date', COALESCE(v_row->>'BookingAt', v_row->>'booking_at', v_row->>'created_at'),
    'event_type', COALESCE(v_row->>'EventType', v_row->>'event_type'),
    'event_title', COALESCE(v_row->>'EventTitle', v_row->>'event_title'),
    'viewing_start_time', COALESCE(v_row->>'Viewing_StartTime', v_row->>'viewing_start_time'),
    'viewing_end_time', COALESCE(v_row->>'Viewing_EndTime', v_row->>'viewing_end_time'),
    'meeting_url', COALESCE(v_row->>'MeetingURL', v_row->>'meeting_url'),
    'additional_notes', COALESCE(v_row->>'AdditionalNotes', v_row->>'additional_notes'),
    'status', COALESCE(v_row->>'status'),
    'email', COALESCE(v_row->>'Email', v_row->>'email'),
    'created_at', p_tenant.created_at,
    'updated_at', p_tenant.updated_at
  );
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.build_booking_from_tenant(public.tenants) IS
'Builds a booking object from tenant row for accounts.current_bookings. Uses to_jsonb for optional MeetCo columns.';

-- 3. Function to sync tenant bookings to matching accounts
CREATE OR REPLACE FUNCTION public.sync_tenant_bookings_to_accounts()
RETURNS TRIGGER AS $$
DECLARE
  v_tenant_phone_norm text;
  v_booking jsonb;
  v_current jsonb;
  v_updated jsonb;
  v_account_rec RECORD;
BEGIN
  IF NEW.whatsapp_number IS NULL OR trim(NEW.whatsapp_number) = '' THEN
    RETURN NEW;
  END IF;

  v_tenant_phone_norm := public.normalize_phone_for_match(NEW.whatsapp_number);
  IF v_tenant_phone_norm IS NULL OR length(v_tenant_phone_norm) < 8 THEN
    RETURN NEW;
  END IF;

  v_booking := public.build_booking_from_tenant(NEW);

  FOR v_account_rec IN
    SELECT id, current_bookings
    FROM public.accounts
    WHERE whatsapp_number IS NOT NULL
      AND trim(whatsapp_number) != ''
      AND public.normalize_phone_for_match(whatsapp_number) = v_tenant_phone_norm
  LOOP
    v_current := COALESCE(v_account_rec.current_bookings, '[]'::jsonb);
    -- Remove existing booking for this tenant_id if any, then append updated one
    v_updated := (
      SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
      FROM jsonb_array_elements(v_current) AS elem
      WHERE (elem->>'tenant_id')::uuid IS DISTINCT FROM NEW.id
    );
    v_updated := COALESCE(v_updated, '[]'::jsonb) || v_booking;

    UPDATE public.accounts
    SET current_bookings = v_updated,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_account_rec.id;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.sync_tenant_bookings_to_accounts() IS
'Trigger: when tenant is inserted/updated, syncs booking details to accounts.current_bookings for matching whatsapp_number.';

-- 4. Trigger on tenants - fires on any insert/update to catch all booking-related changes
DROP TRIGGER IF EXISTS trigger_sync_tenant_bookings_to_accounts ON public.tenants;
CREATE TRIGGER trigger_sync_tenant_bookings_to_accounts
  AFTER INSERT OR UPDATE ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_tenant_bookings_to_accounts();

-- 5. Initial sync: populate current_bookings for existing tenant-account matches
UPDATE public.accounts acc
SET
  current_bookings = sub.bookings,
  updated_at = timezone('utc'::text, now())
FROM (
  SELECT
    acc.id AS account_id,
    COALESCE(
      jsonb_agg(public.build_booking_from_tenant(t) ORDER BY t.created_at DESC),
      '[]'::jsonb
    ) AS bookings
  FROM public.accounts acc
  JOIN public.tenants t
    ON t.whatsapp_number IS NOT NULL
    AND trim(t.whatsapp_number) != ''
    AND public.normalize_phone_for_match(t.whatsapp_number) = public.normalize_phone_for_match(acc.whatsapp_number)
  WHERE acc.whatsapp_number IS NOT NULL
    AND trim(acc.whatsapp_number) != ''
  GROUP BY acc.id
) sub
WHERE acc.id = sub.account_id;
