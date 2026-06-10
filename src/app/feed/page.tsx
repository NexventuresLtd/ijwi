import { Suspense } from 'react'
import { createClient } from '@/lib/supabase/server'
import FeedClient from './FeedClient'

export default async function FeedPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  // Fetch posts — followed voices first for logged-in users
  let postsRaw: any[] | null = null
  if (user) {
    const { data: following } = await supabase
      .from('follows')
      .select('following_id')
      .eq('follower_id', user.id)
    const followedIds = (following ?? []).map((f: any) => f.following_id)

    if (followedIds.length > 0) {
      const [followedRes, recentRes] = await Promise.all([
        supabase
          .from('posts')
          .select(`*, author:profiles(id, voice_name, is_revealed, real_name, avatar_url, is_verified, subscription_status, is_approved_poster)`)
          .or('status.eq.published,status.is.null')
          .in('author_id', followedIds)
          .order('created_at', { ascending: false })
          .limit(15),
        supabase
          .from('posts')
          .select(`*, author:profiles(id, voice_name, is_revealed, real_name, avatar_url, is_verified, subscription_status, is_approved_poster)`)
          .or('status.eq.published,status.is.null')
          .not('author_id', 'in', `(${followedIds.join(',')})`)
          .order('created_at', { ascending: false })
          .limit(10),
      ])
      const seen = new Set<string>()
      postsRaw = [
        ...(followedRes.data ?? []),
        ...(recentRes.data ?? []),
      ].filter(p => { if (seen.has(p.id)) return false; seen.add(p.id); return true })
    } else {
      const { data } = await supabase
        .from('posts')
        .select(`*, author:profiles(id, voice_name, is_revealed, real_name, avatar_url, is_verified, subscription_status, is_approved_poster)`)
        .or('status.eq.published,status.is.null')
        .order('created_at', { ascending: false })
        .limit(20)
      postsRaw = data
    }
  } else {
    try {
      const { data } = await supabase
        .from('posts')
        .select(`*, author:profiles!posts_author_id_fkey(id, voice_name, is_revealed, real_name, avatar_url)`)
        .or('status.eq.published,status.is.null')
        .order('created_at', { ascending: false })
        .limit(20)
      postsRaw = data
    } catch {
      postsRaw = []
    }
  }

  // Fetch user's reactions if logged in
  let userReactionMap: Record<string, string[]> = {}
  if (user && postsRaw) {
    try {
      const postIds = postsRaw.map(p => p.id)
      const { data: reactions } = await supabase
        .from('reactions')
        .select('post_id, reaction_type')
        .eq('user_id', user.id)
        .in('post_id', postIds)
      reactions?.forEach(r => {
        if (!userReactionMap[r.post_id]) userReactionMap[r.post_id] = []
        userReactionMap[r.post_id].push(r.reaction_type)
      })
    } catch {}
  }

  // Fetch current user's profile
  let profile = null
  if (user) {
    const { data } = await supabase.from('profiles').select('*').eq('id', user.id).single()
    profile = data
  }

  // Admin check — env var (by user ID or email) or DB flag
  const adminIds = (process.env.ADMIN_USER_IDS ?? '').split(',').map(s => s.trim()).filter(Boolean)
  const adminEmails = (process.env.ADMIN_EMAILS ?? 'armandkayiranga7@gmail.com').split(',').map(s => s.trim()).filter(Boolean)
  const { data: { user: authUser } } = await supabase.auth.getUser()
  const userEmail = authUser?.email ?? ''
  const isAdmin = user ? (
    adminIds.includes(user.id) ||
    adminEmails.includes(userEmail) ||
    profile?.is_admin === true
  ) : false

  // Admins get full approved poster + Pro access automatically
  if (isAdmin && profile) {
    profile.is_approved_poster = true
    profile.subscription_status = 'active'
    profile.is_verified = true
  }

  // Trending posts: top 5 by fire reactions in the past 7 days
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()
  const { data: trendingRaw } = await supabase
    .from('posts')
    .select('id, title, body, content_type, reaction_fire, author_id, author:profiles(id, voice_name)')
    .gte('created_at', sevenDaysAgo)
    .order('reaction_fire', { ascending: false })
    .limit(5)

  const trending = (trendingRaw ?? []).map(p => ({
    id: p.id,
    title: p.title ?? null,
    body: p.body,
    content_type: p.content_type,
    fire: p.reaction_fire ?? 0,
    author_name: (p.author as any)?.voice_name ?? 'Anonymous voice',
  }))

  // Fetch user suggestions (people not yet followed, excluding self)
  let suggestions: { id: string; voice_name: string; voice_role?: string }[] = []
  if (user) {
    const { data: alreadyFollowing } = await supabase
      .from('follows').select('following_id').eq('follower_id', user.id)
    const followingIds = (alreadyFollowing ?? []).map(f => f.following_id)
    const excludeIds = [user.id, ...followingIds]
    const { data: allUsers } = await supabase
      .from('profiles').select('id, voice_name, voice_role').not('voice_name', 'ilike', 'deleted-%').order('created_at', { ascending: false }).limit(10)
    suggestions = (allUsers ?? []).filter(u => !excludeIds.includes(u.id)).slice(0, 4)
  } else {
    const { data: topUsers } = await supabase
      .from('profiles').select('id, voice_name, voice_role').not('voice_name', 'ilike', 'deleted-%').order('created_at', { ascending: false }).limit(4)
    suggestions = topUsers ?? []
  }

  // Up next essays for guest sidebar
  const { data: upNextPosts } = await supabase
    .from('posts')
    .select('id, title, read_time')
    .eq('content_type', 'essay')
    .or('status.eq.published,status.is.null')
    .order('created_at', { ascending: false })
    .limit(3)

  const posts = (postsRaw ?? []).map(p => ({
    ...p,
    reactions: {
      fire: p.reaction_fire ?? 0,
      amen: p.reaction_amen ?? 0,
      healed: p.reaction_healed ?? 0,
      needed: p.reaction_needed ?? 0,
      sharing: p.reaction_sharing ?? 0,
    }
  }))

  return (
    <Suspense>
      <FeedClient
        initialPosts={posts}
        currentUserId={user?.id}
        profile={profile}
        userReactionMap={userReactionMap}
        suggestions={suggestions}
        trending={trending}
        upNextPosts={upNextPosts ?? []}
        isPro={profile?.is_pro ?? false}
        isAdmin={isAdmin}
      />
    </Suspense>
  )
}
