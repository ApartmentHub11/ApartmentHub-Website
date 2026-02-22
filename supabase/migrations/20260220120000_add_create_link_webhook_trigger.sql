-- Add CreateLink webhook trigger
-- Fires when apartment status changes to CreateLink
-- Webhook URL: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link

-- Ensure the function exists (uses body as jsonb for pg_net)
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
    v_apartment_json := to_jsonb(NEW);
    v_new_status := COALESCE(v_apartment_json->>'Status', v_apartment_json->>'status');
    IF TG_OP = 'UPDATE' THEN v_old_status := COALESCE(to_jsonb(OLD)->>'Status', to_jsonb(OLD)->>'status'); ELSE v_old_status := NULL; END IF;

    IF v_new_status = 'CreateLink' AND (v_old_status IS NULL OR v_old_status != 'CreateLink') THEN
        v_agent_id := COALESCE(v_apartment_json->>'real_estate_agent_id', v_apartment_json->>'Real Estate Agent Id', v_apartment_json->>'real_estate_agent_id');
        IF v_agent_id IS NOT NULL AND v_agent_id != '' THEN
            SELECT to_jsonb(agents) INTO v_agent_json FROM public.real_estate_agents agents WHERE id = v_agent_id::uuid LIMIT 1;
        END IF;
        v_payload := v_apartment_json || jsonb_build_object(
            'real_estate_agent', COALESCE(v_agent_json, 'null'::jsonb),
            'timestamp', NOW(),
            'event_type', 'apartment_status_create_link',
            'trigger_operation', TG_OP
        );
        BEGIN
            PERFORM net.http_post(
                url := v_webhook_url,
                body := v_payload,
                headers := jsonb_build_object('Content-Type', 'application/json', 'User-Agent', 'Supabase-Webhook-Trigger')
            );
            RAISE NOTICE '[CreateLink Webhook] Sent for apartment %', v_apartment_json->>'id';
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '[CreateLink Webhook] Failed for apartment %: %', v_apartment_json->>'id', SQLERRM;
        END;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger (one trigger only, no duplicates)
DROP TRIGGER IF EXISTS trigger_apartment_create_link_webhook ON public.apartments;
CREATE TRIGGER trigger_apartment_create_link_webhook
    AFTER INSERT OR UPDATE OF status ON public.apartments
    FOR EACH ROW
    EXECUTE FUNCTION public.send_create_link_webhook();

COMMENT ON FUNCTION public.send_create_link_webhook() IS
'Sends webhook when apartment status changes to CreateLink. URL: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
