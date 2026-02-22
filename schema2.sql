


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';


SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."accounts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_name" "text" NOT NULL,
    "whatsapp_number" "text",
    "email" "text",
    "nationality" "text",
    "date_of_birth" "date",
    "sex" "text",
    "preferred_language" "text",
    "tags" "text"[],
    "salesforce_account_id" "text",
    "assigned_crm_agent_id" "uuid",
    "current_address" "text",
    "current_zipcode" "text",
    "preferred_location" "text",
    "move_in_date" "date",
    "work_status" "text",
    "monthly_income" numeric,
    "events_booked" "jsonb" DEFAULT '[]'::"jsonb",
    "apartments_applied_for" "jsonb" DEFAULT '[]'::"jsonb",
    "co_tenants" "jsonb" DEFAULT '[]'::"jsonb",
    "co_tenant_relation" "text",
    "guarantor_relation" "text",
    "documents" "jsonb" DEFAULT '[]'::"jsonb",
    "negotiation_notes" "text",
    "status" "text",
    "contract_start_date" "date",
    "contract_end_date" "date",
    "documentation_status" "text",
    "additional_notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "preference_rent_min" numeric,
    "preference_rent_max" numeric,
    "preference_min_bedrooms" integer,
    CONSTRAINT "accounts_documentation_status_check" CHECK (("documentation_status" = ANY (ARRAY['Pending'::"text", 'Complete'::"text", 'Rejected'::"text"]))),
    CONSTRAINT "accounts_status_check" CHECK (("status" = ANY (ARRAY['Null'::"text", 'Offer Made'::"text", 'Deal In Progress'::"text", 'Deal Closed'::"text", 'Lost'::"text"])))
);


ALTER TABLE "public"."accounts" OWNER TO "postgres";


COMMENT ON TABLE "public"."accounts" IS 'Internal CRM detailed account/tenant records';



COMMENT ON COLUMN "public"."accounts"."preference_rent_min" IS 'Minimum rent the candidate is willing to pay';



COMMENT ON COLUMN "public"."accounts"."preference_rent_max" IS 'Maximum rent the candidate is willing to pay';



COMMENT ON COLUMN "public"."accounts"."preference_min_bedrooms" IS 'Minimum number of bedrooms required';



CREATE OR REPLACE FUNCTION "public"."get_accounts_in_segment"("segment_id" "uuid") RETURNS SETOF "public"."accounts"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_min_budget NUMERIC;
    v_max_budget NUMERIC;
    v_min_bedrooms INTEGER;
BEGIN
    -- Get segment details
    SELECT min_budget, max_budget, min_bedrooms
    INTO v_min_budget, v_max_budget, v_min_bedrooms
    FROM public.candidate_segments
    WHERE id = segment_id;

    -- Return matching accounts
    RETURN QUERY
    SELECT *
    FROM public.accounts
    WHERE 
        -- 1. Budget Match: 
        -- The candidate's MAX budget should be at least the Segment's MIN budget.
        -- (e.g. Segment starts at 1500. Calculate wants candidates who can pay 1500+. A candidate with max budget 1400 is not a match.)
        (preference_rent_max >= v_min_budget OR preference_rent_max IS NULL)
        
        -- And ideally, their budget shouldn't be wildly higher than the segment max? 
        -- For now, let's keep it simple: Ensure they *can* afford the range.
        -- If segment has a max budget, checking if their MIN budget is below it to ensure overlap?
        -- Let's stick to simple "Ability to pay":
        -- Candidate Max Budget >= Segment Min Budget.
        -- Also, Candidate Min Bedrooms <= Segment Min Bedrooms (Candidate wants 1, Segment is 1 -> Match. Candidate wants 2, Segment is 1 -> No match?
        -- Wait, segment usually implies "Properties in this segment".
        -- If segment is "1 Bedroom Apartments", a candidate wanting "2 Bedrooms" is NOT a match.
        -- If segment is "2 Bedroom Apartments", a candidate wanting "1 Bedroom" MIGHT be a match (upgrade), but usually people filter strictly or >=.
        
        AND (preference_min_bedrooms <= v_min_bedrooms OR preference_min_bedrooms IS NULL);
END;
$$;


ALTER FUNCTION "public"."get_accounts_in_segment"("segment_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_accounts_in_segment"("segment_id" "uuid") IS 'Returns accounts that match the criteria of a given segment ID';



CREATE OR REPLACE FUNCTION "public"."get_matched_tenants_for_apartment"("p_apartment_id" "uuid", "p_apartment_tags" "text"[]) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."get_matched_tenants_for_apartment"("p_apartment_id" "uuid", "p_apartment_tags" "text"[]) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_matched_tenants_for_apartment"("p_apartment_id" "uuid", "p_apartment_tags" "text"[]) IS 'Returns accounts/tenants that match apartment tags. Uses array overlap operator (&&) to find accounts with matching tags.';



CREATE OR REPLACE FUNCTION "public"."handle_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_active_webhook"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."send_active_webhook"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."send_active_webhook"() IS 'Sends webhook when apartment status changes to Active. Includes ALL apartment table columns + matched tenants based on tags.';



CREATE OR REPLACE FUNCTION "public"."send_create_link_webhook"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."send_create_link_webhook"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."send_create_link_webhook"() IS 'Sends webhook when apartment status changes to CreateLink. Includes ALL apartment table columns.';



CREATE OR REPLACE FUNCTION "public"."sync_all_accounts_documentation_status"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    account_record RECORD;
    v_required_docs_count INTEGER;
    v_received_docs_count INTEGER;
    v_all_complete BOOLEAN;
BEGIN
    -- Loop through all accounts with whatsapp_number
    FOR account_record IN 
        SELECT id, whatsapp_number 
        FROM public.accounts 
        WHERE whatsapp_number IS NOT NULL
    LOOP
        -- Find dossier(s) linked to this phone number
        -- Check all personen in those dossiers
        SELECT 
            COUNT(*) FILTER (WHERE d.is_required = true) as required_count,
            COUNT(*) FILTER (WHERE d.is_required = true AND d.status = 'ontvangen') as received_count
        INTO v_required_docs_count, v_received_docs_count
        FROM public.dossiers dos
        INNER JOIN public.personen p ON dos.id = p.dossier_id
        LEFT JOIN public.documenten d ON p.id = d.persoon_id
        WHERE dos.phone_number = account_record.whatsapp_number;

        -- Determine if all required documents are complete
        -- If there are no required documents, set to Pending
        IF v_required_docs_count = 0 THEN
            v_all_complete := false;
        ELSIF v_required_docs_count > 0 AND v_required_docs_count = v_received_docs_count THEN
            v_all_complete := true;
        ELSE
            v_all_complete := false;
        END IF;

        -- Update the account
        UPDATE public.accounts
        SET documentation_status = CASE 
            WHEN v_all_complete THEN 'Complete'
            ELSE 'Pending'
        END,
        updated_at = TIMEZONE('utc'::text, NOW())
        WHERE id = account_record.id
        AND documentation_status IS DISTINCT FROM CASE 
            WHEN v_all_complete THEN 'Complete'
            ELSE 'Pending'
        END;
    END LOOP;
END;
$$;


ALTER FUNCTION "public"."sync_all_accounts_documentation_status"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_all_accounts_documentation_status"() IS 'Manually syncs documentation_status for all accounts based on current documenten table state. Useful for initial setup or data migration.';



CREATE OR REPLACE FUNCTION "public"."trigger_accounts_tags_webhook"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    v_payload JSONB;
    v_tags_changed BOOLEAN := false;
BEGIN
    -- Check if tags column has changed
    -- For INSERT, check if tags is not null/empty
    -- For UPDATE, check if tags value actually changed
    IF TG_OP = 'INSERT' THEN
        -- On insert, trigger if tags is provided
        IF NEW.tags IS NOT NULL AND array_length(NEW.tags, 1) > 0 THEN
            v_tags_changed := true;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- On update, trigger only if tags actually changed
        -- Compare arrays: if old is null/empty and new is not, or vice versa, or if arrays differ
        IF (OLD.tags IS DISTINCT FROM NEW.tags) THEN
            v_tags_changed := true;
        END IF;
    END IF;

    -- Only trigger webhook if tags actually changed
    IF v_tags_changed THEN
        -- Build payload with account information
        v_payload := jsonb_build_object(
            'event_type', TG_OP,
            'account_id', NEW.id,
            'tenant_name', NEW.tenant_name,
            'whatsapp_number', NEW.whatsapp_number,
            'email', NEW.email,
            'tags', NEW.tags,
            'old_tags', CASE WHEN TG_OP = 'UPDATE' THEN OLD.tags ELSE NULL END,
            'timestamp', NOW(),
            'salesforce_account_id', NEW.salesforce_account_id
        );

        -- Call webhook asynchronously using pg_net (non-blocking)
        -- This doesn't block the transaction
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
            -- Webhook failures should not prevent database operations
            RAISE WARNING 'Webhook call failed: %', SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_accounts_tags_webhook"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."trigger_accounts_tags_webhook"() IS 'Triggers webhook when tags column changes in accounts table. Uses pg_net for async HTTP requests. Webhook URL: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';



CREATE OR REPLACE FUNCTION "public"."trigger_apartment_status_active_webhook"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."trigger_apartment_status_active_webhook"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."trigger_apartment_status_active_webhook"() IS 'Triggers webhook when apartment status changes to Active. Sends all apartment info and list of shortlisted tenants matched based on tags. Webhook URL: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';



CREATE OR REPLACE FUNCTION "public"."trigger_apartment_status_create_link_webhook"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."trigger_apartment_status_create_link_webhook"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."trigger_apartment_status_create_link_webhook"() IS 'Triggers webhook when apartment status changes to CreateLink. Sends all apartment table data to the webhook. Webhook URL: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';



CREATE OR REPLACE FUNCTION "public"."update_accounts_documentation_status"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_persoon_id UUID;
    v_dossier_id UUID;
    v_phone_number TEXT;
    v_required_docs_count INTEGER;
    v_received_docs_count INTEGER;
    v_all_complete BOOLEAN;
BEGIN
    -- Get the persoon_id from the trigger context
    IF TG_OP = 'DELETE' THEN
        v_persoon_id := OLD.persoon_id;
    ELSE
        v_persoon_id := NEW.persoon_id;
    END IF;

    -- Get the dossier_id from personen table
    SELECT dossier_id INTO v_dossier_id
    FROM public.personen
    WHERE id = v_persoon_id;

    -- If no dossier found, exit
    IF v_dossier_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    -- Get the phone_number from dossiers
    SELECT phone_number INTO v_phone_number
    FROM public.dossiers
    WHERE id = v_dossier_id;

    -- If no phone number found, exit
    IF v_phone_number IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    -- Check all personen in this dossier
    -- Count required documents vs received documents for all personen in the dossier
    SELECT 
        COUNT(*) FILTER (WHERE d.is_required = true) as required_count,
        COUNT(*) FILTER (WHERE d.is_required = true AND d.status = 'ontvangen') as received_count
    INTO v_required_docs_count, v_received_docs_count
    FROM public.personen p
    LEFT JOIN public.documenten d ON p.id = d.persoon_id
    WHERE p.dossier_id = v_dossier_id;

    -- Determine if all required documents are complete
    -- If there are no required documents at all, keep status as is (don't change to Complete automatically)
    -- If there are required documents and all are received, status is Complete
    -- Otherwise, status is Pending
    IF v_required_docs_count = 0 THEN
        -- No required documents found, don't update (might be initial state or no personen yet)
        RETURN COALESCE(NEW, OLD);
    ELSIF v_required_docs_count > 0 AND v_required_docs_count = v_received_docs_count THEN
        v_all_complete := true;
    ELSE
        v_all_complete := false;
    END IF;

    -- Update all accounts linked to this phone number
    UPDATE public.accounts
    SET documentation_status = CASE 
        WHEN v_all_complete THEN 'Complete'
        ELSE 'Pending'
    END,
    updated_at = TIMEZONE('utc'::text, NOW())
    WHERE whatsapp_number = v_phone_number
    AND documentation_status IS DISTINCT FROM CASE 
        WHEN v_all_complete THEN 'Complete'
        ELSE 'Pending'
    END;

    RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION "public"."update_accounts_documentation_status"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."update_accounts_documentation_status"() IS 'Updates accounts.documentation_status when documenten records change. Checks if all required documents are uploaded (status = ontvangen).';



CREATE OR REPLACE FUNCTION "public"."update_accounts_documentation_status_on_persoon"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_dossier_id UUID;
    v_phone_number TEXT;
    v_required_docs_count INTEGER;
    v_received_docs_count INTEGER;
    v_all_complete BOOLEAN;
BEGIN
    -- Get the dossier_id from the trigger context
    IF TG_OP = 'DELETE' THEN
        v_dossier_id := OLD.dossier_id;
    ELSE
        v_dossier_id := NEW.dossier_id;
    END IF;

    -- Get the phone_number from dossiers
    SELECT phone_number INTO v_phone_number
    FROM public.dossiers
    WHERE id = v_dossier_id;

    -- If no phone number found, exit
    IF v_phone_number IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    -- Check all personen in this dossier
    SELECT 
        COUNT(*) FILTER (WHERE d.is_required = true) as required_count,
        COUNT(*) FILTER (WHERE d.is_required = true AND d.status = 'ontvangen') as received_count
    INTO v_required_docs_count, v_received_docs_count
    FROM public.personen p
    LEFT JOIN public.documenten d ON p.id = d.persoon_id
    WHERE p.dossier_id = v_dossier_id;

    -- Determine if all required documents are complete
    -- If there are no required documents at all, don't update
    IF v_required_docs_count = 0 THEN
        RETURN COALESCE(NEW, OLD);
    ELSIF v_required_docs_count > 0 AND v_required_docs_count = v_received_docs_count THEN
        v_all_complete := true;
    ELSE
        v_all_complete := false;
    END IF;

    -- Update all accounts linked to this phone number
    UPDATE public.accounts
    SET documentation_status = CASE 
        WHEN v_all_complete THEN 'Complete'
        ELSE 'Pending'
    END,
    updated_at = TIMEZONE('utc'::text, NOW())
    WHERE whatsapp_number = v_phone_number
    AND documentation_status IS DISTINCT FROM CASE 
        WHEN v_all_complete THEN 'Complete'
        ELSE 'Pending'
    END;

    RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION "public"."update_accounts_documentation_status_on_persoon"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."update_accounts_documentation_status_on_persoon"() IS 'Updates accounts.documentation_status when personen records change (affects document count).';



CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."apartments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "street" "text",
    "area" "text",
    "full_address" "text",
    "zip_code" "text",
    "rental_price" numeric,
    "bedrooms" "text",
    "square_meters" numeric,
    "tags" "text"[],
    "status" "text",
    "event_link" "text",
    "booking_details" "jsonb" DEFAULT '{}'::"jsonb",
    "slot_dates" "jsonb" DEFAULT '[]'::"jsonb",
    "salesforce_id" "text",
    "additional_notes" "text",
    "real_estate_agent_id" "uuid",
    "viewing_participants" "jsonb" DEFAULT '[]'::"jsonb",
    "viewing_cancellations" "jsonb" DEFAULT '[]'::"jsonb",
    "booking_reschedules" "jsonb" DEFAULT '[]'::"jsonb",
    "apartmenthub_agents" "jsonb" DEFAULT '[]'::"jsonb",
    "people_making_offer" "jsonb" DEFAULT '[]'::"jsonb",
    "offers_in" "jsonb" DEFAULT '[]'::"jsonb",
    "offers_sent" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "apartments_status_check" CHECK (("status" = ANY (ARRAY['Null'::"text", 'CreateLink'::"text", 'Active'::"text", 'Closed'::"text"])))
);


ALTER TABLE "public"."apartments" OWNER TO "postgres";


COMMENT ON TABLE "public"."apartments" IS 'Public apartment listings';



CREATE TABLE IF NOT EXISTS "public"."biedingen" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "dossier_id" "uuid" NOT NULL,
    "amount" numeric NOT NULL,
    "motivation" "text" NOT NULL,
    "start_date" "date" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "biedingen_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'accepted'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."biedingen" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."candidate_segments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "min_budget" numeric NOT NULL,
    "max_budget" numeric,
    "min_bedrooms" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."candidate_segments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."crm_agents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "whatsapp_number" "text",
    "email" "text",
    "employee_id" "text",
    "salesforce_agent_id" "text",
    "assigned_apartments_supabase" "uuid"[],
    "assigned_apartments_salesforce" "text"[],
    "assigned_tenants_supabase" "uuid"[],
    "internal_notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."crm_agents" OWNER TO "postgres";


COMMENT ON TABLE "public"."crm_agents" IS 'Internal CRM agent records with detailed info';



CREATE TABLE IF NOT EXISTS "public"."documenten" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "persoon_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "is_required" boolean DEFAULT true,
    "status" "text" DEFAULT 'ontbreekt'::"text" NOT NULL,
    "reason_missing" "text",
    "file_path" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "documenten_status_check" CHECK (("status" = ANY (ARRAY['ontvangen'::"text", 'ontbreekt'::"text"])))
);


ALTER TABLE "public"."documenten" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dossiers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "phone_number" "text" NOT NULL,
    "apartment_id" "text",
    "apartment_address" "text",
    "is_complete" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."dossiers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."personen" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "dossier_id" "uuid" NOT NULL,
    "rol" "text" NOT NULL,
    "naam" "text" NOT NULL,
    "whatsapp" "text" NOT NULL,
    "is_required" boolean DEFAULT true,
    "docs_complete" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "linked_to_persoon_id" "uuid",
    CONSTRAINT "check_guarantor_link" CHECK (((("rol" = 'Garantsteller'::"text") AND ("linked_to_persoon_id" IS NOT NULL)) OR (("rol" <> 'Garantsteller'::"text") AND ("linked_to_persoon_id" IS NULL)) OR (("rol" = 'Garantsteller'::"text") AND ("linked_to_persoon_id" IS NULL)))),
    CONSTRAINT "personen_rol_check" CHECK (("rol" = ANY (ARRAY['Hoofdhuurder'::"text", 'Medehuurder'::"text", 'Garantsteller'::"text"])))
);


ALTER TABLE "public"."personen" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."real_estate_agents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "phone_number" "text",
    "picture_url" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."real_estate_agents" OWNER TO "postgres";


COMMENT ON TABLE "public"."real_estate_agents" IS 'Public profiles for real estate agents linked to listings';



CREATE TABLE IF NOT EXISTS "public"."tenants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "whatsapp_number" "text",
    "salesforce_account_id" "text",
    "tags" "text"[],
    "apartment_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."tenants" OWNER TO "postgres";


COMMENT ON TABLE "public"."tenants" IS 'Simplified tenant records linked to apartments';



CREATE TABLE IF NOT EXISTS "public"."verification_codes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "phone_number" "text" NOT NULL,
    "code" "text" NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."verification_codes" OWNER TO "postgres";


ALTER TABLE ONLY "public"."accounts"
    ADD CONSTRAINT "accounts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."apartments"
    ADD CONSTRAINT "apartments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."biedingen"
    ADD CONSTRAINT "biedingen_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."candidate_segments"
    ADD CONSTRAINT "candidate_segments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."crm_agents"
    ADD CONSTRAINT "crm_agents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."documenten"
    ADD CONSTRAINT "documenten_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dossiers"
    ADD CONSTRAINT "dossiers_phone_number_key" UNIQUE ("phone_number");



ALTER TABLE ONLY "public"."dossiers"
    ADD CONSTRAINT "dossiers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."personen"
    ADD CONSTRAINT "personen_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."real_estate_agents"
    ADD CONSTRAINT "real_estate_agents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."verification_codes"
    ADD CONSTRAINT "verification_codes_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_accounts_assigned_crm_agent_id" ON "public"."accounts" USING "btree" ("assigned_crm_agent_id");



CREATE INDEX "idx_accounts_salesforce_account_id" ON "public"."accounts" USING "btree" ("salesforce_account_id");



CREATE INDEX "idx_accounts_status" ON "public"."accounts" USING "btree" ("status");



CREATE INDEX "idx_apartments_real_estate_agent_id" ON "public"."apartments" USING "btree" ("real_estate_agent_id");



CREATE INDEX "idx_apartments_status" ON "public"."apartments" USING "btree" ("status");



CREATE INDEX "idx_personen_linked_to" ON "public"."personen" USING "btree" ("linked_to_persoon_id");



CREATE INDEX "idx_tenants_apartment_id" ON "public"."tenants" USING "btree" ("apartment_id");



CREATE OR REPLACE TRIGGER "set_accounts_updated_at" BEFORE UPDATE ON "public"."accounts" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "set_apartments_updated_at" BEFORE UPDATE ON "public"."apartments" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "set_crm_agents_updated_at" BEFORE UPDATE ON "public"."crm_agents" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "set_real_estate_agents_updated_at" BEFORE UPDATE ON "public"."real_estate_agents" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "set_tenants_updated_at" BEFORE UPDATE ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_accounts_tags_webhook" AFTER INSERT OR UPDATE OF "tags" ON "public"."accounts" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_accounts_tags_webhook"();



CREATE OR REPLACE TRIGGER "trigger_apartment_active_webhook" AFTER INSERT OR UPDATE ON "public"."apartments" FOR EACH ROW EXECUTE FUNCTION "public"."send_active_webhook"();



CREATE OR REPLACE TRIGGER "trigger_apartment_create_link_webhook" AFTER INSERT OR UPDATE ON "public"."apartments" FOR EACH ROW EXECUTE FUNCTION "public"."send_create_link_webhook"();



CREATE OR REPLACE TRIGGER "trigger_update_accounts_documentation_status" AFTER INSERT OR DELETE OR UPDATE ON "public"."documenten" FOR EACH ROW EXECUTE FUNCTION "public"."update_accounts_documentation_status"();



CREATE OR REPLACE TRIGGER "trigger_update_accounts_documentation_status_on_persoon" AFTER INSERT OR DELETE OR UPDATE ON "public"."personen" FOR EACH ROW EXECUTE FUNCTION "public"."update_accounts_documentation_status_on_persoon"();



CREATE OR REPLACE TRIGGER "update_documenten_updated_at" BEFORE UPDATE ON "public"."documenten" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_dossiers_updated_at" BEFORE UPDATE ON "public"."dossiers" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."accounts"
    ADD CONSTRAINT "accounts_assigned_crm_agent_id_fkey" FOREIGN KEY ("assigned_crm_agent_id") REFERENCES "public"."crm_agents"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."apartments"
    ADD CONSTRAINT "apartments_real_estate_agent_id_fkey" FOREIGN KEY ("real_estate_agent_id") REFERENCES "public"."real_estate_agents"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."biedingen"
    ADD CONSTRAINT "biedingen_dossier_id_fkey" FOREIGN KEY ("dossier_id") REFERENCES "public"."dossiers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documenten"
    ADD CONSTRAINT "documenten_persoon_id_fkey" FOREIGN KEY ("persoon_id") REFERENCES "public"."personen"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."personen"
    ADD CONSTRAINT "personen_dossier_id_fkey" FOREIGN KEY ("dossier_id") REFERENCES "public"."dossiers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."personen"
    ADD CONSTRAINT "personen_linked_to_persoon_id_fkey" FOREIGN KEY ("linked_to_persoon_id") REFERENCES "public"."personen"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenants_apartment_id_fkey" FOREIGN KEY ("apartment_id") REFERENCES "public"."apartments"("id") ON DELETE SET NULL;



CREATE POLICY "Authenticated access to accounts" ON "public"."accounts" TO "authenticated" USING (true);



CREATE POLICY "Authenticated access to crm_agents" ON "public"."crm_agents" TO "authenticated" USING (true);



CREATE POLICY "Authenticated access to tenants" ON "public"."tenants" TO "authenticated" USING (true);



CREATE POLICY "Authenticated read access for candidate_segments" ON "public"."candidate_segments" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Public read access for apartments" ON "public"."apartments" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Public read access for real_estate_agents" ON "public"."real_estate_agents" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Service role can manage verification codes" ON "public"."verification_codes" USING (true);



CREATE POLICY "Users can insert personen in their dossier" ON "public"."personen" FOR INSERT WITH CHECK (("dossier_id" IN ( SELECT "dossiers"."id"
   FROM "public"."dossiers"
  WHERE ("dossiers"."phone_number" = (("current_setting"('request.jwt.claims'::"text", true))::json ->> 'phone_number'::"text")))));



CREATE POLICY "Users can insert their own biedingen" ON "public"."biedingen" FOR INSERT WITH CHECK (("dossier_id" IN ( SELECT "dossiers"."id"
   FROM "public"."dossiers"
  WHERE ("dossiers"."phone_number" = (("current_setting"('request.jwt.claims'::"text", true))::json ->> 'phone_number'::"text")))));



CREATE POLICY "Users can update documenten in their dossier" ON "public"."documenten" FOR UPDATE USING (("persoon_id" IN ( SELECT "p"."id"
   FROM ("public"."personen" "p"
     JOIN "public"."dossiers" "d" ON (("p"."dossier_id" = "d"."id")))
  WHERE ("d"."phone_number" = (("current_setting"('request.jwt.claims'::"text", true))::json ->> 'phone_number'::"text")))));



CREATE POLICY "Users can update their own dossier" ON "public"."dossiers" FOR UPDATE USING (("phone_number" = (("current_setting"('request.jwt.claims'::"text", true))::json ->> 'phone_number'::"text")));



CREATE POLICY "Users can view documenten in their dossier" ON "public"."documenten" FOR SELECT USING (("persoon_id" IN ( SELECT "p"."id"
   FROM ("public"."personen" "p"
     JOIN "public"."dossiers" "d" ON (("p"."dossier_id" = "d"."id")))
  WHERE ("d"."phone_number" = (("current_setting"('request.jwt.claims'::"text", true))::json ->> 'phone_number'::"text")))));



CREATE POLICY "Users can view personen in their dossier" ON "public"."personen" FOR SELECT USING (("dossier_id" IN ( SELECT "dossiers"."id"
   FROM "public"."dossiers"
  WHERE ("dossiers"."phone_number" = (("current_setting"('request.jwt.claims'::"text", true))::json ->> 'phone_number'::"text")))));



CREATE POLICY "Users can view their own biedingen" ON "public"."biedingen" FOR SELECT USING (("dossier_id" IN ( SELECT "dossiers"."id"
   FROM "public"."dossiers"
  WHERE ("dossiers"."phone_number" = (("current_setting"('request.jwt.claims'::"text", true))::json ->> 'phone_number'::"text")))));



CREATE POLICY "Users can view their own dossier" ON "public"."dossiers" FOR SELECT USING (("phone_number" = (("current_setting"('request.jwt.claims'::"text", true))::json ->> 'phone_number'::"text")));



ALTER TABLE "public"."accounts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."apartments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."biedingen" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."candidate_segments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."crm_agents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."documenten" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."dossiers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."personen" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."real_estate_agents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tenants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."verification_codes" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON TABLE "public"."accounts" TO "anon";
GRANT ALL ON TABLE "public"."accounts" TO "authenticated";
GRANT ALL ON TABLE "public"."accounts" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_accounts_in_segment"("segment_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_accounts_in_segment"("segment_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_accounts_in_segment"("segment_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_matched_tenants_for_apartment"("p_apartment_id" "uuid", "p_apartment_tags" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."get_matched_tenants_for_apartment"("p_apartment_id" "uuid", "p_apartment_tags" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_matched_tenants_for_apartment"("p_apartment_id" "uuid", "p_apartment_tags" "text"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."send_active_webhook"() TO "anon";
GRANT ALL ON FUNCTION "public"."send_active_webhook"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_active_webhook"() TO "service_role";



GRANT ALL ON FUNCTION "public"."send_create_link_webhook"() TO "anon";
GRANT ALL ON FUNCTION "public"."send_create_link_webhook"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_create_link_webhook"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_all_accounts_documentation_status"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_all_accounts_documentation_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_all_accounts_documentation_status"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_accounts_tags_webhook"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_accounts_tags_webhook"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_accounts_tags_webhook"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_apartment_status_active_webhook"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_apartment_status_active_webhook"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_apartment_status_active_webhook"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_apartment_status_create_link_webhook"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_apartment_status_create_link_webhook"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_apartment_status_create_link_webhook"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_accounts_documentation_status"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_accounts_documentation_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_accounts_documentation_status"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_accounts_documentation_status_on_persoon"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_accounts_documentation_status_on_persoon"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_accounts_documentation_status_on_persoon"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON TABLE "public"."apartments" TO "anon";
GRANT ALL ON TABLE "public"."apartments" TO "authenticated";
GRANT ALL ON TABLE "public"."apartments" TO "service_role";



GRANT ALL ON TABLE "public"."biedingen" TO "anon";
GRANT ALL ON TABLE "public"."biedingen" TO "authenticated";
GRANT ALL ON TABLE "public"."biedingen" TO "service_role";



GRANT ALL ON TABLE "public"."candidate_segments" TO "anon";
GRANT ALL ON TABLE "public"."candidate_segments" TO "authenticated";
GRANT ALL ON TABLE "public"."candidate_segments" TO "service_role";



GRANT ALL ON TABLE "public"."crm_agents" TO "anon";
GRANT ALL ON TABLE "public"."crm_agents" TO "authenticated";
GRANT ALL ON TABLE "public"."crm_agents" TO "service_role";



GRANT ALL ON TABLE "public"."documenten" TO "anon";
GRANT ALL ON TABLE "public"."documenten" TO "authenticated";
GRANT ALL ON TABLE "public"."documenten" TO "service_role";



GRANT ALL ON TABLE "public"."dossiers" TO "anon";
GRANT ALL ON TABLE "public"."dossiers" TO "authenticated";
GRANT ALL ON TABLE "public"."dossiers" TO "service_role";



GRANT ALL ON TABLE "public"."personen" TO "anon";
GRANT ALL ON TABLE "public"."personen" TO "authenticated";
GRANT ALL ON TABLE "public"."personen" TO "service_role";



GRANT ALL ON TABLE "public"."real_estate_agents" TO "anon";
GRANT ALL ON TABLE "public"."real_estate_agents" TO "authenticated";
GRANT ALL ON TABLE "public"."real_estate_agents" TO "service_role";



GRANT ALL ON TABLE "public"."tenants" TO "anon";
GRANT ALL ON TABLE "public"."tenants" TO "authenticated";
GRANT ALL ON TABLE "public"."tenants" TO "service_role";



GRANT ALL ON TABLE "public"."verification_codes" TO "anon";
GRANT ALL ON TABLE "public"."verification_codes" TO "authenticated";
GRANT ALL ON TABLE "public"."verification_codes" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







