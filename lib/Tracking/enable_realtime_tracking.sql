-- Enable Realtime for tracking_links
-- This allows the Supabase client to listen for changes (like approval)
-- and push them to the app in real-time.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'tracking_links'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.tracking_links;
    END IF;
END $$;
