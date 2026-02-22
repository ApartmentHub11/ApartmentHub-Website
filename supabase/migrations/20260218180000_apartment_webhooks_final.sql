-- Final Webhook Functions for Apartment Status Changes
-- These functions trigger when apartment status changes and send ALL apartment details to webhooks
-- Works with any column name format (Status, status, etc.)

-- Enable pg_net extension
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_net;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_net extension not available. Webhook calls may not work.';
END $$;

-- ==========================================
-- Function 1: CreateLink Webhook
-- Triggers when status changes to 'CreateLink'
-- Sends ALL apartment table data
-- ==========================================

CREATE OR REPLACE FUNCTION public.send_create_link_webhook()
RETURNS TRIGGER AS $$
DECLARE
    v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    v_payload JSONB;
    v_new_status TEXT;
    v_old_status TEXT;
    v_apartment_json JSONB;
    v_agent_json JSONB;
    v_agent_id TEXT;
BEGIN
    -- Get status from NEW row (works with "Status" or "status" column)
    v_apartment_json := to_jsonb(NEW);
    v_new_status := COALESCE(v_apartment_json->>'Status', v_apartment_json->>'status');
    
    -- Get old status if UPDATE
    IF TG_OP = 'UPDATE' THEN
        v_old_status := COALESCE(to_jsonb(OLD)->>'Status', to_jsonb(OLD)->>'status');
    ELSE
        v_old_status := NULL;
    END IF;

    -- Only trigger when status changes to 'CreateLink'
    IF v_new_status = 'CreateLink' AND (v_old_status IS NULL OR v_old_status != 'CreateLink') THEN
        
        -- Get real estate agent info if available
        v_agent_id := COALESCE(
            v_apartment_json->>'real_estate_agent_id',
            v_apartment_json->>'Real Estate Agent Id',
            v_apartment_json->>'real_estate_agent_id'
        );
        
        IF v_agent_id IS NOT NULL AND v_agent_id != '' THEN
            SELECT to_jsonb(agents) INTO v_agent_json
            FROM public.real_estate_agents agents
            WHERE id = v_agent_id::uuid
            LIMIT 1;
        END IF;

        -- Build payload with ALL apartment data + agent info + timestamp
        v_payload := v_apartment_json || jsonb_build_object(
            'real_estate_agent', COALESCE(v_agent_json, 'null'::jsonb),
            'timestamp', NOW(),
            'event_type', 'apartment_status_create_link',
            'trigger_operation', TG_OP
        );

        -- Send webhook asynchronously
        BEGIN
            PERFORM net.http_post(
                url := v_webhook_url,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'User-Agent', 'Supabase-Webhook-Trigger'
                ),
                body := v_payload::text
            );
            
            RAISE NOTICE '[CreateLink Webhook] Sent for apartment %', v_apartment_json->>'id';
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '[CreateLink Webhook] Failed for apartment %: %', 
                v_apartment_json->>'id', SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- Function 2: Active Webhook
-- Triggers when status changes to 'Active'
-- Sends ALL apartment data + matched tenants
-- ==========================================

CREATE OR REPLACE FUNCTION public.send_active_webhook()
RETURNS TRIGGER AS $$
DECLARE
    v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';
    v_payload JSONB;
    v_new_status TEXT;
    v_old_status TEXT;
    v_apartment_json JSONB;
    v_agent_json JSONB;
    v_agent_id TEXT;
    v_matched_tenants JSONB;
    v_tags_array TEXT[];
    v_tags_json JSONB;
BEGIN
    -- Get status from NEW row
    v_apartment_json := to_jsonb(NEW);
    v_new_status := COALESCE(v_apartment_json->>'Status', v_apartment_json->>'status');
    
    -- Get old status if UPDATE
    IF TG_OP = 'UPDATE' THEN
        v_old_status := COALESCE(to_jsonb(OLD)->>'Status', to_jsonb(OLD)->>'status');
    ELSE
        v_old_status := NULL;
    END IF;

    -- Only trigger when status changes to 'Active'
    IF v_new_status = 'Active' AND (v_old_status IS NULL OR v_old_status != 'Active') THEN
        
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

        -- Extract tags array for matching
        v_tags_json := v_apartment_json->'tags';
        IF v_tags_json IS NOT NULL AND v_tags_json != 'null'::jsonb AND jsonb_typeof(v_tags_json) = 'array' THEN
            SELECT ARRAY(SELECT jsonb_array_elements_text(v_tags_json)) INTO v_tags_array;
        ELSE
            v_tags_array := NULL;
        END IF;

        -- Get matched tenants based on tags
        v_matched_tenants := public.get_matched_tenants_for_apartment(
            (v_apartment_json->>'id')::uuid,
            v_tags_array
        );

        -- Build payload with ALL apartment data + agent + matched tenants
        v_payload := jsonb_build_object(
            'event_type', 'apartment_status_active',
            'trigger_operation', TG_OP,
            'apartment', v_apartment_json || jsonb_build_object(
                'real_estate_agent', COALESCE(v_agent_json, 'null'::jsonb)
            ),
            'matched_tenants', v_matched_tenants,
            'matched_tenants_count', jsonb_array_length(v_matched_tenants),
            'timestamp', NOW()
        );

        -- Send webhook asynchronously
        BEGIN
            PERFORM net.http_post(
                url := v_webhook_url,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'User-Agent', 'Supabase-Webhook-Trigger'
                ),
                body := v_payload::text
            );
            
            RAISE NOTICE '[Active Webhook] Sent for apartment % with % matched tenants', 
                v_apartment_json->>'id', jsonb_array_length(v_matched_tenants);
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '[Active Webhook] Failed for apartment %: %', 
                v_apartment_json->>'id', SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- Create Triggers
-- ==========================================

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS trigger_apartment_create_link_webhook ON public.apartments;
DROP TRIGGER IF EXISTS trigger_apartment_active_webhook ON public.apartments;
DROP TRIGGER IF EXISTS trigger_apartment_status_create_link_webhook ON public.apartments;
DROP TRIGGER IF EXISTS trigger_apartment_status_active_webhook ON public.apartments;

-- Create new triggers that fire on INSERT or UPDATE
CREATE TRIGGER trigger_apartment_create_link_webhook
    AFTER INSERT OR UPDATE ON public.apartments
    FOR EACH ROW
    EXECUTE FUNCTION public.send_create_link_webhook();

CREATE TRIGGER trigger_apartment_active_webhook
    AFTER INSERT OR UPDATE ON public.apartments
    FOR EACH ROW
    EXECUTE FUNCTION public.send_active_webhook();

-- ==========================================
-- Comments
-- ==========================================

COMMENT ON FUNCTION public.send_create_link_webhook() IS 
'Sends webhook when apartment status changes to CreateLink. Includes ALL apartment table columns.';

COMMENT ON FUNCTION public.send_active_webhook() IS 
'Sends webhook when apartment status changes to Active. Includes ALL apartment table columns + matched tenants based on tags.';
