-- Migration to add organizer_payouts for manual cashouts

CREATE TABLE organizer_payouts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    recipient_number TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'completed', 'failed'
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Turn on Row Level Security
ALTER TABLE organizer_payouts ENABLE ROW LEVEL SECURITY;

-- Allow users to view their own payouts
CREATE POLICY "Users can view their own payouts" 
ON organizer_payouts FOR SELECT 
USING (auth.uid() = user_id);
