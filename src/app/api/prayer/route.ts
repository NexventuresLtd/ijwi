import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function POST(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { post_id, action } = await req.json()
  if (!post_id || !['add', 'remove'].includes(action)) {
    return NextResponse.json({ error: 'Invalid request' }, { status: 400 })
  }

  if (action === 'add') {
    await supabase.from('prayer_chains').upsert(
      { post_id, user_id: user.id },
      { onConflict: 'post_id,user_id' }
    )
  } else {
    await supabase.from('prayer_chains').delete()
      .match({ post_id, user_id: user.id })
  }

  // Return updated prayer count
  const { count } = await supabase
    .from('prayer_chains')
    .select('*', { count: 'exact', head: true })
    .eq('post_id', post_id)

  return NextResponse.json({ prayer_count: count ?? 0 })
}
