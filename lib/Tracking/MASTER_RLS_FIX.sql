-- ============================================================
-- MASTER RLS FIX - Resolves Infinite Recursion on all tables
-- Run this ENTIRELY in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- SECTION 1: FIX THE PROFILES TABLE
-- ============================================================
-- Drop ALL existing policies on profiles to break any recursive chains
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'profiles' LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
    END LOOP;
END;
$$;

-- Recreate simple, non-recursive policies for profiles
-- Uses auth.uid() directly - NO cross-table lookups
CREATE POLICY "profiles_select"
ON public.profiles FOR SELECT
TO authenticated
USING (auth.uid() = id);

CREATE POLICY "profiles_insert"
ON public.profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Service role always bypasses RLS, so no special policy needed

-- ============================================================
-- SECTION 2: FIX THE TRACKING_LINKS TABLE
-- ============================================================
-- Drop ALL existing policies on tracking_links
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'tracking_links' LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.tracking_links', pol.policyname);
    END LOOP;
END;
$$;

-- Create tracking_links table if it doesn't exist yet
CREATE TABLE IF NOT EXISTS public.tracking_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tracker_id UUID NOT NULL REFERENCES public.trackers(id) ON DELETE CASCADE,
    primary_user_email TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    verification_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tracker_id, primary_user_email)
);

ALTER TABLE public.tracking_links ENABLE ROW LEVEL SECURITY;

-- Tracker policy: use auth.uid() directly (no subqueries)
CREATE POLICY "tracking_links_tracker"
ON public.tracking_links FOR ALL
TO authenticated
USING (auth.uid() = tracker_id)
WITH CHECK (auth.uid() = tracker_id);

-- Primary user policy: use auth.email() directly (no table lookup!)
-- auth.email() reads straight from JWT - never causes recursion
CREATE POLICY "tracking_links_user"
ON public.tracking_links FOR ALL
TO authenticated
USING (primary_user_email = auth.email())
WITH CHECK (primary_user_email = auth.email());

-- ============================================================
-- SECTION 3: GRANT PERMISSIONS
-- ============================================================
GRANT ALL ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;

GRANT ALL ON public.tracking_links TO authenticated;
GRANT ALL ON public.tracking_links TO service_role;
GRANT ALL ON public.tracking_links TO anon;

-- ============================================================
-- OPTIONAL: Verify policies were created
-- ============================================================
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename IN ('profiles', 'tracking_links')
ORDER BY tablename, policyname;
