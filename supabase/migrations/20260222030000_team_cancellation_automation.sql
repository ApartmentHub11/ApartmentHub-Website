-- Migration: ApartmentHub Team Cancellation Automation
--
-- When "anyCancellation ?" is set to true on a tenant:
-- 1. Send webhook to n8n with all tenant info
-- 2. Move tenant from viewing_participants → viewing_cancellations (with cancelled_by field)
-- 3. Move tenant from current_bookings → cancelled_bookings (with cancelled_by field)

------------------------------------------------------------------------
-- 1. Update build_tenant_participant to include cancelled_by
------------------------------------------------------------------------
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
    'cancelled_by', COALESCE(v_row->>'cancelledBy', v_row->>'cancelled_by'),
    'created_at', p_tenant.created_at,
    'updated_at', p_tenant.updated_at
  );
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.build_tenant_participant(public.tenants) IS
'Builds a JSONB object with tenant details for viewing_participants/viewing_cancellations. Includes cancelled_by field.';

------------------------------------------------------------------------
-- 2. Update build_booking_from_tenant to include cancelled_by
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
    'cancelled_by', COALESCE(v_row->>'cancelledBy', v_row->>'cancelled_by'),
    'created_at', p_tenant.created_at,
    'updated_at', p_tenant.updated_at
  );
END;
$$ LANGUAGE plpgsql STABLE;

------------------------------------------------------------------------
-- 3. Trigger function: fires when "anyCancellation ?" flips to true
------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_team_cancellation()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/cancelledby-apartmenthub-team';
  v_payload JSONB;
  v_tenant_json JSONB;
  v_tenant_event_url text;
  v_tenant_phone_norm text;
  v_apt_record RECORD;
  v_participant jsonb;
  v_current_participants jsonb;
  v_current_cancellations jsonb;
  v_updated_participants jsonb;
  v_account_rec RECORD;
  v_booking jsonb;
BEGIN
  -- =============================================
  -- STEP 1: Send webhook with all tenant info
  -- =============================================
  v_tenant_json := to_jsonb(NEW);
  v_payload := jsonb_build_object(
    'event_type', 'tenant_cancelled_by_team',
    'tenant', v_tenant_json,
    'cancelled_by', COALESCE(v_tenant_json->>'cancelledBy', v_tenant_json->>'cancelled_by', 'ApartmentHub Team'),
    'timestamp', NOW()
  );

  BEGIN
    PERFORM net.http_post(
      url := v_webhook_url,
      body := v_payload,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'User-Agent', 'Supabase-Webhook-Trigger'
      )
    );
    RAISE NOTICE '[Team Cancellation Webhook] Sent for tenant %', NEW.id;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[Team Cancellation Webhook] Failed for tenant %: %', NEW.id, SQLERRM;
  END;

  -- =============================================
  -- STEP 2: Move from viewing_participants → viewing_cancellations
  -- =============================================
  v_tenant_event_url := public.extract_tenant_event_url(NEW);
  v_tenant_phone_norm := public.normalize_phone_for_match(NEW.whatsapp_number);
  v_participant := public.build_tenant_participant(NEW);

  IF v_tenant_event_url IS NOT NULL THEN
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
      IF v_tenant_phone_norm IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_current_cancellations) AS elem
        WHERE public.normalize_phone_for_match(elem->>'whatsapp_number') = v_tenant_phone_norm
      ) THEN
        v_current_cancellations := v_current_cancellations || v_participant;
      END IF;

      -- Remove from viewing_participants by whatsapp_number
      v_current_participants := COALESCE(v_apt_record.viewing_participants, '[]'::jsonb);
      IF v_tenant_phone_norm IS NOT NULL THEN
        v_updated_participants := (
          SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
          FROM jsonb_array_elements(v_current_participants) AS elem
          WHERE public.normalize_phone_for_match(elem->>'whatsapp_number') IS DISTINCT FROM v_tenant_phone_norm
        );
      ELSE
        v_updated_participants := (
          SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
          FROM jsonb_array_elements(v_current_participants) AS elem
          WHERE (elem->>'tenant_id')::uuid IS DISTINCT FROM NEW.id
        );
      END IF;

      UPDATE public.apartments
      SET viewing_participants = v_updated_participants,
          viewing_cancellations = v_current_cancellations,
          updated_at = timezone('utc'::text, now())
      WHERE id = v_apt_record.id;
    END LOOP;
  END IF;

  -- =============================================
  -- STEP 3: Move from current_bookings → cancelled_bookings in accounts
  -- =============================================
  IF v_tenant_phone_norm IS NOT NULL AND length(v_tenant_phone_norm) >= 8 THEN
    v_booking := public.build_booking_from_tenant(NEW);

    FOR v_account_rec IN
      SELECT id, current_bookings, cancelled_bookings
      FROM public.accounts
      WHERE whatsapp_number IS NOT NULL
        AND trim(whatsapp_number) != ''
        AND public.normalize_phone_for_match(whatsapp_number) = v_tenant_phone_norm
    LOOP
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
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.handle_team_cancellation() IS
'When "anyCancellation ?" is set to true: sends webhook to n8n, moves tenant from viewing_participants to viewing_cancellations (with cancelled_by), and moves from current_bookings to cancelled_bookings (with cancelled_by).';

------------------------------------------------------------------------
-- 4. Create trigger on tenants for "anyCancellation ?" changes
------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_handle_team_cancellation ON public.tenants;
CREATE TRIGGER trigger_handle_team_cancellation
  AFTER UPDATE OF "anyCancellation ?" ON public.tenants
  FOR EACH ROW
  WHEN (NEW."anyCancellation ?" = true AND (OLD."anyCancellation ?" IS DISTINCT FROM true))
  EXECUTE FUNCTION public.handle_team_cancellation();

------------------------------------------------------------------------
-- 5. Backfill: for tenants where "anyCancellation ?" is already true,
--    move from viewing_participants → viewing_cancellations (with cancelled_by)
------------------------------------------------------------------------
DO $$
DECLARE
  v_tenant public.tenants%ROWTYPE;
  v_tenant_event_url text;
  v_tenant_phone_norm text;
  v_participant jsonb;
  v_apt_record RECORD;
  v_current_cancellations jsonb;
  v_current_participants jsonb;
  v_updated_participants jsonb;
BEGIN
  FOR v_tenant IN
    SELECT * FROM public.tenants
    WHERE "anyCancellation ?" = true
  LOOP
    v_tenant_event_url := public.extract_tenant_event_url(v_tenant);
    v_tenant_phone_norm := public.normalize_phone_for_match(v_tenant.whatsapp_number);
    v_participant := public.build_tenant_participant(v_tenant);

    IF v_tenant_event_url IS NOT NULL THEN
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
        IF v_tenant_phone_norm IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM jsonb_array_elements(v_current_cancellations) AS elem
          WHERE public.normalize_phone_for_match(elem->>'whatsapp_number') = v_tenant_phone_norm
        ) THEN
          v_current_cancellations := v_current_cancellations || v_participant;
        END IF;

        -- Remove from viewing_participants
        v_current_participants := COALESCE(v_apt_record.viewing_participants, '[]'::jsonb);
        IF v_tenant_phone_norm IS NOT NULL THEN
          v_updated_participants := (
            SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
            FROM jsonb_array_elements(v_current_participants) AS elem
            WHERE public.normalize_phone_for_match(elem->>'whatsapp_number') IS DISTINCT FROM v_tenant_phone_norm
          );
        ELSE
          v_updated_participants := (
            SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
            FROM jsonb_array_elements(v_current_participants) AS elem
            WHERE (elem->>'tenant_id')::uuid IS DISTINCT FROM v_tenant.id
          );
        END IF;

        UPDATE public.apartments
        SET viewing_participants = v_updated_participants,
            viewing_cancellations = v_current_cancellations,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_apt_record.id;
      END LOOP;
    END IF;
  END LOOP;

  RAISE NOTICE '[Backfill] Processed existing cancelled tenants for viewing_participants/viewing_cancellations';
END;
$$;

------------------------------------------------------------------------
-- 6. Backfill: for tenants where "anyCancellation ?" is already true,
--    move from current_bookings → cancelled_bookings in accounts (with cancelled_by)
------------------------------------------------------------------------
DO $$
DECLARE
  v_tenant public.tenants%ROWTYPE;
  v_tenant_phone_norm text;
  v_booking jsonb;
  v_account_rec RECORD;
BEGIN
  FOR v_tenant IN
    SELECT * FROM public.tenants
    WHERE "anyCancellation ?" = true
      AND whatsapp_number IS NOT NULL
      AND trim(whatsapp_number) != ''
  LOOP
    v_tenant_phone_norm := public.normalize_phone_for_match(v_tenant.whatsapp_number);
    IF v_tenant_phone_norm IS NULL OR length(v_tenant_phone_norm) < 8 THEN
      CONTINUE;
    END IF;

    v_booking := public.build_booking_from_tenant(v_tenant);

    FOR v_account_rec IN
      SELECT id, current_bookings, cancelled_bookings
      FROM public.accounts
      WHERE whatsapp_number IS NOT NULL
        AND trim(whatsapp_number) != ''
        AND public.normalize_phone_for_match(whatsapp_number) = v_tenant_phone_norm
    LOOP
      IF NOT EXISTS (
        SELECT 1 FROM unnest(COALESCE(v_account_rec.cancelled_bookings, ARRAY[]::text[])) AS entry
        WHERE entry::jsonb->>'tenant_id' = v_tenant.id::text
      ) THEN
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
      END IF;
    END LOOP;
  END LOOP;

  RAISE NOTICE '[Backfill] Processed existing cancelled tenants for accounts current_bookings/cancelled_bookings';
END;
$$;
