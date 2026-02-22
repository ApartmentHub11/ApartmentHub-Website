-- Migration: Sync tenants to apartment viewing_participants when whatsapp matches qualified_users
-- When a tenant's whatsapp_number matches a qualified_user's whatsapp_number for an apartment,
-- the tenant is added to that apartment's viewing_participants column.

-- 1. Phone normalization function for consistent comparison
CREATE OR REPLACE FUNCTION public.normalize_phone_for_match(phone text)
RETURNS text AS $$
DECLARE
  digits text;
BEGIN
  IF phone IS NULL OR trim(phone) = '' THEN
    RETURN NULL;
  END IF;
  -- Replace leading 00 with + (international format), then keep digits only
  phone := regexp_replace(trim(phone), '^00', '+');
  digits := regexp_replace(phone, '[^0-9]', '', 'g');
  -- Dutch numbers: 06... = +316..., so 0625504864 -> 31625504864
  IF length(digits) >= 9 AND digits ~ '^0[1-9]' THEN
    digits := '31' || substr(digits, 2);
  END IF;
  RETURN digits;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION public.normalize_phone_for_match(text) IS
'Normalizes phone numbers for comparison by extracting digits only. Handles +31..., 0031..., 31... formats.';

-- 2. Function to build tenant participant object from tenant row
-- Uses only base columns that exist in the tenants table
CREATE OR REPLACE FUNCTION public.build_tenant_participant(p_tenant public.tenants)
RETURNS jsonb AS $$
BEGIN
  RETURN jsonb_build_object(
    'tenant_id', p_tenant.id,
    'name', p_tenant.name,
    'whatsapp_number', p_tenant.whatsapp_number,
    'salesforce_account_id', p_tenant.salesforce_account_id,
    'tags', p_tenant.tags,
    'apartment_id', p_tenant.apartment_id,
    'created_at', p_tenant.created_at,
    'updated_at', p_tenant.updated_at
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION public.build_tenant_participant(public.tenants) IS
'Builds a JSONB object with tenant details for viewing_participants.';

-- 3. Function to sync a tenant to viewing_participants of matching apartments
CREATE OR REPLACE FUNCTION public.sync_tenant_to_viewing_participants()
RETURNS TRIGGER AS $$
DECLARE
  v_tenant_phone_norm text;
  v_apt_record RECORD;
  v_qu jsonb;
  v_qu_elem jsonb;
  v_qu_phone_norm text;
  v_participant jsonb;
  v_current jsonb;
  v_updated jsonb;
  v_found boolean;
BEGIN
  -- Skip if tenant has no whatsapp number
  IF NEW.whatsapp_number IS NULL OR trim(NEW.whatsapp_number) = '' THEN
    RETURN NEW;
  END IF;

  v_tenant_phone_norm := public.normalize_phone_for_match(NEW.whatsapp_number);
  IF v_tenant_phone_norm IS NULL OR length(v_tenant_phone_norm) < 8 THEN
    RETURN NEW;
  END IF;

  v_participant := public.build_tenant_participant(NEW);

  -- Find apartments whose qualified_users contains a matching whatsapp_number
  FOR v_apt_record IN
    SELECT id, qualified_users, viewing_participants
    FROM public.apartments
    WHERE qualified_users IS NOT NULL
      AND jsonb_array_length(qualified_users) > 0
  LOOP
    v_found := false;
    FOR v_qu_elem IN SELECT * FROM jsonb_array_elements(v_apt_record.qualified_users)
    LOOP
      v_qu_phone_norm := public.normalize_phone_for_match(
        COALESCE(
          v_qu_elem->>'whatsapp_number',
          v_qu_elem->>'WhatsApp Number',
          v_qu_elem->>'whatsAppNumber',
          v_qu_elem->>'WhatsAppNumber'
        )
      );
      IF v_qu_phone_norm IS NOT NULL AND v_qu_phone_norm = v_tenant_phone_norm THEN
        v_found := true;
        EXIT;
      END IF;
    END LOOP;

    IF v_found THEN
      -- Check if tenant already in viewing_participants (by tenant_id)
      v_current := COALESCE(v_apt_record.viewing_participants, '[]'::jsonb);
      IF NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_current) AS elem
        WHERE (elem->>'tenant_id')::uuid = NEW.id
      ) THEN
        v_updated := v_current || v_participant;
        UPDATE public.apartments
        SET viewing_participants = v_updated,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_apt_record.id;
      END IF;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.sync_tenant_to_viewing_participants() IS
'Trigger: when a tenant is inserted/updated, adds them to viewing_participants of apartments where qualified_users contains matching whatsapp_number.';

-- 4. Function to sync viewing_participants when apartment qualified_users changes
CREATE OR REPLACE FUNCTION public.sync_apartment_viewing_participants_from_qualified()
RETURNS TRIGGER AS $$
DECLARE
  v_qu_elem jsonb;
  v_qu_phone_norm text;
  v_participants jsonb := '[]'::jsonb;
  v_tenant_row public.tenants%ROWTYPE;
BEGIN
  IF NEW.qualified_users IS NULL OR jsonb_array_length(NEW.qualified_users) = 0 THEN
    UPDATE public.apartments
    SET viewing_participants = '[]'::jsonb,
        updated_at = timezone('utc'::text, now())
    WHERE id = NEW.id;
    RETURN NEW;
  END IF;

  -- For each whatsapp in qualified_users, find matching tenants and add to participants
  FOR v_qu_elem IN SELECT * FROM jsonb_array_elements(NEW.qualified_users)
  LOOP
    v_qu_phone_norm := public.normalize_phone_for_match(
      COALESCE(
        v_qu_elem->>'whatsapp_number',
        v_qu_elem->>'WhatsApp Number',
        v_qu_elem->>'whatsAppNumber',
        v_qu_elem->>'WhatsAppNumber'
      )
    );
    IF v_qu_phone_norm IS NULL OR length(v_qu_phone_norm) < 8 THEN
      CONTINUE;
    END IF;

    FOR v_tenant_row IN
      SELECT t
      FROM public.tenants t
      WHERE t.whatsapp_number IS NOT NULL
        AND trim(t.whatsapp_number) != ''
        AND public.normalize_phone_for_match(t.whatsapp_number) = v_qu_phone_norm
    LOOP
      -- Avoid duplicate tenant_id in participants
      IF NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_participants) AS elem
        WHERE (elem->>'tenant_id')::uuid = v_tenant_row.id
      ) THEN
        v_participants := v_participants || public.build_tenant_participant(v_tenant_row);
      END IF;
    END LOOP;
  END LOOP;

  UPDATE public.apartments
  SET viewing_participants = v_participants,
      updated_at = timezone('utc'::text, now())
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.sync_apartment_viewing_participants_from_qualified() IS
'Trigger: when apartment qualified_users changes, rebuilds viewing_participants from tenants with matching whatsapp numbers.';

-- 5. Trigger on tenants: when tenant is inserted or updated
DROP TRIGGER IF EXISTS trigger_sync_tenant_to_viewing_participants ON public.tenants;
CREATE TRIGGER trigger_sync_tenant_to_viewing_participants
  AFTER INSERT OR UPDATE OF whatsapp_number, name, apartment_id, salesforce_account_id, tags
  ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_tenant_to_viewing_participants();

-- 6. Trigger on apartments: when qualified_users changes (via update_apartment_qualified_users)
DROP TRIGGER IF EXISTS trigger_sync_viewing_participants_from_qualified ON public.apartments;
CREATE TRIGGER trigger_sync_viewing_participants_from_qualified
  AFTER UPDATE OF qualified_users ON public.apartments
  FOR EACH ROW
  WHEN (OLD.qualified_users IS DISTINCT FROM NEW.qualified_users)
  EXECUTE FUNCTION public.sync_apartment_viewing_participants_from_qualified();

-- 7. Initial sync: for all apartments with qualified_users, populate viewing_participants from matching tenants
UPDATE public.apartments a
SET
  viewing_participants = (
    SELECT COALESCE(jsonb_agg(public.build_tenant_participant(t)), '[]'::jsonb)
    FROM public.tenants t
    WHERE t.whatsapp_number IS NOT NULL
      AND trim(t.whatsapp_number) != ''
      AND EXISTS (
        SELECT 1 FROM jsonb_array_elements(COALESCE(a.qualified_users, '[]'::jsonb)) qu
        WHERE public.normalize_phone_for_match(COALESCE(
              qu->>'whatsapp_number',
              qu->>'WhatsApp Number',
              qu->>'whatsAppNumber',
              qu->>'WhatsAppNumber'
            )) = public.normalize_phone_for_match(t.whatsapp_number)
      )
  ),
  updated_at = timezone('utc'::text, now())
WHERE a.qualified_users IS NOT NULL
  AND jsonb_array_length(COALESCE(a.qualified_users, '[]'::jsonb)) > 0;
