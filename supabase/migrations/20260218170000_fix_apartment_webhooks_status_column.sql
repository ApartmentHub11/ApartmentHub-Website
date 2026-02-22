-- Fix apartment webhooks to work when status column is "Status" (capital S) or "status"
-- Uses to_jsonb(NEW)->>'Status' / ->>'status' so it works with either column name.
-- Also trigger on any UPDATE (not just UPDATE OF status) so it fires regardless of column name.

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
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Webhook call failed for apartment %: %', (to_jsonb(NEW)->>'id'), SQLERRM;
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
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Webhook call failed for apartment %: %', (to_jsonb(NEW)->>'id'), SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate triggers to fire on ANY update (not just UPDATE OF status)
-- so they fire even if the column is named "Status"
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
