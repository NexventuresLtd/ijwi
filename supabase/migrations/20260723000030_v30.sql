-- =============================================================
-- IJWI MIGRATIONS V30
-- =============================================================

-- Allow users to insert notifications (needed for client-side notify_helper.dart)
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;

CREATE POLICY "notifications_insert"
  ON public.notifications FOR INSERT
  WITH CHECK (auth.uid() = actor_id);
