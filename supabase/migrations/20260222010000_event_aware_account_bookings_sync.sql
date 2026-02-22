-- Migration: Event-aware sync of tenant bookings to accounts
--
-- BOOKING_CREATED / BOOKING_ACCEPTED → add to accounts.current_bookings (jsonb)
-- BOOKING_CANCELLED → add to accounts.cancelled_bookings (text[]) + remove from current_bookings

------------------------------------------------------------------------
-- 1. Update build_booking_from_tenant to also capture TriggerEvent + EventURL
------------------------------------------------------------------------
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
    'booking_date', COALESCE(v_row->>'bookingDate', v_row->>'BookingAt', v_row->>'booking_at', v_row->>'created_at'),
    'trigger_event', COALESCE(v_row->>'TriggerEvent', v_row->>'EventType', v_row->>'event_type'),
    'event_title', COALESCE(v_row->>'eventTitle', v_row->>'EventTitle', v_row->>'event_title'),
    'event_url', COALESCE(v_row->>'EventURL', v_row->>'MeetingURL', v_row->>'meetcoURL'),
    'viewing_start_time', COALESCE(v_row->>'Viewing_StartTime', v_row->>'viewing_start_time'),
    'viewing_end_time', COALESCE(v_row->>'Viewing_EndTime', v_row->>'viewing_end_time'),
    'additional_notes', COALESCE(v_row->>'AdditionalNotes', v_row->>'additional_notes'),
    'status', v_row->>'status',
    'email', COALESCE(v_row->>'Email', v_row->>'email'),
    'created_at', p_tenant.created_at,
    'updated_at', p_tenant.updated_at
  );
END;
$$ LANGUAGE plpgsql STABLE;

------------------------------------------------------------------------
-- 2. Event-aware sync function
------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_tenant_bookings_to_accounts()
RETURNS TRIGGER AS $$
DECLARE
  v_event_type text;
  v_tenant_phone_norm text;
  v_booking jsonb;
  v_current jsonb;
  v_updated jsonb;
  v_account_rec RECORD;
BEGIN
  -- Must have whatsapp_number to match
  IF NEW.whatsapp_number IS NULL OR trim(NEW.whatsapp_number) = '' THEN
    RETURN NEW;
  END IF;

  v_tenant_phone_norm := public.normalize_phone_for_match(NEW.whatsapp_number);
  IF v_tenant_phone_norm IS NULL OR length(v_tenant_phone_norm) < 8 THEN
    RETURN NEW;
  END IF;

  -- Extract event type
  v_event_type := public.extract_tenant_event_type(NEW);

  -- Only act on recognized booking events
  IF v_event_type IS NULL OR v_event_type NOT IN ('BOOKING_CREATED', 'BOOKING_ACCEPTED', 'BOOKING_CANCELLED') THEN
    RETURN NEW;
  END IF;

  v_booking := public.build_booking_from_tenant(NEW);

  FOR v_account_rec IN
    SELECT id, current_bookings, cancelled_bookings
    FROM public.accounts
    WHERE whatsapp_number IS NOT NULL
      AND trim(whatsapp_number) != ''
      AND public.normalize_phone_for_match(whatsapp_number) = v_tenant_phone_norm
  LOOP
    IF v_event_type = 'BOOKING_CANCELLED' THEN
      -- 1) Append to cancelled_bookings (text[]) as JSON string
      -- 2) Remove ALL entries with same whatsapp from current_bookings
      --    (the original BOOKING_CREATED entry has a different tenant_id)
      UPDATE public.accounts
      SET cancelled_bookings = array_append(
            COALESCE(cancelled_bookings, ARRAY[]::text[]),
            v_booking::text
          ),
          current_bookings = (
            SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
            FROM jsonb_array_elements(COALESCE(v_account_rec.current_bookings, '[]'::jsonb)) AS elem
            WHERE public.normalize_phone_for_match(elem->>'whatsapp_number') IS DISTINCT FROM v_tenant_phone_norm
          ),
          updated_at = timezone('utc'::text, now())
      WHERE id = v_account_rec.id;

    ELSE
      -- BOOKING_CREATED / BOOKING_ACCEPTED: upsert in current_bookings
      v_current := COALESCE(v_account_rec.current_bookings, '[]'::jsonb);
      -- Remove existing entry for this tenant_id, then append fresh one
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
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.sync_tenant_bookings_to_accounts() IS
'On BOOKING_CREATED/BOOKING_ACCEPTED: add to accounts.current_bookings. '
'On BOOKING_CANCELLED: move to accounts.cancelled_bookings and remove from current_bookings.';

------------------------------------------------------------------------
-- 3. Re-create trigger
------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_sync_tenant_bookings_to_accounts ON public.tenants;
CREATE TRIGGER trigger_sync_tenant_bookings_to_accounts
  AFTER INSERT OR UPDATE ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_tenant_bookings_to_accounts();

------------------------------------------------------------------------
-- 4. Backfill: current_bookings for BOOKING_CREATED / BOOKING_ACCEPTED tenants
------------------------------------------------------------------------
UPDATE public.accounts acc
SET
  current_bookings = sub.bookings,
  updated_at = timezone('utc'::text, now())
FROM (
  SELECT
    acc2.id AS account_id,
    COALESCE(
      jsonb_agg(public.build_booking_from_tenant(t) ORDER BY t.created_at DESC),
      '[]'::jsonb
    ) AS bookings
  FROM public.accounts acc2
  JOIN public.tenants t
    ON t.whatsapp_number IS NOT NULL
    AND trim(t.whatsapp_number) != ''
    AND public.normalize_phone_for_match(t.whatsapp_number) = public.normalize_phone_for_match(acc2.whatsapp_number)
  WHERE acc2.whatsapp_number IS NOT NULL
    AND trim(acc2.whatsapp_number) != ''
    AND upper(trim(COALESCE(
      (to_jsonb(t)->>'TriggerEvent'),
      (to_jsonb(t)->>'EventType'),
      (to_jsonb(t)->>'event_type'),
      ''
    ))) IN ('BOOKING_CREATED', 'BOOKING_ACCEPTED')
  GROUP BY acc2.id
) sub
WHERE acc.id = sub.account_id;

------------------------------------------------------------------------
-- 5. Backfill: cancelled_bookings for BOOKING_CANCELLED tenants
------------------------------------------------------------------------
UPDATE public.accounts acc
SET
  cancelled_bookings = sub.cancellations,
  updated_at = timezone('utc'::text, now())
FROM (
  SELECT
    acc2.id AS account_id,
    array_agg(public.build_booking_from_tenant(t)::text ORDER BY t.created_at DESC) AS cancellations
  FROM public.accounts acc2
  JOIN public.tenants t
    ON t.whatsapp_number IS NOT NULL
    AND trim(t.whatsapp_number) != ''
    AND public.normalize_phone_for_match(t.whatsapp_number) = public.normalize_phone_for_match(acc2.whatsapp_number)
  WHERE acc2.whatsapp_number IS NOT NULL
    AND trim(acc2.whatsapp_number) != ''
    AND upper(trim(COALESCE(
      (to_jsonb(t)->>'TriggerEvent'),
      (to_jsonb(t)->>'EventType'),
      (to_jsonb(t)->>'event_type'),
      ''
    ))) = 'BOOKING_CANCELLED'
  GROUP BY acc2.id
) sub
WHERE acc.id = sub.account_id;
