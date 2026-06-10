import { createClient } from '@/lib/supabase/server'
import Navbar from '@/components/layout/Navbar'
import ExploreClient from './ExploreClient'

export default async function ExplorePage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  let profile = null
  if (user) {
    const { data } = await supabase.from('profiles').select('*').eq('id', user.id).single()
    profile = data
  }

  const { data: topPostsRaw } = await supabase
    .from('posts')
    .select(`*, author:profiles(id, voice_name, is_revealed, real_name, avatar_url, level, xp)`)
    .order('reaction_fire', { ascending: false })
    .limit(16)

  const topPosts = (topPostsRaw ?? []).map(p => ({
    ...p,
    reactions: {
      fire: p.reaction_fire ?? 0,
      amen: p.reaction_amen ?? 0,
      healed: p.reaction_healed ?? 0,
      needed: p.reaction_needed ?? 0,
      sharing: p.reaction_sharing ?? 0,
    },
    tags: p.tags ?? [],
    comment_count: p.comment_count ?? 0,
  }))

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--warm-white)' }}>
      <Navbar profile={profile} />

      <main className="ij-page-container" style={{ flex: 1 }}>
        {/* Header */}
        <div style={{ marginBottom: '24px' }}>
          <h1 style={{
            fontFamily: 'var(--font-display)', fontSize: '30px', fontWeight: 500,
            color: 'var(--text-primary)', marginBottom: '4px',
          }}>
            Explore
          </h1>
          <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
            Discover voices, topics, and testimonies.
          </p>
        </div>

        <ExploreClient initialPosts={topPosts} currentUserId={user?.id} />
      </main>
    </div>
  )
}
