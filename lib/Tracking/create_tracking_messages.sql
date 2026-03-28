-- Create tracking_messages table
CREATE TABLE IF NOT EXISTS public.tracking_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    sender_name TEXT,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    is_read BOOLEAN DEFAULT false
);

-- Enable RLS
ALTER TABLE public.tracking_messages ENABLE ROW LEVEL SECURITY;

-- Allow users to send messages
CREATE POLICY "Users can send tracking messages" 
ON public.tracking_messages FOR INSERT 
WITH CHECK (auth.uid() = sender_id);

-- Allow users to see messages sent to them
CREATE POLICY "Users can view messages sent to them" 
ON public.tracking_messages FOR SELECT 
USING (auth.uid() = receiver_id);

-- Enable Realtime for tracking_messages
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'tracking_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.tracking_messages;
    END IF;
END $$;
