CREATE OR REPLACE FUNCTION "public"."sync_all_accounts_documentation_status"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    account_record RECORD;
    v_required_docs_count INTEGER;
    v_received_docs_count INTEGER;
    v_all_complete BOOLEAN;
BEGIN
    FOR account_record IN 
        SELECT id, whatsapp_number 
        FROM public.accounts 
        WHERE whatsapp_number IS NOT NULL
    LOOP
        SELECT 
            COUNT(*) as required_count,
            COUNT(*) FILTER (WHERE d.status = 'ontvangen') as received_count
        INTO v_required_docs_count, v_received_docs_count
        FROM public.dossiers dos
        INNER JOIN public.personen p ON dos.id = p.dossier_id
        LEFT JOIN public.documenten d ON p.id = d.persoon_id
        WHERE dos.phone_number = account_record.whatsapp_number;

        IF v_required_docs_count = 0 THEN
            v_all_complete := false;
        ELSIF v_required_docs_count > 0 AND v_required_docs_count = v_received_docs_count THEN
            v_all_complete := true;
        ELSE
            v_all_complete := false;
        END IF;

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
    IF TG_OP = 'DELETE' THEN
        v_persoon_id := OLD.persoon_id;
    ELSE
        v_persoon_id := NEW.persoon_id;
    END IF;

    SELECT dossier_id INTO v_dossier_id
    FROM public.personen
    WHERE id = v_persoon_id;

    IF v_dossier_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    SELECT phone_number INTO v_phone_number
    FROM public.dossiers
    WHERE id = v_dossier_id;

    IF v_phone_number IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    SELECT 
        COUNT(*) as required_count,
        COUNT(*) FILTER (WHERE d.status = 'ontvangen') as received_count
    INTO v_required_docs_count, v_received_docs_count
    FROM public.personen p
    LEFT JOIN public.documenten d ON p.id = d.persoon_id
    WHERE p.dossier_id = v_dossier_id;

    IF v_required_docs_count = 0 THEN
        RETURN COALESCE(NEW, OLD);
    ELSIF v_required_docs_count > 0 AND v_required_docs_count = v_received_docs_count THEN
        v_all_complete := true;
    ELSE
        v_all_complete := false;
    END IF;

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
    IF TG_OP = 'DELETE' THEN
        v_dossier_id := OLD.dossier_id;
    ELSE
        v_dossier_id := NEW.dossier_id;
    END IF;

    SELECT phone_number INTO v_phone_number
    FROM public.dossiers
    WHERE id = v_dossier_id;

    IF v_phone_number IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    SELECT 
        COUNT(*) as required_count,
        COUNT(*) FILTER (WHERE d.status = 'ontvangen') as received_count
    INTO v_required_docs_count, v_received_docs_count
    FROM public.personen p
    LEFT JOIN public.documenten d ON p.id = d.persoon_id
    WHERE p.dossier_id = v_dossier_id;

    IF v_required_docs_count = 0 THEN
        RETURN COALESCE(NEW, OLD);
    ELSIF v_required_docs_count > 0 AND v_required_docs_count = v_received_docs_count THEN
        v_all_complete := true;
    ELSE
        v_all_complete := false;
    END IF;

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
