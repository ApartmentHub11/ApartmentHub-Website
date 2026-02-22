-- ============================================
-- Test: Qualified Users Active Webhook
-- Run this in Supabase SQL Editor to test the webhook
-- ============================================

-- Step 1: Apply the migration (creates function + trigger)
\i supabase/migrations/20260220000000_qualified_users_active_webhook.sql
-- Note: \i doesn't work in Supabase SQL Editor. Paste migration first, then run this test.

-- ============================================
-- Step 2: Verify trigger and function exist
-- ============================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'trigger_qualified_user_active_webhook'
    ) THEN
        RAISE NOTICE '✅ Trigger exists: trigger_qualified_user_active_webhook';
    ELSE
        RAISE EXCEPTION '❌ Trigger not found. Run the migration first (20260220000000_qualified_users_active_webhook.sql)';
    END IF;
END $$;

-- ============================================
-- Step 3: Run test - simulate status change Null -> Active
-- ============================================
DO $$
DECLARE
    v_apt_id UUID;
    v_orig_status TEXT;
BEGIN
    -- Pick first apartment (or replace with specific ID)
    SELECT id, status INTO v_apt_id, v_orig_status
    FROM public.apartments
    LIMIT 1;
    
    IF v_apt_id IS NULL THEN
        RAISE EXCEPTION '❌ No apartments found. Create an apartment first.';
    END IF;
    
    RAISE NOTICE 'Testing apartment: % (original status: %)', v_apt_id, v_orig_status;
    
    -- Step 3a: Set status to Null (simulates "change from Active to Null")
    UPDATE public.apartments SET status = 'Null' WHERE id = v_apt_id;
    RAISE NOTICE '  -> Set status to Null';
    
    -- Step 3b: Set status to Active (this SHOULD trigger the webhook)
    UPDATE public.apartments SET status = 'Active' WHERE id = v_apt_id;
    RAISE NOTICE '  -> Set status to Active (webhook should have fired)';
    
    -- Step 3c: Restore original status
    UPDATE public.apartments SET status = COALESCE(v_orig_status, 'Null') WHERE id = v_apt_id;
    RAISE NOTICE '  -> Restored status to %', COALESCE(v_orig_status, 'Null');
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Test complete. Check your n8n workflow for webhook:';
    RAISE NOTICE '   https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-active';
END $$;
