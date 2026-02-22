-- Test Script for Webhook Triggers
-- Run this in Supabase SQL Editor to test webhook triggers
-- Make sure migrations have been applied first!

-- ==========================================
-- TEST 1: Accounts Tags Webhook
-- ==========================================
-- This should trigger when tags are updated in accounts table

DO $$
DECLARE
    v_test_account_id UUID;
    v_test_whatsapp TEXT := '+31612345678';
BEGIN
    RAISE NOTICE '=== TEST 1: Testing Accounts Tags Webhook ===';
    
    -- Check if there's an existing account to test with
    SELECT id INTO v_test_account_id
    FROM public.accounts
    WHERE whatsapp_number = v_test_whatsapp
    LIMIT 1;
    
    -- If no account exists, create a test account
    IF v_test_account_id IS NULL THEN
        INSERT INTO public.accounts (
            tenant_name,
            whatsapp_number,
            email,
            tags
        ) VALUES (
            'Test Tenant',
            v_test_whatsapp,
            'test@example.com',
            ARRAY['test-tag-1', 'test-tag-2']
        )
        RETURNING id INTO v_test_account_id;
        
        RAISE NOTICE 'Created test account with ID: %', v_test_account_id;
    ELSE
        RAISE NOTICE 'Using existing account with ID: %', v_test_account_id;
    END IF;
    
    -- Update tags to trigger webhook
    RAISE NOTICE 'Updating tags to trigger webhook...';
    UPDATE public.accounts
    SET tags = ARRAY['updated-tag-1', 'updated-tag-2', 'updated-tag-3']
    WHERE id = v_test_account_id;
    
    RAISE NOTICE 'Tags updated! Webhook should have been triggered.';
    RAISE NOTICE 'Check your webhook endpoint: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    RAISE NOTICE '';
END $$;

-- ==========================================
-- TEST 2: Apartment Status CreateLink Webhook
-- ==========================================
-- This should trigger when apartment status changes to 'CreateLink'

DO $$
DECLARE
    v_test_apartment_id UUID;
    v_test_apartment_name TEXT := 'Test Apartment for CreateLink';
BEGIN
    RAISE NOTICE '=== TEST 2: Testing Apartment CreateLink Webhook ===';
    
    -- Check if there's an existing apartment to test with
    SELECT id INTO v_test_apartment_id
    FROM public.apartments
    WHERE name = v_test_apartment_name
    LIMIT 1;
    
    -- If no apartment exists, create a test apartment
    IF v_test_apartment_id IS NULL THEN
        INSERT INTO public.apartments (
            name,
            street,
            area,
            full_address,
            zip_code,
            rental_price,
            bedrooms,
            square_meters,
            tags,
            status
        ) VALUES (
            v_test_apartment_name,
            'Test Street 123',
            'Test Area',
            'Test Street 123, Test Area',
            '1234AB',
            1500,
            '2',
            75,
            ARRAY['test-apartment-tag'],
            'Null'
        )
        RETURNING id INTO v_test_apartment_id;
        
        RAISE NOTICE 'Created test apartment with ID: %', v_test_apartment_id;
    ELSE
        RAISE NOTICE 'Using existing apartment with ID: %', v_test_apartment_id;
    END IF;
    
    -- Change status to CreateLink to trigger webhook
    RAISE NOTICE 'Changing status to CreateLink to trigger webhook...';
    UPDATE public.apartments
    SET status = 'CreateLink'
    WHERE id = v_test_apartment_id;
    
    RAISE NOTICE 'Status changed to CreateLink! Webhook should have been triggered.';
    RAISE NOTICE 'Check your webhook endpoint: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    RAISE NOTICE '';
END $$;

-- ==========================================
-- TEST 3: Apartment Status Active Webhook
-- ==========================================
-- This should trigger when apartment status changes to 'Active'
-- It should also send matched tenants based on tags

DO $$
DECLARE
    v_test_apartment_id UUID;
    v_test_apartment_name TEXT := 'Test Apartment for Active';
    v_test_account_id UUID;
BEGIN
    RAISE NOTICE '=== TEST 3: Testing Apartment Active Webhook ===';
    
    -- First, create a test account with matching tags
    SELECT id INTO v_test_account_id
    FROM public.accounts
    WHERE tenant_name = 'Test Tenant for Matching'
    LIMIT 1;
    
    IF v_test_account_id IS NULL THEN
        INSERT INTO public.accounts (
            tenant_name,
            whatsapp_number,
            email,
            tags
        ) VALUES (
            'Test Tenant for Matching',
            '+31698765432',
            'matching@example.com',
            ARRAY['test-apartment-tag', 'matching-tag'] -- Matching tag with apartment
        )
        RETURNING id INTO v_test_account_id;
        
        RAISE NOTICE 'Created test account with matching tags, ID: %', v_test_account_id;
    END IF;
    
    -- Check if there's an existing apartment to test with
    SELECT id INTO v_test_apartment_id
    FROM public.apartments
    WHERE name = v_test_apartment_name
    LIMIT 1;
    
    -- If no apartment exists, create a test apartment
    IF v_test_apartment_id IS NULL THEN
        INSERT INTO public.apartments (
            name,
            street,
            area,
            full_address,
            zip_code,
            rental_price,
            bedrooms,
            square_meters,
            tags,
            status
        ) VALUES (
            v_test_apartment_name,
            'Active Test Street 456',
            'Active Test Area',
            'Active Test Street 456, Active Test Area',
            '5678CD',
            2000,
            '3',
            100,
            ARRAY['test-apartment-tag', 'another-tag'], -- Matching tag with account
            'Null'
        )
        RETURNING id INTO v_test_apartment_id;
        
        RAISE NOTICE 'Created test apartment with ID: %', v_test_apartment_id;
    ELSE
        RAISE NOTICE 'Using existing apartment with ID: %', v_test_apartment_id;
    END IF;
    
    -- Change status to Active to trigger webhook
    RAISE NOTICE 'Changing status to Active to trigger webhook...';
    UPDATE public.apartments
    SET status = 'Active'
    WHERE id = v_test_apartment_id;
    
    RAISE NOTICE 'Status changed to Active! Webhook should have been triggered.';
    RAISE NOTICE 'Check your webhook endpoint: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';
    RAISE NOTICE 'The webhook should include apartment data and matched tenants.';
    RAISE NOTICE '';
END $$;

-- ==========================================
-- VERIFICATION QUERIES
-- ==========================================

-- Check if triggers exist
SELECT 
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name IN (
    'trigger_accounts_tags_webhook',
    'trigger_apartment_status_create_link_webhook',
    'trigger_apartment_status_active_webhook'
)
ORDER BY trigger_name;

-- Check if functions exist
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
    'trigger_accounts_tags_webhook',
    'trigger_apartment_status_create_link_webhook',
    'trigger_apartment_status_active_webhook',
    'get_matched_tenants_for_apartment'
)
ORDER BY routine_name;

-- Check pg_net extension status
SELECT 
    extname,
    extversion
FROM pg_extension
WHERE extname = 'pg_net';

RAISE NOTICE '=== Test Script Complete ===';
RAISE NOTICE 'Please check your webhook endpoints to verify the triggers are working.';
RAISE NOTICE 'If webhooks are not being received, check:';
RAISE NOTICE '1. pg_net extension is enabled';
RAISE NOTICE '2. Webhook URLs are correct';
RAISE NOTICE '3. Network/firewall allows outbound HTTP requests';
