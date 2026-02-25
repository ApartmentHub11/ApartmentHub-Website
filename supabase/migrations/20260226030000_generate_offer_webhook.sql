-- Migration: Generate Offer Webhook
--
-- When a phone number is entered into the "generate_offer" column
-- on the apartments table, automatically send a webhook to n8n
-- with tenant phone number and apartment details.

-- ==========================================
-- 1. Add generate_offer column to apartments
-- ==========================================
ALTER TABLE public.apartments
ADD COLUMN IF NOT EXISTS "generate_offer" TEXT;

COMMENT ON COLUMN public.apartments."generate_offer" IS
'Enter a tenant phone number here to trigger an automatic offer message via n8n webhook.';

-- ==========================================
-- 2. Trigger function: fires when generate_offer is set/changed
-- ==========================================
CREATE OR REPLACE FUNCTION public.handle_generate_offer()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url TEXT := 'https://davidvanwachem.app.n8n.cloud/webhook/send-offer-to-the-tenant';
  v_payload JSONB;
  v_phone TEXT;
BEGIN
  v_phone := trim(NEW."generate_offer");

  -- Only fire when a non-empty phone number is set
  IF v_phone IS NULL OR v_phone = '' THEN
    RETURN NEW;
  END IF;

  -- Build payload with tenant phone + full apartment details
  v_payload := jsonb_build_object(
    'event_type', 'generate_offer',
    'tenant_phone', v_phone,
    'apartment_id', NEW.id,
    'apartment_name', NEW.name,
    'full_address', COALESCE(NEW."Full Address", NEW.full_address, NEW.street),
    'area', NEW.area,
    'rental_price', NEW.rental_price,
    'bedrooms', NEW.bedrooms,
    'square_meters', NEW.square_meters,
    'event_link', NEW.event_link,
    'status', NEW.status,
    'salesforce_id', NEW.salesforce_id,
    'additional_notes', NEW.additional_notes,
    'tags', to_jsonb(COALESCE(NEW.tags, ARRAY[]::TEXT[])),
    'timestamp', NOW()
  );

  BEGIN
    PERFORM net.http_post(
      url := v_webhook_url,
      body := v_payload,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'User-Agent', 'Supabase-Webhook-Trigger'
      )
    );
    RAISE NOTICE '[Generate Offer] Webhook sent for apartment % to phone %', NEW.id, v_phone;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[Generate Offer] Webhook failed for apartment %: %', NEW.id, SQLERRM;
  END;

  -- Clear the field after sending so it can be re-used
  -- (done via a separate UPDATE to avoid recursion issues)
  -- The trigger won't re-fire because we only fire on non-empty values
  NEW."generate_offer" := NULL;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.handle_generate_offer() IS
'When a phone number is entered in apartments.generate_offer, sends a webhook to n8n with tenant phone and apartment details, then clears the field.';

-- ==========================================
-- 3. Create trigger
-- ==========================================
DROP TRIGGER IF EXISTS trigger_generate_offer ON public.apartments;
CREATE TRIGGER trigger_generate_offer
  BEFORE UPDATE OF "generate_offer" ON public.apartments
  FOR EACH ROW
  WHEN (NEW."generate_offer" IS NOT NULL AND trim(NEW."generate_offer") != ''
        AND (OLD."generate_offer" IS DISTINCT FROM NEW."generate_offer"))
  EXECUTE FUNCTION public.handle_generate_offer();
