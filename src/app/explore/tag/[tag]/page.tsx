import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import Navbar from '@/components/layout/Navbar'
import PostCard from '@/components/post/PostCard'

interface TagPageProps {
  params: Promise<{ tag: string }>
}

export default async function TagPage({ params }: TagPageProps) {
  const { tag } = await params
  if (!tag) notFound()

  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  let profile = null
  if (user) {
    const { data } = await supabase.from('profiles').select('*').eq('id', user.id).single()
    profile = data
  }

  const { data: postsRaw } = await supabase
    .from('posts')
    .select(`*, author:profiles(id, voice_name, is_revealed, real_name, avatar_url, level, xp)`)
    .contains('tags', [tag])
    .order('created_at', { ascending: false })
    .limit(30)

  let userReactionMap: Record<string, string[]> = {}
  if (user && postsRaw?.length) {
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

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--warm-white)' }}>
      <Navbar profile={profile} />

      <main style={{ flex: 1, maxWidth: '680px', padding: '28px 24px' }}>
        {/* Back */}
        <Link href="/explore" style={{
          display: 'inline-flex', alignItems: 'center', gap: '6px',
          fontSize: '13px', color: 'var(--text-muted)', textDecoration: 'none',
          marginBottom: '20px',
        }}>
          ← Explore
        </Link>

        {/* Header */}
        <div style={{ marginBottom: '28px' }}>
          <div style={{
            display: 'inline-block', padding: '6px 16px', borderRadius: '100px',
            background: 'var(--flame-soft)', color: 'var(--flame)',
            fontSize: '13px', fontWeight: 600, marginBottom: '12px',
          }}>
            #{tag}
          </div>
          <h1 style={{
            fontFamily: 'var(--font-display)', fontSize: '28px', fontWeight: 500,
            color: 'var(--text-primary)', marginBottom: '6px',
          }}>
            #{tag}
          </h1>
          <p style={{ fontSize: '14px', color: 'var(--text-muted)' }}>
            {posts.length} {posts.length === 1 ? 'voice' : 'voices'} sharing on this topic
          </p>
        </div>

        {/* Posts */}
        {posts.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '80px 20px' }}>
            <div style={{ fontSize: '48px', marginBottom: '16px' }}>🌱</div>
            <p style={{
              fontFamily: 'var(--font-display)', fontSize: '20px',
              color: 'var(--text-secondary)', marginBottom: '8px',
            }}>
              No voices yet on #{tag}
            </p>
            <p style={{ fontSize: '14px', color: 'var(--text-muted)', marginBottom: '24px' }}>
              Be the first to share something on this topic.
            </p>
            {user && (
              <Link href="/feed" style={{
                padding: '11px 28px', borderRadius: '100px',
                background: 'var(--flame)', color: 'white',
                textDecoration: 'none', fontSize: '14px', fontWeight: 600,
              }}>
                Share your voice →
              </Link>
            )}
          </div>
        ) : (
          <div className="stagger">
            {posts.map(post => (
              <PostCard
                key={post.id}
                post={post}
                currentUserId={user?.id}
                userReactions={(userReactionMap[post.id] ?? []) as any}
                isPro={profile?.is_pro ?? false}
              />
            ))}
          </div>
        )}
      </main>
    </div>
  )
}
