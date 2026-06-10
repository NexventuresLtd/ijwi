import { createClient } from '@/lib/supabase/server'
import SparksClient from './SparksClient'

export const metadata = {
  title: 'Sparks — Ijwi',
  description: 'Moments of faith — testimonies, worship, and the Word in motion.',
}

export default async function SparksPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  let profile = null
  let userSparksCount = 0
  let isPro = false

  if (user) {
    const { data } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single()
    profile = data
    isPro = data?.is_pro ?? false

    // Count sparks posted THIS calendar month (for the monthly free cap)
    const monthStart = new Date()
    monthStart.setDate(1)
    monthStart.setHours(0, 0, 0, 0)
    const { count } = await supabase
      .from('posts')
      .select('*', { count: 'exact', head: true })
      .eq('author_id', user.id)
      .eq('content_type', 'short')
      .gte('created_at', monthStart.toISOString())

    userSparksCount = count ?? 0
  }

  // Fetch latest sparks (posts with content_type = 'short' OR any post with a video)
  const { data: sparksRaw } = await supabase
    .from('posts')
    .select(`
      *,
      author:profiles(id, voice_name, is_revealed, real_name, avatar_url, level, xp)
    `)
    .or('content_type.eq.short,video_url.not.is.null')
    .order('created_at', { ascending: false })
    .limit(30)

  const sparks = (sparksRaw ?? []).map(p => ({
    ...p,
    reactions: {
      fire: p.reaction_fire ?? 0,
      amen: p.reaction_amen ?? 0,
      healed: p.reaction_healed ?? 0,
      needed: p.reaction_needed ?? 0,
      sharing: p.reaction_sharing ?? 0,
    }
  }))

  // Which sparks has the current user reacted to?
  let userReactionMap: Record<string, string[]> = {}
  if (user && sparks.length > 0) {
    const { data: userReactions } = await supabase
      .from('reactions')
      .select('post_id, reaction_type')
      .eq('user_id', user.id)
      .in('post_id', sparks.map(s => s.id))

    userReactions?.forEach(r => {
      if (!userReactionMap[r.post_id]) userReactionMap[r.post_id] = []
      userReactionMap[r.post_id].push(r.reaction_type)
    })
  }

  // Who does current user follow?
  let followingIds: string[] = []
  if (user) {
    const { data: following } = await supabase
      .from('follows')
      .select('following_id')
      .eq('follower_id', user.id)
    followingIds = following?.map(f => f.following_id) ?? []
  }

  const accountAgeDays = profile
    ? Math.floor((Date.now() - new Date(profile.created_at).getTime()) / 86400000)
    : 999

  return (
    <SparksClient
      sparks={sparks}
      profile={profile}
      currentUserId={user?.id}
      isPro={isPro}
      userSparksCount={userSparksCount}
      accountAgeDays={accountAgeDays}
      userReactionMap={userReactionMap}
      initialFollowingIds={followingIds}
    />
  )
}
