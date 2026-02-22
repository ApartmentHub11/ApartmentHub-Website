-- Apply the webhook fix and test immediately
-- Run this ENTIRE script in Supabase SQL Editor

-- ==========================================
-- STEP 1: Apply the fix migration
-- ==========================================

-- 1) CreateLink webhook function (status-agnostic)
CREATE OR REPLACE FUNCTION public.trigger_apartment_status_create_link_webhook()
RETURNS TRIGGER AS $$
DECLARE
    v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    v_payload JSONB;
    v_real_estate_agent JSONB;
    v_new_status TEXT;
    v_old_status TEXT;
BEGIN
    v_new_status := COALESCE(to_jsonb(NEW)->>'Status', to_jsonb(NEW)->>'status');
    IF TG_OP = 'INSERT' THEN
        v_old_status := NULL;
    ELSE
        v_old_status := COALESCE(to_jsonb(OLD)->>'Status', to_jsonb(OLD)->>'status');
    END IF;

    IF v_new_status = 'CreateLink' AND (v_old_status IS NULL OR v_old_status != 'CreateLink') THEN
        IF (COALESCE(to_jsonb(NEW)->>'real_estate_agent_id', to_jsonb(NEW)->>'Real Estate Agent Id')) IS NOT NULL AND (COALESCE(to_jsonb(NEW)->>'real_estate_agent_id', to_jsonb(NEW)->>'Real Estate Agent Id')) != '' THEN
            SELECT jsonb_build_object(
                'id', id,
                'name', name,
                'phone_number', phone_number,
                'picture_url', picture_url
            )
            INTO v_real_estate_agent
            FROM public.real_estate_agents
            WHERE id = (COALESCE(to_jsonb(NEW)->>'real_estate_agent_id', to_jsonb(NEW)->>'Real Estate Agent Id'))::uuid;
        END IF;

        v_payload := to_jsonb(NEW) || jsonb_build_object(
            'real_estate_agent', v_real_estate_agent,
            'timestamp', NOW()
        );

        BEGIN
            PERFORM net.http_post(
                url := v_webhook_url,
                headers := jsonb_build_object('Content-Type', 'application/json'),
                body := v_payload::text
            );
            RAISE NOTICE '✅ Webhook sent to CreateLink endpoint';
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '❌ Webhook call failed for apartment %: %', (to_jsonb(NEW)->>'id'), SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2) Active webhook function (status-agnostic)
CREATE OR REPLACE FUNCTION public.trigger_apartment_status_active_webhook()
RETURNS TRIGGER AS $$
DECLARE
    v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';
    v_payload JSONB;
    v_apartment_data JSONB;
    v_matched_tenants JSONB;
    v_real_estate_agent JSONB;
    v_new_status TEXT;
    v_old_status TEXT;
    v_apt_tags TEXT[];
BEGIN
    v_new_status := COALESCE(to_jsonb(NEW)->>'Status', to_jsonb(NEW)->>'status');
    IF TG_OP = 'INSERT' THEN
        v_old_status := NULL;
    ELSE
        v_old_status := COALESCE(to_jsonb(OLD)->>'Status', to_jsonb(OLD)->>'status');
    END IF;

    IF v_new_status = 'Active' AND (v_old_status IS NULL OR v_old_status != 'Active') THEN
        IF (COALESCE(to_jsonb(NEW)->>'real_estate_agent_id', to_jsonb(NEW)->>'Real Estate Agent Id')) IS NOT NULL AND (COALESCE(to_jsonb(NEW)->>'real_estate_agent_id', to_jsonb(NEW)->>'Real Estate Agent Id')) != '' THEN
            SELECT jsonb_build_object(
                'id', id,
                'name', name,
                'phone_number', phone_number,
                'picture_url', picture_url
            )
            INTO v_real_estate_agent
            FROM public.real_estate_agents
            WHERE id = (COALESCE(to_jsonb(NEW)->>'real_estate_agent_id', to_jsonb(NEW)->>'Real Estate Agent Id'))::uuid;
        END IF;

        v_apartment_data := to_jsonb(NEW) || jsonb_build_object('real_estate_agent', v_real_estate_agent);

        IF to_jsonb(NEW)->'tags' IS NOT NULL AND to_jsonb(NEW)->'tags' != 'null'::jsonb THEN
            v_apt_tags := ARRAY(SELECT jsonb_array_elements_text(to_jsonb(NEW)->'tags'));
        ELSE
            v_apt_tags := NULL;
        END IF;
        v_matched_tenants := public.get_matched_tenants_for_apartment((to_jsonb(NEW)->>'id')::uuid, v_apt_tags);

        v_payload := jsonb_build_object(
            'event_type', 'apartment_status_active',
            'apartment', v_apartment_data,
            'matched_tenants', v_matched_tenants,
            'matched_tenants_count', jsonb_array_length(v_matched_tenants),
            'timestamp', NOW()
        );

        BEGIN
            PERFORM net.http_post(
                url := v_webhook_url,
                headers := jsonb_build_object('Content-Type', 'application/json'),
                body := v_payload::text
            );
            RAISE NOTICE '✅ Webhook sent to Active endpoint';
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '❌ Webhook call failed for apartment %: %', (to_jsonb(NEW)->>'id'), SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate triggers to fire on ANY update (not just UPDATE OF status)
DROP TRIGGER IF EXISTS trigger_apartment_status_create_link_webhook ON public.apartments;
CREATE TRIGGER trigger_apartment_status_create_link_webhook
    AFTER INSERT OR UPDATE ON public.apartments
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_apartment_status_create_link_webhook();

DROP TRIGGER IF EXISTS trigger_apartment_status_active_webhook ON public.apartments;
CREATE TRIGGER trigger_apartment_status_active_webhook
    AFTER INSERT OR UPDATE ON public.apartments
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_apartment_status_active_webhook();

RAISE NOTICE '✅ Triggers updated! Now testing...';

-- ==========================================
-- STEP 2: Test the triggers
-- ==========================================

DO $$
DECLARE
    test_id UUID;
    current_status TEXT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Testing Webhooks ===';
    RAISE NOTICE '';
    
    -- Create test apartment
    INSERT INTO public.apartments ("Full Address", status, tags)
    VALUES ('Fix Test ' || extract(epoch from now())::text, 'Null', ARRAY['fix-test'])
    RETURNING id INTO test_id;
    
    RAISE NOTICE 'Created test apartment: %', test_id;
    
    -- Test CreateLink
    RAISE NOTICE 'Updating to CreateLink...';
    UPDATE public.apartments SET status = 'CreateLink' WHERE id = test_id;
    
    SELECT COALESCE(to_jsonb(apartments)->>'Status', to_jsonb(apartments)->>'status') 
    INTO current_status FROM public.apartments WHERE id = test_id;
    RAISE NOTICE 'Status: %', current_status;
    RAISE NOTICE '⏳ Check n8n for CreateLink webhook execution';
    
    PERFORM pg_sleep(3);
    
    -- Test Active
    RAISE NOTICE '';
    RAISE NOTICE 'Updating to Active...';
    UPDATE public.apartments SET status = 'Null' WHERE id = test_id;
    UPDATE public.apartments SET status = 'Active' WHERE id = test_id;
    
    SELECT COALESCE(to_jsonb(apartments)->>'Status', to_jsonb(apartments)->>'status') 
    INTO current_status FROM public.apartments WHERE id = test_id;
    RAISE NOTICE 'Status: %', current_status;
    RAISE NOTICE '⏳ Check n8n for Active webhook execution';
    RAISE NOTICE '';
    RAISE NOTICE 'Test complete!';
END $$;

SELECT '✅ Fix applied and tested. Check n8n executions NOW!' AS result;
