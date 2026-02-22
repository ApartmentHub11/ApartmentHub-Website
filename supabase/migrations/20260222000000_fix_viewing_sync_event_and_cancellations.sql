-- Migration: Fix viewing_participants sync and add viewing_cancellations support
--
-- Fixes 3 issues + adds BOOKING_ACCEPTED support:
-- 1. extract_tenant_event_type() now checks TriggerEvent column (not just EventType)
-- 2. BOOKING_CREATED matching uses event_link only (no qualified_users whatsapp requirement)
-- 3. BOOKING_CANCELLED adds tenant details to viewing_cancellations before removing from viewing_participants

------------------------------------------------------------------------
-- 1. Fix extract_tenant_event_type to also check TriggerEvent column
------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.extract_tenant_event_type(p_tenant public.tenants)
RETURNS text AS $$
DECLARE
  v_row jsonb;
BEGIN
  v_row := to_jsonb(p_tenant);
  RETURN NULLIF(trim(upper(COALESCE(
    v_row->>'TriggerEvent',
    v_row->>'EventType',
    v_row->>'event_type'
  ))), '');
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.extract_tenant_event_type(public.tenants) IS
'Extracts the event type from a tenant row, checking TriggerEvent, EventType, and event_type columns.';

------------------------------------------------------------------------
-- 1b. Fix extract_tenant_event_url to also check EventURL column
------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.extract_tenant_event_url(p_tenant public.tenants)
RETURNS text AS $$
DECLARE
  v_row jsonb;
BEGIN
  v_row := to_jsonb(p_tenant);
  RETURN NULLIF(trim(COALESCE(
    v_row->>'EventURL',
    v_row->>'MeetingURL',
    v_row->>'meetcoURL',
    v_row->>'meeting_url',
    v_row->>'event_link'
  )), '');
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.extract_tenant_event_url(public.tenants) IS
'Extracts the event/meeting URL from a tenant row, checking EventURL, MeetingURL, meetcoURL, meeting_url, and event_link columns.';

------------------------------------------------------------------------
-- 2. Updated sync function: event_link match only + viewing_cancellations
------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_tenant_to_viewing_participants()
RETURNS TRIGGER AS $$
DECLARE
  v_event_type text;
  v_tenant_event_url text;
  v_tenant_phone_norm text;
  v_apt_record RECORD;
  v_participant jsonb;
  v_current_participants jsonb;
  v_current_cancellations jsonb;
  v_updated jsonb;
BEGIN
  -- Extract the event type (now checks TriggerEvent first)
  v_event_type := public.extract_tenant_event_type(NEW);

  -- Only act on BOOKING_CREATED, BOOKING_ACCEPTED, or BOOKING_CANCELLED
  IF v_event_type IS NULL OR v_event_type NOT IN ('BOOKING_CREATED', 'BOOKING_ACCEPTED', 'BOOKING_CANCELLED') THEN
    RETURN NEW;
  END IF;

  -- Extract tenant event URL
  v_tenant_event_url := public.extract_tenant_event_url(NEW);
  IF v_tenant_event_url IS NULL THEN
    RETURN NEW;
  END IF;

  -- Build participant object
  v_participant := public.build_tenant_participant(NEW);

  IF v_event_type = 'BOOKING_CANCELLED' THEN
    -- Normalize the cancelling tenant's phone for cross-row matching
    v_tenant_phone_norm := public.normalize_phone_for_match(NEW.whatsapp_number);

    -- For each apartment with matching event_link:
    --   a) Add tenant to viewing_cancellations
    --   b) Remove ALL entries with same whatsapp from viewing_participants
    FOR v_apt_record IN
      SELECT id, event_link, viewing_participants, viewing_cancellations
      FROM public.apartments
      WHERE event_link IS NOT NULL
    LOOP
      IF NOT public.event_url_matches(v_tenant_event_url, v_apt_record.event_link) THEN
        CONTINUE;
      END IF;

      -- Add to viewing_cancellations (deduplicate by whatsapp_number)
      v_current_cancellations := COALESCE(v_apt_record.viewing_cancellations, '[]'::jsonb);
      IF NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_current_cancellations) AS elem
        WHERE public.normalize_phone_for_match(elem->>'whatsapp_number') = v_tenant_phone_norm
      ) THEN
        v_current_cancellations := v_current_cancellations || v_participant;
      END IF;

      -- Remove from viewing_participants by whatsapp_number match
      -- (the original BOOKING_CREATED entry has a different tenant_id)
      v_current_participants := COALESCE(v_apt_record.viewing_participants, '[]'::jsonb);
      v_updated := (
        SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(v_current_participants) AS elem
        WHERE public.normalize_phone_for_match(elem->>'whatsapp_number') IS DISTINCT FROM v_tenant_phone_norm
      );

      UPDATE public.apartments
      SET viewing_participants = v_updated,
          viewing_cancellations = v_current_cancellations,
          updated_at = timezone('utc'::text, now())
      WHERE id = v_apt_record.id;
    END LOOP;

    RETURN NEW;
  END IF;

  -- BOOKING_CREATED or BOOKING_ACCEPTED: add to viewing_participants when event_link matches
  FOR v_apt_record IN
    SELECT id, event_link, viewing_participants
    FROM public.apartments
    WHERE event_link IS NOT NULL
  LOOP
    IF NOT public.event_url_matches(v_tenant_event_url, v_apt_record.event_link) THEN
      CONTINUE;
    END IF;

    -- Add to viewing_participants (if not already present)
    v_current_participants := COALESCE(v_apt_record.viewing_participants, '[]'::jsonb);
    IF NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_current_participants) AS elem
      WHERE (elem->>'tenant_id')::uuid = NEW.id
    ) THEN
      v_updated := v_current_participants || v_participant;
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
'On BOOKING_CREATED/BOOKING_ACCEPTED: add tenant to viewing_participants when event_link matches. '
'On BOOKING_CANCELLED: add to viewing_cancellations and remove from viewing_participants.';

------------------------------------------------------------------------
-- 3. Re-create trigger (fires on all INSERT/UPDATE, not limited columns)
------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_sync_tenant_to_viewing_participants ON public.tenants;
CREATE TRIGGER trigger_sync_tenant_to_viewing_participants
  AFTER INSERT OR UPDATE ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_tenant_to_viewing_participants();

------------------------------------------------------------------------
-- 4. Initial sync: backfill viewing_participants for BOOKING_CREATED tenants
------------------------------------------------------------------------
UPDATE public.apartments a
SET
  viewing_participants = sub.participants,
  updated_at = timezone('utc'::text, now())
FROM (
  SELECT
    a2.id AS apt_id,
    COALESCE(jsonb_agg(public.build_tenant_participant(t)), '[]'::jsonb) AS participants
  FROM public.apartments a2
  JOIN public.tenants t
    ON public.extract_tenant_event_url(t) IS NOT NULL
    AND a2.event_link IS NOT NULL
    AND public.event_url_matches(public.extract_tenant_event_url(t), a2.event_link)
  WHERE upper(trim(COALESCE(
    (to_jsonb(t)->>'TriggerEvent'),
    (to_jsonb(t)->>'EventType'),
    (to_jsonb(t)->>'event_type'),
    ''
  ))) IN ('BOOKING_CREATED', 'BOOKING_ACCEPTED')
  GROUP BY a2.id
) sub
WHERE a.id = sub.apt_id;

------------------------------------------------------------------------
-- 5. Initial sync: backfill viewing_cancellations for BOOKING_CANCELLED tenants
------------------------------------------------------------------------
UPDATE public.apartments a
SET
  viewing_cancellations = sub.cancellations,
  updated_at = timezone('utc'::text, now())
FROM (
  SELECT
    a2.id AS apt_id,
    COALESCE(jsonb_agg(public.build_tenant_participant(t)), '[]'::jsonb) AS cancellations
  FROM public.apartments a2
  JOIN public.tenants t
    ON public.extract_tenant_event_url(t) IS NOT NULL
    AND a2.event_link IS NOT NULL
    AND public.event_url_matches(public.extract_tenant_event_url(t), a2.event_link)
  WHERE upper(trim(COALESCE(
    (to_jsonb(t)->>'TriggerEvent'),
    (to_jsonb(t)->>'EventType'),
    (to_jsonb(t)->>'event_type'),
    ''
  ))) = 'BOOKING_CANCELLED'
  GROUP BY a2.id
) sub
WHERE a.id = sub.apt_id;
