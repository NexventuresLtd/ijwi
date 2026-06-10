import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import EventsClient from './EventsClient'

export const metadata = {
  title: 'Events — Ijwi',
  description: 'Faith gatherings, worship nights, prayer summits, and community events.',
}

export default async function EventsPage() {
  const supabase = await createClient()

  const { data: { user } } = await supabase.auth.getUser()
  const { data: events } = await supabase
    .from('events')
    .select(`
      id, title, description, location, event_date, ends_at,
      ticket_price, ticket_currency, max_attendees, created_at,
      cover_image_url, is_free, is_virtual, stream_url, tags,
      organizer:profiles!events_organizer_id_fkey(id, voice_name, avatar_url, is_verified)
    `)
    .gte('event_date', new Date().toISOString())
    .order('event_date', { ascending: true })
    .limit(40)

  const { data: profile } = user
    ? await supabase.from('profiles').select('id, is_admin').eq('id', user.id).single()
    : { data: null }

  const normalizedEvents = (events ?? []).map(e => ({
    ...e,
    organizer: Array.isArray(e.organizer) ? e.organizer[0] : e.organizer,
  }))

  return <EventsClient events={normalizedEvents as any} currentUserId={user?.id} profile={profile as any} isAdmin={profile?.is_admin ?? false} />
}
