-- Migration: Sync accounts.documentation_status on accounts INSERT or whatsapp_number UPDATE
--
-- Problem this solves:
--   The existing trigger fires on documenten changes (INSERT/UPDATE/DELETE) and walks
--   UP the chain: documenten → personen → dossiers.phone_number → accounts.whatsapp_number
--   to update documentation_status.
--
--   BUT: if Zoko inserts an account AFTER documents are already uploaded, no documenten
--   change fires, so documentation_status stays NULL forever.
--
-- Fix:
--   1. Re-create sync_all_accounts_documentation_status() correctly (fix the  
--      PL/pgSQL variable interpolation bug from the previous migration).
--   2. Add a BEFORE INSERT/UPDATE trigger on accounts that immediately sets
--      documentation_status when a new account row arrives.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Fix the existing sync_all_accounts_documentation_status() function
--    (Previous version had a bug: used account_record.whatsapp_number directly
--     inside a SQL expression where a PL/pgSQL variable is needed.)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_all_accounts_documentation_status()
RETURNS void AS $$
DECLARE
    account_record RECORD;
    v_phone TEXT;
    v_required_docs_count INTEGER;
    v_received_docs_count INTEGER;
    v_all_complete BOOLEAN;
BEGIN
    FOR account_record IN
        SELECT id, whatsapp_number
        FROM public.accounts
        WHERE whatsapp_number IS NOT NULL
    LOOP
        -- Assign to local variable so it can be used in SQL expressions
        v_phone := account_record.whatsapp_number;

        SELECT
            COUNT(*) FILTER (WHERE d.is_required = true)                             AS required_count,
            COUNT(*) FILTER (WHERE d.is_required = true AND d.status = 'ontvangen') AS received_count
        INTO v_required_docs_count, v_received_docs_count
        FROM public.dossiers dos
        INNER JOIN public.personen p  ON dos.id  = p.dossier_id
        LEFT  JOIN public.documenten d ON p.id   = d.persoon_id
        WHERE dos.phone_number = v_phone
           OR REPLACE(dos.phone_number, ' ', '') = REPLACE(v_phone, ' ', '');

        IF v_required_docs_count IS NULL OR v_required_docs_count = 0 THEN
            v_all_complete := false;
        ELSIF v_required_docs_count = v_received_docs_count THEN
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
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. New trigger: fires BEFORE accounts INSERT or whatsapp_number UPDATE
--    so that when Zoko creates an account, it checks existing documenten
--    records and sets documentation_status immediately.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_documentation_status_on_account_upsert()
RETURNS TRIGGER AS $$
DECLARE
    v_phone TEXT;
    v_required_docs_count INTEGER;
    v_received_docs_count INTEGER;
    v_new_status TEXT;
BEGIN
    -- Only run if whatsapp_number is present
    IF NEW.whatsapp_number IS NULL THEN
        RETURN NEW;
    END IF;

    -- On UPDATE, only re-check if whatsapp_number actually changed
    IF TG_OP = 'UPDATE' AND OLD.whatsapp_number IS NOT DISTINCT FROM NEW.whatsapp_number THEN
        RETURN NEW;
    END IF;

    v_phone := NEW.whatsapp_number;

    -- Walk DOWN the chain: dossiers → personen → documenten
    SELECT
        COUNT(*) FILTER (WHERE d.is_required = true)                             AS required_count,
        COUNT(*) FILTER (WHERE d.is_required = true AND d.status = 'ontvangen') AS received_count
    INTO v_required_docs_count, v_received_docs_count
    FROM public.dossiers dos
    INNER JOIN public.personen p  ON dos.id  = p.dossier_id
    LEFT  JOIN public.documenten d ON p.id   = d.persoon_id
    WHERE dos.phone_number = v_phone
       OR REPLACE(dos.phone_number, ' ', '') = REPLACE(v_phone, ' ', '');

    -- If no matching dossier / docs exist yet, leave whatever Zoko sent
    IF v_required_docs_count IS NULL OR v_required_docs_count = 0 THEN
        RETURN NEW;
    ELSIF v_required_docs_count = v_received_docs_count THEN
        v_new_status := 'Complete';
    ELSE
        v_new_status := 'Pending';
    END IF;

    -- Only overwrite if it differs
    IF NEW.documentation_status IS DISTINCT FROM v_new_status THEN
        NEW.documentation_status := v_new_status;
        RAISE LOG '[sync_documentation_status_on_account_upsert] Set documentation_status=% for whatsapp=%',
            v_new_status, v_phone;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_sync_documentation_status_on_account_upsert ON public.accounts;
CREATE TRIGGER trigger_sync_documentation_status_on_account_upsert
    BEFORE INSERT OR UPDATE OF whatsapp_number ON public.accounts
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_documentation_status_on_account_upsert();

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Backfill existing accounts
-- ─────────────────────────────────────────────────────────────────────────────
SELECT public.sync_all_accounts_documentation_status();

COMMENT ON FUNCTION public.sync_documentation_status_on_account_upsert() IS
'Fires BEFORE accounts INSERT or whatsapp_number UPDATE. Looks up dossiers/personen/documenten
by phone number and sets documentation_status=Complete|Pending when a matching dossier exists.
Solves the race condition where Zoko inserts an account after documents are already uploaded.';
