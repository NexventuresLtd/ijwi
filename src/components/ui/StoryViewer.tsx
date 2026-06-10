'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import Link from 'next/link'
import { Post } from '@/lib/types'
import ProfileAvatar from '@/components/ui/ProfileAvatar'
import { createClient } from '@/lib/supabase/client'

interface StoryViewerProps {
  stories: Post[]
  startIndex?: number
  currentUserId?: string
  onClose: () => void
}

const STORY_DURATION = 7000 // 7 seconds per story

export default function StoryViewer({
  stories,
  startIndex = 0,
  currentUserId,
  onClose,
}: StoryViewerProps) {
  const [idx, setIdx] = useState(startIndex)
  const [progress, setProgress] = useState(0)
  const [reacted, setReacted] = useState(false)
  const [viewCount, setViewCount] = useState(0)
  const [viewers, setViewers] = useState<Array<{ id: string; voice_name: string }>>([])
  const [showViewers, setShowViewers] = useState(false)
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const startTimeRef = useRef<number>(Date.now())
  const supabase = createClient()

  const story = stories[idx]
  const isOwn = !!currentUserId && currentUserId === story?.author_id

  // Track view (silently — table may not exist yet)
  useEffect(() => {
    if (!story || !currentUserId || isOwn) return
    supabase
      .from('story_views')
      .upsert({ story_id: story.id, viewer_id: currentUserId }, { onConflict: 'story_id,viewer_id' })
      .then(() => {})
  }, [story?.id]) // eslint-disable-line react-hooks/exhaustive-deps

  // Load view count for own story
  useEffect(() => {
    if (!story || !isOwn) return
    setViewCount(0)
    supabase
      .from('story_views')
      .select('viewer_id', { count: 'exact', head: true })
      .eq('story_id', story.id)
      .then(({ count }) => setViewCount(count ?? 0))
  }, [story?.id, isOwn]) // eslint-disable-line react-hooks/exhaustive-deps

  // Load viewer names (only when panel opened)
  const loadViewers = useCallback(async () => {
    if (!story || !isOwn) return
    const { data } = await supabase
      .from('story_views')
      .select('viewer:profiles(id, voice_name)')
      .eq('story_id', story.id)
    if (data) setViewers(data.map((r: any) => r.viewer))
  }, [story?.id, isOwn]) // eslint-disable-line react-hooks/exhaustive-deps

  // Progress timer — restarts whenever idx changes
  useEffect(() => {
    setProgress(0)
    setShowViewers(false)
    startTimeRef.current = Date.now()

    intervalRef.current = setInterval(() => {
      const elapsed = Date.now() - startTimeRef.current
      const pct = Math.min((elapsed / STORY_DURATION) * 100, 100)
      setProgress(pct)
      if (pct >= 100) {
        clearInterval(intervalRef.current!)
        if (idx < stories.length - 1) {
          setIdx(i => i + 1)
        } else {
          onClose()
        }
      }
    }, 50)

    return () => { if (intervalRef.current) clearInterval(intervalRef.current) }
  }, [idx]) // eslint-disable-line react-hooks/exhaustive-deps

  const goNext = useCallback(() => {
    if (idx < stories.length - 1) setIdx(i => i + 1)
    else onClose()
  }, [idx, stories.length, onClose])

  const goPrev = useCallback(() => {
    if (idx > 0) setIdx(i => i - 1)
    // if first story, do nothing (don't close)
  }, [idx])

  const handleReact = async () => {
    if (!currentUserId || reacted || isOwn) return
    setReacted(true)
    await supabase.from('reactions').insert({
      post_id: story.id,
      user_id: currentUserId,
      reaction_type: 'fire',
    })
  }

  if (!story) return null

  const isVideo = !!(story.video_url && story.content_type === 'short')
  const authorName = story.is_anonymous
    ? 'Anonymous'
    : story.author?.voice_name ?? 'Voice'

  // Dark background for video, warm for text
  const isDark = isVideo
  const textColor = isDark ? 'white' : 'var(--text-primary)'
  const mutedColor = isDark ? 'rgba(255,255,255,0.6)' : 'var(--text-muted)'

  return (
    <div
      style={{
        position: 'fixed', inset: 0, zIndex: 300,
        background: isDark ? '#000' : 'var(--warm-white)',
        display: 'flex', flexDirection: 'column',
        userSelect: 'none',
      }}
    >
      {/* ── Progress bars ────────────────────────────────── */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, zIndex: 10,
        display: 'flex', gap: '3px', padding: '10px 12px 0',
      }}>
        {stories.map((_, i) => (
          <div
            key={i}
            style={{
              flex: 1, height: '2px',
              background: isDark ? 'rgba(255,255,255,0.25)' : 'var(--border)',
              borderRadius: '2px', overflow: 'hidden',
            }}
          >
            <div style={{
              height: '100%',
              background: isDark ? 'white' : 'var(--flame)',
              borderRadius: '2px',
              width: i < idx ? '100%' : i === idx ? `${progress}%` : '0%',
            }} />
          </div>
        ))}
      </div>

      {/* ── Header: avatar + name + close ───────────────── */}
      <div
        style={{
          position: 'absolute', top: '18px', left: 0, right: 0, zIndex: 10,
          display: 'flex', alignItems: 'center', gap: '10px', padding: '8px 14px',
        }}
      >
        {story.author && !story.is_anonymous ? (
          <Link
            href={`/profile/${story.author.id}`}
            style={{ flexShrink: 0, textDecoration: 'none' }}
            onClick={e => e.stopPropagation()}
          >
            <ProfileAvatar
              userId={story.author.id}
              avatarUrl={story.author.avatar_url}
              isRevealed={story.author.is_revealed}
              size={34}
            />
          </Link>
        ) : (
          <ProfileAvatar
            userId={story.author_id}
            avatarUrl={undefined}
            isRevealed={false}
            size={34}
          />
        )}
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: '14px', fontWeight: 600, color: textColor }}>{authorName}</div>
        </div>
        <button
          onClick={onClose}
          style={{
            background: 'none', border: 'none', cursor: 'pointer',
            fontSize: '26px', color: textColor, lineHeight: 1, padding: '4px 8px',
          }}
        >
          ×
        </button>
      </div>

      {/* ── Tap zones: left = prev, right = next ────────── */}
      <div style={{ position: 'absolute', inset: 0, zIndex: 5, display: 'flex' }}>
        <div
          style={{ flex: 1, cursor: 'pointer' }}
          onClick={goPrev}
        />
        <div
          style={{ flex: 1, cursor: 'pointer' }}
          onClick={goNext}
        />
      </div>

      {/* ── Story content ───────────────────────────────── */}
      <div style={{
        flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: '80px 24px 120px',
      }}>
        {isVideo ? (
          <video
            src={story.video_url!}
            autoPlay
            playsInline
            muted
            loop
            style={{
              maxHeight: '100%', maxWidth: '100%',
              borderRadius: '16px', position: 'relative', zIndex: 6,
            }}
            onClick={e => e.stopPropagation()}
          />
        ) : (
          <div
            onClick={e => e.stopPropagation()}
            style={{
              background: 'var(--surface)', borderRadius: '20px',
              padding: '28px 24px', maxWidth: '420px', width: '100%',
              boxShadow: '0 4px 32px rgba(0,0,0,0.1)',
              position: 'relative', zIndex: 6,
            }}
          >
            {story.title && (
              <h2 style={{
                fontFamily: 'var(--font-display)', fontSize: '22px',
                color: 'var(--text-primary)', marginBottom: '14px', lineHeight: 1.35,
              }}>
                {story.title}
              </h2>
            )}
            <p style={{
              fontSize: '15px', color: 'var(--text-secondary)',
              lineHeight: 1.8, whiteSpace: 'pre-wrap',
            }}>
              {story.body.slice(0, 400)}{story.body.length > 400 ? '…' : ''}
            </p>
            {story.body.length > 400 && (
              <Link
                href={`/post/${story.id}`}
                onClick={e => { e.stopPropagation(); onClose() }}
                style={{
                  display: 'inline-block', marginTop: '14px',
                  fontSize: '13px', color: 'var(--flame)',
                  textDecoration: 'none', fontWeight: 600,
                }}
              >
                Read full →
              </Link>
            )}
          </div>
        )}
      </div>

      {/* ── Bottom bar ──────────────────────────────────── */}
      <div
        onClick={e => e.stopPropagation()}
        style={{
          position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 10,
          padding: '12px 20px 44px',
          background: 'linear-gradient(to top, rgba(0,0,0,0.4) 0%, transparent 100%)',
          display: 'flex', alignItems: 'center', gap: '10px',
        }}
      >
        {/* Others: react button */}
        {!isOwn && currentUserId && (
          <button
            onClick={handleReact}
            style={{
              flex: 1, display: 'flex', alignItems: 'center',
              justifyContent: 'center', gap: '8px',
              padding: '10px 18px', borderRadius: '100px',
              background: reacted ? 'rgba(255,107,43,0.25)' : 'rgba(255,255,255,0.15)',
              border: `1.5px solid ${reacted ? 'var(--flame)' : 'rgba(255,255,255,0.4)'}`,
              color: reacted ? 'var(--flame)' : 'white',
              fontSize: '14px', cursor: reacted ? 'default' : 'pointer',
              fontFamily: 'var(--font-body)', fontWeight: 500,
              backdropFilter: 'blur(8px)',
            }}
          >
            {reacted ? '🔥 Touched my heart' : '🔥 This touched my heart'}
          </button>
        )}

        {/* Not logged in: join prompt */}
        {!currentUserId && (
          <Link
            href="/auth/signup"
            onClick={e => e.stopPropagation()}
            style={{
              flex: 1, display: 'flex', alignItems: 'center',
              justifyContent: 'center', padding: '10px',
              borderRadius: '100px', background: 'var(--flame)',
              color: 'white', textDecoration: 'none',
              fontSize: '14px', fontWeight: 600, fontFamily: 'var(--font-body)',
            }}
          >
            Join Ijwi to react →
          </Link>
        )}

        {/* Own story: views button */}
        {isOwn && (
          <button
            onClick={async () => {
              const opening = !showViewers
              setShowViewers(opening)
              if (opening) await loadViewers()
            }}
            style={{
              display: 'flex', alignItems: 'center', gap: '8px',
              padding: '10px 18px', borderRadius: '100px',
              background: 'rgba(255,255,255,0.15)',
              border: '1px solid rgba(255,255,255,0.3)',
              color: 'white', fontSize: '14px', cursor: 'pointer',
              fontFamily: 'var(--font-body)',
              backdropFilter: 'blur(8px)',
            }}
          >
            👁 {viewCount} {viewCount === 1 ? 'view' : 'views'}
          </button>
        )}
      </div>

      {/* ── Viewers panel ───────────────────────────────── */}
      {showViewers && isOwn && (
        <div
          onClick={e => e.stopPropagation()}
          style={{
            position: 'absolute', bottom: '100px', left: '16px', right: '16px',
            zIndex: 20, background: 'var(--surface)', borderRadius: '18px',
            padding: '16px 20px', maxHeight: '220px', overflowY: 'auto',
            boxShadow: '0 8px 40px rgba(0,0,0,0.25)',
          }}
        >
          <div style={{
            fontSize: '11px', fontWeight: 700, color: 'var(--text-muted)',
            textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '12px',
          }}>
            Seen by
          </div>
          {viewers.length === 0 ? (
            <p style={{ fontSize: '14px', color: 'var(--text-muted)' }}>No views yet</p>
          ) : viewers.map(v => (
            <div key={v.id} style={{
              fontSize: '14px', color: 'var(--text-primary)',
              padding: '6px 0', borderBottom: '1px solid var(--border)',
            }}>
              {v.voice_name}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
