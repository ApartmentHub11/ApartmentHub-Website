-- =============================================================================
-- Query: Match Apartments with Accounts by Tags (Price + Bedrooms)
-- =============================================================================
-- Parses ACCOUNT tags in format:
--   - "€1000-2000€" (price range)
--   - "1 Bedroom", "2 Bedrooms" (bedroom count)
-- Matches apartments where rental_price is in range and bedrooms <= tag.
-- Returns users grouped by tag/category. View auto-updates on query.
-- =============================================================================

-- Run migration first: supabase/migrations/20260219190000_apartment_account_matches_view.sql
-- Then query: SELECT * FROM public.apartment_account_matches_by_tag;

-- Option A: Grouped by tag/category (via VIEW - auto-refreshed)
-- -----------------------------------------------------------------------------
SELECT * FROM public.apartment_account_matches_by_tag;


-- Option B: Flat result (one row per apartment-account-tag match)
-- -----------------------------------------------------------------------------
-- Use this if you want to see each match as a separate row
/*
SELECT 
  seg.name AS tag_category,
  apt.id AS apartment_id,
  apt."Full Address" AS apartment_address,
  apt.rental_price,
  apt.bedrooms AS apartment_bedrooms,
  acc.id AS account_id,
  acc.tenant_name,
  acc.whatsapp_number,
  acc.email,
  acc.tags AS account_tags
FROM public.apartments apt
CROSS JOIN public.accounts acc
CROSS JOIN LATERAL unnest(COALESCE(acc.tags, ARRAY[]::TEXT[])) AS tag_name
INNER JOIN public.candidate_segments seg ON seg.name = tag_name
WHERE 
  apt.rental_price IS NOT NULL
  AND apt.rental_price >= seg.min_budget
  AND (seg.max_budget IS NULL OR apt.rental_price <= seg.max_budget)
  AND (
    COALESCE(
      (regexp_match(apt.bedrooms, '[0-9]+'))[1]::INTEGER,
      0
    ) <= seg.min_bedrooms
  )
ORDER BY seg.name, apt.rental_price, acc.tenant_name;
*/


-- Option C: If accounts use preference columns instead of tags
-- -----------------------------------------------------------------------------
-- Use this if you prefer preference_rent_min/max and preference_min_bedrooms
-- (no candidate_segments / tags needed)
/*
SELECT 
  'preference_match' AS category,
  jsonb_agg(
    jsonb_build_object(
      'account_id', acc.id,
      'tenant_name', acc.tenant_name,
      'whatsapp_number', acc.whatsapp_number,
      'apartment_id', apt.id,
      'apartment_address', apt."Full Address",
      'rental_price', apt.rental_price,
      'bedrooms', apt.bedrooms
    )
  ) AS matching_users
FROM public.apartments apt
INNER JOIN public.accounts acc ON (
  apt.rental_price IS NOT NULL
  AND apt.rental_price >= COALESCE(acc.preference_rent_min, 0)
  AND (acc.preference_rent_max IS NULL OR apt.rental_price <= acc.preference_rent_max)
  AND (
    COALESCE(
      (regexp_match(apt.bedrooms, '[0-9]+'))[1]::INTEGER,
      0
    ) >= COALESCE(acc.preference_min_bedrooms, 0)
  )
);
*/
