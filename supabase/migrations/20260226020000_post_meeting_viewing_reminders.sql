-- Migration: Post-Meeting Viewing Reminders
--
-- Sends reminders at 15min, 4hrs, 17hrs, and 40hrs AFTER a viewing meeting
-- ends (based on viewing_end_time). These are separate from the document
-- upload reminders (which fire after account creation).
--
-- Components:
-- 1. viewing_reminders table
-- 2. Trigger to schedule reminders when a tenant gets a booking/viewing
-- 3. pg_cron job to process due viewing reminders every 5 minutes

-- ==========================================
-- 1. Create viewing_reminders table
-- ==========================================
CREATE TABLE IF NOT EXISTS public.viewing_reminders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Who to remind
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    account_id UUID REFERENCES public.accounts(id) ON DELETE SET NULL,
    phone_number TEXT NOT NULL,
    tenant_name TEXT,

    -- Viewing details
    apartment_id UUID REFERENCES public.apartments(id) ON DELETE SET NULL,
    viewing_end_time TIMESTAMP WITH TIME ZONE NOT NULL,

    -- Scheduling
    reminder_interval TEXT NOT NULL,  -- '15min', '4hr', '17hr', '40hr'
    scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL,  -- When this reminder should fire

    -- Status tracking
    sent_at TIMESTAMP WITH TIME ZONE,      -- NULL = not yet sent
    skipped_at TIMESTAMP WITH TIME ZONE,   -- NULL = not skipped
    webhook_response TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_viewing_reminders_due
    ON public.viewing_reminders(scheduled_at)
    WHERE sent_at IS NULL AND skipped_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_viewing_reminders_tenant
    ON public.viewing_reminders(tenant_id);

CREATE INDEX IF NOT EXISTS idx_viewing_reminders_phone
    ON public.viewing_reminders(phone_number);

-- RLS
ALTER TABLE public.viewing_reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role full access for viewing_reminders" ON public.viewing_reminders;
CREATE POLICY "Service role full access for viewing_reminders"
    ON public.viewing_reminders
    FOR ALL
    USING (true);

COMMENT ON TABLE public.viewing_reminders IS
'Scheduled post-viewing-meeting reminders. Created after a viewing ends. Processed by pg_cron every 5 minutes. Reminders at: 15min, 4hr, 17hr, and 40hr after viewing_end_time.';

-- ==========================================
-- 1b. Helper to safely parse a text value as timestamptz
-- ==========================================
-- Returns NULL on failure (e.g. time-only values like '07:30:00')
CREATE OR REPLACE FUNCTION public._safe_parse_timestamptz(p_val TEXT)
RETURNS TIMESTAMP WITH TIME ZONE AS $$
BEGIN
    IF p_val IS NULL OR p_val = '' THEN
        RETURN NULL;
    END IF;
    RETURN p_val::timestamptz;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ==========================================
-- 2. Function to schedule viewing reminders for a tenant
-- ==========================================
CREATE OR REPLACE FUNCTION public.schedule_viewing_reminders()
RETURNS TRIGGER AS $$
DECLARE
    v_phone TEXT;
    v_tenant_name TEXT;
    v_end_time TIMESTAMP WITH TIME ZONE;
    v_row jsonb;
    v_account_id UUID;
    v_phone_norm TEXT;
BEGIN
    v_row := to_jsonb(NEW);
    v_phone := NEW.whatsapp_number;
    v_tenant_name := NEW.name;

    -- Don't schedule if no phone number
    IF v_phone IS NULL OR v_phone = '' THEN
        RETURN NEW;
    END IF;

    -- Extract viewing end time safely (handles time-only values like '07:30:00')
    v_end_time := public._safe_parse_timestamptz(
        COALESCE(v_row->>'Viewing_EndTime', v_row->>'viewing_end_time')
    );

    -- Can't schedule without an end time
    IF v_end_time IS NULL THEN
        RETURN NEW;
    END IF;

    -- Don't schedule for past viewings that are more than 41 hours ago
    IF v_end_time < (NOW() - INTERVAL '41 hours') THEN
        RETURN NEW;
    END IF;

    -- Look up the account for this tenant
    v_phone_norm := public.normalize_phone_for_match(v_phone);
    SELECT id INTO v_account_id
    FROM public.accounts
    WHERE public.normalize_phone_for_match(whatsapp_number) = v_phone_norm
    LIMIT 1;

    -- Don't schedule duplicate reminders for the same tenant + viewing
    IF EXISTS (
        SELECT 1 FROM public.viewing_reminders
        WHERE tenant_id = NEW.id
          AND viewing_end_time = v_end_time
          AND sent_at IS NULL
          AND skipped_at IS NULL
        LIMIT 1
    ) THEN
        RETURN NEW;
    END IF;

    -- Insert 4 reminder rows at intervals after the viewing ends
    INSERT INTO public.viewing_reminders
        (tenant_id, account_id, phone_number, tenant_name, apartment_id,
         viewing_end_time, reminder_interval, scheduled_at)
    VALUES
        (NEW.id, v_account_id, v_phone, v_tenant_name, NEW.apartment_id,
         v_end_time, '15min',  v_end_time + INTERVAL '15 minutes'),
        (NEW.id, v_account_id, v_phone, v_tenant_name, NEW.apartment_id,
         v_end_time, '4hr',    v_end_time + INTERVAL '4 hours'),
        (NEW.id, v_account_id, v_phone, v_tenant_name, NEW.apartment_id,
         v_end_time, '17hr',   v_end_time + INTERVAL '17 hours'),
        (NEW.id, v_account_id, v_phone, v_tenant_name, NEW.apartment_id,
         v_end_time, '40hr',   v_end_time + INTERVAL '40 hours');

    RAISE LOG '[ViewingReminders] Scheduled 4 post-meeting reminders for tenant=% phone=% end_time=%',
        NEW.id, v_phone, v_end_time;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.schedule_viewing_reminders() IS
'Trigger function that schedules 4 post-viewing reminders at 15min, 4hr, 17hr, and 40hr after the viewing ends.';

-- ==========================================
-- 3. Triggers on tenants table
-- ==========================================
-- On new tenant insert (if they already have viewing times)
DROP TRIGGER IF EXISTS trigger_schedule_viewing_reminders_insert ON public.tenants;
CREATE TRIGGER trigger_schedule_viewing_reminders_insert
    AFTER INSERT ON public.tenants
    FOR EACH ROW
    EXECUTE FUNCTION public.schedule_viewing_reminders();

-- On tenant update (when viewing times are added/changed)
DROP TRIGGER IF EXISTS trigger_schedule_viewing_reminders_update ON public.tenants;
CREATE TRIGGER trigger_schedule_viewing_reminders_update
    AFTER UPDATE ON public.tenants
    FOR EACH ROW
    EXECUTE FUNCTION public.schedule_viewing_reminders();

-- ==========================================
-- 4. Function to process due viewing reminders (called by pg_cron)
-- ==========================================
CREATE OR REPLACE FUNCTION public.process_viewing_reminders()
RETURNS void AS $$
DECLARE
    v_reminder RECORD;
    v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/post-viewing-reminder';
    v_payload JSONB;
    v_apt_address TEXT;
    v_cancelled BOOLEAN;
BEGIN
    FOR v_reminder IN
        SELECT r.*
        FROM public.viewing_reminders r
        WHERE r.sent_at IS NULL
          AND r.skipped_at IS NULL
          AND r.scheduled_at <= NOW()
        ORDER BY r.scheduled_at ASC
        LIMIT 50
    LOOP
        -- Check if the tenant's viewing was cancelled
        v_cancelled := false;
        IF v_reminder.tenant_id IS NOT NULL THEN
            SELECT COALESCE("anyCancellation ?", false)
            INTO v_cancelled
            FROM public.tenants
            WHERE id = v_reminder.tenant_id;
        END IF;

        -- Skip if viewing was cancelled
        IF v_cancelled THEN
            UPDATE public.viewing_reminders
            SET skipped_at = NOW(),
                webhook_response = 'Skipped: viewing was cancelled'
            WHERE id = v_reminder.id;

            RAISE LOG '[ViewingReminders] Skipped reminder % (%): viewing cancelled',
                v_reminder.id, v_reminder.reminder_interval;
            CONTINUE;
        END IF;

        -- Get apartment address for context
        v_apt_address := NULL;
        IF v_reminder.apartment_id IS NOT NULL THEN
            SELECT "Full Address" INTO v_apt_address
            FROM public.apartments
            WHERE id = v_reminder.apartment_id;
        END IF;

        -- Build webhook payload
        v_payload := jsonb_build_object(
            'event_type', 'viewing_reminder',
            'reminder_id', v_reminder.id,
            'tenant_id', v_reminder.tenant_id,
            'account_id', v_reminder.account_id,
            'phone_number', v_reminder.phone_number,
            'tenant_name', COALESCE(v_reminder.tenant_name, ''),
            'apartment_id', v_reminder.apartment_id,
            'apartment_address', COALESCE(v_apt_address, ''),
            'viewing_end_time', v_reminder.viewing_end_time,
            'reminder_interval', v_reminder.reminder_interval,
            'scheduled_at', v_reminder.scheduled_at,
            'timestamp', NOW()
        );

        -- Send webhook via pg_net
        BEGIN
            PERFORM net.http_post(
                url := v_webhook_url,
                body := v_payload,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'User-Agent', 'Supabase-Viewing-Reminder'
                )
            );

            UPDATE public.viewing_reminders
            SET sent_at = NOW(),
                webhook_response = 'Sent successfully'
            WHERE id = v_reminder.id;

            RAISE LOG '[ViewingReminders] Sent reminder % (%) for phone=%',
                v_reminder.id, v_reminder.reminder_interval, v_reminder.phone_number;

        EXCEPTION WHEN OTHERS THEN
            UPDATE public.viewing_reminders
            SET webhook_response = 'Error: ' || SQLERRM
            WHERE id = v_reminder.id;

            RAISE WARNING '[ViewingReminders] Failed to send reminder % for phone=%: %',
                v_reminder.id, v_reminder.phone_number, SQLERRM;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.process_viewing_reminders() IS
'Processes due post-viewing reminders. Called by pg_cron every 5 minutes. Skips cancelled viewings. Sends webhook to n8n for follow-up.';

-- ==========================================
-- 5. Schedule the pg_cron job
-- ==========================================
DO $$
BEGIN
    PERFORM cron.unschedule('process-viewing-reminders');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

SELECT cron.schedule(
    'process-viewing-reminders',
    '*/5 * * * *',
    'SELECT public.process_viewing_reminders()'
);

-- ==========================================
-- 6. Backfill: schedule reminders for existing tenants with viewing times
-- ==========================================


DO $$
DECLARE
    v_tenant RECORD;
    v_end_time TIMESTAMP WITH TIME ZONE;
    v_row jsonb;
    v_phone_norm TEXT;
    v_account_id UUID;
BEGIN
    FOR v_tenant IN
        SELECT * FROM public.tenants
        WHERE whatsapp_number IS NOT NULL
          AND trim(whatsapp_number) != ''
    LOOP
        v_row := to_jsonb(v_tenant);

        -- Safely parse viewing end time (handles time-only values like '07:30:00')
        v_end_time := public._safe_parse_timestamptz(
            COALESCE(v_row->>'Viewing_EndTime', v_row->>'viewing_end_time')
        );

        -- Skip if no end time or if viewing ended more than 41 hours ago
        IF v_end_time IS NULL OR v_end_time < (NOW() - INTERVAL '41 hours') THEN
            CONTINUE;
        END IF;

        -- Skip if already has reminders for this viewing
        IF EXISTS (
            SELECT 1 FROM public.viewing_reminders
            WHERE tenant_id = v_tenant.id
              AND viewing_end_time = v_end_time
            LIMIT 1
        ) THEN
            CONTINUE;
        END IF;

        -- Look up account
        v_phone_norm := public.normalize_phone_for_match(v_tenant.whatsapp_number);
        SELECT id INTO v_account_id
        FROM public.accounts
        WHERE public.normalize_phone_for_match(whatsapp_number) = v_phone_norm
        LIMIT 1;

        INSERT INTO public.viewing_reminders
            (tenant_id, account_id, phone_number, tenant_name, apartment_id,
             viewing_end_time, reminder_interval, scheduled_at)
        VALUES
            (v_tenant.id, v_account_id, v_tenant.whatsapp_number, v_tenant.name,
             v_tenant.apartment_id, v_end_time, '15min', v_end_time + INTERVAL '15 minutes'),
            (v_tenant.id, v_account_id, v_tenant.whatsapp_number, v_tenant.name,
             v_tenant.apartment_id, v_end_time, '4hr', v_end_time + INTERVAL '4 hours'),
            (v_tenant.id, v_account_id, v_tenant.whatsapp_number, v_tenant.name,
             v_tenant.apartment_id, v_end_time, '17hr', v_end_time + INTERVAL '17 hours'),
            (v_tenant.id, v_account_id, v_tenant.whatsapp_number, v_tenant.name,
             v_tenant.apartment_id, v_end_time, '40hr', v_end_time + INTERVAL '40 hours');
    END LOOP;

    RAISE NOTICE '[ViewingReminders] Backfilled post-meeting reminders for existing tenants';
END;
$$;

COMMENT ON TABLE public.viewing_reminders IS
'Post-viewing-meeting reminders. Scheduled when a tenant gets a viewing. Processed by pg_cron every 5 minutes. Sends webhooks at 15min, 4hr, 17hr, 40hr after the viewing ends. Skips cancelled viewings.';
