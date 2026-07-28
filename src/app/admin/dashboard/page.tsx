import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AdminClient from './AdminClient'

export default async function AdminDashboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/admin')

  const adminIds = (process.env.ADMIN_USER_IDS ?? '').split(',').map(s => s.trim()).filter(Boolean)
  const adminEmails = (process.env.ADMIN_EMAILS ?? 'armandkayiranga7@gmail.com').split(',').map(s => s.trim()).filter(Boolean)

  const isEnvAdmin = adminIds.includes(user.id) || adminEmails.includes(user.email ?? '')

  if (!isEnvAdmin) {
    const { data: profile } = await supabase.from('profiles').select('is_admin').eq('id', user.id).single()
    if (!profile?.is_admin) redirect('/admin')
  }

  const { data: posts } = await supabase
    .from('posts')
    .select(`id, content_type, title, body, created_at, is_anonymous, author:profiles(id, voice_name, is_banned)`)
    .order('created_at', { ascending: false })
    .limit(50)

  const { data: users } = await supabase
    .from('profiles')
    .select('id, voice_name, real_name, level, xp, voice_role, is_banned, is_admin, is_answerer, is_dm_listed, is_approved_poster, created_at')
    .order('created_at', { ascending: false })
    .limit(50)

  const { data: reports } = await supabase
    .from('reports')
    .select(`id, reason, notes, reviewed, created_at, post:posts(id, title, body, content_type), reporter:profiles(id, voice_name)`)
    .eq('reviewed', false)
    .order('created_at', { ascending: false })
    .limit(50)

  const { data: payments } = await supabase
    .from('payments')
    .select(`id, phone, amount, currency, ref, status, created_at, user:profiles(id, voice_name)`)
    .order('created_at', { ascending: false })
    .limit(100)

  const { data: eventBookings } = await supabase
    .from('event_bookings')
    .select('id, payment_status, created_at, events(ticket_price), ticket_tiers(price)')
    .eq('payment_status', 'completed')
    .order('created_at', { ascending: false })
    .limit(1000)

  return (
    <AdminClient
      posts={(posts ?? []) as any}
      users={(users ?? []) as any}
      reports={(reports ?? []) as any}
      payments={(payments ?? []) as any}
      bookings={(eventBookings ?? []) as any}
    />
  )
}
