import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import EventDetailClient from './EventDetailClient'
import type { Metadata } from 'next'

export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  const supabase = await createClient()
  const { data: event } = await supabase
    .from('events')
    .select('title, description, cover_image_url')
    .eq('id', params.id)
    .single()

  if (!event) return { title: 'Event Not Found' }

  return {
    title: event.title,
    description: event.description || 'Join this event on Ijwi.',
    openGraph: {
      title: event.title,
      description: event.description || 'Join this event on Ijwi.',
      images: event.cover_image_url ? [event.cover_image_url] : [],
      type: 'website',
    },
    twitter: {
      card: 'summary_large_image',
      title: event.title,
      description: event.description || 'Join this event on Ijwi.',
      images: event.cover_image_url ? [event.cover_image_url] : [],
    },
  }
}

export default async function EventDetailPage({ params }: { params: { id: string } }) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: event } = await supabase
    .from('events')
    .select(`
      id, title, description, location, event_date, ends_at,
      ticket_price, ticket_currency, max_attendees, created_at,
      cover_image_url, is_free, is_virtual, stream_url, tags,
      organizer_id,
      organizer:profiles!events_organizer_id_fkey(id, voice_name, avatar_url, is_verified, bio)
    `)
    .eq('id', params.id)
    .single()

  if (!event) notFound()

  const normalizedEvent = {
    ...event,
    organizer: Array.isArray(event.organizer) ? event.organizer[0] : event.organizer,
  }

  const { count: attendeeCount } = await supabase
    .from('event_tickets')
    .select('*', { count: 'exact', head: true })
    .eq('event_id', params.id)
    .eq('status', 'paid')

  const { data: userTicket } = user
    ? await supabase.from('event_tickets')
        .select('id, status')
        .eq('event_id', params.id)
        .eq('user_id', user.id)
        .single()
    : { data: null }

  const { data: profile } = user
    ? await supabase.from('profiles').select('*').eq('id', user.id).single()
    : { data: null }

  return (
    <EventDetailClient
      event={normalizedEvent as any}
      attendeeCount={attendeeCount ?? 0}
      currentUserId={user?.id}
      userTicket={userTicket}
      profile={profile as any}
    />
  )
}
