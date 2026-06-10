import { createClient } from '@/lib/supabase/server'
import { notFound, redirect } from 'next/navigation'
import LiveRoomClient from './LiveRoomClient'

export default async function LiveRoomPage({ params }: { params: { id: string } }) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect(`/auth/login?redirect=/events/${params.id}/live`)

  const { data: event } = await supabase
    .from('events')
    .select('id, title, organizer_id, is_virtual, stream_url, event_date, ends_at')
    .eq('id', params.id)
    .single()

  if (!event || !event.is_virtual) notFound()
  // If there's an external stream URL, redirect there
  if (event.stream_url) redirect(event.stream_url)

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single()

  // Fetch initial messages
  const { data: messages } = await supabase
    .from('live_messages')
    .select('id, user_id, message, created_at')
    .eq('event_id', params.id)
    .order('created_at', { ascending: true })
    .limit(100)

  // Fetch profiles for message authors
  const authorIds = [...new Set((messages ?? []).map(m => m.user_id))]
  const { data: authors } = authorIds.length > 0
    ? await supabase.from('profiles').select('id, voice_name, real_name, is_revealed, avatar_url').in('id', authorIds)
    : { data: [] }

  const authorMap: Record<string, { voice_name: string; real_name: string | null; is_revealed: boolean; avatar_url?: string }> = {}
  for (const a of (authors ?? [])) {
    authorMap[a.id] = a
  }

  return (
    <LiveRoomClient
      eventId={event.id}
      eventTitle={event.title}
      organizerId={event.organizer_id}
      currentUserId={user.id}
      profile={profile as any}
      initialMessages={(messages ?? []).map(m => ({ ...m, author: authorMap[m.user_id] }))}
    />
  )
}
