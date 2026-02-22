-- Quick verification: Check if triggers fire when apartment status changes
-- This creates a test apartment, updates it, and shows what happens
-- Run this ENTIRE script in Supabase SQL Editor

DO $$
DECLARE
    test_id UUID;
    current_status TEXT;
BEGIN
    RAISE NOTICE 'Creating test apartment...';
    
    INSERT INTO public.apartments ("Full Address", status, tags)
    VALUES ('Curl Test Street ' || extract(epoch from now())::text, 'Null', ARRAY['curl-test'])
    RETURNING id INTO test_id;
    
    RAISE NOTICE 'Created apartment ID: %', test_id;
    RAISE NOTICE '';
    RAISE NOTICE 'Now updating status to CreateLink (should trigger webhook)...';
    
    UPDATE public.apartments SET status = 'CreateLink' WHERE id = test_id;
    
    SELECT COALESCE(to_jsonb(apartments)->>'Status', to_jsonb(apartments)->>'status') 
    INTO current_status
    FROM public.apartments WHERE id = test_id;
    
    RAISE NOTICE 'Status after update: %', current_status;
    RAISE NOTICE '';
    RAISE NOTICE '⏳ Wait 5 seconds, then check n8n for webhook execution...';
    RAISE NOTICE '   Expected webhook: trigger-status-change-create-link';
    
    PERFORM pg_sleep(5);
    
    RAISE NOTICE '';
    RAISE NOTICE 'Now updating status to Active (should trigger webhook)...';
    
    UPDATE public.apartments SET status = 'Null' WHERE id = test_id;
    UPDATE public.apartments SET status = 'Active' WHERE id = test_id;
    
    SELECT COALESCE(to_jsonb(apartments)->>'Status', to_jsonb(apartments)->>'status') 
    INTO current_status
    FROM public.apartments WHERE id = test_id;
    
    RAISE NOTICE 'Status after update: %', current_status;
    RAISE NOTICE '';
    RAISE NOTICE '⏳ Wait 5 seconds, then check n8n for webhook execution...';
    RAISE NOTICE '   Expected webhook: trigger-status-change-active';
    RAISE NOTICE '';
    RAISE NOTICE 'Test apartment ID: %', test_id;
    RAISE NOTICE 'You can delete it later if needed.';
    
END $$;

-- Show the test apartment
SELECT 
    id,
    "Full Address" as address,
    COALESCE(to_jsonb(apartments)->>'Status', to_jsonb(apartments)->>'status') as status,
    created_at
FROM public.apartments
WHERE "Full Address" LIKE 'Curl Test Street%'
ORDER BY created_at DESC
LIMIT 1;

SELECT 'Test complete. Check n8n executions NOW.' AS result;
