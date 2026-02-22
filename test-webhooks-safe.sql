-- Safe Webhook Test Script
-- This script only updates existing records - no INSERTs
-- Run this in Supabase SQL Editor

-- ==========================================
-- TEST 1: Accounts Tags Webhook
-- ==========================================
DO $$
DECLARE
    test_account_id UUID;
    account_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO account_count FROM public.accounts;
    
    IF account_count = 0 THEN
        RAISE NOTICE '⚠️  No accounts found. Please create at least one account first.';
        RAISE NOTICE '   You can create one with: INSERT INTO public.accounts (tenant_name, whatsapp_number, email, tags) VALUES (''Test'', ''+31611111111'', ''test@test.com'', ARRAY[''test'']);';
    ELSE
        SELECT id INTO test_account_id FROM public.accounts LIMIT 1;
        
        -- Update tags to trigger webhook
        UPDATE public.accounts
        SET tags = ARRAY['webhook-test-' || extract(epoch from now())::text]
        WHERE id = test_account_id;
        
        RAISE NOTICE '✅ Accounts tags webhook triggered!';
        RAISE NOTICE '   Account ID: %', test_account_id;
        RAISE NOTICE '   Check: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    END IF;
END $$;

-- ==========================================
-- TEST 2: Apartment CreateLink Webhook
-- ==========================================
DO $$
DECLARE
    test_apartment_id UUID;
    apartment_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO apartment_count FROM public.apartments;
    
    IF apartment_count = 0 THEN
        RAISE NOTICE '⚠️  No apartments found. Please create at least one apartment first.';
        RAISE NOTICE '   You can create one with: INSERT INTO public.apartments (status, tags) VALUES (''Null'', ARRAY[''test'']);';
    ELSE
        SELECT id INTO test_apartment_id FROM public.apartments LIMIT 1;
        
        -- Set status to Null first (if not already)
        UPDATE public.apartments SET status = 'Null' WHERE id = test_apartment_id;
        
        -- Change to CreateLink to trigger webhook
        UPDATE public.apartments
        SET status = 'CreateLink'
        WHERE id = test_apartment_id;
        
        RAISE NOTICE '✅ Apartment CreateLink webhook triggered!';
        RAISE NOTICE '   Apartment ID: %', test_apartment_id;
        RAISE NOTICE '   Check: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    END IF;
END $$;

-- ==========================================
-- TEST 3: Apartment Active Webhook
-- ==========================================
DO $$
DECLARE
    test_apartment_id UUID;
    test_account_id UUID;
    apartment_count INTEGER;
    account_count INTEGER;
    matching_tag TEXT := 'matching-tag-' || extract(epoch from now())::text;
BEGIN
    SELECT COUNT(*) INTO apartment_count FROM public.apartments;
    SELECT COUNT(*) INTO account_count FROM public.accounts;
    
    IF apartment_count = 0 OR account_count = 0 THEN
        RAISE NOTICE '⚠️  Need at least one apartment and one account for this test.';
    ELSE
        SELECT id INTO test_apartment_id FROM public.apartments LIMIT 1;
        SELECT id INTO test_account_id FROM public.accounts LIMIT 1;
        
        -- Update tags to match
        UPDATE public.accounts SET tags = ARRAY[matching_tag] WHERE id = test_account_id;
        UPDATE public.apartments SET tags = ARRAY[matching_tag] WHERE id = test_apartment_id;
        
        -- Set status to Null first
        UPDATE public.apartments SET status = 'Null' WHERE id = test_apartment_id;
        
        -- Change to Active to trigger webhook
        UPDATE public.apartments
        SET status = 'Active'
        WHERE id = test_apartment_id;
        
        RAISE NOTICE '✅ Apartment Active webhook triggered!';
        RAISE NOTICE '   Apartment ID: %', test_apartment_id;
        RAISE NOTICE '   Matching tag: %', matching_tag;
        RAISE NOTICE '   Check: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';
    END IF;
END $$;

-- ==========================================
-- VERIFY TRIGGERS EXIST
-- ==========================================
SELECT 
    'Trigger: ' || trigger_name || ' on table: ' || event_object_table as status
FROM information_schema.triggers
WHERE trigger_name IN (
    'trigger_accounts_tags_webhook',
    'trigger_apartment_status_create_link_webhook',
    'trigger_apartment_status_active_webhook'
)
ORDER BY trigger_name;

-- Check table row counts
SELECT 
    'accounts' as table_name, 
    COUNT(*) as row_count 
FROM public.accounts
UNION ALL
SELECT 
    'apartments' as table_name, 
    COUNT(*) as row_count 
FROM public.apartments;

SELECT '✅ Test script completed! Check your webhook endpoints.' as result;
