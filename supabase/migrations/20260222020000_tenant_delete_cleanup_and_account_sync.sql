-- Migration: Tenant DELETE cleanup + Accounts-side sync trigger
--
-- 1. When a tenant is DELETED: remove from apartment viewing_participants/viewing_cancellations
--    and from account current_bookings/cancelled_bookings
-- 2. When an account's whatsapp_number is added/changed: pull matching tenant bookings

------------------------------------------------------------------------
-- 1. Cleanup function: fires AFTER DELETE on tenants
------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cleanup_deleted_tenant()
RETURNS TRIGGER AS $$
DECLARE
  v_tenant_phone_norm text;
BEGIN
  -- Remove from all apartments' viewing_participants
  UPDATE public.apartments
  SET viewing_participants = (
        SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(COALESCE(viewing_participants, '[]'::jsonb)) AS elem
        WHERE (elem->>'tenant_id')::uuid IS DISTINCT FROM OLD.id
      ),
      -- Remove from viewing_cancellations
      viewing_cancellations = (
        SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(COALESCE(viewing_cancellations, '[]'::jsonb)) AS elem
        WHERE (elem->>'tenant_id')::uuid IS DISTINCT FROM OLD.id
      ),
      updated_at = timezone('utc'::text, now())
  WHERE viewing_participants::text LIKE '%' || OLD.id::text || '%'
     OR viewing_cancellations::text LIKE '%' || OLD.id::text || '%';

  -- Remove from all accounts' current_bookings
  UPDATE public.accounts
  SET current_bookings = (
        SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(COALESCE(current_bookings, '[]'::jsonb)) AS elem
        WHERE (elem->>'tenant_id')::uuid IS DISTINCT FROM OLD.id
      ),
      -- Remove from cancelled_bookings (text[] containing JSON strings)
      cancelled_bookings = (
        SELECT COALESCE(array_agg(entry), ARRAY[]::text[])
        FROM unnest(COALESCE(cancelled_bookings, ARRAY[]::text[])) AS entry
        WHERE entry::jsonb->>'tenant_id' IS DISTINCT FROM OLD.id::text
      ),
      updated_at = timezone('utc'::text, now())
  WHERE current_bookings::text LIKE '%' || OLD.id::text || '%'
     OR array_to_string(COALESCE(cancelled_bookings, ARRAY[]::text[]), ',') LIKE '%' || OLD.id::text || '%';

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.cleanup_deleted_tenant() IS
'After tenant DELETE: removes tenant from apartments viewing_participants/viewing_cancellations and accounts current_bookings/cancelled_bookings.';

------------------------------------------------------------------------
-- 2. Create DELETE trigger on tenants
------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_cleanup_deleted_tenant ON public.tenants;
CREATE TRIGGER trigger_cleanup_deleted_tenant
  AFTER DELETE ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.cleanup_deleted_tenant();

------------------------------------------------------------------------
-- 3. Accounts-side trigger: when whatsapp_number changes, pull tenant bookings
------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_account_bookings_from_tenants()
RETURNS TRIGGER AS $$
DECLARE
  v_phone_norm text;
  v_bookings jsonb;
  v_cancellations text[];
BEGIN
  IF NEW.whatsapp_number IS NULL OR trim(NEW.whatsapp_number) = '' THEN
    RETURN NEW;
  END IF;

  v_phone_norm := public.normalize_phone_for_match(NEW.whatsapp_number);
  IF v_phone_norm IS NULL OR length(v_phone_norm) < 8 THEN
    RETURN NEW;
  END IF;

  -- Build current_bookings from BOOKING_CREATED / BOOKING_ACCEPTED tenants
  SELECT COALESCE(jsonb_agg(public.build_booking_from_tenant(t) ORDER BY t.created_at DESC), '[]'::jsonb)
  INTO v_bookings
  FROM public.tenants t
  WHERE t.whatsapp_number IS NOT NULL
    AND trim(t.whatsapp_number) != ''
    AND public.normalize_phone_for_match(t.whatsapp_number) = v_phone_norm
    AND upper(trim(COALESCE(
      (to_jsonb(t)->>'TriggerEvent'),
      (to_jsonb(t)->>'EventType'),
      (to_jsonb(t)->>'event_type'),
      ''
    ))) IN ('BOOKING_CREATED', 'BOOKING_ACCEPTED');

  -- Build cancelled_bookings from BOOKING_CANCELLED tenants
  SELECT COALESCE(array_agg(public.build_booking_from_tenant(t)::text ORDER BY t.created_at DESC), ARRAY[]::text[])
  INTO v_cancellations
  FROM public.tenants t
  WHERE t.whatsapp_number IS NOT NULL
    AND trim(t.whatsapp_number) != ''
    AND public.normalize_phone_for_match(t.whatsapp_number) = v_phone_norm
    AND upper(trim(COALESCE(
      (to_jsonb(t)->>'TriggerEvent'),
      (to_jsonb(t)->>'EventType'),
      (to_jsonb(t)->>'event_type'),
      ''
    ))) = 'BOOKING_CANCELLED';

  -- Update the account (use NEW.id since this is a trigger on accounts)
  UPDATE public.accounts
  SET current_bookings = v_bookings,
      cancelled_bookings = v_cancellations,
      updated_at = timezone('utc'::text, now())
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.sync_account_bookings_from_tenants() IS
'When account whatsapp_number is set/changed, pulls matching tenant bookings into current_bookings and cancelled_bookings.';

------------------------------------------------------------------------
-- 4. Create trigger on accounts for whatsapp_number changes
------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_sync_account_bookings_from_tenants ON public.accounts;
CREATE TRIGGER trigger_sync_account_bookings_from_tenants
  AFTER INSERT OR UPDATE OF whatsapp_number ON public.accounts
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_account_bookings_from_tenants();
