-- Cleanup: Remove ALL duplicate webhook triggers
-- Keep only trigger_qualified_user_active_webhook for status changes to Active
-- This prevents webhooks from firing multiple times (currently 7 triggers = 7x webhook calls!)

-- Drop ALL duplicate triggers (found 7 total triggers, keeping only 1)
DROP TRIGGER IF EXISTS trg_apartment_status_active_webhook ON public.apartments;
DROP TRIGGER IF EXISTS trg_apartment_status_create_link_webhook ON public.apartments;
DROP TRIGGER IF EXISTS trigger_apartment_active_webhook ON public.apartments;
DROP TRIGGER IF EXISTS trigger_apartment_create_link_webhook ON public.apartments;
DROP TRIGGER IF EXISTS trigger_apartment_status_active_webhook ON public.apartments;
DROP TRIGGER IF EXISTS trigger_apartment_status_create_link_webhook ON public.apartments;

-- Keep ONLY trigger_qualified_user_active_webhook (fires when status changes to Active)
-- This is the one you want - it sends webhook with qualified_users data

-- Note: trigger_update_apartment_qualified_users is kept because it updates qualified_users
-- but it doesn't send webhooks, so it won't cause duplicate webhook calls
