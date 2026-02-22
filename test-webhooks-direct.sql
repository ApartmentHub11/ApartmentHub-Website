-- Direct Webhook Testing with Fake Payloads
-- This script directly calls webhook endpoints with fake data
-- Useful for testing webhook endpoints without database triggers
-- Requires pg_net extension

-- Enable pg_net extension
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_net;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_net extension not available. Direct webhook calls may not work.';
END $$;

-- ==========================================
-- TEST 1: Accounts Tags Webhook (Direct Call)
-- ==========================================

DO $$
DECLARE
    webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    fake_payload JSONB;
    response_id BIGINT;
BEGIN
    RAISE NOTICE '=== TEST 1: Direct Accounts Tags Webhook Call ===';
    
    fake_payload := jsonb_build_object(
        'event_type', 'UPDATE',
        'account_id', gen_random_uuid()::text,
        'tenant_name', 'Fake Direct Test Tenant',
        'whatsapp_number', '+31612345678',
        'email', 'fake-direct-test@example.com',
        'tags', ARRAY['direct-test-tag-1', 'direct-test-tag-2', 'webhook-test'],
        'old_tags', ARRAY['old-tag-1'],
        'timestamp', NOW(),
        'salesforce_account_id', 'SF-DIRECT-TEST-12345'
    );
    
    RAISE NOTICE 'Sending fake payload to: %', webhook_url;
    RAISE NOTICE 'Payload: %', fake_payload;
    
    BEGIN
        SELECT id INTO response_id
        FROM net.http_post(
            url := webhook_url,
            headers := jsonb_build_object(
                'Content-Type', 'application/json'
            ),
            body := fake_payload::text
        );
        
        RAISE NOTICE '✅ Webhook call submitted! Request ID: %', response_id;
        RAISE NOTICE '   Check your n8n endpoint to verify the request was received.';
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '❌ Webhook call failed: %', SQLERRM;
    END;
    
    RAISE NOTICE '';
END $$;

-- Wait a moment
SELECT pg_sleep(2);

-- ==========================================
-- TEST 2: Apartment CreateLink Webhook (Direct Call)
-- ==========================================

DO $$
DECLARE
    webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    fake_payload JSONB;
    response_id BIGINT;
BEGIN
    RAISE NOTICE '=== TEST 2: Direct Apartment CreateLink Webhook Call ===';
    
    fake_payload := jsonb_build_object(
        'id', gen_random_uuid()::text,
        'full_address', 'Fake Direct Test Street 789, Direct Test Area',
        'street', 'Fake Direct Test Street 789',
        'area', 'Direct Test Area',
        'zip_code', '9999ZZ',
        'rental_price', 1750.50,
        'bedrooms', '2',
        'square_meters', 85,
        'tags', ARRAY['direct-test-apartment', 'furnished', 'city-center'],
        'status', 'CreateLink',
        'event_link', 'https://cal.com/fake-direct-test',
        'booking_details', '{}'::jsonb,
        'slot_dates', '[]'::jsonb,
        'salesforce_id', 'SF-DIRECT-CREATELINK-12345',
        'additional_notes', 'This is a direct webhook test payload',
        'real_estate_agent_id', gen_random_uuid()::text,
        'real_estate_agent', jsonb_build_object(
            'id', gen_random_uuid()::text,
            'name', 'Fake Direct Test Agent',
            'phone_number', '+31698765432',
            'picture_url', 'https://example.com/fake-agent.jpg'
        ),
        'viewing_participants', '[]'::jsonb,
        'viewing_cancellations', '[]'::jsonb,
        'booking_reschedules', '[]'::jsonb,
        'apartmenthub_agents', '[]'::jsonb,
        'people_making_offer', '[]'::jsonb,
        'offers_in', '[]'::jsonb,
        'offers_sent', '[]'::jsonb,
        'created_at', NOW(),
        'updated_at', NOW(),
        'timestamp', NOW()
    );
    
    RAISE NOTICE 'Sending fake payload to: %', webhook_url;
    RAISE NOTICE 'Payload size: % bytes', length(fake_payload::text);
    
    BEGIN
        SELECT id INTO response_id
        FROM net.http_post(
            url := webhook_url,
            headers := jsonb_build_object(
                'Content-Type', 'application/json'
            ),
            body := fake_payload::text
        );
        
        RAISE NOTICE '✅ Webhook call submitted! Request ID: %', response_id;
        RAISE NOTICE '   Check your n8n endpoint to verify the request was received.';
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '❌ Webhook call failed: %', SQLERRM;
    END;
    
    RAISE NOTICE '';
END $$;

-- Wait a moment
SELECT pg_sleep(2);

-- ==========================================
-- TEST 3: Apartment Active Webhook (Direct Call)
-- ==========================================

DO $$
DECLARE
    webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';
    fake_payload JSONB;
    fake_apartment JSONB;
    fake_matched_tenants JSONB;
    response_id BIGINT;
BEGIN
    RAISE NOTICE '=== TEST 3: Direct Apartment Active Webhook Call ===';
    
    -- Create fake apartment data
    fake_apartment := jsonb_build_object(
        'id', gen_random_uuid()::text,
        'full_address', 'Fake Direct Active Street 321, Direct Active Area',
        'street', 'Fake Direct Active Street 321',
        'area', 'Direct Active Area',
        'zip_code', '8888YY',
        'rental_price', 2200.00,
        'bedrooms', '3',
        'square_meters', 120,
        'tags', ARRAY['pet-friendly', 'parking', 'garden', 'balcony'],
        'status', 'Active',
        'event_link', 'https://cal.com/fake-direct-active',
        'booking_details', jsonb_build_object(
            'available', true,
            'booking_url', 'https://cal.com/fake-direct-active'
        ),
        'slot_dates', jsonb_build_array(
            jsonb_build_object('date', '2026-03-15', 'time', '10:00'),
            jsonb_build_object('date', '2026-03-15', 'time', '14:00')
        ),
        'salesforce_id', 'SF-DIRECT-ACTIVE-12345',
        'additional_notes', 'This is a direct webhook test for Active status',
        'real_estate_agent_id', gen_random_uuid()::text,
        'real_estate_agent', jsonb_build_object(
            'id', gen_random_uuid()::text,
            'name', 'Fake Direct Active Agent',
            'phone_number', '+31655555555',
            'picture_url', 'https://example.com/fake-active-agent.jpg'
        ),
        'viewing_participants', '[]'::jsonb,
        'viewing_cancellations', '[]'::jsonb,
        'booking_reschedules', '[]'::jsonb,
        'apartmenthub_agents', '[]'::jsonb,
        'people_making_offer', '[]'::jsonb,
        'offers_in', '[]'::jsonb,
        'offers_sent', '[]'::jsonb,
        'created_at', NOW(),
        'updated_at', NOW()
    );
    
    -- Create fake matched tenants
    fake_matched_tenants := jsonb_build_array(
        jsonb_build_object(
            'account_id', gen_random_uuid()::text,
            'tenant_name', 'Fake Matched Tenant 1',
            'whatsapp_number', '+31611111111',
            'email', 'matched-tenant-1@example.com',
            'tags', ARRAY['pet-friendly', 'parking'],
            'preferred_location', 'Amsterdam',
            'move_in_date', '2026-04-01',
            'work_status', 'werknemer',
            'monthly_income', 4000,
            'salesforce_account_id', 'SF-MATCHED-1',
            'status', 'Deal In Progress',
            'documentation_status', 'Complete'
        ),
        jsonb_build_object(
            'account_id', gen_random_uuid()::text,
            'tenant_name', 'Fake Matched Tenant 2',
            'whatsapp_number', '+31622222222',
            'email', 'matched-tenant-2@example.com',
            'tags', ARRAY['pet-friendly', 'garden'],
            'preferred_location', 'Amsterdam',
            'move_in_date', '2026-05-01',
            'work_status', 'ondernemer',
            'monthly_income', 5000,
            'salesforce_account_id', 'SF-MATCHED-2',
            'status', 'Offer Made',
            'documentation_status', 'Pending'
        )
    );
    
    -- Build complete payload
    fake_payload := jsonb_build_object(
        'event_type', 'apartment_status_active',
        'apartment', fake_apartment,
        'matched_tenants', fake_matched_tenants,
        'matched_tenants_count', jsonb_array_length(fake_matched_tenants),
        'timestamp', NOW()
    );
    
    RAISE NOTICE 'Sending fake payload to: %', webhook_url;
    RAISE NOTICE 'Payload size: % bytes', length(fake_payload::text);
    RAISE NOTICE 'Matched tenants count: %', jsonb_array_length(fake_matched_tenants);
    
    BEGIN
        SELECT id INTO response_id
        FROM net.http_post(
            url := webhook_url,
            headers := jsonb_build_object(
                'Content-Type', 'application/json'
            ),
            body := fake_payload::text
        );
        
        RAISE NOTICE '✅ Webhook call submitted! Request ID: %', response_id;
        RAISE NOTICE '   Check your n8n endpoint to verify the request was received.';
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '❌ Webhook call failed: %', SQLERRM;
    END;
    
    RAISE NOTICE '';
END $$;

-- ==========================================
-- SUMMARY
-- ==========================================

SELECT '🎉 All direct webhook tests completed!' as result;
SELECT '📋 Check your n8n webhook endpoints to verify all requests were received.' as next_step;
