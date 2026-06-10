import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import NotificationsClient from './NotificationsClient'

export default async function NotificationsPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/auth/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single()

  if (!profile) redirect('/auth/login')

  // Fetch notifications for this user (from a notifications table if it exists)
  // We build a synthetic notification feed from activity
  const [
    { data: newFollowers },
    { data: recentReactions },
    { data: recentComments },
  ] = await Promise.all([
    // People who recently followed this user
    supabase
      .from('follows')
      .select('follower_id, created_at, follower:profiles!follower_id(id, voice_name, level)')
      .eq('following_id', user.id)
      .order('created_at', { ascending: false })
      .limit(10),

    // Recent fire reactions on user's posts
    supabase
      .from('reactions')
      .select('post_id, user_id, created_at, reactor:profiles!user_id(id, voice_name), post:posts!post_id(id, title, body)')
      .eq('reaction_type', 'fire')
      .in(
        'post_id',
        // We need the user's post IDs — subquery workaround
        (await supabase.from('posts').select('id').eq('author_id', user.id).limit(50)).data?.map(p => p.id) ?? []
      )
      .order('created_at', { ascending: false })
      .limit(10),

    // Recent comments on user's posts
    supabase
      .from('comments')
      .select('id, post_id, author_id, body, created_at, author:profiles!author_id(id, voice_name), post:posts!post_id(id, title, body)')
      .in(
        'post_id',
        (await supabase.from('posts').select('id').eq('author_id', user.id).limit(50)).data?.map(p => p.id) ?? []
      )
      .neq('author_id', user.id) // exclude own comments
      .order('created_at', { ascending: false })
      .limit(10),
  ])

  // Merge into unified notifications list
  type Notif = {
    id: string
    type: 'follow' | 'fire' | 'comment'
    created_at: string
    actor_name: string
    actor_id: string
    target_title?: string
    target_id?: string
    excerpt?: string
  }

  const notifications: Notif[] = []

  newFollowers?.forEach(f => {
    const follower = f.follower as any
    notifications.push({
      id: `follow-${f.follower_id}`,
      type: 'follow',
      created_at: f.created_at,
      actor_name: follower?.voice_name ?? 'Someone',
      actor_id: f.follower_id,
    })
  })

  recentReactions?.forEach(r => {
    const reactor = r.reactor as any
    const post = r.post as any
    notifications.push({
      id: `fire-${r.post_id}-${r.user_id}`,
      type: 'fire',
      created_at: r.created_at,
      actor_name: reactor?.voice_name ?? 'Someone',
      actor_id: r.user_id,
      target_id: r.post_id,
      target_title: post?.title ?? post?.body?.slice(0, 50) ?? 'your post',
    })
  })

  recentComments?.forEach(c => {
    const author = c.author as any
    const post = c.post as any
    notifications.push({
      id: `comment-${c.id}`,
      type: 'comment',
      created_at: c.created_at,
      actor_name: author?.voice_name ?? 'Someone',
      actor_id: c.author_id,
      target_id: c.post_id,
      target_title: post?.title ?? post?.body?.slice(0, 50) ?? 'your post',
      excerpt: c.body?.slice(0, 80),
    })
  })

  // Sort by recency
  notifications.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())

  // Which of these followers does the current user already follow back?
  const followerIds = newFollowers?.map(f => f.follower_id) ?? []
  const { data: alreadyFollowingData } = followerIds.length > 0
    ? await supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', user.id)
        .in('following_id', followerIds)
    : { data: [] }

  const alreadyFollowingIds = alreadyFollowingData?.map((f: any) => f.following_id) ?? []

  return (
    <NotificationsClient
      profile={profile}
      currentUserId={user.id}
      notifications={notifications}
      alreadyFollowingIds={alreadyFollowingIds}
    />
  )
}
