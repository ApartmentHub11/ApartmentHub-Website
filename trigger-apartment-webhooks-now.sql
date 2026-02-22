-- Trigger apartment webhooks RIGHT NOW (no new data, uses existing rows)
-- Run this ENTIRE script in Supabase SQL Editor (Select All, then Run)

DO $$
DECLARE
    aid UUID;
    n_apt INTEGER;
BEGIN
    SELECT COUNT(*) INTO n_apt FROM public.apartments;
    IF n_apt < 1 THEN
        RAISE NOTICE 'No apartments found. Run test-apartment-webhooks-fake-data.sql first.';
        RETURN;
    END IF;

    SELECT id INTO aid FROM public.apartments ORDER BY created_at DESC LIMIT 1;

    -- 1) Trigger CreateLink webhook
    UPDATE public.apartments SET status = 'Null' WHERE id = aid;
    UPDATE public.apartments SET status = 'CreateLink' WHERE id = aid;
    RAISE NOTICE 'CreateLink webhook triggered for apartment %', aid;

    PERFORM pg_sleep(2);

    -- 2) Trigger Active webhook (same apartment)
    UPDATE public.apartments SET status = 'Null' WHERE id = aid;
    UPDATE public.apartments SET status = 'Active' WHERE id = aid;
    RAISE NOTICE 'Active webhook triggered for apartment %', aid;

    RAISE NOTICE 'Done. Check n8n executions.';
END $$;

SELECT 'Webhooks triggered. Check n8n.' AS result;
