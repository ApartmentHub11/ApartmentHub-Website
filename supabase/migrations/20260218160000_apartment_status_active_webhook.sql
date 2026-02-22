-- Migration: Webhook trigger for apartment status change to Active
-- Triggers webhook when apartment status changes to 'Active'
-- Sends all apartment info and list of shortlisted tenants matched based on tags

-- Enable pg_net extension for async HTTP requests (recommended for Supabase)
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_net;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_net extension not available. Webhook calls may not work. Consider using Edge Functions instead.';
END $$;

-- Function to find matched tenants based on tags
CREATE OR REPLACE FUNCTION public.get_matched_tenants_for_apartment(p_apartment_id UUID, p_apartment_tags TEXT[])
RETURNS JSONB AS $$
DECLARE
    v_matched_accounts JSONB;
BEGIN
    -- Find accounts where tags overlap with apartment tags
    -- Using array overlap operator (&&) to find any matching tags
    -- Only match if both apartment and account have tags, and they overlap
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'account_id', id,
            'tenant_name', tenant_name,
            'whatsapp_number', whatsapp_number,
            'email', email,
            'tags', tags,
            'preferred_location', preferred_location,
            'move_in_date', move_in_date,
            'work_status', work_status,
            'monthly_income', monthly_income,
            'salesforce_account_id', salesforce_account_id,
            'status', status,
            'documentation_status', documentation_status
        )
    ), '[]'::jsonb)
    INTO v_matched_accounts
    FROM public.accounts
    WHERE 
        -- Both apartment and account must have tags, and they must overlap
        (p_apartment_tags IS NOT NULL AND array_length(p_apartment_tags, 1) > 0)
        AND (tags IS NOT NULL AND array_length(tags, 1) > 0)
        AND (tags && p_apartment_tags);

    RETURN v_matched_accounts;
END;
$$ LANGUAGE plpgsql;

-- Function to call webhook when apartment status changes to Active
CREATE OR REPLACE FUNCTION public.trigger_apartment_status_active_webhook()
RETURNS TRIGGER AS $$
DECLARE
    v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';
    v_payload JSONB;
    v_apartment_data JSONB;
    v_matched_tenants JSONB;
    v_real_estate_agent JSONB;
BEGIN
    -- Only trigger when status changes to 'Active'
    IF NEW.status = 'Active' AND (OLD.status IS NULL OR OLD.status != 'Active') THEN
        
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
        v_apartment_data := to_jsonb(NEW) || jsonb_build_object(
            'real_estate_agent', v_real_estate_agent
        );

        -- Get matched tenants based on tags
        v_matched_tenants := public.get_matched_tenants_for_apartment(NEW.id, NEW.tags);

        -- Build complete payload with apartment and matched tenants
        v_payload := jsonb_build_object(
            'event_type', 'apartment_status_active',
            'apartment', v_apartment_data,
            'matched_tenants', v_matched_tenants,
            'matched_tenants_count', jsonb_array_length(v_matched_tenants),
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
DROP TRIGGER IF EXISTS trigger_apartment_status_active_webhook ON public.apartments;
CREATE TRIGGER trigger_apartment_status_active_webhook
    AFTER INSERT OR UPDATE OF status ON public.apartments
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_apartment_status_active_webhook();

-- Comment on functions
COMMENT ON FUNCTION public.get_matched_tenants_for_apartment(UUID, TEXT[]) IS 
'Returns accounts/tenants that match apartment tags. Uses array overlap operator (&&) to find accounts with matching tags.';

COMMENT ON FUNCTION public.trigger_apartment_status_active_webhook() IS 
'Triggers webhook when apartment status changes to Active. Sends all apartment info and list of shortlisted tenants matched based on tags. Webhook URL: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';
