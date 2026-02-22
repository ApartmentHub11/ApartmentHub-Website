-- Fix: pg_net.http_post expects body as jsonb, not text
-- Run this in Supabase SQL Editor to fix all webhook functions

-- 1) send_create_link_webhook
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
        v_payload := v_apartment_json || jsonb_build_object('real_estate_agent', COALESCE(v_agent_json, 'null'::jsonb), 'timestamp', NOW(), 'event_type', 'apartment_status_create_link', 'trigger_operation', TG_OP);
        BEGIN
            PERFORM net.http_post(url := v_webhook_url, body := v_payload, headers := jsonb_build_object('Content-Type', 'application/json', 'User-Agent', 'Supabase-Webhook-Trigger'));
            RAISE NOTICE '[CreateLink Webhook] Sent for apartment %', v_apartment_json->>'id';
        EXCEPTION WHEN OTHERS THEN RAISE WARNING '[CreateLink Webhook] Failed for apartment %: %', v_apartment_json->>'id', SQLERRM;
        END;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2) send_active_webhook
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
    v_apartment_json := to_jsonb(NEW);
    v_new_status := COALESCE(v_apartment_json->>'Status', v_apartment_json->>'status');
    IF TG_OP = 'UPDATE' THEN v_old_status := COALESCE(to_jsonb(OLD)->>'Status', to_jsonb(OLD)->>'status'); ELSE v_old_status := NULL; END IF;

    IF v_new_status = 'Active' AND (v_old_status IS NULL OR v_old_status != 'Active') THEN
        v_agent_id := COALESCE(v_apartment_json->>'real_estate_agent_id', v_apartment_json->>'Real Estate Agent Id');
        IF v_agent_id IS NOT NULL AND v_agent_id != '' THEN
            SELECT to_jsonb(agents) INTO v_agent_json FROM public.real_estate_agents agents WHERE id = v_agent_id::uuid LIMIT 1;
        END IF;
        v_tags_json := v_apartment_json->'tags';
        IF v_tags_json IS NOT NULL AND v_tags_json != 'null'::jsonb AND jsonb_typeof(v_tags_json) = 'array' THEN
            SELECT ARRAY(SELECT jsonb_array_elements_text(v_tags_json)) INTO v_tags_array;
        ELSE v_tags_array := NULL;
        END IF;
        v_matched_tenants := public.get_matched_tenants_for_apartment((v_apartment_json->>'id')::uuid, v_tags_array);
        v_payload := jsonb_build_object('event_type', 'apartment_status_active', 'trigger_operation', TG_OP, 'apartment', v_apartment_json || jsonb_build_object('real_estate_agent', COALESCE(v_agent_json, 'null'::jsonb)), 'matched_tenants', v_matched_tenants, 'matched_tenants_count', jsonb_array_length(v_matched_tenants), 'timestamp', NOW());
        BEGIN
            PERFORM net.http_post(url := v_webhook_url, body := v_payload, headers := jsonb_build_object('Content-Type', 'application/json', 'User-Agent', 'Supabase-Webhook-Trigger'));
            RAISE NOTICE '[Active Webhook] Sent for apartment %', v_apartment_json->>'id';
        EXCEPTION WHEN OTHERS THEN RAISE WARNING '[Active Webhook] Failed for apartment %: %', v_apartment_json->>'id', SQLERRM;
        END;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3) trigger_apartment_status_create_link_webhook
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
    IF TG_OP = 'INSERT' THEN v_old_status := NULL; ELSE v_old_status := COALESCE(to_jsonb(OLD)->>'Status', to_jsonb(OLD)->>'status'); END IF;

    IF v_new_status = 'CreateLink' AND (v_old_status IS NULL OR v_old_status != 'CreateLink') THEN
        IF (COALESCE(to_jsonb(NEW)->>'real_estate_agent_id', to_jsonb(NEW)->>'Real Estate Agent Id')) IS NOT NULL AND (COALESCE(to_jsonb(NEW)->>'real_estate_agent_id', to_jsonb(NEW)->>'Real Estate Agent Id')) != '' THEN
            SELECT jsonb_build_object('id', id, 'name', name, 'phone_number', phone_number, 'picture_url', picture_url) INTO v_real_estate_agent FROM public.real_estate_agents WHERE id = (COALESCE(to_jsonb(NEW)->>'real_estate_agent_id', to_jsonb(NEW)->>'Real Estate Agent Id'))::uuid;
        END IF;
        v_payload := to_jsonb(NEW) || jsonb_build_object('real_estate_agent', v_real_estate_agent, 'timestamp', NOW());
        BEGIN
            PERFORM net.http_post(url := v_webhook_url, body := v_payload, headers := jsonb_build_object('Content-Type', 'application/json'));
            RAISE NOTICE '[CreateLink Webhook] Sent';
        EXCEPTION WHEN OTHERS THEN RAISE WARNING 'Webhook call failed for apartment %: %', (to_jsonb(NEW)->>'id'), SQLERRM;
        END;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4) trigger_apartment_status_active_webhook
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
    IF TG_OP = 'INSERT' THEN v_old_status := NULL; ELSE v_old_status := COALESCE(to_jsonb(OLD)->>'Status', to_jsonb(OLD)->>'status'); END IF;

    IF v_new_status = 'Active' AND (v_old_status IS NULL OR v_old_status != 'Active') THEN
        IF (COALESCE(to_jsonb(NEW)->>'real_estate_agent_id', to_jsonb(NEW)->>'Real Estate Agent Id')) IS NOT NULL AND (COALESCE(to_jsonb(NEW)->>'real_estate_agent_id', to_jsonb(NEW)->>'Real Estate Agent Id')) != '' THEN
            SELECT jsonb_build_object('id', id, 'name', name, 'phone_number', phone_number, 'picture_url', picture_url) INTO v_real_estate_agent FROM public.real_estate_agents WHERE id = (COALESCE(to_jsonb(NEW)->>'real_estate_agent_id', to_jsonb(NEW)->>'Real Estate Agent Id'))::uuid;
        END IF;
        v_apartment_data := to_jsonb(NEW) || jsonb_build_object('real_estate_agent', v_real_estate_agent);
        IF to_jsonb(NEW)->'tags' IS NOT NULL AND to_jsonb(NEW)->'tags' != 'null'::jsonb THEN v_apt_tags := ARRAY(SELECT jsonb_array_elements_text(to_jsonb(NEW)->'tags')); ELSE v_apt_tags := NULL; END IF;
        v_matched_tenants := public.get_matched_tenants_for_apartment((to_jsonb(NEW)->>'id')::uuid, v_apt_tags);
        v_payload := jsonb_build_object('event_type', 'apartment_status_active', 'apartment', v_apartment_data, 'matched_tenants', v_matched_tenants, 'matched_tenants_count', jsonb_array_length(v_matched_tenants), 'timestamp', NOW());
        BEGIN
            PERFORM net.http_post(url := v_webhook_url, body := v_payload, headers := jsonb_build_object('Content-Type', 'application/json'));
            RAISE NOTICE '[Active Webhook] Sent';
        EXCEPTION WHEN OTHERS THEN RAISE WARNING 'Webhook call failed for apartment %: %', (to_jsonb(NEW)->>'id'), SQLERRM;
        END;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5) send_qualified_user_active_webhook (ensure body as jsonb)
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
    v_new_status := COALESCE(to_jsonb(NEW)->>'status', to_jsonb(NEW)->>'Status');
    v_apartment_json := to_jsonb(NEW);
    IF TG_OP = 'UPDATE' THEN v_old_status := COALESCE(to_jsonb(OLD)->>'status', to_jsonb(OLD)->>'Status'); ELSE v_old_status := NULL; END IF;

    IF v_new_status = 'Active' AND (v_old_status IS NULL OR (v_old_status IS NOT NULL AND v_old_status <> 'Active')) THEN
        v_agent_id := COALESCE(v_apartment_json->>'real_estate_agent_id', v_apartment_json->>'Real Estate Agent Id');
        IF v_agent_id IS NOT NULL AND v_agent_id != '' THEN
            SELECT to_jsonb(agents) INTO v_agent_json FROM public.real_estate_agents agents WHERE id = v_agent_id::uuid LIMIT 1;
        END IF;
        v_payload := jsonb_build_object('event_type', 'status_changed_to_active', 'trigger_operation', TG_OP, 'apartment', v_apartment_json || jsonb_build_object('real_estate_agent', COALESCE(v_agent_json, 'null'::jsonb)), 'timestamp', NOW());
        BEGIN
            PERFORM net.http_post(url := v_webhook_url, body := v_payload, headers := jsonb_build_object('Content-Type', 'application/json', 'User-Agent', 'Supabase-Webhook-Trigger'));
            RAISE NOTICE '[Status Active Webhook] Sent for apartment %', v_apartment_json->>'id';
        EXCEPTION WHEN OTHERS THEN RAISE WARNING '[Status Active Webhook] Failed for apartment %: %', v_apartment_json->>'id', SQLERRM;
        END;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
