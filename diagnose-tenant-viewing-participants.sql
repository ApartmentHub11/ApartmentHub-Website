-- Diagnostic: Why Abhinav (+31625504864) is not in viewing_participants
-- Run this in Supabase SQL Editor to debug
--
-- IMPORTANT: Run migrations first:  npx supabase db push
-- This script requires normalize_phone_for_match and build_tenant_participant (from migration 20260221100000)

-- 1. Check if migration was applied (triggers exist)
SELECT tgname AS trigger_name 
FROM pg_trigger 
WHERE tgrelid = 'public.tenants'::regclass 
  AND tgname = 'trigger_sync_tenant_to_viewing_participants';

-- 2. Find apartments and show which key holds the phone in qualified_users
SELECT 
  a.id AS apartment_id,
  a."Full Address",
  jsonb_pretty(a.qualified_users) AS qualified_users_raw,
  a.viewing_participants
FROM public.apartments a
WHERE a.qualified_users IS NOT NULL
  AND a.qualified_users::text ILIKE '%625504864%'  -- partial match for the number
  OR a.qualified_users::text ILIKE '%31625504864%';

-- 3. Test phone normalization (run after migration is applied)
SELECT 
  public.normalize_phone_for_match('+31625504864'::text) AS tenant_normalized,
  public.normalize_phone_for_match((qu->>'whatsapp_number')::text) AS qu_normalized
FROM public.apartments a,
     jsonb_array_elements(COALESCE(a.qualified_users, '[]'::jsonb)) qu
WHERE a.qualified_users::text ILIKE '%625504864%'
LIMIT 5;

-- 4. Manual fix: Sync Abhinav to viewing_participants for matching apartments
-- Run this block - it will add Abhinav to any apartment where qualified_users has +31625504864
-- (Run this if migration is applied but sync didn't run - e.g. tenant existed before migration)
DO $$
DECLARE
  v_apt RECORD;
  v_participant jsonb;
  v_current jsonb;
  v_updated jsonb;
BEGIN
  FOR v_apt IN
    SELECT a.id, a.qualified_users, a.viewing_participants
    FROM public.apartments a
    WHERE a.qualified_users IS NOT NULL
      AND jsonb_array_length(a.qualified_users) > 0
      AND EXISTS (
        SELECT 1 FROM jsonb_array_elements(a.qualified_users) qu
        WHERE public.normalize_phone_for_match(COALESCE(qu->>'whatsapp_number', qu->>'WhatsApp Number', qu->>'whatsAppNumber', qu->>'WhatsAppNumber')) = public.normalize_phone_for_match('+31625504864'::text)
      )
  LOOP
    SELECT public.build_tenant_participant(t) INTO v_participant
    FROM public.tenants t
    WHERE t.whatsapp_number = '+31625504864'
    LIMIT 1;
    
    IF v_participant IS NOT NULL THEN
      v_current := COALESCE(v_apt.viewing_participants, '[]'::jsonb);
      IF NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_current) elem
        WHERE (elem->>'tenant_id') = (v_participant->>'tenant_id')
      ) THEN
        v_updated := v_current || v_participant;
        UPDATE public.apartments
        SET viewing_participants = v_updated, updated_at = now()
        WHERE id = v_apt.id;
        RAISE NOTICE 'Added Abhinav to apartment %', v_apt.id;
      END IF;
    END IF;
  END LOOP;
END $$;

-- 5. Verify: Check that Abhinav now appears in viewing_participants
SELECT 
  a.id,
  a."Full Address",
  a.viewing_participants
FROM public.apartments a
WHERE a.viewing_participants::text LIKE '%31625504864%';
