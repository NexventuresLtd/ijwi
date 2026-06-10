import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import Navbar from '@/components/layout/Navbar'
import EventCreateClient from './EventCreateClient'

export const metadata = { title: 'Create Event — Ijwi' }

export default async function EventCreatePage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/login?next=/events/create')
  const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).single()
  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--ij-bg-base)' }}>
      <Navbar profile={profile as any} />
      <EventCreateClient currentUserId={user.id} />
    </div>
  )
}
