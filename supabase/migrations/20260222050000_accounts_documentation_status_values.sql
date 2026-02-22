-- Migration: Add new documentation_status values to accounts
-- Adds 'Not filled', 'Partial', and 'Offered' to the allowed values

ALTER TABLE public.accounts DROP CONSTRAINT IF EXISTS accounts_documentation_status_check;

ALTER TABLE public.accounts ADD CONSTRAINT accounts_documentation_status_check CHECK (
    documentation_status IN (
        'Not filled',
        'Partial',
        'Pending',
        'Complete',
        'Rejected',
        'Offered'
    )
);

COMMENT ON COLUMN public.accounts.documentation_status IS 'Status of the tenant''s document package: Not filled, Partial, Pending, Complete, Rejected, or Offered';
