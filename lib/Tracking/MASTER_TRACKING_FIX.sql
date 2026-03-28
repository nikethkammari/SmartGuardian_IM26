-- ============================================================
-- MASTER TRACKING FIX (REFINED)
-- 1. Adds 'status' to profiles with specific values
-- 2. Adds current location to journeys
-- 3. Enables REALTIME for tracking
-- 4. Updates RPC for Tracker Dashboard
-- ============================================================

-- 1. Profiles Update: Add status column
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Offline';

-- 2. Journeys Update: Ensure columns exist for real-time tracking
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='journeys' AND column_name='current_lat') THEN
        ALTER TABLE journeys ADD COLUMN current_lat DOUBLE PRECISION;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='journeys' AND column_name='current_lng') THEN
        ALTER TABLE journeys ADD COLUMN current_lng DOUBLE PRECISION;
    END IF;
END $$;

-- 3. ENABLE REALTIME
-- This is CRITICAL for the tracker to see live updates automatically
BEGIN;
  -- Remove existing publication if any to avoid errors
  DROP PUBLICATION IF EXISTS supabase_realtime;
  -- Create publication for tables we want to track in real-time
  CREATE PUBLICATION supabase_realtime FOR TABLE public.profiles, public.journeys;
COMMIT;

-- 4. UPDATE RPC: get_tracked_profiles
-- This function is used by the Tracker Home Page to list users and their status
DROP FUNCTION IF EXISTS public.get_tracked_profiles(UUID);

CREATE OR REPLACE FUNCTION public.get_tracked_profiles(tracker_uuid UUID)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email TEXT,
  photo_url TEXT,
  vehicle_number TEXT,
  is_active BOOLEAN, -- True if there is an 'active' journey
  status TEXT        -- 'Active', 'On Journey', or 'Offline'
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.full_name,
    p.email,
    p.photo_url,
    p.vehicle_number,
    EXISTS (
      SELECT 1 FROM journeys j
      WHERE j.user_id = p.id
        AND j.status = 'active'
    ) AS is_active,
    p.status
  FROM profiles p
  INNER JOIN tracking_links tl
    ON tl.primary_user_email = p.email
  WHERE tl.tracker_id = tracker_uuid
    AND tl.status = 'approved';
END;
$$;
