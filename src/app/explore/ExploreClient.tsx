'use client'

import { useState, useEffect, useRef } from 'react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { Post } from '@/lib/types'
import ProfileAvatar from '@/components/ui/ProfileAvatar'
import { CONTENT_TYPE_LABELS } from '@/lib/utils'

const TAGS = ['faith', 'testimony', 'healing', 'prayer', 'devotional', 'africa', 'youth', 'hope', 'grace', 'worship', 'scripture', 'revival', 'mercy', 'salvation']

interface ExploreClientProps {
  initialPosts: Post[]
  currentUserId?: string
}

interface UserResult {
  id: string
  voice_name: string
  real_name: string | null
  avatar_url: string | null
  is_revealed: boolean
  level: string
}

export default function ExploreClient({ initialPosts, currentUserId }: ExploreClientProps) {
  const [query, setQuery] = useState('')
  const [userResults, setUserResults] = useState<UserResult[]>([])
  const [postResults, setPostResults] = useState<Post[]>([])
  const [searching, setSearching] = useState(false)
  const supabase = createClient()

  useEffect(() => {
    if (!query.trim()) {
      setUserResults([])
      setPostResults([])
      setSearching(false)
      return
    }

    setSearching(true)
    const timer = setTimeout(async () => {
      const [usersResp, postsResp] = await Promise.all([
        supabase
          .from('profiles')
          .select('id, voice_name, real_name, avatar_url, is_revealed, level')
          .ilike('voice_name', `%${query}%`)
          .not('voice_name', 'ilike', 'deleted-%')
          .limit(8),
        supabase
          .from('posts')
          .select(`*, author:profiles(id, voice_name, is_revealed, real_name, avatar_url, level, xp)`)
          .or(`title.ilike.%${query}%,body.ilike.%${query}%`)
          .order('created_at', { ascending: false })
          .limit(12),
      ])

      setUserResults(usersResp.data ?? [])
      const mapped = (postsResp.data ?? []).map((p: any) => ({
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
      setPostResults(mapped)
      setSearching(false)
    }, 380)

    return () => clearTimeout(timer)
  }, [query])

  const isSearching = query.trim().length > 0

  return (
    <div>
      {/* Search bar — sticky */}
      <div style={{
        position: 'sticky', top: 0, zIndex: 20,
        background: 'var(--warm-white)', paddingBottom: '16px', paddingTop: '4px',
      }}>
        <div style={{ position: 'relative' }}>
          <span style={{
            position: 'absolute', left: '16px', top: '50%',
            transform: 'translateY(-50%)', fontSize: '16px', pointerEvents: 'none',
            color: 'var(--text-muted)',
          }}>
            🔍
          </span>
          <input
            type="text"
            placeholder="Search people, topics, posts..."
            value={query}
            onChange={e => setQuery(e.target.value)}
            style={{
              width: '100%', padding: '14px 44px', borderRadius: '100px',
              border: '1.5px solid var(--border)', background: 'var(--surface)',
              fontSize: '15px', fontFamily: 'var(--font-body)', color: 'var(--text-primary)',
              outline: 'none', boxSizing: 'border-box',
              boxShadow: '0 1px 4px rgba(0,0,0,0.04)',
            }}
          />
          {query && (
            <button
              onClick={() => setQuery('')}
              style={{
                position: 'absolute', right: '10px', top: '50%',
                transform: 'translateY(-50%)', background: 'var(--surface-2)',
                border: 'none', cursor: 'pointer', fontSize: '15px',
                color: 'var(--text-muted)', width: '36px', height: '36px',
                borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}
            >
              ×
            </button>
          )}
        </div>
      </div>

      {/* ── SEARCH RESULTS ── */}
      {isSearching ? (
        <div>
          {searching && (
            <div style={{ textAlign: 'center', padding: '24px', color: 'var(--text-muted)', fontSize: '14px' }}>
              Searching...
            </div>
          )}

          {/* People results */}
          {userResults.length > 0 && (
            <div style={{ marginBottom: '28px' }}>
              <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '14px' }}>
                People
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0' }}>
                {userResults.map(user => (
                  <Link
                    key={user.id}
                    href={`/profile/${user.id}`}
                    style={{
                      display: 'flex', alignItems: 'center', gap: '14px',
                      padding: '12px 0', textDecoration: 'none',
                      borderBottom: '1px solid var(--border)',
                    }}
                  >
                    <ProfileAvatar
                      userId={user.id}
                      avatarUrl={user.avatar_url ?? undefined}
                      isRevealed={user.is_revealed}
                      size={48}
                    />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{
                        fontSize: '15px', fontWeight: 600, color: 'var(--text-primary)',
                        fontFamily: 'var(--font-display)',
                      }}>
                        {user.voice_name}
                      </div>
                      {user.is_revealed && user.real_name && (
                        <div style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>{user.real_name}</div>
                      )}
                      <div style={{ fontSize: '12px', color: 'var(--text-muted)', textTransform: 'capitalize' }}>{user.level}</div>
                    </div>
                    <span style={{ fontSize: '14px', color: 'var(--text-muted)' }}>›</span>
                  </Link>
                ))}
              </div>
            </div>
          )}

          {/* Post results */}
          {postResults.length > 0 && (
            <div>
              <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '14px' }}>
                Posts
              </div>
              <div className="explore-post-grid">
                {postResults.map(post => (
                  <PostGridCard key={post.id} post={post} />
                ))}
              </div>
            </div>
          )}

          {!searching && userResults.length === 0 && postResults.length === 0 && (
            <div style={{ textAlign: 'center', padding: '60px 20px' }}>
              <div style={{ fontSize: '44px', marginBottom: '14px' }}>🔍</div>
              <p style={{ fontFamily: 'var(--font-display)', fontSize: '20px', color: 'var(--text-secondary)', marginBottom: '6px' }}>
                No results for &ldquo;{query}&rdquo;
              </p>
              <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>Try a different name or topic</p>
            </div>
          )}
        </div>
      ) : (
        /* ── BROWSE (not searching) ── */
        <div className="explore-desktop-grid">
          {/* Left column: topics + type tiles + post grid */}
          <div>
            {/* Tags */}
            <div style={{ marginBottom: '28px' }}>
              <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '14px' }}>
                Browse topics
              </div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
                {TAGS.map(tag => (
                  <Link key={tag} href={`/explore/tag/${tag}`} className="tag-link">
                    #{tag}
                  </Link>
                ))}
              </div>
            </div>

            {/* Content type tiles */}
            <div style={{ marginBottom: '28px' }}>
              <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '14px' }}>
                Browse by type
              </div>
              <div className="explore-type-grid">
                {[
                  { href: '/feed?tab=For+You', icon: '📖', label: 'Stories' },
                  { href: '/feed?tab=For+You', icon: '📖', label: 'Devotionals' },
                  { href: '/feed?tab=Voices',  icon: '🎙️', label: 'Spoken Word' },
                  { href: '/feed?tab=Questions', icon: '💭', label: 'Questions' },
                  { href: '/feed?tab=For+You', icon: '🙏', label: 'Prayer Wall' },
                  { href: '/sparks',           icon: '✨', label: 'Sparks' },
                ].map(({ href, icon, label }) => (
                  <Link
                    key={label}
                    href={href}
                    style={{
                      display: 'flex', flexDirection: 'column', alignItems: 'center',
                      padding: '18px 8px', borderRadius: '16px',
                      background: 'var(--surface)', border: '1px solid var(--border)',
                      textDecoration: 'none', gap: '8px', transition: 'border-color 0.15s',
                    }}
                  >
                    <span style={{ fontSize: '26px' }}>{icon}</span>
                    <span style={{ fontSize: '12px', fontWeight: 500, color: 'var(--text-primary)', textAlign: 'center', lineHeight: 1.2 }}>{label}</span>
                  </Link>
                ))}
              </div>
            </div>

            {/* Post grid — 2 columns */}
            <div>
              <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '14px' }}>
                Most anointed this week
              </div>
              <div className="explore-post-grid">
                {initialPosts.map((post, i) => (
                  <PostGridCard key={post.id} post={post} featured={i === 0} />
                ))}
              </div>
            </div>
          </div>

          {/* Right column: community links (sticky on desktop) */}
          <div style={{ position: 'sticky', top: 80 }}>
            <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: '16px', padding: '20px', marginBottom: '16px' }}>
              <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '16px' }}>
                Quick links
              </div>
              {[
                { href: '/feed', label: '🏠 Your feed' },
                { href: '/dms', label: '💬 Messages' },
                { href: '/sparks', label: '✨ Sparks' },
                { href: '/notifications', label: '🔔 Notifications' },
                { href: '/settings', label: '⚙️ Settings' },
              ].map(({ href, label }) => (
                <Link key={href} href={href} style={{ display: 'block', padding: '9px 0', borderBottom: '1px solid var(--border)', textDecoration: 'none', fontSize: '14px', color: 'var(--text-secondary)', fontFamily: 'var(--font-body)' }}>
                  {label}
                </Link>
              ))}
            </div>
            <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: '16px', padding: '20px' }}>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', lineHeight: 1.7, fontFamily: 'var(--font-body)', fontStyle: 'italic' }}>
                "Let everything that has breath praise the Lord." — Psalm 150:6
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

// ── Compact post tile for the grid ───────────────────────────────────────────
function PostGridCard({ post, featured = false }: { post: Post; featured?: boolean }) {
  const isVideo = post.content_type === 'short' && post.video_url
  const label = CONTENT_TYPE_LABELS[post.content_type as keyof typeof CONTENT_TYPE_LABELS] ?? post.content_type
  const videoRef = useRef<HTMLVideoElement>(null)
  const wrapRef = useRef<HTMLDivElement>(null)
  const [playing, setPlaying] = useState(false)

  // Autoplay muted video when scrolled into view
  useEffect(() => {
    if (!isVideo || !wrapRef.current) return
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          videoRef.current?.play().catch(() => {})
          setPlaying(true)
        } else {
          videoRef.current?.pause()
          setPlaying(false)
        }
      },
      { threshold: 0.5 }
    )
    observer.observe(wrapRef.current)
    return () => observer.disconnect()
  }, [isVideo])

  return (
    <Link
      href={isVideo ? '/sparks' : `/post/${post.id}`}
      style={{
        display: 'block', borderRadius: '14px', overflow: 'hidden',
        background: 'var(--surface)', border: '1px solid var(--border)',
        textDecoration: 'none', position: 'relative',
        ...(featured ? { gridColumn: '1 / -1' } : {}),
      }}
    >
      {isVideo ? (
        <div
          ref={wrapRef}
          style={{
            position: 'relative', width: '100%',
            aspectRatio: featured ? '16/9' : '9/16',
            maxHeight: featured ? '220px' : '280px',
            background: '#0a0a0a', overflow: 'hidden',
          }}
        >
          <video
            ref={videoRef}
            src={post.video_url!}
            muted
            loop
            playsInline
            preload="metadata"
            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
          />
          {/* Play icon — shown when paused */}
          {!playing && (
            <div style={{
              position: 'absolute', inset: 0,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              background: 'rgba(0,0,0,0.2)',
            }}>
              <div style={{
                width: '44px', height: '44px', borderRadius: '50%',
                background: 'rgba(255,255,255,0.25)', backdropFilter: 'blur(4px)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <span style={{ color: 'white', fontSize: '18px', marginLeft: '3px' }}>▶</span>
              </div>
            </div>
          )}
          {/* Author + "Tap to watch" overlay */}
          <div style={{
            position: 'absolute', bottom: 0, left: 0, right: 0,
            padding: '28px 10px 10px',
            background: 'linear-gradient(to top, rgba(0,0,0,0.75) 0%, transparent 100%)',
          }}>
            <div style={{ fontSize: '10px', color: 'rgba(255,255,255,0.6)', marginBottom: '2px' }}>
              {post.is_anonymous ? 'Anonymous' : (post.author?.voice_name ?? 'Voice')}
            </div>
            <div style={{ fontSize: '11px', color: 'rgba(255,255,255,0.9)', fontWeight: 600 }}>
              Tap to watch →
            </div>
          </div>
        </div>
      ) : (
        <div style={{ padding: featured ? '18px' : '14px' }}>
          <div style={{
            fontSize: '10px', color: 'var(--flame)', fontWeight: 700,
            textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: '8px',
          }}>
            {label}
          </div>
          <div style={{
            fontSize: featured ? '16px' : '13px',
            fontWeight: featured ? 500 : 400,
            fontFamily: post.content_type === 'letter' || post.content_type === 'spoken_word' ? 'var(--font-display)' : 'var(--font-body)',
            color: 'var(--text-primary)', lineHeight: 1.45,
            overflow: 'hidden', display: '-webkit-box',
            WebkitLineClamp: featured ? 3 : 4,
            WebkitBoxOrient: 'vertical' as const,
            marginBottom: '10px',
          }}>
            {post.title || post.body}
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: '6px',
            fontSize: '11px', color: 'var(--text-muted)',
          }}>
            <ProfileAvatar
              userId={post.author?.id ?? post.author_id}
              avatarUrl={post.author?.avatar_url}
              isRevealed={post.author?.is_revealed && !post.is_anonymous}
              size={18}
            />
            {post.is_anonymous ? 'Anonymous' : (post.author?.voice_name ?? 'Voice')}
            <span style={{ marginLeft: 'auto' }}>✨ {post.reactions?.fire ?? 0}</span>
          </div>
        </div>
      )}
    </Link>
  )
}
