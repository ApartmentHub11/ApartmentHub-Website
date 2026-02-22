-- Debug script to verify webhook triggers are firing
-- This will help us see if triggers execute and if webhooks are called
-- Run this ENTIRE script in Supabase SQL Editor

DO $$
DECLARE
    test_apartment_id UUID;
    v_new_status TEXT;
    v_old_status TEXT;
    v_trigger_fired BOOLEAN := false;
BEGIN
    RAISE NOTICE '=== Testing Webhook Triggers ===';
    RAISE NOTICE '';

    -- Get an existing apartment
    SELECT id INTO test_apartment_id FROM public.apartments ORDER BY created_at DESC LIMIT 1;
    
    IF test_apartment_id IS NULL THEN
        RAISE NOTICE 'No apartments found. Creating one...';
        INSERT INTO public.apartments ("Full Address", status, tags)
        VALUES ('Debug Test Street, Debug Area', 'Null', ARRAY['debug-test'])
        RETURNING id INTO test_apartment_id;
        RAISE NOTICE 'Created apartment: %', test_apartment_id;
    ELSE
        RAISE NOTICE 'Using existing apartment: %', test_apartment_id;
    END IF;

    -- Check current status
    SELECT COALESCE(to_jsonb(apartments)->>'Status', to_jsonb(apartments)->>'status') INTO v_old_status
    FROM public.apartments WHERE id = test_apartment_id;
    
    RAISE NOTICE 'Current status: %', v_old_status;
    RAISE NOTICE '';

    -- Test 1: Trigger CreateLink webhook
    RAISE NOTICE '=== Test 1: Triggering CreateLink Webhook ===';
    RAISE NOTICE 'Updating apartment % to CreateLink...', test_apartment_id;
    
    -- Set to Null first to ensure status change
    UPDATE public.apartments 
    SET status = 'Null' 
    WHERE id = test_apartment_id;
    
    -- Now change to CreateLink (this should trigger webhook)
    UPDATE public.apartments 
    SET status = 'CreateLink' 
    WHERE id = test_apartment_id;
    
    -- Verify the update worked
    SELECT COALESCE(to_jsonb(apartments)->>'Status', to_jsonb(apartments)->>'status') INTO v_new_status
    FROM public.apartments WHERE id = test_apartment_id;
    
    RAISE NOTICE 'Status after update: %', v_new_status;
    RAISE NOTICE '✅ If status is CreateLink, the UPDATE succeeded';
    RAISE NOTICE '📡 Check n8n now for webhook execution on: trigger-status-change-create-link';
    RAISE NOTICE '';

    PERFORM pg_sleep(3);

    -- Test 2: Trigger Active webhook
    RAISE NOTICE '=== Test 2: Triggering Active Webhook ===';
    RAISE NOTICE 'Updating apartment % to Active...', test_apartment_id;
    
    -- Set to Null first
    UPDATE public.apartments 
    SET status = 'Null' 
    WHERE id = test_apartment_id;
    
    -- Now change to Active (this should trigger webhook)
    UPDATE public.apartments 
    SET status = 'Active' 
    WHERE id = test_apartment_id;
    
    -- Verify
    SELECT COALESCE(to_jsonb(apartments)->>'Status', to_jsonb(apartments)->>'status') INTO v_new_status
    FROM public.apartments WHERE id = test_apartment_id;
    
    RAISE NOTICE 'Status after update: %', v_new_status;
    RAISE NOTICE '✅ If status is Active, the UPDATE succeeded';
    RAISE NOTICE '📡 Check n8n now for webhook execution on: trigger-status-change-active';
    RAISE NOTICE '';

    RAISE NOTICE '=== Test Complete ===';
    RAISE NOTICE 'If you see the status updates above but NO webhooks in n8n, then:';
    RAISE NOTICE '1. Triggers might not be firing (check trigger definitions)';
    RAISE NOTICE '2. pg_net might not be working (check extension status)';
    RAISE NOTICE '3. Webhook URLs might be incorrect';
    RAISE NOTICE '4. Network/firewall might be blocking requests from Supabase to n8n';
    
END $$;

-- Verify triggers exist and are enabled
SELECT 
    trigger_name,
    event_object_table,
    event_manipulation,
    action_timing,
    CASE WHEN trigger_name IS NOT NULL THEN '✅ Exists' ELSE '❌ Missing' END as status
FROM information_schema.triggers
WHERE trigger_name IN (
    'trigger_apartment_status_create_link_webhook',
    'trigger_apartment_status_active_webhook'
)
ORDER BY trigger_name;

-- Check if functions exist
SELECT 
    routine_name,
    CASE WHEN routine_name IS NOT NULL THEN '✅ Exists' ELSE '❌ Missing' END as status
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
    'trigger_apartment_status_create_link_webhook',
    'trigger_apartment_status_active_webhook'
)
ORDER BY routine_name;

-- Check pg_net extension
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
        THEN '✅ pg_net enabled' 
        ELSE '❌ pg_net NOT enabled' 
    END as pg_net_status;

SELECT 'Debug test complete. Check the output above and verify in n8n.' AS result;
