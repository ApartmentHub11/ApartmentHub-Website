-- Migration: Add qualified_users column to apartments table
-- Stores matching users whose account tags match apartment's rental_price and bedrooms
-- Auto-updates via triggers when apartments or accounts change

-- 1. Add qualified_users column to apartments table
ALTER TABLE public.apartments 
ADD COLUMN IF NOT EXISTS qualified_users JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.apartments.qualified_users IS 
'Array of users (accounts) whose tags match this apartment. Auto-updated when apartment or account data changes.';

-- 2. Function to calculate qualified users for an apartment
CREATE OR REPLACE FUNCTION public.calculate_qualified_users_for_apartment(
  p_apartment_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_apartment_record RECORD;
  v_qualified_users JSONB;
BEGIN
  -- Get apartment details
  SELECT 
    id,
    "Full Address",
    rental_price,
    bedrooms
  INTO v_apartment_record
  FROM public.apartments
  WHERE id = p_apartment_id;

  -- If apartment doesn't exist or has no rental_price, return empty array
  IF v_apartment_record.id IS NULL OR v_apartment_record.rental_price IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  -- Find matching users based on account tags
  WITH account_prices AS (
    SELECT 
      acc.id AS account_id,
      tag AS price_tag,
      (regexp_match(tag, '(\d+)\s*-\s*(\d+)'))[1]::numeric AS min_price,
      (regexp_match(tag, '(\d+)\s*-\s*(\d+)'))[2]::numeric AS max_price
    FROM public.accounts acc
    CROSS JOIN LATERAL unnest(COALESCE(acc.tags, ARRAY[]::TEXT[])) AS tag
    WHERE regexp_match(tag, '(\d+)\s*-\s*(\d+)') IS NOT NULL
  ),
  account_bedrooms AS (
    SELECT 
      acc.id AS account_id,
      tag AS bedroom_tag,
      (regexp_match(tag, '(\d+)\s*Bedroom'))[1]::int AS bedroom_count
    FROM public.accounts acc
    CROSS JOIN LATERAL unnest(COALESCE(acc.tags, ARRAY[]::TEXT[])) AS tag
    WHERE regexp_match(tag, '(\d+)\s*Bedroom') IS NOT NULL
  ),
  matching_accounts AS (
    SELECT DISTINCT
      acc.id,
      acc.tenant_name,
      acc.whatsapp_number,
      acc.email,
      acc.tags AS account_tags,
      ap.price_tag,
      ab.bedroom_tag
    FROM public.accounts acc
    JOIN account_prices ap ON ap.account_id = acc.id
    JOIN account_bedrooms ab ON ab.account_id = acc.id
    WHERE 
      -- Rental price matches account's price tag range
      v_apartment_record.rental_price >= ap.min_price 
      AND v_apartment_record.rental_price <= ap.max_price
      -- Bedrooms match: apartment bedrooms <= account's bedroom tag
      AND COALESCE(
        (regexp_match(v_apartment_record.bedrooms, '[0-9]+'))[1]::int,
        0
      ) <= ab.bedroom_count
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'account_id', id,
        'apartment_id', v_apartment_record.id,
        'tenant_name', tenant_name,
        'whatsapp_number', whatsapp_number,
        'apartment_address', v_apartment_record."Full Address",
        'email', email,
        'rental_price', v_apartment_record.rental_price
      )
    ),
    '[]'::jsonb
  )
  INTO v_qualified_users
  FROM matching_accounts;

  RETURN COALESCE(v_qualified_users, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.calculate_qualified_users_for_apartment(UUID) IS 
'Calculates and returns qualified users for an apartment based on account tags matching rental_price and bedrooms.';

-- 3. Function to update qualified_users for an apartment
CREATE OR REPLACE FUNCTION public.update_apartment_qualified_users()
RETURNS TRIGGER AS $$
BEGIN
  -- Update qualified_users for the apartment
  UPDATE public.apartments
  SET qualified_users = public.calculate_qualified_users_for_apartment(NEW.id)
  WHERE id = NEW.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.update_apartment_qualified_users() IS 
'Trigger function to update qualified_users column when apartment data changes.';

-- 4. Function to update qualified_users for all apartments when accounts change
CREATE OR REPLACE FUNCTION public.update_all_apartments_qualified_users()
RETURNS TRIGGER AS $$
BEGIN
  -- Update qualified_users for all apartments
  -- This is needed when account tags change
  UPDATE public.apartments
  SET qualified_users = public.calculate_qualified_users_for_apartment(id)
  WHERE rental_price IS NOT NULL;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.update_all_apartments_qualified_users() IS 
'Trigger function to update qualified_users for all apartments when account tags change.';

-- 5. Create triggers
-- Trigger when apartment is inserted or updated (rental_price or bedrooms change)
DROP TRIGGER IF EXISTS trigger_update_apartment_qualified_users ON public.apartments;
CREATE TRIGGER trigger_update_apartment_qualified_users
  AFTER INSERT OR UPDATE OF rental_price, bedrooms ON public.apartments
  FOR EACH ROW
  EXECUTE FUNCTION public.update_apartment_qualified_users();

-- Trigger when account tags change
DROP TRIGGER IF EXISTS trigger_update_apartments_on_account_tags_change ON public.accounts;
CREATE TRIGGER trigger_update_apartments_on_account_tags_change
  AFTER INSERT OR UPDATE OF tags ON public.accounts
  FOR EACH ROW
  EXECUTE FUNCTION public.update_all_apartments_qualified_users();

-- 6. Initial population: Update qualified_users for all existing apartments
UPDATE public.apartments
SET qualified_users = public.calculate_qualified_users_for_apartment(id)
WHERE rental_price IS NOT NULL;
