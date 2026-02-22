-- Fix: qualified_users may use camelCase keys (whatsAppNumber, apartmentID)
-- This migration updates the sync functions to check all common key variants
-- Run this if tenant Abhinav still doesn't appear in viewing_participants despite matching qualified_users

-- Helper to extract phone from qualified_user jsonb (handles snake_case and camelCase)
CREATE OR REPLACE FUNCTION public.extract_phone_from_qualified_user(qu jsonb)
RETURNS text AS $$
BEGIN
  RETURN COALESCE(
    qu->>'whatsapp_number',
    qu->>'WhatsApp Number',
    qu->>'whatsAppNumber',
    qu->>'WhatsAppNumber'
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Update sync_tenant_to_viewing_participants
CREATE OR REPLACE FUNCTION public.sync_tenant_to_viewing_participants()
RETURNS TRIGGER AS $$
DECLARE
  v_tenant_phone_norm text;
  v_apt_record RECORD;
  v_qu_elem jsonb;
  v_qu_phone_norm text;
  v_participant jsonb;
  v_current jsonb;
  v_updated jsonb;
  v_found boolean;
BEGIN
  IF NEW.whatsapp_number IS NULL OR trim(NEW.whatsapp_number) = '' THEN
    RETURN NEW;
  END IF;

  v_tenant_phone_norm := public.normalize_phone_for_match(NEW.whatsapp_number);
  IF v_tenant_phone_norm IS NULL OR length(v_tenant_phone_norm) < 8 THEN
    RETURN NEW;
  END IF;

  v_participant := public.build_tenant_participant(NEW);

  FOR v_apt_record IN
    SELECT id, qualified_users, viewing_participants
    FROM public.apartments
    WHERE qualified_users IS NOT NULL
      AND jsonb_array_length(qualified_users) > 0
  LOOP
    v_found := false;
    FOR v_qu_elem IN SELECT * FROM jsonb_array_elements(v_apt_record.qualified_users)
    LOOP
      v_qu_phone_norm := public.normalize_phone_for_match(public.extract_phone_from_qualified_user(v_qu_elem));
      IF v_qu_phone_norm IS NOT NULL AND v_qu_phone_norm = v_tenant_phone_norm THEN
        v_found := true;
        EXIT;
      END IF;
    END LOOP;

    IF v_found THEN
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

-- Update sync_apartment_viewing_participants_from_qualified
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

  FOR v_qu_elem IN SELECT * FROM jsonb_array_elements(NEW.qualified_users)
  LOOP
    v_qu_phone_norm := public.normalize_phone_for_match(public.extract_phone_from_qualified_user(v_qu_elem));
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

-- Re-run initial sync to populate viewing_participants for existing data
UPDATE public.apartments a
SET
  viewing_participants = (
    SELECT COALESCE(jsonb_agg(public.build_tenant_participant(t)), '[]'::jsonb)
    FROM public.tenants t
    WHERE t.whatsapp_number IS NOT NULL
      AND trim(t.whatsapp_number) != ''
      AND EXISTS (
        SELECT 1 FROM jsonb_array_elements(COALESCE(a.qualified_users, '[]'::jsonb)) qu
        WHERE public.normalize_phone_for_match(public.extract_phone_from_qualified_user(qu)) =
              public.normalize_phone_for_match(t.whatsapp_number)
      )
  ),
  updated_at = timezone('utc'::text, now())
WHERE a.qualified_users IS NOT NULL
  AND jsonb_array_length(COALESCE(a.qualified_users, '[]'::jsonb)) > 0;
