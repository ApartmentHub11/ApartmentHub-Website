-- Migration: Webhook trigger for apartment status change to CreateLink
-- Triggers webhook when apartment status changes to 'CreateLink'
-- Sends all apartment table data to the webhook

-- Enable pg_net extension for async HTTP requests (recommended for Supabase)
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_net;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_net extension not available. Webhook calls may not work. Consider using Edge Functions instead.';
END $$;

-- Function to call webhook when apartment status changes to CreateLink
CREATE OR REPLACE FUNCTION public.trigger_apartment_status_create_link_webhook()
RETURNS TRIGGER AS $$
DECLARE
    v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    v_payload JSONB;
    v_real_estate_agent JSONB;
BEGIN
    -- Only trigger when status changes to 'CreateLink'
    IF NEW.status = 'CreateLink' AND (OLD.status IS NULL OR OLD.status != 'CreateLink') THEN
        
        -- Get real estate agent info if available
        SELECT jsonb_build_object(
            'id', id,
            'name', name,
            'phone_number', phone_number,
            'picture_url', picture_url
        )
        INTO v_real_estate_agent
        FROM public.real_estate_agents
        WHERE id = NEW.real_estate_agent_id;

        -- Send ALL apartment columns automatically + agent info
        v_payload := to_jsonb(NEW) || jsonb_build_object(
            'real_estate_agent', v_real_estate_agent,
            'timestamp', NOW()
        );

        -- Call webhook asynchronously using pg_net (non-blocking)
        BEGIN
            PERFORM net.http_post(
                url := v_webhook_url,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json'
                ),
                body := v_payload::text
            );
        EXCEPTION WHEN OTHERS THEN
            -- Log error but don't fail the transaction
            RAISE WARNING 'Webhook call failed for apartment %: %', NEW.id, SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on apartments table for status changes
DROP TRIGGER IF EXISTS trigger_apartment_status_create_link_webhook ON public.apartments;
CREATE TRIGGER trigger_apartment_status_create_link_webhook
    AFTER INSERT OR UPDATE OF status ON public.apartments
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_apartment_status_create_link_webhook();

-- Comment on function
COMMENT ON FUNCTION public.trigger_apartment_status_create_link_webhook() IS 
'Triggers webhook when apartment status changes to CreateLink. Sends all apartment table data to the webhook. Webhook URL: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
