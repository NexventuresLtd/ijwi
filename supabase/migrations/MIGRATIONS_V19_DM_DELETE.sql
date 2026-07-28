-- V19: Add delete and update policies to direct_messages
-- Run in Supabase SQL Editor

-- Allow users to delete their own messages, or messages they received (Delete for me)
CREATE POLICY "dm_delete"
  ON direct_messages FOR DELETE
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Allow senders to update their own messages (Delete for everyone sets deleted=true and message='[deleted]')
CREATE POLICY "dm_update_sender"
  ON direct_messages FOR UPDATE
  USING (auth.uid() = sender_id);
