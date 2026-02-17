-- ==========================================
-- 1. PUBLIC / WEBSITE TABLES
-- ==========================================

-- Create Real Estate Agents table (Public Profile)
CREATE TABLE IF NOT EXISTS public.real_estate_agents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    phone_number TEXT,
    picture_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create Apartments table (Listings)
CREATE TABLE IF NOT EXISTS public.apartments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    street TEXT,
    area TEXT,
    full_address TEXT,
    zip_code TEXT,
    rental_price NUMERIC,
    bedrooms TEXT,
    square_meters NUMERIC,
    tags TEXT[], -- Array of text for tags
    status TEXT CHECK (status IN ('Null', 'CreateLink', 'Active', 'Closed')), 
    event_link TEXT,
    
    -- Booking Details & Slots
    booking_details JSONB DEFAULT '{}'::jsonb, -- Store "When the apartment is booked?" details
    slot_dates JSONB DEFAULT '[]'::jsonb, -- Array of slot objects with dates
    
    salesforce_id TEXT, -- Salesforce Apartment object record Number
    
    additional_notes TEXT,
    
    -- Foreign Keys
    real_estate_agent_id UUID REFERENCES public.real_estate_agents(id) ON DELETE SET NULL,
    
    -- List fields modeled as JSONB
    viewing_participants JSONB DEFAULT '[]'::jsonb, 
    viewing_cancellations JSONB DEFAULT '[]'::jsonb, 
    booking_reschedules JSONB DEFAULT '[]'::jsonb, 
    
    -- Linked Agents from apartmenthub
    apartmenthub_agents JSONB DEFAULT '[]'::jsonb, 
    
    -- Offers
    people_making_offer JSONB DEFAULT '[]'::jsonb, 
    offers_in JSONB DEFAULT '[]'::jsonb, 
    offers_sent JSONB DEFAULT '[]'::jsonb, 
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create Tenants table (Simple Public/Listing link)
CREATE TABLE IF NOT EXISTS public.tenants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    whatsapp_number TEXT,
    salesforce_account_id TEXT,
    tags TEXT[],
    
    -- Relationships
    apartment_id UUID REFERENCES public.apartments(id) ON DELETE SET NULL, 
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);


-- ==========================================
-- 2. INTERNAL / CRM TABLES
-- ==========================================

-- Create CRM Agents table (Internal Detailed Profile)
CREATE TABLE IF NOT EXISTS public.crm_agents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY, -- Internal Agent ID
    name TEXT NOT NULL,
    whatsapp_number TEXT,
    email TEXT,
    employee_id TEXT,
    salesforce_agent_id TEXT,
    
    -- Assigned data
    assigned_apartments_supabase UUID[], 
    assigned_apartments_salesforce TEXT[],
    assigned_tenants_supabase UUID[], -- Likely referencing 'accounts'
    
    internal_notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create Accounts table (Detailed CRM Tenant/User)
CREATE TABLE IF NOT EXISTS public.accounts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY, -- Internal Account ID
    tenant_name TEXT NOT NULL,
    whatsapp_number TEXT,
    email TEXT,
    nationality TEXT,
    date_of_birth DATE,
    sex TEXT,
    preferred_language TEXT,
    tags TEXT[],
    salesforce_account_id TEXT,
    
    -- Foreign Key to CRM Agent
    assigned_crm_agent_id UUID REFERENCES public.crm_agents(id) ON DELETE SET NULL,
    
    -- Current Living Situation
    current_address TEXT,
    current_zipcode TEXT,
    
    preferred_location TEXT,
    move_in_date DATE,
    work_status TEXT,
    monthly_income NUMERIC, 
    
    -- Events Booked
    events_booked JSONB DEFAULT '[]'::jsonb,
    
    -- Apartments Applied For
    apartments_applied_for JSONB DEFAULT '[]'::jsonb, 
    
    -- Co-Tenants
    co_tenants JSONB DEFAULT '[]'::jsonb,
    co_tenant_relation TEXT, -- Relationship details if applicable
    guarantor_relation TEXT, -- Guarantor relationship details
    
    -- Documents
    documents JSONB DEFAULT '[]'::jsonb, -- Array of document objects/links
    
    negotiation_notes TEXT,
    
    status TEXT CHECK (status IN ('Null', 'Offer Made', 'Deal In Progress', 'Deal Closed', 'Lost')),
    
    contract_start_date DATE,
    contract_end_date DATE,
    
    documentation_status TEXT CHECK (documentation_status IN ('Pending', 'Complete', 'Rejected')),
    
    additional_notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Safely add columns if they don't exist (handling existing table case)
ALTER TABLE public.accounts ADD COLUMN IF NOT EXISTS current_address TEXT;
ALTER TABLE public.accounts ADD COLUMN IF NOT EXISTS current_zipcode TEXT;
ALTER TABLE public.accounts ADD COLUMN IF NOT EXISTS co_tenant_relation TEXT;
ALTER TABLE public.accounts ADD COLUMN IF NOT EXISTS guarantor_relation TEXT;
ALTER TABLE public.accounts ADD COLUMN IF NOT EXISTS documents JSONB DEFAULT '[]'::jsonb;

-- ==========================================
-- INDEXES & RLS
-- ==========================================

-- Indexes
CREATE INDEX IF NOT EXISTS idx_apartments_real_estate_agent_id ON public.apartments(real_estate_agent_id);
CREATE INDEX IF NOT EXISTS idx_apartments_status ON public.apartments(status);
CREATE INDEX IF NOT EXISTS idx_tenants_apartment_id ON public.tenants(apartment_id);

CREATE INDEX IF NOT EXISTS idx_accounts_salesforce_account_id ON public.accounts(salesforce_account_id);
CREATE INDEX IF NOT EXISTS idx_accounts_assigned_crm_agent_id ON public.accounts(assigned_crm_agent_id);
CREATE INDEX IF NOT EXISTS idx_accounts_status ON public.accounts(status);

-- Enable Row Level Security (RLS)
ALTER TABLE public.real_estate_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.apartments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

-- Post-creation policies (Basic examples for read access)
DROP POLICY IF EXISTS "Public read access for apartments" ON public.apartments;
CREATE POLICY "Public read access for apartments" ON public.apartments FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public read access for real_estate_agents" ON public.real_estate_agents;
CREATE POLICY "Public read access for real_estate_agents" ON public.real_estate_agents FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated access to tenants" ON public.tenants;
CREATE POLICY "Authenticated access to tenants" ON public.tenants FOR ALL TO authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated access to crm_agents" ON public.crm_agents;
CREATE POLICY "Authenticated access to crm_agents" ON public.crm_agents FOR ALL TO authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated access to accounts" ON public.accounts;
CREATE POLICY "Authenticated access to accounts" ON public.accounts FOR ALL TO authenticated USING (true);


-- Reusable Trigger Function for updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
DROP TRIGGER IF EXISTS set_real_estate_agents_updated_at ON public.real_estate_agents;
CREATE TRIGGER set_real_estate_agents_updated_at BEFORE UPDATE ON public.real_estate_agents FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_apartments_updated_at ON public.apartments;
CREATE TRIGGER set_apartments_updated_at BEFORE UPDATE ON public.apartments FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_tenants_updated_at ON public.tenants;
CREATE TRIGGER set_tenants_updated_at BEFORE UPDATE ON public.tenants FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_crm_agents_updated_at ON public.crm_agents;
CREATE TRIGGER set_crm_agents_updated_at BEFORE UPDATE ON public.crm_agents FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_accounts_updated_at ON public.accounts;
CREATE TRIGGER set_accounts_updated_at BEFORE UPDATE ON public.accounts FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Comments
COMMENT ON TABLE public.real_estate_agents IS 'Public profiles for real estate agents linked to listings';
COMMENT ON TABLE public.apartments IS 'Public apartment listings';
COMMENT ON TABLE public.tenants IS 'Simplified tenant records linked to apartments';
COMMENT ON TABLE public.crm_agents IS 'Internal CRM agent records with detailed info';
COMMENT ON TABLE public.accounts IS 'Internal CRM detailed account/tenant records';
