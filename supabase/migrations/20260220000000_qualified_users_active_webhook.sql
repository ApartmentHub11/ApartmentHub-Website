-- Migration: Webhook trigger when apartment status changes to Active
-- Triggers webhook exactly once when status changes to Active from Null or CreateLink

-- Enable pg_net extension if not already enabled
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_net;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_net extension not available. Webhook calls may not work.';
END $$;

-- ==========================================
-- Function: Send webhook when status changes to Active (from Null or CreateLink)
-- ==========================================

CREATE OR REPLACE FUNCTION public.send_qualified_user_active_webhook()
RETURNS TRIGGER AS $$
DECLARE
    v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';
    v_payload JSONB;
    v_new_status TEXT;
    v_old_status TEXT;
    v_apartment_json JSONB;
    v_agent_json JSONB;
    v_agent_id TEXT;
BEGIN
    -- Use direct column access (handles "status" or "Status" via record)
    v_new_status := NEW.status;
    v_apartment_json := to_jsonb(NEW);
    
    IF TG_OP = 'UPDATE' THEN
        v_old_status := OLD.status;
    ELSE
        v_old_status := NULL;
    END IF;

    -- Fire only when status CHANGES to Active (from Null, CreateLink, or any non-Active value)
    IF v_new_status = 'Active' AND (v_old_status IS NULL OR (v_old_status IS NOT NULL AND v_old_status <> 'Active')) THEN
        -- Get real estate agent info if available
        v_agent_id := COALESCE(
            v_apartment_json->>'real_estate_agent_id',
            v_apartment_json->>'Real Estate Agent Id'
        );
        
        IF v_agent_id IS NOT NULL AND v_agent_id != '' THEN
            SELECT to_jsonb(agents) INTO v_agent_json
            FROM public.real_estate_agents agents
            WHERE id = v_agent_id::uuid
            LIMIT 1;
        END IF;

        -- Build payload with apartment data + agent (qualified_users already in apartment)
        v_payload := jsonb_build_object(
            'event_type', 'status_changed_to_active',
            'trigger_operation', TG_OP,
            'apartment', v_apartment_json || jsonb_build_object(
                'real_estate_agent', COALESCE(v_agent_json, 'null'::jsonb)
            ),
            'timestamp', NOW()
        );

        -- Send webhook asynchronously (pg_net expects body as jsonb, not text)
        BEGIN
            PERFORM net.http_post(
                url := v_webhook_url,
                body := v_payload,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'User-Agent', 'Supabase-Webhook-Trigger'
                )
            );
            
            RAISE NOTICE '[Status Active Webhook] Sent for apartment % (status changed to Active)', 
                v_apartment_json->>'id';
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '[Status Active Webhook] Failed for apartment %: %', 
                v_apartment_json->>'id', SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.send_qualified_user_active_webhook() IS 
'Triggers webhook once when apartment status changes to Active from Null or CreateLink. Sends apartment data, agent info, and all qualified users. Webhook URL: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';

-- ==========================================
-- Create Trigger
-- ==========================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_qualified_user_active_webhook ON public.apartments;

-- Create trigger that fires on INSERT or UPDATE OF status
-- Ensures trigger runs whenever status column is modified
CREATE TRIGGER trigger_qualified_user_active_webhook
    AFTER INSERT OR UPDATE OF status ON public.apartments
    FOR EACH ROW
    EXECUTE FUNCTION public.send_qualified_user_active_webhook();
