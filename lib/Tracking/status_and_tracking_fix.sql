-- ============================================================
-- SQL: Status and Tracking Update
-- Run this in Supabase SQL Editor.
-- ============================================================

-- 1. Add status column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'inactive';

-- 2. Add current location columns to journeys table
ALTER TABLE public.journeys 
ADD COLUMN IF NOT EXISTS current_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS current_lng DOUBLE PRECISION;

-- 3. Update get_tracked_profiles RPC to include status
DROP FUNCTION IF EXISTS public.get_tracked_profiles(UUID);

CREATE OR REPLACE FUNCTION public.get_tracked_profiles(tracker_uuid UUID)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email TEXT,
  photo_url TEXT,
  vehicle_number TEXT,
  is_active BOOLEAN,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER  -- Runs as DB owner
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
    -- is_active: check if user has an active journey
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
