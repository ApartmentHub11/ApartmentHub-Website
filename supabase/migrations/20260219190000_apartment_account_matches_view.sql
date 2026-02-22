-- Migration: Create view for apartment-account matches by parsed tags
-- Parses account tags in format "€1000-2000€" (price) and "1 Bedroom"/"2 Bedrooms" (bedrooms)
-- Matches apartments where rental_price is in range and bedrooms <= tag's bedroom count

DROP VIEW IF EXISTS public.apartment_account_matches_by_tag;

CREATE OR REPLACE VIEW public.apartment_account_matches_by_tag AS
WITH account_prices AS (
  SELECT 
    acc.id AS account_id,
    acc.tenant_name,
    acc.whatsapp_number,
    acc.email,
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
)
SELECT 
  (ap.price_tag || ' & ' || ab.bedroom_tag) AS tag_category,
  jsonb_agg(
    jsonb_build_object(
      'account_id', acc.id,
      'tenant_name', acc.tenant_name,
      'whatsapp_number', acc.whatsapp_number,
      'email', acc.email,
      'apartment_id', apt.id,
      'apartment_address', apt."Full Address",
      'rental_price', apt.rental_price,
      'bedrooms', apt.bedrooms
    )
  ) AS matching_users
FROM public.apartments apt
JOIN account_prices ap 
  ON apt.rental_price IS NOT NULL 
  AND apt.rental_price >= ap.min_price 
  AND apt.rental_price <= ap.max_price
JOIN account_bedrooms ab 
  ON ab.account_id = ap.account_id 
  AND COALESCE((regexp_match(apt.bedrooms, '[0-9]+'))[1]::int, 0) <= ab.bedroom_count
JOIN public.accounts acc ON acc.id = ap.account_id
GROUP BY ap.price_tag, ab.bedroom_tag
ORDER BY ap.price_tag, ab.bedroom_tag;

COMMENT ON VIEW public.apartment_account_matches_by_tag IS 
'Matches apartments with accounts based on parsed account tags. Expects price tags like "€1000-2000€" and bedroom tags like "1 Bedroom", "2 Bedrooms". Auto-updates when underlying data changes.';
