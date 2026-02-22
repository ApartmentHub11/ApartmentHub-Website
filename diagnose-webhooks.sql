-- Webhook Diagnostic Script
-- This script helps diagnose why webhooks might not be reaching n8n

-- ==========================================
-- STEP 1: Check pg_net Extension Status
-- ==========================================
SELECT 
    'pg_net Extension Status' as check_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
        THEN '✅ Enabled' 
        ELSE '❌ Not Enabled' 
    END as status;

-- ==========================================
-- STEP 2: Check Webhook Request History (if available)
-- ==========================================
DO $$
DECLARE
    request_count INTEGER;
    rec RECORD;
BEGIN
    -- Try to check if pg_net request queue exists
    BEGIN
        SELECT COUNT(*) INTO request_count
        FROM net.http_request_queue
        WHERE created_at > NOW() - INTERVAL '1 hour';
        
        RAISE NOTICE '=== Recent Webhook Requests (Last Hour) ===';
        RAISE NOTICE 'Total requests: %', request_count;
        
        IF request_count > 0 THEN
            RAISE NOTICE '';
            RAISE NOTICE 'Recent requests:';
            FOR rec IN 
                SELECT id, url, method, status_code, created_at
                FROM net.http_request_queue
                WHERE created_at > NOW() - INTERVAL '1 hour'
                ORDER BY created_at DESC
                LIMIT 5
            LOOP
                RAISE NOTICE '  ID: %, URL: %, Status: %, Time: %', 
                    rec.id, rec.url, rec.status_code, rec.created_at;
            END LOOP;
        ELSE
            RAISE NOTICE '⚠️  No webhook requests found in the last hour.';
            RAISE NOTICE '   This might mean webhooks are not being sent.';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '⚠️  Could not check webhook request history: %', SQLERRM;
        RAISE NOTICE '   This is normal if pg_net does not store request history.';
    END;
END $$;

-- ==========================================
-- STEP 3: Test Webhook Endpoints Directly
-- ==========================================

DO $$
DECLARE
    webhook_url_1 TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    webhook_url_2 TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';
    test_payload JSONB;
    response_id BIGINT;
    test_result TEXT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Testing Webhook Endpoints Directly ===';
    RAISE NOTICE '';
    
    -- Test 1: CreateLink Webhook
    RAISE NOTICE 'Test 1: Testing CreateLink webhook endpoint...';
    test_payload := jsonb_build_object(
        'test', true,
        'timestamp', NOW(),
        'source', 'diagnostic_script'
    );
    
    BEGIN
        SELECT id INTO response_id
        FROM net.http_post(
            url := webhook_url_1,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'User-Agent', 'Supabase-Webhook-Test'
            ),
            body := test_payload::text
        );
        
        RAISE NOTICE '  ✅ Request submitted to: %', webhook_url_1;
        RAISE NOTICE '  Request ID: %', response_id;
        RAISE NOTICE '  ⏳ Check n8n now - you should see an execution!';
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '  ❌ Failed to send request: %', SQLERRM;
    END;
    
    -- Wait a moment
    PERFORM pg_sleep(2);
    
    -- Test 2: Active Webhook
    RAISE NOTICE '';
    RAISE NOTICE 'Test 2: Testing Active webhook endpoint...';
    
    BEGIN
        SELECT id INTO response_id
        FROM net.http_post(
            url := webhook_url_2,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'User-Agent', 'Supabase-Webhook-Test'
            ),
            body := test_payload::text
        );
        
        RAISE NOTICE '  ✅ Request submitted to: %', webhook_url_2;
        RAISE NOTICE '  Request ID: %', response_id;
        RAISE NOTICE '  ⏳ Check n8n now - you should see an execution!';
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '  ❌ Failed to send request: %', SQLERRM;
    END;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== Diagnostic Test Complete ===';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Check n8n webhook executions immediately';
    RAISE NOTICE '2. Verify webhook URLs are correct in n8n';
    RAISE NOTICE '3. Check if webhooks are "Active" in n8n';
    RAISE NOTICE '4. Check n8n execution logs for any errors';
    
END $$;

-- ==========================================
-- STEP 4: Verify Trigger Functions Exist
-- ==========================================
SELECT 
    'Trigger Function Check' as check_type,
    routine_name as function_name,
    CASE 
        WHEN routine_name IS NOT NULL THEN '✅ Exists'
        ELSE '❌ Missing'
    END as status
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
    'trigger_accounts_tags_webhook',
    'trigger_apartment_status_create_link_webhook',
    'trigger_apartment_status_active_webhook'
)
ORDER BY routine_name;

-- ==========================================
-- STEP 5: Check Trigger Configuration
-- ==========================================
SELECT 
    trigger_name,
    event_object_table,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE trigger_name IN (
    'trigger_accounts_tags_webhook',
    'trigger_apartment_status_create_link_webhook',
    'trigger_apartment_status_active_webhook'
)
ORDER BY trigger_name;

-- ==========================================
-- STEP 6: Manual Trigger Test
-- ==========================================

DO $$
DECLARE
    test_account_id UUID;
    test_apartment_id UUID;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Manual Trigger Test ===';
    RAISE NOTICE 'This will actually trigger the database triggers...';
    RAISE NOTICE '';
    
    -- Test Accounts Tags Trigger
    SELECT id INTO test_account_id FROM public.accounts LIMIT 1;
    IF test_account_id IS NOT NULL THEN
        RAISE NOTICE 'Triggering accounts tags webhook...';
        UPDATE public.accounts
        SET tags = ARRAY['diagnostic-test-' || extract(epoch from now())::text]
        WHERE id = test_account_id;
        RAISE NOTICE '  ✅ Accounts tags updated - webhook should be triggered';
        RAISE NOTICE '  ⏳ Check n8n for execution on: trigger-status-change-create-link';
    ELSE
        RAISE NOTICE '  ⚠️  No accounts found to test';
    END IF;
    
    PERFORM pg_sleep(2);
    
    -- Test Apartment CreateLink Trigger
    SELECT id INTO test_apartment_id FROM public.apartments LIMIT 1;
    IF test_apartment_id IS NOT NULL THEN
        RAISE NOTICE '';
        RAISE NOTICE 'Triggering apartment CreateLink webhook...';
        UPDATE public.apartments SET status = 'Null' WHERE id = test_apartment_id;
        UPDATE public.apartments SET status = 'CreateLink' WHERE id = test_apartment_id;
        RAISE NOTICE '  ✅ Apartment status changed to CreateLink - webhook should be triggered';
        RAISE NOTICE '  ⏳ Check n8n for execution on: trigger-status-change-create-link';
    ELSE
        RAISE NOTICE '  ⚠️  No apartments found to test';
    END IF;
    
    PERFORM pg_sleep(2);
    
    -- Test Apartment Active Trigger
    IF test_apartment_id IS NOT NULL THEN
        RAISE NOTICE '';
        RAISE NOTICE 'Triggering apartment Active webhook...';
        UPDATE public.apartments SET status = 'Null' WHERE id = test_apartment_id;
        UPDATE public.apartments SET status = 'Active' WHERE id = test_apartment_id;
        RAISE NOTICE '  ✅ Apartment status changed to Active - webhook should be triggered';
        RAISE NOTICE '  ⏳ Check n8n for execution on: trigger-status-change-active';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== All Trigger Tests Complete ===';
END $$;

SELECT '🔍 Diagnostic complete! Check the output above and verify in n8n.' as result;
