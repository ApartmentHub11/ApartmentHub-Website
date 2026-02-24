-- Migration: Reorganize document storage by phone number & auto-sync accounts
-- 
-- Changes:
-- 1. Add phone_number column to documenten table
-- 2. Create trigger to sync accounts fields from personen/documenten/dossiers
-- 3. Backfill existing data

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Add phone_number column to documenten table
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.documenten ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- Fix the status check constraint to allow all needed values
ALTER TABLE public.documenten DROP CONSTRAINT IF EXISTS documenten_status_check;
ALTER TABLE public.documenten ADD CONSTRAINT documenten_status_check
    CHECK (status IN ('ontvangen', 'ontbreekt', 'pending'));

-- Index for fast lookup by phone_number
CREATE INDEX IF NOT EXISTS idx_documenten_phone_number ON public.documenten(phone_number);

-- Backfill phone_number on existing documenten rows from personen → dossiers chain
UPDATE public.documenten d
SET phone_number = dos.phone_number
FROM public.personen p
INNER JOIN public.dossiers dos ON p.dossier_id = dos.id
WHERE d.persoon_id = p.id
  AND d.phone_number IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Trigger function: sync accounts fields from personen/documenten/dossiers
--    Fires when personen or documenten rows change.
--    Populates: email, work_status, monthly_income, current_address,
--               current_zipcode, documents (JSONB), documentation_status
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sync_accounts_from_dossier_data()
RETURNS TRIGGER AS $$
DECLARE
    v_dossier_id UUID;
    v_phone TEXT;
    v_email TEXT;
    v_werk_status TEXT;
    v_income NUMERIC;
    v_address TEXT;
    v_zipcode TEXT;
    v_docs JSONB;
    v_required_count INTEGER;
    v_received_count INTEGER;
    v_doc_status TEXT;
BEGIN
    -- Determine the dossier_id depending on which table fired the trigger
    IF TG_TABLE_NAME = 'documenten' THEN
        -- Get dossier_id via personen
        SELECT p.dossier_id INTO v_dossier_id
        FROM public.personen p
        WHERE p.id = COALESCE(NEW.persoon_id, OLD.persoon_id);
    ELSIF TG_TABLE_NAME = 'personen' THEN
        v_dossier_id := COALESCE(NEW.dossier_id, OLD.dossier_id);
    ELSE
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF v_dossier_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    -- Get the phone_number from dossiers
    SELECT dos.phone_number INTO v_phone
    FROM public.dossiers dos
    WHERE dos.id = v_dossier_id;

    IF v_phone IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    -- Get the Hoofdhuurder (main tenant) data from personen
    SELECT p.email, p.werk_status, p.bruto_maandinkomen, p.huidige_adres, p.postcode
    INTO v_email, v_werk_status, v_income, v_address, v_zipcode
    FROM public.personen p
    WHERE p.dossier_id = v_dossier_id
      AND p.rol = 'Hoofdhuurder'
    LIMIT 1;

    -- Build documents JSONB array from all documenten in this dossier
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'type', d.type,
            'status', d.status,
            'file_path', d.bestandspad,
            'file_name', d.bestandsnaam,
            'uploaded_at', d.uploaded_at
        )
    ) FILTER (WHERE d.status IN ('ontvangen', 'pending')), '[]'::jsonb)
    INTO v_docs
    FROM public.personen p
    INNER JOIN public.documenten d ON d.persoon_id = p.id
    WHERE p.dossier_id = v_dossier_id;

    -- Calculate documentation_status
    -- Count missing (ontbreekt) vs received (ontvangen/pending) documents
    -- Note: placeholders from edge function use different type names than frontend uploads,
    -- so we compare counts rather than matching by type.
    SELECT
        COUNT(*) FILTER (WHERE d.status = 'ontbreekt') AS missing_count,
        COUNT(*) FILTER (WHERE d.status IN ('ontvangen', 'pending')) AS received_count
    INTO v_required_count, v_received_count
    FROM public.personen p
    LEFT JOIN public.documenten d ON d.persoon_id = p.id
    WHERE p.dossier_id = v_dossier_id;

    IF v_received_count = 0 AND v_required_count = 0 THEN
        v_doc_status := 'Pending';
    ELSIF v_received_count >= v_required_count THEN
        v_doc_status := 'Complete';
    ELSE
        v_doc_status := 'Pending';
    END IF;

    -- Update all accounts matched by phone number
    UPDATE public.accounts
    SET
        email              = COALESCE(v_email, email),
        work_status        = COALESCE(v_werk_status, work_status),
        monthly_income     = COALESCE(v_income, monthly_income),
        current_address    = COALESCE(v_address, current_address),
        current_zipcode    = COALESCE(v_zipcode, current_zipcode),
        documents          = v_docs,
        documentation_status = v_doc_status,
        updated_at         = TIMEZONE('utc'::text, NOW())
    WHERE whatsapp_number = v_phone
       OR REPLACE(whatsapp_number, ' ', '') = REPLACE(v_phone, ' ', '');

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Drop old triggers that only sync documentation_status (this new one supersedes them)
DROP TRIGGER IF EXISTS trigger_update_accounts_documentation_status ON public.documenten;
DROP TRIGGER IF EXISTS trigger_update_accounts_documentation_status_on_persoon ON public.personen;

-- Create new triggers on both tables (drop first in case of re-run)
DROP TRIGGER IF EXISTS trigger_sync_accounts_from_documenten ON public.documenten;
CREATE TRIGGER trigger_sync_accounts_from_documenten
    AFTER INSERT OR UPDATE OR DELETE ON public.documenten
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_accounts_from_dossier_data();

DROP TRIGGER IF EXISTS trigger_sync_accounts_from_personen ON public.personen;
CREATE TRIGGER trigger_sync_accounts_from_personen
    AFTER INSERT OR UPDATE OR DELETE ON public.personen
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_accounts_from_dossier_data();


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Backfill: populate all existing accounts from their linked dossier data
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.backfill_accounts_from_dossier_data()
RETURNS void AS $$
DECLARE
    acc RECORD;
    v_phone TEXT;
    v_email TEXT;
    v_werk_status TEXT;
    v_income NUMERIC;
    v_address TEXT;
    v_zipcode TEXT;
    v_docs JSONB;
    v_required_count INTEGER;
    v_received_count INTEGER;
    v_doc_status TEXT;
BEGIN
    FOR acc IN
        SELECT id, whatsapp_number
        FROM public.accounts
        WHERE whatsapp_number IS NOT NULL
    LOOP
        v_phone := acc.whatsapp_number;

        -- Get Hoofdhuurder data
        SELECT p.email, p.werk_status, p.bruto_maandinkomen, p.huidige_adres, p.postcode
        INTO v_email, v_werk_status, v_income, v_address, v_zipcode
        FROM public.dossiers dos
        INNER JOIN public.personen p ON p.dossier_id = dos.id
        WHERE (dos.phone_number = v_phone OR REPLACE(dos.phone_number, ' ', '') = REPLACE(v_phone, ' ', ''))
          AND p.rol = 'Hoofdhuurder'
        LIMIT 1;

        -- Build documents JSONB
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'type', d.type,
                'status', d.status,
                'file_path', d.bestandspad,
                'file_name', d.bestandsnaam,
                'uploaded_at', d.uploaded_at
            )
        ) FILTER (WHERE d.status IN ('ontvangen', 'pending')), '[]'::jsonb)
        INTO v_docs
        FROM public.dossiers dos
        INNER JOIN public.personen p ON p.dossier_id = dos.id
        INNER JOIN public.documenten d ON d.persoon_id = p.id
        WHERE dos.phone_number = v_phone
           OR REPLACE(dos.phone_number, ' ', '') = REPLACE(v_phone, ' ', '');

        -- Documentation status (missing vs received comparison)
        SELECT
            COUNT(*) FILTER (WHERE d.status = 'ontbreekt') AS missing_count,
            COUNT(*) FILTER (WHERE d.status IN ('ontvangen', 'pending')) AS received_count
        INTO v_required_count, v_received_count
        FROM public.dossiers dos
        INNER JOIN public.personen p ON p.dossier_id = dos.id
        LEFT JOIN public.documenten d ON d.persoon_id = p.id
        WHERE dos.phone_number = v_phone
           OR REPLACE(dos.phone_number, ' ', '') = REPLACE(v_phone, ' ', '');

        IF v_received_count = 0 AND v_required_count = 0 THEN
            v_doc_status := 'Pending';
        ELSIF v_received_count >= v_required_count THEN
            v_doc_status := 'Complete';
        ELSE
            v_doc_status := 'Pending';
        END IF;

        UPDATE public.accounts
        SET
            email              = COALESCE(v_email, email),
            work_status        = COALESCE(v_werk_status, work_status),
            monthly_income     = COALESCE(v_income, monthly_income),
            current_address    = COALESCE(v_address, current_address),
            current_zipcode    = COALESCE(v_zipcode, current_zipcode),
            documents          = v_docs,
            documentation_status = v_doc_status,
            updated_at         = TIMEZONE('utc'::text, NOW())
        WHERE id = acc.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Run the backfill immediately
SELECT public.backfill_accounts_from_dossier_data();

-- ─────────────────────────────────────────────────────────────────────────────
-- Comments
-- ─────────────────────────────────────────────────────────────────────────────
COMMENT ON COLUMN public.documenten.phone_number IS 'Phone number of the person this document belongs to. Used for organizing storage by phone number.';

COMMENT ON FUNCTION public.sync_accounts_from_dossier_data() IS
'Trigger function that syncs account fields (email, work_status, monthly_income, current_address, current_zipcode, documents, documentation_status) from personen/documenten/dossiers whenever those tables change.';

COMMENT ON FUNCTION public.backfill_accounts_from_dossier_data() IS
'Backfill function to populate all existing accounts from their linked dossier data. Safe to run multiple times.';
