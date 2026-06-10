import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import WriteClient from './WriteClient'

export const metadata = { title: 'Write — Ijwi' }

export default async function WritePage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/login?next=/write')

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, voice_name, avatar_url, is_revealed, is_approved_poster, is_admin')
    .eq('id', user.id)
    .single()

  const adminEmails = (process.env.ADMIN_EMAILS ?? 'armandkayiranga7@gmail.com').split(',').map(s => s.trim())
  const isAdmin = profile?.is_admin || adminEmails.includes(user.email ?? '')
  if (!profile?.is_approved_poster && !isAdmin) redirect('/feed')

  return <WriteClient profile={profile} />
}
