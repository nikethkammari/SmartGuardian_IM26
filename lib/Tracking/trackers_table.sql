-- FINAL SQL QUERY FOR TRACKERS ISOLATION
-- This version uses a Database Trigger to automatically create the tracker profile
-- when a new user signs up with the 'tracker' role in their metadata.
-- This avoids the RLS "PostgrestException: code 42501" during client-side registration.

-- 1. Create the trackers table (if not already there)
CREATE TABLE IF NOT EXISTS public.trackers (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable RLS
ALTER TABLE public.trackers ENABLE ROW LEVEL SECURITY;

-- 3. DROP old policies to ensure a clean slate
DROP POLICY IF EXISTS "Trackers can insert their own profile" ON public.trackers;
DROP POLICY IF EXISTS "Trackers can view their own profile" ON public.trackers;
DROP POLICY IF EXISTS "Trackers can update their own profile" ON public.trackers;

-- 4. Set up robust RLS Policies
-- Selective SELECT for trackers to see their own data
CREATE POLICY "Allow individual read access" 
ON public.trackers FOR SELECT 
USING (auth.uid() = id);

-- Selective UPDATE for trackers to manage their own data
CREATE POLICY "Allow individual update access" 
ON public.trackers FOR UPDATE 
USING (auth.uid() = id);

-- 5. TRIGGER: Handle Automatic Profile Creation on Signup
-- This runs on the database side, bypassing client-side RLS issues
CREATE OR REPLACE FUNCTION public.handle_new_tracker()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create a tracker profile if the role in metadata is 'tracker'
  IF (NEW.raw_user_meta_data->>'role' = 'tracker') THEN
    INSERT INTO public.trackers (id, full_name, email)
    VALUES (
      NEW.id,
      NEW.raw_user_meta_data->>'full_name',
      NEW.email
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Bind the trigger to auth.users (runs after every signUp)
DROP TRIGGER IF EXISTS on_auth_user_created_tracker ON auth.users;
CREATE TRIGGER on_auth_user_created_tracker
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_tracker();

-- 7. Grant necessary permissions (Standard for public schema)
GRANT ALL ON public.trackers TO service_role;
GRANT ALL ON public.trackers TO authenticated;
GRANT ALL ON public.trackers TO anon;
