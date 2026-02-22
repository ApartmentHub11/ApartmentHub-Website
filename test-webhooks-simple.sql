-- Simple Webhook Test Script
-- Run this in Supabase SQL Editor after applying migrations

-- ==========================================
-- STEP 1: Test Accounts Tags Webhook
-- ==========================================

-- Option A: Update existing account tags
UPDATE public.accounts
SET tags = ARRAY['test-tag-updated', 'webhook-test']
WHERE id = (SELECT id FROM public.accounts LIMIT 1)
RETURNING id, tenant_name, tags;

-- Option B: Insert new account with tags (if you want to test INSERT trigger)
-- INSERT INTO public.accounts (tenant_name, whatsapp_number, email, tags)
-- VALUES ('Webhook Test Account', '+31612345678', 'webhook-test@example.com', ARRAY['test-tag-1', 'test-tag-2'])
-- RETURNING id, tenant_name, tags;

-- ==========================================
-- STEP 2: Test Apartment CreateLink Webhook
-- ==========================================

-- Update apartment status to CreateLink
UPDATE public.apartments
SET status = 'CreateLink'
WHERE id = (SELECT id FROM public.apartments LIMIT 1)
RETURNING id, name, status;

-- ==========================================
-- STEP 3: Test Apartment Active Webhook
-- ==========================================

-- First, ensure you have accounts with matching tags
-- Update apartment tags to match some account tags
UPDATE public.apartments
SET tags = ARRAY['matching-tag']
WHERE id = (SELECT id FROM public.apartments LIMIT 1);

-- Update account tags to match
UPDATE public.accounts
SET tags = ARRAY['matching-tag', 'another-tag']
WHERE id = (SELECT id FROM public.accounts LIMIT 1);

-- Now change apartment status to Active
UPDATE public.apartments
SET status = 'Active'
WHERE id = (SELECT id FROM public.apartments LIMIT 1)
RETURNING id, name, status, tags;

-- ==========================================
-- VERIFY WEBHOOK CALLS (if pg_net is enabled)
-- ==========================================

-- Check recent webhook calls (if pg_net stores request history)
-- Note: This may not be available depending on pg_net version
SELECT 
    id,
    url,
    method,
    status_code,
    created_at
FROM net.http_request_queue
ORDER BY created_at DESC
LIMIT 10;

-- Alternative: Check if triggers exist
SELECT 
    trigger_name,
    event_object_table,
    event_manipulation,
    action_timing
FROM information_schema.triggers
WHERE trigger_name LIKE '%webhook%'
ORDER BY trigger_name;
