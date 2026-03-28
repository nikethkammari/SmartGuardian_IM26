-- SQL for Tracking Request & Approval System (FIXED)
-- Resolved: Infinite recursion error in RLS policies

-- 1. Create the tracking_links table (if not exists)
CREATE TABLE IF NOT EXISTS public.tracking_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tracker_id UUID NOT NULL REFERENCES public.trackers(id) ON DELETE CASCADE,
    primary_user_email TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved'
    verification_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tracker_id, primary_user_email)
);

-- 2. Enable RLS
ALTER TABLE public.tracking_links ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies - FIXED to avoid infinite recursion
-- The recursion happened because policies were querying the 'profiles' table,
-- which likely had its own policy querying 'tracking_links'.
-- By using auth.jwt() ->> 'email', we avoid table lookups entirely.

DROP POLICY IF EXISTS "Trackers can manage their own links" ON public.tracking_links;
DROP POLICY IF EXISTS "Users can view requests targeting them" ON public.tracking_links;
DROP POLICY IF EXISTS "Users can update requests targeting them" ON public.tracking_links;
DROP POLICY IF EXISTS "Users can manage requests targeting them" ON public.tracking_links;

-- POLICY 1: Trackers can see and manage their own sent requests (By UUID)
CREATE POLICY "Trackers can manage their own links"
ON public.tracking_links FOR ALL
TO authenticated
USING (auth.uid() = tracker_id)
WITH CHECK (auth.uid() = tracker_id);

-- POLICY 2: Primary users can see and approve requests targeting their email
-- This uses the email directly from the JWT to avoid circular table lookups.
CREATE POLICY "Users can manage requests targeting them"
ON public.tracking_links FOR ALL
TO authenticated
USING (primary_user_email = (auth.jwt() ->> 'email'))
WITH CHECK (primary_user_email = (auth.jwt() ->> 'email'));

-- 4. Grant permissions
GRANT ALL ON public.tracking_links TO authenticated;
GRANT ALL ON public.tracking_links TO service_role;
GRANT ALL ON public.tracking_links TO anon;
