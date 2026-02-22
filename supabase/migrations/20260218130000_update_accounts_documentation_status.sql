-- Migration: Update accounts.documentation_status based on documenten table
-- This function checks if all required documents are uploaded for an account
-- and updates the documentation_status accordingly

-- Function to update documentation_status for accounts linked to a dossier
CREATE OR REPLACE FUNCTION public.update_accounts_documentation_status()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

-- Create trigger on documenten table to update accounts when documents change
DROP TRIGGER IF EXISTS trigger_update_accounts_documentation_status ON public.documenten;
CREATE TRIGGER trigger_update_accounts_documentation_status
    AFTER INSERT OR UPDATE OR DELETE ON public.documenten
    FOR EACH ROW
    EXECUTE FUNCTION public.update_accounts_documentation_status();

-- Also create a trigger on personen table in case personen are added/removed
-- which would affect the document count
CREATE OR REPLACE FUNCTION public.update_accounts_documentation_status_on_persoon()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

-- Create trigger on personen table
DROP TRIGGER IF EXISTS trigger_update_accounts_documentation_status_on_persoon ON public.personen;
CREATE TRIGGER trigger_update_accounts_documentation_status_on_persoon
    AFTER INSERT OR UPDATE OR DELETE ON public.personen
    FOR EACH ROW
    EXECUTE FUNCTION public.update_accounts_documentation_status_on_persoon();

-- Create a function to manually update documentation_status for all accounts
-- This can be called to sync existing data
CREATE OR REPLACE FUNCTION public.sync_all_accounts_documentation_status()
RETURNS void AS $$
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
$$ LANGUAGE plpgsql;

-- Comment on functions
COMMENT ON FUNCTION public.update_accounts_documentation_status() IS 
'Updates accounts.documentation_status when documenten records change. Checks if all required documents are uploaded (status = ontvangen).';

COMMENT ON FUNCTION public.update_accounts_documentation_status_on_persoon() IS 
'Updates accounts.documentation_status when personen records change (affects document count).';

COMMENT ON FUNCTION public.sync_all_accounts_documentation_status() IS 
'Manually syncs documentation_status for all accounts based on current documenten table state. Useful for initial setup or data migration.';
