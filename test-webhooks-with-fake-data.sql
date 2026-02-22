-- Test Webhooks with Fake Data
-- This script creates fake data and triggers all webhooks
-- Run this in Supabase SQL Editor

-- ==========================================
-- SETUP: Create Fake Data
-- ==========================================

DO $$
DECLARE
    fake_account_id UUID;
    fake_apartment_create_link_id UUID;
    fake_apartment_active_id UUID;
    fake_real_estate_agent_id UUID;
    matching_tag TEXT := 'pet-friendly';
    test_timestamp TEXT;
BEGIN
    test_timestamp := extract(epoch from now())::text;
    
    RAISE NOTICE '=== Creating Fake Data for Webhook Testing ===';
    RAISE NOTICE '';
    
    -- ==========================================
    -- Create Fake Real Estate Agent (if needed)
    -- ==========================================
    SELECT id INTO fake_real_estate_agent_id 
    FROM public.real_estate_agents 
    LIMIT 1;
    
    IF fake_real_estate_agent_id IS NULL THEN
        INSERT INTO public.real_estate_agents (name, phone_number, picture_url)
        VALUES (
            'Test Agent ' || test_timestamp,
            '+31612345678',
            'https://example.com/agent.jpg'
        )
        RETURNING id INTO fake_real_estate_agent_id;
        RAISE NOTICE '✅ Created fake real estate agent: %', fake_real_estate_agent_id;
    ELSE
        RAISE NOTICE '✅ Using existing real estate agent: %', fake_real_estate_agent_id;
    END IF;
    
    -- ==========================================
    -- Create Fake Account with Tags
    -- ==========================================
    INSERT INTO public.accounts (
        tenant_name,
        whatsapp_number,
        email,
        nationality,
        date_of_birth,
        sex,
        preferred_language,
        tags,
        preferred_location,
        work_status,
        monthly_income,
        documentation_status
    ) VALUES (
        'Fake Tenant ' || test_timestamp,
        '+316' || LPAD((random() * 99999999)::int::text, 8, '0'),
        'fake-tenant-' || test_timestamp || '@test.com',
        'Dutch',
        '1990-01-15'::date,
        'Male',
        'nl',
        ARRAY[matching_tag, 'parking', 'balcony'],
        'Amsterdam',
        'werknemer',
        3500,
        'Pending'
    )
    RETURNING id INTO fake_account_id;
    
    RAISE NOTICE '✅ Created fake account: %', fake_account_id;
    RAISE NOTICE '   Tags: pet-friendly, parking, balcony';
    RAISE NOTICE '';
    
    -- ==========================================
    -- Create Fake Apartment for CreateLink Test
    -- ==========================================
    INSERT INTO public.apartments (
        full_address,
        street,
        area,
        zip_code,
        rental_price,
        bedrooms,
        square_meters,
        tags,
        status,
        event_link,
        salesforce_id,
        additional_notes,
        real_estate_agent_id,
        booking_details,
        slot_dates
    ) VALUES (
        'Fake Street 123, Test Area',
        'Fake Street 123',
        'Test Area',
        '1234AB',
        1500.00,
        '2',
        75,
        ARRAY['test-apartment-tag'],
        'Null',
        'https://cal.com/test-event',
        'SF-' || test_timestamp,
        'This is a fake apartment for testing CreateLink webhook',
        fake_real_estate_agent_id,
        '{}'::jsonb,
        '[]'::jsonb
    )
    RETURNING id INTO fake_apartment_create_link_id;
    
    RAISE NOTICE '✅ Created fake apartment for CreateLink test: %', fake_apartment_create_link_id;
    RAISE NOTICE '';
    
    -- ==========================================
    -- Create Fake Apartment for Active Test (with matching tags)
    -- ==========================================
    INSERT INTO public.apartments (
        full_address,
        street,
        area,
        zip_code,
        rental_price,
        bedrooms,
        square_meters,
        tags,
        status,
        event_link,
        salesforce_id,
        additional_notes,
        real_estate_agent_id,
        booking_details,
        slot_dates,
        viewing_participants,
        offers_in
    ) VALUES (
        'Active Test Street 456, Active Area',
        'Active Test Street 456',
        'Active Area',
        '5678CD',
        2000.00,
        '3',
        100,
        ARRAY[matching_tag, 'parking', 'garden'], -- Matching tags with account
        'Null',
        'https://cal.com/active-event',
        'SF-ACTIVE-' || test_timestamp,
        'This is a fake apartment for testing Active webhook with matched tenants',
        fake_real_estate_agent_id,
        '{"available": true}'::jsonb,
        '[{"date": "2026-03-01", "time": "14:00"}]'::jsonb,
        '[]'::jsonb,
        '[]'::jsonb
    )
    RETURNING id INTO fake_apartment_active_id;
    
    RAISE NOTICE '✅ Created fake apartment for Active test: %', fake_apartment_active_id;
    RAISE NOTICE '   Tags: pet-friendly, parking, garden (matching with account)';
    RAISE NOTICE '';
    
    -- ==========================================
    -- TRIGGER WEBHOOKS
    -- ==========================================
    
    RAISE NOTICE '=== Triggering Webhooks ===';
    RAISE NOTICE '';
    
    -- Test 1: Accounts Tags Webhook
    RAISE NOTICE '1. Triggering Accounts Tags Webhook...';
    UPDATE public.accounts
    SET tags = ARRAY['updated-tag-1', 'updated-tag-2', 'webhook-test-' || test_timestamp]
    WHERE id = fake_account_id;
    
    RAISE NOTICE '   ✅ Accounts tags updated!';
    RAISE NOTICE '   📡 Webhook should be sent to: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    RAISE NOTICE '';
    
    -- Wait a moment (simulate delay)
    PERFORM pg_sleep(1);
    
    -- Test 2: Apartment CreateLink Webhook
    RAISE NOTICE '2. Triggering Apartment CreateLink Webhook...';
    UPDATE public.apartments
    SET status = 'CreateLink'
    WHERE id = fake_apartment_create_link_id;
    
    RAISE NOTICE '   ✅ Apartment status changed to CreateLink!';
    RAISE NOTICE '   📡 Webhook should be sent to: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    RAISE NOTICE '';
    
    -- Wait a moment
    PERFORM pg_sleep(1);
    
    -- Test 3: Apartment Active Webhook
    RAISE NOTICE '3. Triggering Apartment Active Webhook...';
    UPDATE public.apartments
    SET status = 'Active'
    WHERE id = fake_apartment_active_id;
    
    RAISE NOTICE '   ✅ Apartment status changed to Active!';
    RAISE NOTICE '   📡 Webhook should be sent to: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';
    RAISE NOTICE '   👥 Should include matched tenant (account with matching tags)';
    RAISE NOTICE '';
    
    -- ==========================================
    -- SUMMARY
    -- ==========================================
    
    RAISE NOTICE '=== Test Summary ===';
    RAISE NOTICE 'Created fake account ID: %', fake_account_id;
    RAISE NOTICE 'Created fake apartment (CreateLink) ID: %', fake_apartment_create_link_id;
    RAISE NOTICE 'Created fake apartment (Active) ID: %', fake_apartment_active_id;
    RAISE NOTICE '';
    RAISE NOTICE '✅ All webhooks have been triggered!';
    RAISE NOTICE '📋 Check your n8n webhook endpoints to verify the requests were received.';
    RAISE NOTICE '';
    RAISE NOTICE 'To clean up test data, run:';
    RAISE NOTICE '  DELETE FROM public.apartments WHERE id IN (''%'', ''%'');', fake_apartment_create_link_id, fake_apartment_active_id;
    RAISE NOTICE '  DELETE FROM public.accounts WHERE id = ''%'';', fake_account_id;
    
END $$;

-- ==========================================
-- VERIFY CREATED DATA
-- ==========================================

SELECT 
    'Fake Account' as type,
    id::text as id,
    tenant_name as name,
    tags,
    created_at
FROM public.accounts
WHERE tenant_name LIKE 'Fake Tenant%'
ORDER BY created_at DESC
LIMIT 1;

SELECT 
    'Fake Apartment (CreateLink)' as type,
    id::text as id,
    full_address as name,
    status,
    tags,
    created_at
FROM public.apartments
WHERE additional_notes LIKE '%CreateLink webhook%'
ORDER BY created_at DESC
LIMIT 1;

SELECT 
    'Fake Apartment (Active)' as type,
    id::text as id,
    full_address as name,
    status,
    tags,
    created_at
FROM public.apartments
WHERE additional_notes LIKE '%Active webhook%'
ORDER BY created_at DESC
LIMIT 1;

-- ==========================================
-- CHECK WEBHOOK TRIGGERS STATUS
-- ==========================================

SELECT 
    '✅ Webhook Triggers Status' as status,
    COUNT(*) as trigger_count
FROM information_schema.triggers
WHERE trigger_name IN (
    'trigger_accounts_tags_webhook',
    'trigger_apartment_status_create_link_webhook',
    'trigger_apartment_status_active_webhook'
);

SELECT '🎉 Fake data created and webhooks triggered! Check your n8n endpoints.' as result;
