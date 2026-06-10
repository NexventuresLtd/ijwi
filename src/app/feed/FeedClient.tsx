'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { motion, AnimatePresence } from 'framer-motion'
import ProfileAvatar from '@/components/ui/ProfileAvatar'
import { Post, Profile, ContentType } from '@/lib/types'
import PostCard from '@/components/post/PostCard'
import PostComposer from '@/components/post/PostComposer'
import Navbar from '@/components/layout/Navbar'
import IjwiLogo from '@/components/IjwiLogo'
import { createClient } from '@/lib/supabase/client'
import StoryViewer from '@/components/ui/StoryViewer'

// Curated daily verses — rotates by day of year
const DAILY_VERSES = [
  { ref: 'Psalm 46:10', text: 'Be still, and know that I am God.' },
  { ref: 'Isaiah 41:10', text: 'Do not fear, for I am with you; do not be dismayed, for I am your God.' },
  { ref: 'Jeremiah 29:11', text: 'For I know the plans I have for you, plans to prosper you and not to harm you.' },
  { ref: 'Romans 8:28', text: 'And we know that in all things God works for the good of those who love him.' },
  { ref: 'Philippians 4:13', text: 'I can do all this through him who gives me strength.' },
  { ref: 'Proverbs 3:5-6', text: 'Trust in the LORD with all your heart and lean not on your own understanding.' },
  { ref: 'Matthew 11:28', text: 'Come to me, all you who are weary and burdened, and I will give you rest.' },
  { ref: 'Joshua 1:9', text: 'Be strong and courageous. Do not be afraid; do not be discouraged.' },
  { ref: 'Psalm 23:1', text: 'The LORD is my shepherd, I lack nothing.' },
  { ref: '2 Corinthians 5:17', text: 'If anyone is in Christ, the new creation has come. The old has gone, the new is here.' },
  { ref: 'Psalm 34:18', text: 'The LORD is close to the brokenhearted and saves those who are crushed in spirit.' },
  { ref: 'Romans 5:8', text: 'But God demonstrates his own love for us in this: While we were still sinners, Christ died for us.' },
  { ref: 'Isaiah 40:31', text: 'But those who hope in the LORD will renew their strength. They will soar on wings like eagles.' },
  { ref: 'Lamentations 3:23', text: 'Great is your faithfulness. His mercies are new every morning.' },
]

function calcVerse() {
  const now = new Date()
  const dayOfYear = Math.floor(
    (now.getTime() - new Date(now.getFullYear(), 0, 0).getTime()) / 86400000
  )
  return DAILY_VERSES[dayOfYear % DAILY_VERSES.length]
}

function useDailyVerse() {
  const [verse, setVerse] = useState(calcVerse)

  useEffect(() => {
    let timeoutId: ReturnType<typeof setTimeout>
    const scheduleNext = () => {
      const now = new Date()
      const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
      const msUntilMidnight = midnight.getTime() - now.getTime()
      timeoutId = setTimeout(() => {
        setVerse(calcVerse())
        scheduleNext()
      }, msUntilMidnight)
    }
    scheduleNext()
    return () => clearTimeout(timeoutId)
  }, [])

  return verse
}

interface TrendingPost {
  id: string
  title: string | null
  body: string
  content_type: string
  fire: number
  author_name: string
}

interface FeedClientProps {
  initialPosts: Post[]
  currentUserId?: string
  profile?: Profile | null
  userReactionMap: Record<string, string[]>
  suggestions: { id: string; voice_name: string; voice_role?: string }[]
  trending: TrendingPost[]
  upNextPosts?: { id: string; title: string | null; read_time?: number }[]
  isPro?: boolean
  isAdmin?: boolean
}

const FEED_TABS: { label: string; types: string[] | null; followersOnly?: boolean }[] = [
  { label: 'For You',   types: null },
  { label: 'Voices',    types: null, followersOnly: true },
  { label: 'Questions', types: ['question'] },
]

const TOPIC_CHIPS = ['#faith', '#prayer', '#testimony', '#devotional', '#worship', '#healing']

const PAGE_SIZE = 20

export default function FeedClient({
  initialPosts,
  currentUserId,
  profile,
  userReactionMap,
  suggestions,
  trending,
  upNextPosts = [],
  isPro = false,
  isAdmin = false,
}: FeedClientProps) {
  const searchParams = useSearchParams()
  const initialTab = (() => {
    const tab = searchParams.get('tab')
    if (tab && FEED_TABS.some(t => t.label === tab)) return tab
    return 'For You'
  })()

  const [posts, setPosts] = useState(initialPosts)
  const [activeTab, setActiveTab] = useState(initialTab)
  const [showComposer, setShowComposer] = useState(false)
  const [showPicker, setShowPicker] = useState(false)
  const [composeType, setComposeType] = useState<ContentType | undefined>()
  const [followedIds, setFollowedIds] = useState<string[]>([])
  const [followsLoaded, setFollowsLoaded] = useState(!currentUserId)
  const [hasUnread, setHasUnread] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)
  const [hasMore, setHasMore] = useState(initialPosts.length === PAGE_SIZE)
  const [storyViewerIdx, setStoryViewerIdx] = useState<number | null>(null)
  const [newPostsQueue, setNewPostsQueue] = useState<Post[]>([])
  const [hintDismissed, setHintDismissed] = useState(true)
  const [prayerPosts, setPrayerPosts] = useState<{ id: string; body: string; author_id: string; author_name: string; prayer_count: number }[]>([])
  const loaderRef = useRef<HTMLDivElement>(null)
  const dailyVerse = useDailyVerse()

  const storyCutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
  const storyPosts = initialPosts.filter(p =>
    p.content_type === 'story' && p.author && p.created_at >= storyCutoff
  ).slice(0, 12)

  const supabase = createClient()

  useEffect(() => {
    supabase
      .from('posts')
      .select('id, body, author_id, prayer_count, author:profiles(voice_name)')
      .eq('content_type', 'prayer')
      .order('created_at', { ascending: false })
      .limit(3)
      .then(({ data }) => {
        if (data) setPrayerPosts(data.map((p: any) => ({
          id: p.id,
          body: p.body,
          author_id: p.author_id,
          author_name: (p.author as any)?.voice_name ?? 'Anonymous',
          prayer_count: p.prayer_count ?? 0,
        })))
      })
  }, [])

  useEffect(() => {
    if (!profile?.id) return
    const lastSeen = localStorage.getItem('notif_last_seen') ?? new Date(0).toISOString()
    supabase
      .from('follows')
      .select('*', { count: 'exact', head: true })
      .eq('following_id', profile.id)
      .gte('created_at', lastSeen)
      .then(({ count }) => { if ((count ?? 0) > 0) setHasUnread(true) })
  }, [profile?.id])

  useEffect(() => {
    if (!currentUserId) return
    const dismissed = localStorage.getItem('ijwi_follow_hint_dismissed') === 'true'
    supabase
      .from('follows')
      .select('following_id')
      .eq('follower_id', currentUserId)
      .then(({ data }) => {
        if (data) {
          setFollowedIds(data.map((r: any) => r.following_id))
          if (!dismissed && data.length === 0) setHintDismissed(false)
        }
        setFollowsLoaded(true)
      })
  }, [currentUserId])

  useEffect(() => {
    const channel = supabase
      .channel('feed-realtime')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'posts' }, async (payload) => {
        const raw = payload.new as any
        const { data } = await supabase
          .from('posts')
          .select(`*, author:profiles(id, voice_name, is_revealed, real_name, avatar_url, level, xp)`)
          .eq('id', raw.id)
          .single()
        if (!data) return
        const post: Post = {
          ...data,
          reactions: {
            fire: data.reaction_fire ?? 0,
            amen: data.reaction_amen ?? 0,
            healed: data.reaction_healed ?? 0,
            needed: data.reaction_needed ?? 0,
            sharing: data.reaction_sharing ?? 0,
          },
          tags: data.tags ?? [],
        }
        if (raw.author_id !== currentUserId) {
          setNewPostsQueue(q => [post, ...q])
        }
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [currentUserId])

  const handlePostCreated = () => {
    setShowComposer(false)
    supabase
      .from('posts')
      .select(`*, author:profiles(id, voice_name, is_revealed, real_name, avatar_url, level, xp)`)
      .order('created_at', { ascending: false })
      .limit(PAGE_SIZE)
      .then(({ data }) => {
        if (data) setPosts(data.map((p: any) => ({
          ...p,
          reactions: { fire: p.reaction_fire ?? 0, amen: p.reaction_amen ?? 0, healed: p.reaction_healed ?? 0, needed: p.reaction_needed ?? 0, sharing: p.reaction_sharing ?? 0 },
          tags: p.tags ?? [],
        })))
      })
  }

  const handleFollow = async (targetId: string) => {
    if (!currentUserId) return
    await supabase.from('follows').insert({ follower_id: currentUserId, following_id: targetId })
    setFollowedIds(ids => [...ids, targetId])
  }

  const loadMore = useCallback(async () => {
    if (loadingMore || !hasMore) return
    setLoadingMore(true)

    const tab = FEED_TABS.find(t => t.label === activeTab)
    const oldest = posts[posts.length - 1]?.created_at

    let query = supabase
      .from('posts')
      .select(`*, author:profiles(id, voice_name, is_revealed, real_name, avatar_url, level, xp)`)
      .order('created_at', { ascending: false })
      .limit(PAGE_SIZE)

    if (oldest) query = query.lt('created_at', oldest)
    if (tab?.types && tab.types.length === 1) query = query.eq('content_type', tab.types[0])
    if (tab?.types && tab.types.length > 1) query = query.in('content_type', tab.types)
    if (tab?.followersOnly) {
      if (followedIds.length === 0) { setLoadingMore(false); setHasMore(false); return }
      query = query.in('author_id', followedIds)
    }

    const { data } = await query

    if (!data || data.length === 0) {
      setHasMore(false)
    } else {
      const mapped = data.map((p: any) => ({
        ...p,
        reactions: {
          fire: p.reaction_fire ?? 0,
          amen: p.reaction_amen ?? 0,
          healed: p.reaction_healed ?? 0,
          needed: p.reaction_needed ?? 0,
          sharing: p.reaction_sharing ?? 0,
        }
      }))
      setPosts(prev => [...prev, ...mapped])
      setHasMore(data.length === PAGE_SIZE)
    }
    setLoadingMore(false)
  }, [loadingMore, hasMore, activeTab, posts, supabase])

  useEffect(() => {
    const el = loaderRef.current
    if (!el) return
    const observer = new IntersectionObserver(
      (entries) => { if (entries[0].isIntersecting) loadMore() },
      { rootMargin: '200px' }
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [loadMore])

  const handleTabChange = (label: string) => {
    setActiveTab(label)
    const tab = FEED_TABS.find(t => t.label === label)
    setPosts(initialPosts.filter(p => {
      if (tab?.followersOnly) return followedIds.includes(p.author_id ?? '')
      return !tab?.types ? true : tab.types!.includes(p.content_type)
    }))
    setHasMore(true)
  }

  const filteredPosts = posts.filter(post => {
    const tab = FEED_TABS.find(t => t.label === activeTab)
    if (tab?.followersOnly) return followedIds.includes(post.author_id ?? '')
    return !tab?.types ? true : tab.types!.includes(post.content_type)
  })

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--warm-white)' }}>
      <Navbar profile={profile} onCompose={() => setShowPicker(true)} isAdmin={isAdmin} />

      {/* Left sidebar — desktop only */}
      <div className="feed-left-sidebar">
        <div style={{ marginBottom: 28 }}>
          <div className="ij-section-label" style={{ marginBottom: 12 }}>Active Voices</div>
          {suggestions.slice(0, 5).map(user => {
            const alreadyFollowed = followedIds.includes(user.id)
            return (
              <div key={user.id} style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12, justifyContent: 'space-between' }}>
                <Link href={`/profile/${user.id}`} style={{ display: 'flex', alignItems: 'center', gap: 8, textDecoration: 'none', flex: 1, minWidth: 0 }}>
                  <ProfileAvatar userId={user.id} size={28} voiceName={user.voice_name} />
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontSize: '12px', fontWeight: 600, color: 'var(--ij-text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {user.voice_name}
                    </div>
                    {user.voice_role && user.voice_role !== 'voice' && (
                      <div style={{ fontSize: '10px', color: 'var(--ij-text-secondary)', textTransform: 'capitalize' }}>{user.voice_role.replace(/_/g, ' ')}</div>
                    )}
                  </div>
                </Link>
                {currentUserId && user.id !== currentUserId && !alreadyFollowed && (
                  <button
                    onClick={() => handleFollow(user.id)}
                    style={{
                      fontSize: '10px', padding: '3px 8px', borderRadius: 999,
                      border: '1px solid var(--ij-gold)', background: 'transparent',
                      color: 'var(--ij-gold)', cursor: 'pointer', flexShrink: 0,
                      fontFamily: 'var(--ij-font-body)',
                    }}
                  >
                    +
                  </button>
                )}
              </div>
            )
          })}
          <Link href="/explore" style={{ fontSize: '11px', color: 'var(--ij-gold)', textDecoration: 'none', fontWeight: 500 }}>
            See all →
          </Link>
        </div>

        <div>
          <div className="ij-section-label" style={{ marginBottom: 10 }}>Topics</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {TOPIC_CHIPS.map(tag => (
              <Link key={tag} href={`/explore/tag/${tag.slice(1)}`} className="ij-chip">
                {tag}
              </Link>
            ))}
          </div>
        </div>
      </div>

      {/* Main feed */}
      <main className="feed-main" style={{ flex: 1, maxWidth: '680px', padding: '28px 24px', minWidth: 0, width: '100%' }}>

        {/* Stories row */}
        {storyPosts.length > 0 && (
          <div style={{ marginBottom: '20px' }}>
            <div
              className="hide-scrollbar"
              style={{ display: 'flex', gap: '14px', overflowX: 'auto', paddingBottom: '4px' }}
            >
              {currentUserId && profile && (
                <button
                  onClick={() => { setComposeType('story'); setShowComposer(true) }}
                  style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px', background: 'none', border: 'none', cursor: 'pointer', flexShrink: 0 }}
                >
                  <div style={{
                    width: 56, height: 56, borderRadius: '50%',
                    border: '2px dashed var(--flame)', display: 'flex',
                    alignItems: 'center', justifyContent: 'center',
                    background: 'var(--flame-soft)',
                  }}>
                    <span style={{ fontSize: 22, color: 'var(--flame)', fontWeight: 300, lineHeight: 1 }}>+</span>
                  </div>
                  <span style={{ fontSize: 11, color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>Your flame</span>
                </button>
              )}
              {storyPosts.map((post, i) => (
                <button
                  key={post.id}
                  onClick={() => setStoryViewerIdx(i)}
                  style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px', background: 'none', border: 'none', cursor: 'pointer', flexShrink: 0 }}
                >
                  <div style={{ padding: 2, borderRadius: '50%', background: 'linear-gradient(135deg, var(--flame), #FFB830)' }}>
                    <div style={{ padding: 2, borderRadius: '50%', background: 'var(--warm-white)' }}>
                      <ProfileAvatar
                        userId={post.author!.id}
                        avatarUrl={post.author!.avatar_url}
                        isRevealed={post.author!.is_revealed && !post.is_anonymous}
                        size={48}
                        voiceName={post.author!.voice_name ?? undefined}
                      />
                    </div>
                  </div>
                  <span style={{
                    fontSize: 11, color: 'var(--text-muted)', whiteSpace: 'nowrap',
                    maxWidth: 60, overflow: 'hidden', textOverflow: 'ellipsis',
                  }}>
                    {post.is_anonymous ? 'Anonymous' : (post.author!.voice_name ?? 'Voice')}
                  </span>
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Guest hero banner */}
        {!profile && (
          <div style={{
            background: 'linear-gradient(135deg, #221840 0%, #130E2A 100%)',
            border: '1px solid var(--ij-border-gold)',
            borderRadius: 16, padding: '28px',
            marginBottom: 32,
            display: 'flex', alignItems: 'center',
            justifyContent: 'space-between', gap: 24,
            overflow: 'hidden', position: 'relative',
          }}>
            <div style={{
              position: 'absolute', inset: 0,
              background: 'radial-gradient(ellipse 60% 80% at 80% 50%, rgba(240,168,50,0.08) 0%, transparent 60%)',
              pointerEvents: 'none',
            }} />
            <div style={{ position: 'relative', zIndex: 1 }}>
              <p style={{
                fontFamily: 'var(--ij-font-body)', fontSize: '0.7rem', fontWeight: 700,
                letterSpacing: '0.12em', textTransform: 'uppercase',
                color: 'var(--ij-gold)', marginBottom: 8,
              }}>Welcome to Ijwi</p>
              <h2 style={{
                fontFamily: 'var(--ij-font-display)',
                fontSize: 'clamp(1.2rem, 2.5vw, 1.7rem)',
                fontWeight: 700, color: '#F2EEE8',
                lineHeight: 1.25, margin: '0 0 10px', maxWidth: 420,
              }}>
                A faith community where your voice matters
              </h2>
              <p style={{
                fontFamily: 'var(--ij-font-body)', fontSize: '0.88rem',
                color: 'rgba(245,240,232,0.65)',
                lineHeight: 1.55, margin: '0 0 20px', maxWidth: 380,
              }}>
                Read faith essays, pray together, watch Sparks, and discover events — built for African Christian youth.
              </p>
              <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                <Link href="/auth/signup" style={{ textDecoration: 'none' }}>
                  <button style={{
                    background: 'linear-gradient(135deg, #C9860A, #F0A832)',
                    border: 'none', borderRadius: 999,
                    color: '#0C0916', cursor: 'pointer',
                    fontFamily: 'var(--ij-font-body)', fontSize: '0.88rem', fontWeight: 700,
                    padding: '10px 22px', minHeight: 42,
                  }}>Find your voice →</button>
                </Link>
                <Link href="/auth/login" style={{ textDecoration: 'none' }}>
                  <button style={{
                    background: 'transparent',
                    border: '1px solid rgba(245,240,232,0.25)',
                    borderRadius: 999, color: '#F2EEE8', cursor: 'pointer',
                    fontFamily: 'var(--ij-font-body)', fontSize: '0.88rem', fontWeight: 500,
                    padding: '10px 22px', minHeight: 42,
                  }}>Sign in</button>
                </Link>
              </div>
            </div>
            <div style={{
              display: 'flex', flexDirection: 'column', gap: 8,
              flexShrink: 0, position: 'relative', zIndex: 1,
            }} className="guest-hero-pills">
              {[
                { icon: '📖', label: 'Read faith essays' },
                { icon: '🙏', label: 'Join prayer chains' },
                { icon: '✨', label: 'Watch faith Sparks' },
                { icon: '🎟️', label: 'Discover events' },
              ].map(item => (
                <div key={item.label} style={{
                  display: 'flex', alignItems: 'center', gap: 8,
                  background: 'rgba(255,255,255,0.06)',
                  borderRadius: 999, padding: '7px 14px',
                  whiteSpace: 'nowrap',
                }}>
                  <span style={{ fontSize: 14 }}>{item.icon}</span>
                  <span style={{
                    fontFamily: 'var(--ij-font-body)', fontSize: '0.78rem',
                    color: 'rgba(245,240,232,0.75)',
                  }}>{item.label}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Daily verse card — above tabs */}
        <div className="ij-card-featured" style={{ marginBottom: 20, padding: '24px 20px', position: 'relative', overflow: 'hidden' }}>
          {/* Decorative large quote mark */}
          <span style={{
            position: 'absolute', top: -16, left: 10,
            fontFamily: 'var(--ij-font-display)', fontSize: 120, lineHeight: 1,
            color: 'rgba(240,168,50,0.07)', pointerEvents: 'none', userSelect: 'none',
          }}>"</span>
          <div style={{ fontSize: '0.65rem', fontWeight: 700, color: 'var(--ij-gold-muted)', letterSpacing: '0.12em', textTransform: 'uppercase', marginBottom: 10, position: 'relative' }}>
            Today's Verse
          </div>
          <p style={{
            fontFamily: 'var(--ij-font-display)', fontSize: 'clamp(1.05rem, 2.5vw, 1.2rem)', fontStyle: 'italic',
            fontWeight: 600, color: 'var(--ij-text-primary)', lineHeight: 1.65, marginBottom: 10, position: 'relative',
          }}>
            {dailyVerse.text}
          </p>
          <p style={{ fontSize: '0.75rem', fontWeight: 500, color: 'var(--ij-gold)', letterSpacing: '0.05em', textTransform: 'uppercase' }}>
            — {dailyVerse.ref}
          </p>
        </div>

        {/* Feed tabs */}
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: '24px', borderBottom: '1px solid var(--border)' }}>
          <div
            className="hide-scrollbar"
            style={{ display: 'flex', gap: '4px', flex: 1, overflowX: 'auto', WebkitOverflowScrolling: 'touch' as any, scrollbarWidth: 'none' as any }}
          >
            {FEED_TABS.map(tab => {
              const active = activeTab === tab.label
              return (
                <button
                  key={tab.label}
                  onClick={() => handleTabChange(tab.label)}
                  style={{
                    padding: '9px 16px 10px', border: 'none',
                    background: 'transparent', cursor: 'pointer',
                    fontFamily: 'var(--ij-font-body)', flexShrink: 0,
                    fontSize: '14px', fontWeight: active ? 600 : 400,
                    color: active ? 'var(--ij-text)' : 'var(--ij-muted)',
                    borderBottom: `2px solid ${active ? 'var(--ij-gold)' : 'transparent'}`,
                    marginBottom: '-1px',
                    transition: 'color 0.15s, border-color 0.15s',
                  }}
                >
                  {tab.label}
                </button>
              )
            })}
          </div>
          <Link
            href="/notifications"
            onClick={() => { localStorage.setItem('notif_last_seen', new Date().toISOString()); setHasUnread(false) }}
            style={{
              flexShrink: 0, marginLeft: '8px', marginBottom: '-1px',
              padding: '6px 8px', display: 'flex', alignItems: 'center',
              textDecoration: 'none', color: hasUnread ? 'var(--ij-gold)' : 'var(--ij-muted)',
              borderBottom: '2px solid transparent', position: 'relative',
            }}
            title="Notifications"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
              stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
              <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
            </svg>
            {hasUnread && (
              <span style={{
                position: 'absolute', top: '4px', right: '4px',
                width: '8px', height: '8px', borderRadius: '50%',
                background: '#C0392B', border: '1.5px solid var(--warm-white)',
              }} />
            )}
          </Link>
        </div>

        {/* New posts banner */}
        {newPostsQueue.length > 0 && (
          <button
            onClick={() => {
              setPosts(prev => [...newPostsQueue, ...prev])
              setNewPostsQueue([])
              window.scrollTo({ top: 0, behavior: 'smooth' })
            }}
            style={{
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px',
              width: '100%', padding: '12px', borderRadius: '12px',
              background: 'var(--ij-gold)', color: '#FAF9F7', border: 'none',
              cursor: 'pointer', fontSize: '14px', fontWeight: 600,
              fontFamily: 'var(--ij-font-body)', marginBottom: '12px',
              boxShadow: '0 4px 16px rgba(201,134,10,0.25)',
            }}
          >
            ↑ {newPostsQueue.length} new {newPostsQueue.length === 1 ? 'voice' : 'voices'} — tap to load
          </button>
        )}

        {/* Follow hint — show for logged-in users with 0 follows */}
        {currentUserId && !hintDismissed && (
          <div style={{
            background: 'var(--ij-gold-bg)',
            border: '1px solid var(--ij-border-gold)',
            borderRadius: 10, padding: '10px 14px', marginBottom: 16,
            display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12,
          }}>
            <p style={{ fontFamily: 'var(--ij-font-body)', fontSize: '0.82rem', color: 'var(--ij-text-secondary)', margin: 0 }}>
              Follow voices you love to personalize your feed
            </p>
            <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
              <Link href="/explore">
                <button style={{
                  background: 'var(--ij-gold)', border: 'none', borderRadius: 999,
                  color: '#fff', cursor: 'pointer', fontFamily: 'var(--ij-font-body)',
                  fontSize: '0.75rem', fontWeight: 600, padding: '5px 12px',
                }}>Discover voices</button>
              </Link>
              <button
                onClick={() => { setHintDismissed(true); localStorage.setItem('ijwi_follow_hint_dismissed', 'true') }}
                style={{ background: 'transparent', border: 'none', color: 'var(--ij-text-secondary)', cursor: 'pointer', fontSize: '0.75rem', fontFamily: 'var(--ij-font-body)' }}>✕</button>
            </div>
          </div>
        )}

        {/* Empty state */}
        {filteredPosts.length === 0 && (() => {
          const tab = FEED_TABS.find(t => t.label === activeTab)
          if (tab?.followersOnly && !followsLoaded) {
            return (
              <div style={{ textAlign: 'center', padding: '80px 20px', color: 'var(--ij-muted)', fontSize: '14px' }}>
                Loading voices...
              </div>
            )
          }
          if (tab?.followersOnly) {
            return (
              <div style={{ textAlign: 'center', padding: '80px 20px' }}>
                <div style={{ fontSize: '52px', marginBottom: '16px' }}>🎧</div>
                <p style={{ fontFamily: 'var(--ij-font-display)', fontSize: '22px', marginBottom: '8px', color: 'var(--ij-text)' }}>
                  No voices yet
                </p>
                <p style={{ fontSize: '14px', color: 'var(--ij-muted)', marginBottom: '24px' }}>
                  Start listening to voices and their posts will appear here.
                </p>
                <Link href="/explore" style={{
                  display: 'inline-block', padding: '12px 28px', borderRadius: '100px',
                  background: 'var(--ij-gold)', color: '#0C0916', textDecoration: 'none',
                  fontSize: '14px', fontWeight: 600, fontFamily: 'var(--ij-font-body)'
                }}>
                  Find voices →
                </Link>
              </div>
            )
          }
          if (tab?.types?.includes('question')) {
            return (
              <div style={{ textAlign: 'center', padding: '80px 20px' }}>
                <div style={{ fontSize: '52px', marginBottom: '16px' }}>💭</div>
                <p style={{ fontFamily: 'var(--ij-font-display)', fontSize: '22px', marginBottom: '8px', color: 'var(--ij-text)' }}>
                  No questions yet
                </p>
                <p style={{ fontSize: '14px', color: 'var(--ij-muted)', marginBottom: '24px' }}>
                  Be the first to ask the community something.
                </p>
                {currentUserId && (
                  <button
                    onClick={() => { setComposeType('question'); setShowComposer(true) }}
                    style={{
                      padding: '12px 28px', borderRadius: '100px',
                      background: 'var(--ij-gold)', color: '#0C0916', border: 'none',
                      fontSize: '14px', fontWeight: 600, cursor: 'pointer',
                      fontFamily: 'var(--ij-font-body)'
                    }}
                  >
                    Ask a question →
                  </button>
                )}
              </div>
            )
          }
          return (
            <div style={{ textAlign: 'center', padding: '80px 20px' }}>
              <div style={{ fontSize: '52px', marginBottom: '16px' }}>✨</div>
              <p style={{ fontFamily: 'var(--ij-font-display)', fontSize: '22px', marginBottom: '8px', color: 'var(--ij-text)' }}>
                {(profile?.is_approved_poster || isAdmin) ? 'Be the first voice here' : 'Content coming soon'}
              </p>
              <p style={{ fontSize: '14px', color: 'var(--ij-muted)', marginBottom: '24px' }}>
                {(profile?.is_approved_poster || isAdmin)
                  ? 'This space is waiting for someone like you.'
                  : 'Voices are being curated for this feed. Check back soon.'}
              </p>
              {currentUserId && (profile?.is_approved_poster || isAdmin) && (
                <button
                  onClick={() => setShowComposer(true)}
                  style={{
                    padding: '12px 28px', borderRadius: '100px',
                    background: 'var(--ij-gold)', color: '#0C0916', border: 'none',
                    fontSize: '14px', fontWeight: 600, cursor: 'pointer',
                    fontFamily: 'var(--ij-font-body)'
                  }}
                >
                  Share your voice →
                </button>
              )}
            </div>
          )
        })()}

        {/* Posts */}
        <AnimatePresence initial={false}>
          {filteredPosts.map((post, i) => (
            <motion.div
              key={post.id}
              initial={{ opacity: 0, y: 28 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.97 }}
              transition={{ type: 'spring', stiffness: 340, damping: 30, delay: Math.min(i * 0.045, 0.35) }}
            >
              <PostCard
                post={post}
                currentUserId={currentUserId}
                userReactions={(userReactionMap[post.id] ?? []) as any}
                isPro={isPro}
              />
            </motion.div>
          ))}
        </AnimatePresence>

        <div ref={loaderRef} style={{ height: '1px' }} />
        {loadingMore && (
          <div style={{ textAlign: 'center', padding: '24px', color: 'var(--ij-muted)', fontSize: '14px' }}>
            Loading more voices...
          </div>
        )}
        {!hasMore && filteredPosts.length > 0 && (
          <div style={{ textAlign: 'center', padding: '32px', color: 'var(--ij-muted)', fontSize: '13px', fontFamily: 'var(--ij-font-display)', fontStyle: 'italic' }}>
            You've heard every voice today — glory to God.
          </div>
        )}
      </main>

      {/* Right sidebar — hidden on mobile/tablet */}
      <aside className="right-sidebar" style={{
        width: '300px', flexShrink: 0, padding: '28px 20px',
        display: 'flex', flexDirection: 'column', gap: '16px'
      }}>
        {/* Your voice card */}
        {profile && (
          <div className="ij-card" style={{ padding: '20px' }}>
            <div className="ij-section-label" style={{ marginBottom: 12 }}>Your voice</div>
            <Link href={`/profile/${profile.id}`} style={{ textDecoration: 'none', display: 'block' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '14px' }}>
                <ProfileAvatar
                  userId={profile.id}
                  avatarUrl={profile.avatar_url}
                  isRevealed={profile.is_revealed}
                  size={42}
                  voiceName={profile.voice_name}
                />
                <div>
                  <div style={{ fontSize: '15px', fontWeight: 600, color: 'var(--ij-text)', fontFamily: 'var(--ij-font-display)' }}>
                    {profile.voice_name}
                  </div>
                  <div style={{ fontSize: '12px', color: 'var(--ij-muted)', textTransform: 'capitalize' }}>
                    {profile.voice_role?.replace(/_/g, ' ') ?? 'voice'}
                    {profile.is_pro && (
                      <span style={{
                        marginLeft: '6px', padding: '1px 6px', borderRadius: '100px',
                        background: 'var(--ij-gold)', color: 'var(--ij-bg-base)',
                        fontSize: '9px', fontWeight: 700
                      }}>PRO</span>
                    )}
                  </div>
                </div>
              </div>
            </Link>
          </div>
        )}

        {/* Guest sidebar: join card + up next */}
        {!profile && (
          <>
            <div className="ij-card" style={{ textAlign: 'center', padding: '24px' }}>
              <div style={{
                width: 44, height: 44, borderRadius: 12,
                background: 'var(--ij-bg-elevated)',
                border: '1px solid var(--ij-border-gold)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                margin: '0 auto 14px',
              }}>
                <IjwiLogo size={26} gradient />
              </div>
              <h3 style={{
                fontFamily: 'var(--ij-font-display)', fontSize: '1.1rem', fontWeight: 700,
                color: 'var(--ij-text-primary)', margin: '0 0 6px',
              }}>Join the community</h3>
              <p style={{
                fontFamily: 'var(--ij-font-body)', fontSize: '0.82rem',
                color: 'var(--ij-text-secondary)', lineHeight: 1.5, margin: '0 0 16px',
              }}>
                Share your faith, pray with others, and be heard.
              </p>
              <Link href="/auth/signup" style={{ display: 'block', marginBottom: 8, textDecoration: 'none' }}>
                <button className="ij-btn-primary" style={{ width: '100%' }}>Find your voice</button>
              </Link>
              <Link href="/auth/login" style={{ display: 'block', textDecoration: 'none' }}>
                <button className="ij-btn-secondary" style={{ width: '100%' }}>Sign in</button>
              </Link>
            </div>

            {upNextPosts.length > 0 && (
              <div className="ij-card" style={{ padding: '20px' }}>
                <div className="ij-section-label" style={{ marginBottom: 12 }}>Up next</div>
                {upNextPosts.map(post => (
                  <Link key={post.id} href={`/post/${post.id}`} style={{ textDecoration: 'none', display: 'block' }}>
                    <div style={{
                      display: 'flex', gap: 10, alignItems: 'flex-start',
                      padding: '10px 0', borderBottom: '1px solid var(--ij-border)',
                    }}>
                      <div style={{ flex: 1 }}>
                        <p style={{
                          fontFamily: 'var(--ij-font-display)', fontSize: '0.88rem', fontWeight: 600,
                          color: 'var(--ij-text-primary)', lineHeight: 1.3, margin: '0 0 3px',
                        }}>{post.title || 'Untitled essay'}</p>
                        <p style={{
                          fontFamily: 'var(--ij-font-body)', fontSize: '0.72rem',
                          color: 'var(--ij-text-secondary)', margin: 0,
                        }}>{post.read_time || 2} min read</p>
                      </div>
                      <span style={{ color: 'var(--ij-text-secondary)', fontSize: 16, flexShrink: 0 }}>🔖</span>
                    </div>
                  </Link>
                ))}
              </div>
            )}
          </>
        )}

        {/* Prayer preview */}
        {prayerPosts.length > 0 && (
          <div style={{
            background: 'var(--ij-surface)', border: '1px solid var(--ij-border-prayer)',
            borderRadius: 14, padding: '16px 16px 0', overflow: 'hidden', position: 'relative',
          }}>
            <div className="ij-section-label" style={{ marginBottom: 12 }}>Prayer Wall</div>
            {prayerPosts.map((p, i) => (
              <Link key={p.id} href={`/post/${p.id}`} style={{ display: 'flex', alignItems: 'flex-start', gap: 8, marginBottom: 14, textDecoration: 'none' }}>
                <ProfileAvatar userId={p.author_id} size={28} voiceName={p.author_name} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: '12px', color: 'var(--ij-text-primary)', lineHeight: 1.45, overflow: 'hidden', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' as const }}>
                    {p.body}
                  </div>
                  <div style={{ fontSize: '10px', color: 'var(--ij-prayer)', marginTop: 2 }}>
                    🙏 {p.prayer_count} praying
                  </div>
                </div>
              </Link>
            ))}
            {/* Fade overlay with CTA */}
            <div style={{
              position: 'relative', height: 48, marginTop: -24,
              background: 'linear-gradient(to bottom, transparent, var(--ij-surface))',
              display: 'flex', alignItems: 'flex-end', paddingBottom: 12, justifyContent: 'center',
            }}>
              {!profile ? (
                <Link href="/auth/signup" style={{ fontSize: '12px', fontFamily: 'var(--ij-font-display)', fontStyle: 'italic', color: 'var(--ij-gold)', textDecoration: 'none' }}>
                  Pray with them → Join Ijwi
                </Link>
              ) : (
                <Link href="/feed?tab=For+You" style={{ fontSize: '12px', color: 'var(--ij-prayer)', textDecoration: 'none', fontFamily: 'var(--ij-font-body)' }}>
                  See all prayers →
                </Link>
              )}
            </div>
          </div>
        )}

        {/* Most Anointed */}
        {trending.length > 0 && (
          <div className="ij-card" style={{ padding: '20px' }}>
            <div className="ij-section-label" style={{ marginBottom: 14 }}>Most Anointed</div>
            {trending.map((p, i) => (
              <Link
                key={p.id}
                href={`/post/${p.id}`}
                style={{ display: 'block', textDecoration: 'none', marginBottom: i < trending.length - 1 ? '14px' : 0 }}
              >
                <div style={{ display: 'flex', gap: '10px', alignItems: 'flex-start' }}>
                  <span style={{
                    fontSize: '11px', fontWeight: 700, color: 'var(--ij-gold)',
                    minWidth: '18px', paddingTop: '2px', flexShrink: 0
                  }}>
                    {i + 1}
                  </span>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{
                      fontSize: '13px', fontWeight: 500, color: 'var(--ij-text)',
                      overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                      marginBottom: '2px'
                    }}>
                      {p.title || p.body.slice(0, 55) + (p.body.length > 55 ? '…' : '')}
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--ij-muted)' }}>
                      {p.author_name} · 🔥 {p.fire}
                    </div>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}

        {/* Voices to follow */}
        {suggestions.length > 0 && (
          <div className="ij-card" style={{ padding: '20px' }}>
            <div className="ij-section-label" style={{ marginBottom: 14 }}>
              {currentUserId ? 'Voices to follow' : 'Active voices'}
            </div>
            {suggestions.map(user => {
              const alreadyFollowed = followedIds.includes(user.id)
              return (
                <div key={user.id} style={{
                  display: 'flex', alignItems: 'center', gap: '10px',
                  marginBottom: '14px', justifyContent: 'space-between'
                }}>
                  <Link href={`/profile/${user.id}`} style={{ display: 'flex', alignItems: 'center', gap: '9px', textDecoration: 'none', flex: 1, minWidth: 0 }}>
                    <ProfileAvatar userId={user.id} size={32} voiceName={user.voice_name} />
                    <div style={{ minWidth: 0 }}>
                      <div style={{
                        fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-primary)',
                        overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap'
                      }}>
                        {user.voice_name}
                      </div>
                      {user.voice_role && user.voice_role !== 'voice' && (
                        <div style={{ fontSize: '11px', color: 'var(--ij-text-secondary)', textTransform: 'capitalize' }}>
                          {user.voice_role.replace(/_/g, ' ')}
                        </div>
                      )}
                    </div>
                  </Link>
                  {currentUserId && user.id !== currentUserId && (
                    alreadyFollowed ? (
                      <span style={{ fontSize: '11px', color: 'var(--ij-muted)', fontStyle: 'italic' }}>Listening ✓</span>
                    ) : (
                      <button
                        onClick={() => handleFollow(user.id)}
                        style={{
                          padding: '5px 13px', borderRadius: '100px', fontSize: '12px',
                          border: '1px solid var(--ij-gold)', background: 'transparent',
                          color: 'var(--ij-gold)', cursor: 'pointer', flexShrink: 0,
                          fontFamily: 'var(--ij-font-body)', fontWeight: 500
                        }}
                      >
                        Listen
                      </button>
                    )
                  )}
                </div>
              )
            })}
            <Link href="/explore" style={{
              display: 'block', textAlign: 'center', fontSize: '13px',
              color: 'var(--ij-gold)', textDecoration: 'none', marginTop: '4px',
              fontWeight: 500
            }}>
              Explore more →
            </Link>
          </div>
        )}
      </aside>

      {/* Story viewer */}
      {storyViewerIdx !== null && storyPosts.length > 0 && (
        <StoryViewer
          stories={storyPosts}
          startIndex={storyViewerIdx}
          currentUserId={currentUserId}
          onClose={() => setStoryViewerIdx(null)}
        />
      )}

      {/* Composer modal */}
      {showComposer && (
        <div
          onClick={(e) => e.target === e.currentTarget && setShowComposer(false)}
          style={{
            position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            zIndex: 200, padding: '16px', backdropFilter: 'blur(8px)',
            overflowY: 'auto',
          }}
        >
          <PostComposer
            onClose={() => setShowComposer(false)}
            onPost={handlePostCreated}
            initialType={composeType}
          />
        </div>
      )}

      {/* Compose type picker — animated bottom sheet */}
      <AnimatePresence>
      {showPicker && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={() => setShowPicker(false)}
          style={{
            position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.65)',
            zIndex: 200, display: 'flex', alignItems: 'flex-end',
            backdropFilter: 'blur(8px)',
          }}
        >
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', stiffness: 380, damping: 38 }}
            onClick={e => e.stopPropagation()}
            style={{
              background: 'var(--ij-bg-surface)',
              width: '100%', maxWidth: '540px',
              margin: '0 auto', borderRadius: '28px 28px 0 0',
              padding: '0 0 env(safe-area-inset-bottom)',
              border: '1px solid var(--ij-border-gold)',
              borderBottom: 'none',
              boxShadow: '0 -8px 48px rgba(0,0,0,0.4)',
            }}
          >
            {/* Drag handle */}
            <div style={{ paddingTop: 12, paddingBottom: 4, display: 'flex', justifyContent: 'center' }}>
              <div style={{ width: 44, height: 4, background: 'var(--ij-border-gold)', borderRadius: 2 }} />
            </div>

            {/* Header */}
            <div style={{ padding: '16px 24px 12px', borderBottom: '1px solid var(--ij-border)' }}>
              <p style={{
                fontFamily: 'var(--ij-font-display)', fontSize: '1.3rem', fontWeight: 700,
                color: 'var(--ij-text-primary)', letterSpacing: '0.01em',
              }}>
                {(profile?.is_approved_poster || isAdmin) ? 'What will you share?' : 'Ask the community'}
              </p>
              <p style={{ fontSize: '12px', color: 'var(--ij-text-secondary)', marginTop: 3 }}>
                {(profile?.is_approved_poster || isAdmin) ? 'Your voice matters — choose your format' : 'Ask anything — voices are here to help'}
              </p>
            </div>

            {/* Compose options — approved posters get full menu, others get question only */}
            <div style={{ padding: '16px 20px 0' }}>
              {(profile?.is_approved_poster || isAdmin) ? (
                <>
                  <Link
                    href="/write"
                    onClick={() => setShowPicker(false)}
                    style={{
                      display: 'flex', alignItems: 'center', gap: 16,
                      padding: '16px 18px', borderRadius: 18,
                      background: 'linear-gradient(135deg, var(--ij-gold-bg), rgba(242,172,58,0.04))',
                      border: '1px solid var(--ij-border-gold)',
                      textDecoration: 'none', marginBottom: 12,
                    }}
                  >
                    <div style={{
                      width: 48, height: 48, borderRadius: 14, flexShrink: 0,
                      background: 'linear-gradient(135deg, #C9860A, #F2AC3A)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      fontSize: '22px',
                    }}>
                      ✍️
                    </div>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: '15px', fontWeight: 700, color: 'var(--ij-text-primary)', marginBottom: 2 }}>Write an Essay</div>
                      <div style={{ fontSize: '12px', color: 'var(--ij-text-secondary)', lineHeight: 1.4 }}>Testimonies, devotionals, long-form faith writing</div>
                    </div>
                    <span style={{ fontSize: 18, color: 'var(--ij-gold)' }}>→</span>
                  </Link>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, paddingBottom: 24 }}>
                    {([
                      { type: 'story' as const, icon: '📸', label: 'Photo', desc: 'Image + caption', color: 'rgba(52,199,89,0.12)', border: 'rgba(52,199,89,0.25)' },
                      { type: 'question' as const, icon: '💭', label: 'Question', desc: 'Ask the community', color: 'rgba(139,120,240,0.12)', border: 'rgba(139,120,240,0.25)' },
                      { type: 'spoken_word' as const, icon: '🎙️', label: 'Spoken Word', desc: 'Record your voice', color: 'rgba(255,59,48,0.10)', border: 'rgba(255,59,48,0.25)' },
                      { href: '/sparks', icon: '⚡', label: 'Spark', desc: 'Short faith video', color: 'rgba(255,149,0,0.12)', border: 'rgba(255,149,0,0.25)' },
                    ] as const).map((item) => {
                      const commonStyle: React.CSSProperties = {
                        display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 10,
                        padding: '14px', borderRadius: 16,
                        border: `1px solid ${'border' in item ? item.border : 'var(--ij-border)'}`,
                        background: 'color' in item ? item.color : 'transparent',
                        cursor: 'pointer', textAlign: 'left',
                        fontFamily: 'var(--ij-font-body)',
                        textDecoration: 'none',
                      }
                      const inner = (
                        <>
                          <div style={{ fontSize: '24px', lineHeight: 1 }}>{item.icon}</div>
                          <div>
                            <div style={{ fontSize: '13px', fontWeight: 700, color: 'var(--ij-text-primary)', marginBottom: 2 }}>{item.label}</div>
                            <div style={{ fontSize: '11px', color: 'var(--ij-text-secondary)', lineHeight: 1.3 }}>{item.desc}</div>
                          </div>
                        </>
                      )
                      if ('href' in item) {
                        return (
                          <Link key={item.label} href={item.href} onClick={() => setShowPicker(false)} style={commonStyle}>
                            {inner}
                          </Link>
                        )
                      }
                      return (
                        <button key={item.type} onClick={() => { setComposeType(item.type); setShowPicker(false); setShowComposer(true) }} style={commonStyle}>
                          {inner}
                        </button>
                      )
                    })}
                  </div>
                </>
              ) : (
                <div style={{ paddingBottom: 24 }}>
                  <button
                    onClick={() => { setComposeType('question'); setShowPicker(false); setShowComposer(true) }}
                    style={{
                      display: 'flex', alignItems: 'center', gap: 16,
                      padding: '16px 18px', borderRadius: 18, width: '100%',
                      background: 'rgba(139,120,240,0.08)',
                      border: '1px solid rgba(139,120,240,0.30)',
                      cursor: 'pointer', textAlign: 'left',
                      fontFamily: 'var(--ij-font-body)',
                    }}
                  >
                    <div style={{
                      width: 48, height: 48, borderRadius: 14, flexShrink: 0,
                      background: 'rgba(139,120,240,0.20)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      fontSize: '22px',
                    }}>
                      💬
                    </div>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: '15px', fontWeight: 700, color: 'var(--ij-text-primary)', marginBottom: 2 }}>Ask a question</div>
                      <div style={{ fontSize: '12px', color: 'var(--ij-text-secondary)', lineHeight: 1.4 }}>Ask a voice in the community</div>
                    </div>
                    <span style={{ fontSize: 18, color: 'var(--ij-text-secondary)' }}>→</span>
                  </button>
                </div>
              )}
            </div>
          </motion.div>
        </motion.div>
      )}
      </AnimatePresence>
    </div>
  )
}
