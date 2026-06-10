import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import ProfilePageClient from './ProfilePageClient'

export default async function ProfilePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', id)
    .single()

  if (!profile) notFound()

  const isOwnProfile = user?.id === id

  // Fetch posts. Own profile sees ALL their posts (including anonymous).
  // Visitors only see non-anonymous posts.
  // We match status='published' OR status IS NULL to handle rows that
  // predate the status column being added to the database.
  let postsRaw: any[] | null = null

  if (isOwnProfile) {
    // Own profile: all posts, no status or anonymous filter
    const { data } = await supabase
      .from('posts')
      .select('*')
      .eq('author_id', id)
      .order('created_at', { ascending: false })
      .limit(30)
    postsRaw = data
  } else {
    // Visitor: only non-anonymous published posts
    const { data } = await supabase
      .from('posts')
      .select('*')
      .eq('author_id', id)
      .eq('is_anonymous', false)
      .or('status.eq.published,status.is.null')
      .order('created_at', { ascending: false })
      .limit(30)
    postsRaw = data
  }

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

  const totalFire = posts.reduce((sum, p) => sum + (p.reactions?.fire ?? 0), 0)

  // Follower / following counts
  const [{ count: followerCount }, { count: followingCount }] = await Promise.all([
    supabase.from('follows').select('*', { count: 'exact', head: true }).eq('following_id', id),
    supabase.from('follows').select('*', { count: 'exact', head: true }).eq('follower_id', id),
  ])

  // Post count — own profile counts everything, visitors only non-anonymous
  let postCount: number | null = null

  if (isOwnProfile) {
    // Own profile: count all their posts regardless of status or anonymity
    const { count } = await supabase
      .from('posts')
      .select('*', { count: 'exact', head: true })
      .eq('author_id', id)
    postCount = count
  } else {
    const { count } = await supabase
      .from('posts')
      .select('*', { count: 'exact', head: true })
      .eq('author_id', id)
      .eq('is_anonymous', false)
      .or('status.eq.published,status.is.null')
    postCount = count
  }

  let isFollowing = false
  let currentUserProfile = null
  let isPro = false

  if (user) {
    const [{ data: follow }, { data: cp }] = await Promise.all([
      supabase
        .from('follows')
        .select('follower_id')
        .eq('follower_id', user.id)
        .eq('following_id', id)
        .maybeSingle(),
      supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single(),
    ])
    isFollowing = !!follow
    currentUserProfile = cp
    const adminEmails = (process.env.ADMIN_EMAILS ?? 'armandkayiranga7@gmail.com').split(',').map(s => s.trim())
    const isAdminUser = cp?.is_admin || adminEmails.includes(user?.email ?? '')
    isPro = cp?.is_pro || cp?.is_approved_poster || isAdminUser || false
  }

  return (
    <ProfilePageClient
      profile={profile}
      posts={posts}
      followerCount={followerCount ?? 0}
      followingCount={followingCount ?? 0}
      postCount={postCount ?? 0}
      totalFire={totalFire}
      isFollowing={isFollowing}
      isOwnProfile={isOwnProfile}
      currentUserId={user?.id}
      currentUserProfile={currentUserProfile}
      isPro={isPro}
    />
  )
}
