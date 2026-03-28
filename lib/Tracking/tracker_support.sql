-- SQL Migration to support User vs Tracker roles

-- 1. Add role column to profiles table if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='profiles' AND column_name='role') THEN
        ALTER TABLE profiles ADD COLUMN role TEXT DEFAULT 'user' CHECK (role IN ('user', 'tracker'));
    END IF;
END $$;

-- 2. Update existing policies or ensure they work with the new column
-- (Optional) If you want to restrict trackers from seeing user journey data, 
-- you would add RLS policies here.

-- 3. The email_exists RPC should already work as it checks auth.users 
-- but if we want to check specifically in profiles and include role:
/*
create or replace function get_profile_by_email(p_email text)
returns table (id uuid, full_name text, role text)
language plpgsql
security definer
as $$
begin
  return query
  select p.id, p.full_name, p.role
  from profiles p
  where p.email = p_email;
end;
$$;
*/
