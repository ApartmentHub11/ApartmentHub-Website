-- ==========================================
-- Co-tenant & Guarantor Account Relations
-- ==========================================
-- Adds a self-referencing FK (linked_account_id) and account_role column
-- to the accounts table so co-tenant and guarantor accounts can be formally
-- linked to the main tenant's account via a lookup relation.

-- 1. Add linked_account_id (FK to self) and account_role columns
ALTER TABLE public.accounts
  ADD COLUMN IF NOT EXISTS linked_account_id UUID REFERENCES public.accounts(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS account_role TEXT DEFAULT 'tenant';

-- 2. Add check constraint for valid account_role values
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'check_account_role'
  ) THEN
    ALTER TABLE public.accounts
      ADD CONSTRAINT check_account_role
      CHECK (account_role IN ('tenant', 'co-tenant', 'guarantor'));
  END IF;
END $$;

-- 3. Index for efficient lookup queries
CREATE INDEX IF NOT EXISTS idx_accounts_linked_account_id
  ON public.accounts(linked_account_id);

-- 4. Backfill linked_account_id from existing co_tenants JSONB column
-- For each main tenant account that has co_tenants entries,
-- update the referenced accounts with the link back.
DO $$
DECLARE
  rec RECORD;
  ct_entry JSONB;
  ct_account_id UUID;
  ct_role TEXT;
BEGIN
  FOR rec IN
    SELECT id, co_tenants
    FROM public.accounts
    WHERE co_tenants IS NOT NULL
      AND co_tenants != '[]'::jsonb
      AND jsonb_array_length(co_tenants) > 0
  LOOP
    FOR ct_entry IN SELECT * FROM jsonb_array_elements(rec.co_tenants)
    LOOP
      ct_account_id := (ct_entry ->> 'account_id')::UUID;
      ct_role := ct_entry ->> 'role';

      -- Map role names: 'Medehuurder' -> 'co-tenant', 'Garantsteller' -> 'guarantor'
      IF ct_role = 'Medehuurder' THEN
        ct_role := 'co-tenant';
      ELSIF ct_role = 'Garantsteller' THEN
        ct_role := 'guarantor';
      END IF;

      -- Update the co-tenant/guarantor account to link back to the main tenant
      UPDATE public.accounts
      SET linked_account_id = rec.id,
          account_role = COALESCE(ct_role, 'co-tenant')
      WHERE id = ct_account_id
        AND linked_account_id IS NULL;  -- Don't overwrite if already linked
    END LOOP;
  END LOOP;
END $$;

-- Comments
COMMENT ON COLUMN public.accounts.linked_account_id IS 'FK to the main tenant account this co-tenant/guarantor belongs to';
COMMENT ON COLUMN public.accounts.account_role IS 'Role: tenant (default), co-tenant, or guarantor';
