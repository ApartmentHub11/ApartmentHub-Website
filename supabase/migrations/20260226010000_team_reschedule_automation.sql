-- Migration: ApartmentHub Team Reschedule Automation
--
-- When "anyReschedule ?" is set to true on a tenant:
-- 1. Send webhook to n8n with all tenant info + reschedule details
-- 2. Add reschedule entry to booking_reschedules in apartments
-- 3. Update reschedule info in accounts

------------------------------------------------------------------------
-- 1. Add "anyReschedule ?" column to tenants if not exists
------------------------------------------------------------------------
ALTER TABLE public.tenants
ADD COLUMN IF NOT EXISTS "anyReschedule ?" BOOLEAN DEFAULT false;

------------------------------------------------------------------------
-- 2. Helper: build reschedule object from tenant
------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.build_reschedule_from_tenant(p_tenant public.tenants)
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
    'rescheduled_by', COALESCE(v_row->>'rescheduledBy', v_row->>'rescheduled_by', 'ApartmentHub Team'),
    'original_start_time', COALESCE(v_row->>'Viewing_StartTime', v_row->>'viewing_start_time'),
    'original_end_time', COALESCE(v_row->>'Viewing_EndTime', v_row->>'viewing_end_time'),
    'event_url', COALESCE(v_row->>'EventURL', v_row->>'MeetingURL', v_row->>'meetcoURL'),
    'event_title', COALESCE(v_row->>'eventTitle', v_row->>'EventTitle', v_row->>'event_title'),
    'trigger_event', COALESCE(v_row->>'TriggerEvent', v_row->>'EventType', v_row->>'event_type'),
    'rescheduled_at', NOW(),
    'created_at', p_tenant.created_at,
    'updated_at', p_tenant.updated_at
  );
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION public.build_reschedule_from_tenant(public.tenants) IS
'Builds a JSONB object with tenant reschedule details for booking_reschedules.';

------------------------------------------------------------------------
-- 3. Trigger function: fires when "anyReschedule ?" flips to true
------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_team_reschedule()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/rescheduledby-apartmenthub-team';
  v_payload JSONB;
  v_tenant_json JSONB;
  v_tenant_event_url text;
  v_tenant_phone_norm text;
  v_apt_record RECORD;
  v_reschedule_entry jsonb;
  v_current_reschedules jsonb;
  v_account_rec RECORD;
BEGIN
  -- =============================================
  -- STEP 1: Send webhook with all tenant info
  -- =============================================
  v_tenant_json := to_jsonb(NEW);
  v_payload := jsonb_build_object(
    'event_type', 'tenant_rescheduled_by_team',
    'tenant', v_tenant_json,
    'rescheduled_by', COALESCE(v_tenant_json->>'rescheduledBy', v_tenant_json->>'rescheduled_by', 'ApartmentHub Team'),
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
    RAISE NOTICE '[Team Reschedule Webhook] Sent for tenant %', NEW.id;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[Team Reschedule Webhook] Failed for tenant %: %', NEW.id, SQLERRM;
  END;

  -- =============================================
  -- STEP 2: Add to booking_reschedules in apartments
  -- =============================================
  v_tenant_event_url := public.extract_tenant_event_url(NEW);
  v_reschedule_entry := public.build_reschedule_from_tenant(NEW);

  IF v_tenant_event_url IS NOT NULL THEN
    FOR v_apt_record IN
      SELECT id, event_link, booking_reschedules
      FROM public.apartments
      WHERE event_link IS NOT NULL
    LOOP
      IF NOT public.event_url_matches(v_tenant_event_url, v_apt_record.event_link) THEN
        CONTINUE;
      END IF;

      v_current_reschedules := COALESCE(v_apt_record.booking_reschedules, '[]'::jsonb);
      v_current_reschedules := v_current_reschedules || v_reschedule_entry;

      UPDATE public.apartments
      SET booking_reschedules = v_current_reschedules,
          updated_at = timezone('utc'::text, now())
      WHERE id = v_apt_record.id;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.handle_team_reschedule() IS
'When "anyReschedule ?" is set to true: sends webhook to n8n and adds entry to apartments.booking_reschedules.';

------------------------------------------------------------------------
-- 4. Create trigger on tenants for "anyReschedule ?" changes
------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_handle_team_reschedule ON public.tenants;
CREATE TRIGGER trigger_handle_team_reschedule
  AFTER UPDATE OF "anyReschedule ?" ON public.tenants
  FOR EACH ROW
  WHEN (NEW."anyReschedule ?" = true AND (OLD."anyReschedule ?" IS DISTINCT FROM true))
  EXECUTE FUNCTION public.handle_team_reschedule();

------------------------------------------------------------------------
-- 5. Backfill: for tenants where "anyReschedule ?" is already true
------------------------------------------------------------------------
DO $$
DECLARE
  v_tenant public.tenants%ROWTYPE;
  v_tenant_event_url text;
  v_reschedule_entry jsonb;
  v_apt_record RECORD;
  v_current_reschedules jsonb;
BEGIN
  FOR v_tenant IN
    SELECT * FROM public.tenants
    WHERE "anyReschedule ?" = true
  LOOP
    v_tenant_event_url := public.extract_tenant_event_url(v_tenant);
    v_reschedule_entry := public.build_reschedule_from_tenant(v_tenant);

    IF v_tenant_event_url IS NOT NULL THEN
      FOR v_apt_record IN
        SELECT id, event_link, booking_reschedules
        FROM public.apartments
        WHERE event_link IS NOT NULL
      LOOP
        IF NOT public.event_url_matches(v_tenant_event_url, v_apt_record.event_link) THEN
          CONTINUE;
        END IF;

        v_current_reschedules := COALESCE(v_apt_record.booking_reschedules, '[]'::jsonb);

        -- Deduplicate by tenant_id
        IF NOT EXISTS (
          SELECT 1 FROM jsonb_array_elements(v_current_reschedules) AS elem
          WHERE elem->>'tenant_id' = v_tenant.id::text
        ) THEN
          v_current_reschedules := v_current_reschedules || v_reschedule_entry;

          UPDATE public.apartments
          SET booking_reschedules = v_current_reschedules,
              updated_at = timezone('utc'::text, now())
          WHERE id = v_apt_record.id;
        END IF;
      END LOOP;
    END IF;
  END LOOP;

  RAISE NOTICE '[Backfill] Processed existing rescheduled tenants';
END;
$$;
