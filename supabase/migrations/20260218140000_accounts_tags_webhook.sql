-- Migration: Webhook trigger for accounts.tags column changes
-- Triggers webhook when tags column is modified in accounts table

-- Enable pg_net extension for async HTTP requests (recommended for Supabase)
-- If pg_net is not available, this will fail gracefully and you can use the alternative approach below
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_net;
EXCEPTION WHEN OTHERS THEN
    -- If pg_net is not available, the trigger will still be created but webhook calls will fail silently
    -- Consider using Supabase Edge Functions as an alternative
    RAISE NOTICE 'pg_net extension not available. Webhook calls may not work. Consider using Edge Functions instead.';
END $$;

-- Function to call webhook when tags change
CREATE OR REPLACE FUNCTION public.trigger_accounts_tags_webhook()
RETURNS TRIGGER AS $$
DECLARE
    v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';
    v_payload JSONB;
    v_tags_changed BOOLEAN := false;
BEGIN
    -- Check if tags column has changed
    -- For INSERT, check if tags is not null/empty
    -- For UPDATE, check if tags value actually changed
    IF TG_OP = 'INSERT' THEN
        -- On insert, trigger if tags is provided
        IF NEW.tags IS NOT NULL AND array_length(NEW.tags, 1) > 0 THEN
            v_tags_changed := true;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- On update, trigger only if tags actually changed
        -- Compare arrays: if old is null/empty and new is not, or vice versa, or if arrays differ
        IF (OLD.tags IS DISTINCT FROM NEW.tags) THEN
            v_tags_changed := true;
        END IF;
    END IF;

    -- Only trigger webhook if tags actually changed
    IF v_tags_changed THEN
        -- Build payload with account information
        v_payload := jsonb_build_object(
            'event_type', TG_OP,
            'account_id', NEW.id,
            'tenant_name', NEW.tenant_name,
            'whatsapp_number', NEW.whatsapp_number,
            'email', NEW.email,
            'tags', NEW.tags,
            'old_tags', CASE WHEN TG_OP = 'UPDATE' THEN OLD.tags ELSE NULL END,
            'timestamp', NOW(),
            'salesforce_account_id', NEW.salesforce_account_id
        );

        -- Call webhook asynchronously using pg_net (non-blocking)
        -- This doesn't block the transaction
        BEGIN
            PERFORM net.http_post(
                url := v_webhook_url,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json'
                ),
                body := v_payload::text
            );
        EXCEPTION WHEN OTHERS THEN
            -- Log error but don't fail the transaction
            -- Webhook failures should not prevent database operations
            RAISE WARNING 'Webhook call failed: %', SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on accounts table for tags changes
DROP TRIGGER IF EXISTS trigger_accounts_tags_webhook ON public.accounts;
CREATE TRIGGER trigger_accounts_tags_webhook
    AFTER INSERT OR UPDATE OF tags ON public.accounts
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_accounts_tags_webhook();

-- Comment on function
COMMENT ON FUNCTION public.trigger_accounts_tags_webhook() IS 
'Triggers webhook when tags column changes in accounts table. Uses pg_net for async HTTP requests. Webhook URL: https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link';

-- Alternative approach if pg_net is not available:
-- Create a Supabase Edge Function that calls the webhook, then call that function from the trigger
-- Example Edge Function code would be:
--   const response = await fetch('https://davidvanwachem.app.n8n.cloud/webhook/trigger-status-change-create-link', {
--     method: 'POST',
--     headers: { 'Content-Type': 'application/json' },
--     body: JSON.stringify(req.body)
--   });
-- Then call it from the trigger using: SELECT net.http_post(url := 'https://your-project.supabase.co/functions/v1/your-function', ...)
