import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import DmsListClient from './DmsListClient'

export default async function DmsPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/auth/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single()

  if (!profile) redirect('/auth/login')

  // Fetch all approved helpers (exclude current user)
  const { data: helpers } = await supabase
    .from('profiles')
    .select('id, voice_name, real_name, is_revealed, avatar_url, voice_role, dm_title, dm_bio')
    .eq('is_dm_listed', true)
    .neq('id', user.id)
    .order('voice_name', { ascending: true })

  // Fetch all conversations this user has started (latest message per helper)
  const { data: myMessages } = await supabase
    .from('direct_messages')
    .select('receiver_id, sender_id, message, created_at')
    .or(`sender_id.eq.${user.id},receiver_id.eq.${user.id}`)
    .order('created_at', { ascending: false })

  // Build conversation map: other_user_id -> latest message
  const convMap: Record<string, { message: string; created_at: string }> = {}
  for (const msg of (myMessages ?? [])) {
    const otherId = msg.sender_id === user.id ? msg.receiver_id : msg.sender_id
    if (!convMap[otherId]) {
      convMap[otherId] = { message: msg.message, created_at: msg.created_at }
    }
  }

  return (
    <DmsListClient
      currentUserId={user.id}
      profile={profile}
      helpers={(helpers ?? []) as any}
      convMap={convMap}
    />
  )
}
