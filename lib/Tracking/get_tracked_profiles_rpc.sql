-- ============================================================
-- SQL: get_tracked_profiles RPC
-- Securely fetches approved primary user profiles for a tracker
-- using SECURITY DEFINER to bypass RLS recursion.
-- Run this in Supabase SQL Editor.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_tracked_profiles(tracker_uuid UUID)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email TEXT,
  photo_url TEXT,
  vehicle_number TEXT,
  is_active BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER  -- Runs as DB owner, bypasses all RLS
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
    ) AS is_active
  FROM profiles p
  INNER JOIN tracking_links tl
    ON tl.primary_user_email = p.email
  WHERE tl.tracker_id = tracker_uuid
    AND tl.status = 'approved';
END;
$$;

-- Grant execution rights to logged-in users
GRANT EXECUTE ON FUNCTION public.get_tracked_profiles(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tracked_profiles(UUID) TO service_role;
