import { createClient } from '@/lib/supabase/server'
import { redirect, notFound } from 'next/navigation'
import ChatClient from './ChatClient'

export default async function DmChatPage({ params }: { params: Promise<{ userId: string }> }) {
  const { userId } = await params
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/auth/login')
  if (userId === user.id) redirect('/dms')

  // Fetch helper profile (must be dm_listed)
  const { data: helper } = await supabase
    .from('profiles')
    .select('id, voice_name, real_name, is_revealed, avatar_url, level, dm_title, dm_bio, is_dm_listed')
    .eq('id', userId)
    .single()

  if (!helper || !helper.is_dm_listed) notFound()

  // Fetch current user profile
  const { data: myProfile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single()

  // Fetch conversation messages
  const { data: messages } = await supabase
    .from('direct_messages')
    .select('*')
    .or(
      `and(sender_id.eq.${user.id},receiver_id.eq.${userId}),and(sender_id.eq.${userId},receiver_id.eq.${user.id})`
    )
    .order('created_at', { ascending: true })
    .limit(100)

  // Mark unread messages from helper as read
  await supabase
    .from('direct_messages')
    .update({ read_at: new Date().toISOString() })
    .eq('sender_id', userId)
    .eq('receiver_id', user.id)
    .is('read_at', null)

  return (
    <ChatClient
      currentUserId={user.id}
      myProfile={myProfile}
      helper={helper as any}
      initialMessages={(messages ?? []) as any}
    />
  )
}
