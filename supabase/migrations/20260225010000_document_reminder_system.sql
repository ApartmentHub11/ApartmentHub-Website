-- Migration: Persistent Document Upload Reminder System
--
-- Creates a server-side reminder system using pg_cron that sends webhooks
-- at 15min, 4hrs, 17hrs, and 40hrs after account creation if documents
-- are not yet uploaded. Works even when user logs out or closes browser.
--
-- Components:
-- 1. document_reminders table
-- 2. Trigger to schedule reminders on new accounts/dossiers
-- 3. pg_cron job to process due reminders every 5 minutes
-- 4. Webhook sends to n8n for WhatsApp notification delivery

-- ==========================================
-- 0. Enable required extensions
-- ==========================================
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_net;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_net extension not available. Webhook calls may not work.';
END $$;

DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron extension not available. Scheduled reminders will not work.';
END $$;

-- ==========================================
-- 1. Create document_reminders table
-- ==========================================
CREATE TABLE IF NOT EXISTS public.document_reminders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Who to remind
    account_id UUID REFERENCES public.accounts(id) ON DELETE CASCADE,
    dossier_id UUID,
    phone_number TEXT NOT NULL,
    
    -- Scheduling
    reminder_interval TEXT NOT NULL,  -- '15min', '4hr', '17hr', '40hr'
    scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL,  -- When this reminder should fire
    
    -- Status tracking
    sent_at TIMESTAMP WITH TIME ZONE,      -- NULL = not yet sent
    skipped_at TIMESTAMP WITH TIME ZONE,   -- NULL = not skipped (set when docs already complete)
    webhook_response TEXT,                  -- Response from webhook call (for debugging)
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Indexes for efficient processing
CREATE INDEX IF NOT EXISTS idx_document_reminders_due 
    ON public.document_reminders(scheduled_at) 
    WHERE sent_at IS NULL AND skipped_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_document_reminders_account 
    ON public.document_reminders(account_id);

CREATE INDEX IF NOT EXISTS idx_document_reminders_phone 
    ON public.document_reminders(phone_number);

-- RLS
ALTER TABLE public.document_reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role full access for document_reminders" ON public.document_reminders;
CREATE POLICY "Service role full access for document_reminders" 
    ON public.document_reminders 
    FOR ALL 
    USING (true);

COMMENT ON TABLE public.document_reminders IS 
'Scheduled reminders for document uploads. Rows are created when an account is created and processed by pg_cron. Reminders at 15min, 4hrs, 17hrs, and 40hrs after creation.';

-- ==========================================
-- 2. Function to schedule reminders for an account
-- ==========================================
CREATE OR REPLACE FUNCTION public.schedule_document_reminders()
RETURNS TRIGGER AS $$
DECLARE
    v_phone TEXT;
    v_account_id UUID;
    v_dossier_id UUID;
    v_now TIMESTAMP WITH TIME ZONE := NOW();
BEGIN
    -- Get the relevant data depending on which table fired
    IF TG_TABLE_NAME = 'accounts' THEN
        v_phone := NEW.whatsapp_number;
        v_account_id := NEW.id;
        
        -- Try to find a linked dossier
        SELECT id INTO v_dossier_id
        FROM public.dossiers
        WHERE phone_number = v_phone 
           OR REPLACE(phone_number, ' ', '') = REPLACE(v_phone, ' ', '')
        LIMIT 1;
        
    ELSIF TG_TABLE_NAME = 'dossiers' THEN
        v_phone := NEW.phone_number;
        v_dossier_id := NEW.id;
        
        -- Try to find a linked account
        SELECT id INTO v_account_id
        FROM public.accounts
        WHERE whatsapp_number = v_phone
           OR REPLACE(whatsapp_number, ' ', '') = REPLACE(v_phone, ' ', '')
        LIMIT 1;
    ELSE
        RETURN NEW;
    END IF;
    
    -- Don't schedule if no phone number
    IF v_phone IS NULL OR v_phone = '' THEN
        RETURN NEW;
    END IF;
    
    -- Don't schedule duplicate reminders for the same phone number
    IF EXISTS (
        SELECT 1 FROM public.document_reminders 
        WHERE phone_number = v_phone 
          AND sent_at IS NULL 
          AND skipped_at IS NULL
        LIMIT 1
    ) THEN
        RETURN NEW;
    END IF;
    
    -- Insert 4 reminder rows at the specified intervals
    INSERT INTO public.document_reminders 
        (account_id, dossier_id, phone_number, reminder_interval, scheduled_at)
    VALUES
        (v_account_id, v_dossier_id, v_phone, '15min',  v_now + INTERVAL '15 minutes'),
        (v_account_id, v_dossier_id, v_phone, '4hr',    v_now + INTERVAL '4 hours'),
        (v_account_id, v_dossier_id, v_phone, '17hr',   v_now + INTERVAL '17 hours'),
        (v_account_id, v_dossier_id, v_phone, '40hr',   v_now + INTERVAL '40 hours');
    
    RAISE LOG '[DocumentReminders] Scheduled 4 reminders for phone=% account=% dossier=%', 
        v_phone, v_account_id, v_dossier_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.schedule_document_reminders() IS 
'Trigger function that schedules 4 document upload reminders at 15min, 4hr, 17hr, and 40hr after account/dossier creation.';

-- ==========================================
-- 3. Triggers to schedule reminders
-- ==========================================

-- On new account creation
DROP TRIGGER IF EXISTS trigger_schedule_doc_reminders_on_account ON public.accounts;
CREATE TRIGGER trigger_schedule_doc_reminders_on_account
    AFTER INSERT ON public.accounts
    FOR EACH ROW
    EXECUTE FUNCTION public.schedule_document_reminders();

-- On new dossier creation
DROP TRIGGER IF EXISTS trigger_schedule_doc_reminders_on_dossier ON public.dossiers;
CREATE TRIGGER trigger_schedule_doc_reminders_on_dossier
    AFTER INSERT ON public.dossiers
    FOR EACH ROW
    EXECUTE FUNCTION public.schedule_document_reminders();

-- ==========================================
-- 4. Function to process due reminders (called by pg_cron)
-- ==========================================
CREATE OR REPLACE FUNCTION public.process_document_reminders()
RETURNS void AS $$
DECLARE
    v_reminder RECORD;
    v_doc_status TEXT;
    v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/document-upload-reminder';
    v_payload JSONB;
    v_tenant_name TEXT;
BEGIN
    -- Process all due, unsent, unskipped reminders
    FOR v_reminder IN
        SELECT r.*
        FROM public.document_reminders r
        WHERE r.sent_at IS NULL
          AND r.skipped_at IS NULL
          AND r.scheduled_at <= NOW()
        ORDER BY r.scheduled_at ASC
        LIMIT 50  -- Process at most 50 per run to avoid long transactions
    LOOP
        -- Check current documentation_status for this account/phone
        v_doc_status := NULL;
        v_tenant_name := NULL;
        
        IF v_reminder.account_id IS NOT NULL THEN
            SELECT documentation_status, tenant_name 
            INTO v_doc_status, v_tenant_name
            FROM public.accounts
            WHERE id = v_reminder.account_id;
        ELSE
            -- Fall back to phone number lookup
            SELECT documentation_status, tenant_name
            INTO v_doc_status, v_tenant_name
            FROM public.accounts
            WHERE whatsapp_number = v_reminder.phone_number
               OR REPLACE(whatsapp_number, ' ', '') = REPLACE(v_reminder.phone_number, ' ', '')
            LIMIT 1;
        END IF;
        
        -- If documents are already complete, skip this reminder
        IF v_doc_status = 'Complete' THEN
            UPDATE public.document_reminders
            SET skipped_at = NOW(),
                webhook_response = 'Skipped: documentation already complete'
            WHERE id = v_reminder.id;
            
            RAISE LOG '[DocumentReminders] Skipped reminder % (%) for phone=%: docs complete', 
                v_reminder.id, v_reminder.reminder_interval, v_reminder.phone_number;
            CONTINUE;
        END IF;
        
        -- Build webhook payload
        v_payload := jsonb_build_object(
            'event_type', 'document_reminder',
            'reminder_id', v_reminder.id,
            'account_id', v_reminder.account_id,
            'dossier_id', v_reminder.dossier_id,
            'phone_number', v_reminder.phone_number,
            'tenant_name', COALESCE(v_tenant_name, ''),
            'reminder_interval', v_reminder.reminder_interval,
            'documentation_status', COALESCE(v_doc_status, 'Pending'),
            'scheduled_at', v_reminder.scheduled_at,
            'created_at', v_reminder.created_at,
            'timestamp', NOW()
        );
        
        -- Send webhook via pg_net
        BEGIN
            PERFORM net.http_post(
                url := v_webhook_url,
                body := v_payload,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'User-Agent', 'Supabase-Document-Reminder'
                )
            );
            
            -- Mark as sent
            UPDATE public.document_reminders
            SET sent_at = NOW(),
                webhook_response = 'Sent successfully'
            WHERE id = v_reminder.id;
            
            RAISE LOG '[DocumentReminders] Sent reminder % (%) for phone=%', 
                v_reminder.id, v_reminder.reminder_interval, v_reminder.phone_number;
                
        EXCEPTION WHEN OTHERS THEN
            -- Mark the attempt but don't block other reminders
            UPDATE public.document_reminders
            SET webhook_response = 'Error: ' || SQLERRM
            WHERE id = v_reminder.id;
            
            RAISE WARNING '[DocumentReminders] Failed to send reminder % for phone=%: %', 
                v_reminder.id, v_reminder.phone_number, SQLERRM;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.process_document_reminders() IS 
'Processes due document upload reminders. Called by pg_cron every 5 minutes. Checks documentation_status before sending - skips if already Complete. Sends webhook to n8n for WhatsApp delivery.';

-- ==========================================
-- 5. Schedule the pg_cron job
-- ==========================================
-- Run every 5 minutes
DO $$
BEGIN
    -- Remove existing job if present
    PERFORM cron.unschedule('process-document-reminders');
EXCEPTION WHEN OTHERS THEN
    -- Job doesn't exist yet, that's fine
    NULL;
END $$;

SELECT cron.schedule(
    'process-document-reminders',
    '*/5 * * * *',
    'SELECT public.process_document_reminders()'
);

-- ==========================================
-- 6. Comments
-- ==========================================
COMMENT ON TABLE public.document_reminders IS 
'Scheduled document upload reminders. Created on account/dossier insert. Processed by pg_cron every 5 minutes. Reminders at: 15 minutes, 4 hours, 17 hours, and 40 hours after creation.';
