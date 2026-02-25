-- Migration: Fix qualified_users price matching and exclude opt-in accounts
--
-- Changes:
-- 1. Fix regex to handle €-prefixed price tags (€1500 - €2000)
-- 2. Exclude accounts with 'opt-in' tag alongside 'ARCHIVED'
-- 3. Re-backfill all apartments' qualified_users

CREATE OR REPLACE FUNCTION public.calculate_qualified_users_for_apartment(
  p_apartment_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_apartment_record RECORD;
  v_qualified_users JSONB;
  v_apt_bedrooms INT;
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

  -- Extract numeric bedroom count from apartment (e.g. "2 Bedrooms" -> 2, "Studio" -> 0)
  v_apt_bedrooms := COALESCE(
    (regexp_match(v_apartment_record.bedrooms, '[0-9]+'))[1]::int,
    0
  );

  -- Find matching users based on account tags using RANGE-BASED logic
  WITH account_price_ranges AS (
    -- For each account, compute the OVERALL min and max price across ALL price tags
    -- Updated regex: €?(\d+)\s*-\s*€?(\d+) to handle tags like "€1500 - €2000"
    SELECT 
      acc.id AS account_id,
      MIN((regexp_match(tag, '€?(\d+)\s*-\s*€?(\d+)'))[1]::numeric) AS overall_min_price,
      MAX((regexp_match(tag, '€?(\d+)\s*-\s*€?(\d+)'))[2]::numeric) AS overall_max_price
    FROM public.accounts acc
    CROSS JOIN LATERAL unnest(COALESCE(acc.tags, ARRAY[]::TEXT[])) AS tag
    WHERE regexp_match(tag, '€?(\d+)\s*-\s*€?(\d+)') IS NOT NULL
      -- Exclude ARCHIVED and OPT-IN accounts
      AND NOT EXISTS (
        SELECT 1 FROM unnest(COALESCE(acc.tags, ARRAY[]::TEXT[])) t
        WHERE UPPER(t) IN ('ARCHIVED', 'OPT-IN')
      )
    GROUP BY acc.id
  ),
  account_min_bedrooms AS (
    -- For each account, find the MINIMUM bedroom count across all bedroom tags
    SELECT 
      acc.id AS account_id,
      MIN((regexp_match(tag, '(\d+)\s*Bedroom'))[1]::int) AS min_bedrooms
    FROM public.accounts acc
    CROSS JOIN LATERAL unnest(COALESCE(acc.tags, ARRAY[]::TEXT[])) AS tag
    WHERE regexp_match(tag, '(\d+)\s*Bedroom') IS NOT NULL
    GROUP BY acc.id
  ),
  matching_accounts AS (
    SELECT DISTINCT
      acc.id,
      acc.tenant_name,
      acc.whatsapp_number,
      acc.email,
      acc.tags AS account_tags,
      apr.overall_min_price,
      apr.overall_max_price,
      amb.min_bedrooms
    FROM public.accounts acc
    JOIN account_price_ranges apr ON apr.account_id = acc.id
    LEFT JOIN account_min_bedrooms amb ON amb.account_id = acc.id
    WHERE 
      -- Apartment rental_price is within the account's overall price range
      v_apartment_record.rental_price >= apr.overall_min_price 
      AND v_apartment_record.rental_price <= apr.overall_max_price
      -- Apartment bedrooms >= account's minimum bedrooms requirement
      AND (amb.min_bedrooms IS NULL OR v_apt_bedrooms >= amb.min_bedrooms)
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
        'rental_price', v_apartment_record.rental_price,
        'price_range', overall_min_price || '-' || overall_max_price,
        'min_bedrooms', min_bedrooms
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
'Calculates qualified users for an apartment using range-based matching:
- Regex handles €-prefixed price tags (€1500 - €2000)
- Apartment price must fall within [overall_min, overall_max]
- Apartment bedrooms must be >= account minimum bedrooms
- Excludes accounts with ARCHIVED or OPT-IN tags';

-- Backfill all apartments
UPDATE public.apartments
SET qualified_users = public.calculate_qualified_users_for_apartment(id)
WHERE rental_price IS NOT NULL;
