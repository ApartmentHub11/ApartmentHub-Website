-- Migration: Create Candidate Segments and Add Preferences to Accounts
-- Description: Adds columns for preferences to the `accounts` table and creates a `candidate_segments` table to categorize candidates based on budget and bedroom needs.

-- 1. Add preference columns to `accounts` table
ALTER TABLE public.accounts
ADD COLUMN IF NOT EXISTS preference_rent_min NUMERIC,
ADD COLUMN IF NOT EXISTS preference_rent_max NUMERIC,
ADD COLUMN IF NOT EXISTS preference_min_bedrooms INTEGER;

COMMENT ON COLUMN public.accounts.preference_rent_min IS 'Minimum rent the candidate is willing to pay';
COMMENT ON COLUMN public.accounts.preference_rent_max IS 'Maximum rent the candidate is willing to pay';
COMMENT ON COLUMN public.accounts.preference_min_bedrooms IS 'Minimum number of bedrooms required';


-- 2. Create `candidate_segments` table
CREATE TABLE IF NOT EXISTS public.candidate_segments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    min_budget NUMERIC NOT NULL,
    max_budget NUMERIC, -- NULL means "and above" (e.g., 5000+)
    min_bedrooms INTEGER NOT NULL,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.candidate_segments ENABLE ROW LEVEL SECURITY;

-- Allow read access for authenticated users
DROP POLICY IF EXISTS "Authenticated read access for candidate_segments" ON public.candidate_segments;
CREATE POLICY "Authenticated read access for candidate_segments" ON public.candidate_segments FOR SELECT TO authenticated USING (true);


-- 3. Insert default segments
-- We delete existing segments to avoid duplicates if this script is re-run (optional/for idempotency)
DELETE FROM public.candidate_segments; 

INSERT INTO public.candidate_segments (name, min_budget, max_budget, min_bedrooms) VALUES
-- €1250 - €1500
('Price €1250 - €1500 & 1 Bedroom', 1250, 1500, 1),
('Price €1250 - €1500 & 3 Bedrooms', 1250, 1500, 3), -- Note: User list skipped 2 Bedroom here, but added 3 & 4. Assuming 2 might be missing or intentional. Added 3 based on request.
('Price €1250 - €1500 & 4 Bedrooms', 1250, 1500, 4),

-- €1500 - €2000
('Price €1500 - €2000 & 1 Bedroom', 1500, 2000, 1),
('Price €1500 - €2000 & 2 Bedrooms', 1500, 2000, 2),
('Price €1500 - €2000 & 3 Bedrooms', 1500, 2000, 3),
('Price €1500 - €2000 & 4 Bedrooms', 1500, 2000, 4),

-- €2000 - €2500
('Price €2000 - €2500 & 1 Bedroom', 2000, 2500, 1),
('Price €2000 - €2500 & 2 Bedrooms', 2000, 2500, 2),
('Price €2000 - €2500 & 3 Bedrooms', 2000, 2500, 3),
('Price €2000 - €2500 & 4 Bedrooms', 2000, 2500, 4),

-- €2500 - €3000
('Price €2500 - €3000 & 1 Bedroom', 2500, 3000, 1),
('Price €2500 - €3000 & 2 Bedrooms', 2500, 3000, 2),
('Price €2500 - €3000 & 3 Bedrooms', 2500, 3000, 3),
('Price €2500 - €3000 & 4 Bedrooms', 2500, 3000, 4),

-- €3000 - €3500
('Price €3000 - €3500 & 1 Bedroom', 3000, 3500, 1),
('Price €3000 - €3500 & 2 Bedrooms', 3000, 3500, 2),
('Price €3000 - €3500 & 3 Bedrooms', 3000, 3500, 3),
('Price €3000 - €3500 & 4 Bedrooms', 3000, 3500, 4),

-- €3500 - €4000
('Price €3500 - €4000 & 1 Bedroom', 3500, 4000, 1),
('Price €3500 - €4000 & 2 Bedrooms', 3500, 4000, 2),
('Price €3500 - €4000 & 3 Bedrooms', 3500, 4000, 3),
('Price €3500 - €4000 & 4 Bedrooms', 3500, 4000, 4),

-- €4000 - €4500
('Price €4000 - €4500 & 1 Bedroom', 4000, 4500, 1),
('Price €4000 - €4500 & 2 Bedrooms', 4000, 4500, 2),
('Price €4000 - €4500 & 3 Bedrooms', 4000, 4500, 3),
('Price €4000 - €4500 & 4 Bedrooms', 4000, 4500, 4),

-- €4500 - €5000
('Price €4500 - €5000 & 1 Bedroom', 4500, 5000, 1),
('Price €4500 - €5000 & 2 Bedrooms', 4500, 5000, 2),
('Price €4500 - €5000 & 3 Bedrooms', 4500, 5000, 3),
('Price €4500 - €5000 & 4 Bedrooms', 4500, 5000, 4),

-- €5000+
('Price €5000+ & 1 Bedroom', 5000, NULL, 1),
('Price €5000+ & 2 Bedrooms', 5000, NULL, 2),
('Price €5000+ & 3 Bedrooms', 5000, NULL, 3),
('Price €5000+ & 4 Bedrooms', 5000, NULL, 4);


-- 4. Create Helper Function to find matching Accounts for a given Segment
-- Usage: SELECT * FROM get_accounts_in_segment('segment-uuid');

CREATE OR REPLACE FUNCTION public.get_accounts_in_segment(segment_id UUID)
RETURNS SETOF public.accounts AS $$
DECLARE
    v_min_budget NUMERIC;
    v_max_budget NUMERIC;
    v_min_bedrooms INTEGER;
BEGIN
    -- Get segment details
    SELECT min_budget, max_budget, min_bedrooms
    INTO v_min_budget, v_max_budget, v_min_bedrooms
    FROM public.candidate_segments
    WHERE id = segment_id;

    -- Return matching accounts
    RETURN QUERY
    SELECT *
    FROM public.accounts
    WHERE 
        -- 1. Budget Match: 
        -- The candidate's MAX budget should be at least the Segment's MIN budget.
        -- (e.g. Segment starts at 1500. Calculate wants candidates who can pay 1500+. A candidate with max budget 1400 is not a match.)
        (preference_rent_max >= v_min_budget OR preference_rent_max IS NULL)
        
        -- And ideally, their budget shouldn't be wildly higher than the segment max? 
        -- For now, let's keep it simple: Ensure they *can* afford the range.
        -- If segment has a max budget, checking if their MIN budget is below it to ensure overlap?
        -- Let's stick to simple "Ability to pay":
        -- Candidate Max Budget >= Segment Min Budget.
        -- Also, Candidate Min Bedrooms <= Segment Min Bedrooms (Candidate wants 1, Segment is 1 -> Match. Candidate wants 2, Segment is 1 -> No match?
        -- Wait, segment usually implies "Properties in this segment".
        -- If segment is "1 Bedroom Apartments", a candidate wanting "2 Bedrooms" is NOT a match.
        -- If segment is "2 Bedroom Apartments", a candidate wanting "1 Bedroom" MIGHT be a match (upgrade), but usually people filter strictly or >=.
        
        AND (preference_min_bedrooms <= v_min_bedrooms OR preference_min_bedrooms IS NULL);
END;
$$ LANGUAGE plpgsql;

-- Comment
COMMENT ON FUNCTION public.get_accounts_in_segment IS 'Returns accounts that match the criteria of a given segment ID';
