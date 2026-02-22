-- Test Apartment Webhooks with Fake Data
-- Creates fake apartment(s), then triggers CreateLink and Active webhooks
--
-- IMPORTANT: Run the ENTIRE script (Select All + Run), not just the last line.
-- If you only run the last SELECT, no data is created and no webhooks fire.

DO $$
DECLARE
    fake_apartment_1_id UUID;
    fake_apartment_2_id UUID;
    fake_agent_id UUID;
    ts TEXT := extract(epoch from now())::text;
BEGIN
    RAISE NOTICE '=== Creating fake apartment data for webhook tests ===';
    RAISE NOTICE '';

    -- Get or create a real_estate_agent (optional, can be NULL)
    SELECT id INTO fake_agent_id FROM public.real_estate_agents LIMIT 1;

    -- Insert fake apartment 1 (for CreateLink webhook)
    -- Minimal columns: only "Full Address" (required), status, tags
    INSERT INTO public.apartments (
        "Full Address",
        status,
        tags
    ) VALUES (
        'Fake Test Street 100, Webhook Test Area',
        'Null',
        ARRAY['test-create-link', 'furnished']
    )
    RETURNING id INTO fake_apartment_1_id;

    RAISE NOTICE 'Created fake apartment 1 (CreateLink test): %', fake_apartment_1_id;

    -- Insert fake apartment 2 (for Active webhook, with tags for matching)
    INSERT INTO public.apartments (
        "Full Address",
        status,
        tags
    ) VALUES (
        'Fake Active Street 200, Active Test Area',
        'Null',
        ARRAY['test-active', 'pet-friendly', 'parking']
    )
    RETURNING id INTO fake_apartment_2_id;

    RAISE NOTICE 'Created fake apartment 2 (Active test): %', fake_apartment_2_id;
    RAISE NOTICE '';

    -- Trigger CreateLink webhook
    RAISE NOTICE 'Triggering CreateLink webhook...';
    UPDATE public.apartments
    SET status = 'CreateLink'
    WHERE id = fake_apartment_1_id;

    RAISE NOTICE '  -> Status set to CreateLink for apartment 1';
    RAISE NOTICE '  -> Check n8n: trigger-status-change-create-link';
    RAISE NOTICE '';

    PERFORM pg_sleep(2);

    -- Trigger Active webhook
    RAISE NOTICE 'Triggering Active webhook...';
    UPDATE public.apartments
    SET status = 'Active'
    WHERE id = fake_apartment_2_id;

    RAISE NOTICE '  -> Status set to Active for apartment 2';
    RAISE NOTICE '  -> Check n8n: trigger-status-change-active';
    RAISE NOTICE '';
    RAISE NOTICE '=== Done. Verify both executions in n8n. ===';
END $$;

-- Show the created rows
SELECT
    id,
    "Full Address" AS full_address,
    status,
    tags,
    created_at
FROM public.apartments
WHERE "Full Address" LIKE 'Fake %'
ORDER BY created_at DESC;

-- This message appears only if you run the whole script. Running just this line does NOT trigger webhooks.
SELECT 'Fake apartments created and webhooks triggered. Check n8n.' AS result;
