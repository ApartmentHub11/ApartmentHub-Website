-- Migration: viewing_participants synced only on BOOKING_CREATED or BOOKING_CANCELLED
-- BOOKING_CREATED: add to viewing_participants when event URL AND whatsapp both match
-- BOOKING_CANCELLED: remove from viewing_participants

-- Add EventType column to tenants if not exists (for webhook to set BOOKING_CREATED/BOOKING_CANCELLED)
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS "EventType" text;

-- Helper to extract tenant event type
CREATE OR REPLACE FUNCTION public.extract_tenant_event_type(p_tenant public.tenants)
RETURNS text AS $$
DECLARE
  v_row jsonb;
BEGIN
  v_row := to_jsonb(p_tenant);
  RETURN NULLIF(trim(upper(COALESCE(v_row->>'EventType', v_row->>'event_type'))), '');
END;
$$ LANGUAGE plpgsql STABLE;

-- Helper to extract tenant event/meeting URL
CREATE OR REPLACE FUNCTION public.extract_tenant_event_url(p_tenant public.tenants)
RETURNS text AS $$
DECLARE
  v_row jsonb;
BEGIN
  v_row := to_jsonb(p_tenant);
  RETURN NULLIF(trim(COALESCE(
    v_row->>'MeetingURL',
    v_row->>'meetcoURL',
    v_row->>'meeting_url',
    v_row->>'event_link'
  )), '');
END;
$$ LANGUAGE plpgsql STABLE;

-- Helper to check if tenant event URL matches apartment event_link
CREATE OR REPLACE FUNCTION public.event_url_matches(tenant_url text, apt_event_link text)
RETURNS boolean AS $$
BEGIN
  IF tenant_url IS NULL OR trim(tenant_url) = '' THEN RETURN false; END IF;
  IF apt_event_link IS NULL OR trim(apt_event_link) = '' THEN RETURN false; END IF;
  tenant_url := lower(trim(tenant_url));
  apt_event_link := lower(trim(apt_event_link));
  RETURN tenant_url = apt_event_link
    OR tenant_url LIKE '%' || apt_event_link || '%'
    OR apt_event_link LIKE '%' || tenant_url || '%';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Enhanced build_tenant_participant with all details (including optional MeetCo columns)
CREATE OR REPLACE FUNCTION public.build_tenant_participant(p_tenant public.tenants)
RETURNS jsonb AS $$
DECLARE
  v_row jsonb;
BEGIN
  v_row := to_jsonb(p_tenant);
  RETURN jsonb_build_object(
    'tenant_id', p_tenant.id,
    'name', p_tenant.name,
    'whatsapp_number', p_tenant.whatsapp_number,
    'salesforce_account_id', p_tenant.salesforce_account_id,
    'tags', p_tenant.tags,
    'apartment_id', p_tenant.apartment_id,
    'created_at', p_tenant.created_at,
    'updated_at', p_tenant.updated_at,
    'event_type', v_row->>'EventType',
    'booking_at', v_row->>'BookingAt',
    'event_title', v_row->>'EventTitle',
    'viewing_start_time', v_row->>'Viewing_StartTime',
    'viewing_end_time', v_row->>'Viewing_EndTime',
    'additional_notes', v_row->>'AdditionalNotes',
    'meeting_url', COALESCE(v_row->>'MeetingURL', v_row->>'meetcoURL'),
    'email', v_row->>'Email',
    'status', v_row->>'status'
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- Sync function: only act on BOOKING_CREATED or BOOKING_CANCELLED
CREATE OR REPLACE FUNCTION public.sync_tenant_to_viewing_participants()
RETURNS TRIGGER AS $$
DECLARE
  v_event_type text;
  v_tenant_event_url text;
  v_tenant_phone_norm text;
  v_apt_record RECORD;
  v_qu_elem jsonb;
  v_qu_phone_norm text;
  v_event_match boolean;
  v_whatsapp_match boolean;
  v_participant jsonb;
  v_current jsonb;
  v_updated jsonb;
BEGIN
  v_event_type := public.extract_tenant_event_type(NEW);
  IF v_event_type IS NULL OR v_event_type NOT IN ('BOOKING_CREATED', 'BOOKING_CANCELLED') THEN
    RETURN NEW;
  END IF;

  IF v_event_type = 'BOOKING_CANCELLED' THEN
    -- Remove tenant from all apartments' viewing_participants
    UPDATE public.apartments apt
    SET viewing_participants = (
      SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
      FROM jsonb_array_elements(COALESCE(apt.viewing_participants, '[]'::jsonb)) AS elem
      WHERE (elem->>'tenant_id')::uuid IS DISTINCT FROM NEW.id
    ),
    updated_at = timezone('utc'::text, now())
    WHERE EXISTS (
      SELECT 1 FROM jsonb_array_elements(COALESCE(apt.viewing_participants, '[]'::jsonb)) elem
      WHERE (elem->>'tenant_id')::uuid = NEW.id
    );
    RETURN NEW;
  END IF;

  /* BOOKING_CREATED: add when BOTH event URL AND whatsapp match */
  v_tenant_event_url := public.extract_tenant_event_url(NEW);
  v_tenant_phone_norm := public.normalize_phone_for_match(NEW.whatsapp_number);
  IF v_tenant_event_url IS NULL OR v_tenant_phone_norm IS NULL OR length(v_tenant_phone_norm) < 8 THEN
    RETURN NEW;
  END IF;

  v_participant := public.build_tenant_participant(NEW);

  FOR v_apt_record IN
    SELECT id, event_link, qualified_users, viewing_participants
    FROM public.apartments
    WHERE event_link IS NOT NULL
      AND qualified_users IS NOT NULL
      AND jsonb_array_length(qualified_users) > 0
  LOOP
    -- Check 1: Event URL matches
    v_event_match := public.event_url_matches(v_tenant_event_url, v_apt_record.event_link);
    IF NOT v_event_match THEN
      CONTINUE;
    END IF;

    -- Check 2: WhatsApp matches qualified_users
    v_whatsapp_match := false;
    FOR v_qu_elem IN SELECT * FROM jsonb_array_elements(v_apt_record.qualified_users)
    LOOP
      v_qu_phone_norm := public.normalize_phone_for_match(COALESCE(
        v_qu_elem->>'whatsapp_number',
        v_qu_elem->>'WhatsApp Number',
        v_qu_elem->>'whatsAppNumber',
        v_qu_elem->>'WhatsAppNumber'
      ));
      IF v_qu_phone_norm = v_tenant_phone_norm THEN
        v_whatsapp_match := true;
        EXIT;
      END IF;
    END LOOP;
    IF NOT v_whatsapp_match THEN
      CONTINUE;
    END IF;

    -- Both match: add to viewing_participants
    v_current := COALESCE(v_apt_record.viewing_participants, '[]'::jsonb);
    IF NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_current) AS elem
      WHERE (elem->>'tenant_id')::uuid = NEW.id
    ) THEN
      v_updated := v_current || v_participant;
      UPDATE public.apartments
      SET viewing_participants = v_updated,
          updated_at = timezone('utc'::text, now())
      WHERE id = v_apt_record.id;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.sync_tenant_to_viewing_participants() IS
'On BOOKING_CREATED: add to viewing_participants when event URL and whatsapp both match. On BOOKING_CANCELLED: remove.';

-- Drop the apartment-side trigger (no longer rebuild from qualified_users)
DROP TRIGGER IF EXISTS trigger_sync_viewing_participants_from_qualified ON public.apartments;

-- Tenant trigger
DROP TRIGGER IF EXISTS trigger_sync_tenant_to_viewing_participants ON public.tenants;
CREATE TRIGGER trigger_sync_tenant_to_viewing_participants
  AFTER INSERT OR UPDATE ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_tenant_to_viewing_participants();

-- Initial sync: only tenants with BOOKING_CREATED where both event URL and whatsapp match
UPDATE public.apartments a
SET
  viewing_participants = (
    SELECT COALESCE(jsonb_agg(public.build_tenant_participant(t)), '[]'::jsonb)
    FROM public.tenants t
    WHERE upper(trim(COALESCE(
      (to_jsonb(t)->>'EventType'),
      (to_jsonb(t)->>'event_type'),
      ''
    ))) = 'BOOKING_CREATED'
      AND public.extract_tenant_event_url(t) IS NOT NULL
      AND a.event_link IS NOT NULL
      AND public.event_url_matches(public.extract_tenant_event_url(t), a.event_link)
      AND t.whatsapp_number IS NOT NULL
      AND trim(t.whatsapp_number) != ''
      AND public.normalize_phone_for_match(t.whatsapp_number) IN (
        SELECT public.normalize_phone_for_match(COALESCE(
          qu->>'whatsapp_number',
          qu->>'WhatsApp Number',
          qu->>'whatsAppNumber',
          qu->>'WhatsAppNumber'
        ))
        FROM jsonb_array_elements(COALESCE(a.qualified_users, '[]'::jsonb)) qu
      )
  ),
  updated_at = timezone('utc'::text, now())
WHERE a.event_link IS NOT NULL
  AND a.qualified_users IS NOT NULL
  AND jsonb_array_length(a.qualified_users) > 0;
