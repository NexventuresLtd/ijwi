'use client'

import { useState, useRef, useEffect, useCallback } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { motion, AnimatePresence } from 'framer-motion'
import { Post, ReactionType } from '@/lib/types'
import { timeAgo, CONTENT_TYPE_LABELS, CONTENT_TYPE_COLORS, REACTIONS } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import PaywallOverlay from '@/components/ui/PaywallOverlay'
import ProfileAvatar from '@/components/ui/ProfileAvatar'
import VerificationBadge from '@/components/ui/VerificationBadge'
import ProBadge from '@/components/ui/ProBadge'

interface PostCardProps {
  post: Post
  currentUserId?: string
  userReactions?: ReactionType[]
  isPro?: boolean
  initialPrayerCount?: number
  initialHasPrayed?: boolean
  fullVideo?: boolean
}

const PAYWALL_WORD_THRESHOLD = 600
const FREE_PREVIEW_CHARS = 1200

export default function PostCard({
  post,
  currentUserId,
  userReactions = [],
  isPro = false,
  initialPrayerCount,
  initialHasPrayed = false,
  fullVideo = false,
}: PostCardProps) {
  const [reactions, setReactions] = useState(post.reactions)
  const [myReactions, setMyReactions] = useState<ReactionType[]>(userReactions)
  const [isExpanded, setIsExpanded] = useState(false)
  const [muted, setMuted] = useState(true)
  const [teaserEnded, setTeaserEnded] = useState(false)
  // Prayer chain
  const [prayerCount, setPrayerCount] = useState(initialPrayerCount ?? post.prayer_count ?? 0)
  const [hasPrayed, setHasPrayed] = useState(initialHasPrayed)
  const [prayerLoading, setPrayerLoading] = useState(false)
  const [prayerPop, setPrayerPop] = useState(false)
  // Three-dot menu
  const [showMenu, setShowMenu] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  // Bless this Voice
  const [showBless, setShowBless] = useState(false)
  const [blessPhone, setBlessPhone] = useState('')
  const [blessAmount, setBlessAmount] = useState(500)
  const [blessLoading, setBlessLoading] = useState(false)
  const [blessSent, setBlessSent] = useState(false)
  const [blessError, setBlessError] = useState('')

  const videoRef = useRef<HTMLVideoElement>(null)
  const videoWrapRef = useRef<HTMLDivElement>(null)
  const TEASER_SECONDS = 35
  const supabase = createClient()

  useEffect(() => {
    if (post.content_type !== 'short' || !post.video_url) return
    const el = videoWrapRef.current
    if (!el) return
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !teaserEnded) {
          videoRef.current?.play().catch(() => {})
        } else {
          videoRef.current?.pause()
        }
      },
      { threshold: 0.5 }
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [post.content_type, post.video_url, teaserEnded])

  useEffect(() => {
    if (!showMenu) return
    function handleClick(e: MouseEvent) {
      if (!menuRef.current?.contains(e.target as Node)) setShowMenu(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [showMenu])

  const handleTimeUpdate = () => {
    if (fullVideo) return
    const vid = videoRef.current
    if (!vid) return
    if (vid.currentTime >= TEASER_SECONDS) {
      vid.pause()
      setTeaserEnded(true)
    }
  }

  const wordCount = post.body.trim().split(/\s+/).length
  const isGated = !isPro
    && (post.content_type === 'story' || post.content_type === 'letter')
    && wordCount > PAYWALL_WORD_THRESHOLD

  const isLong = post.body.length > 400 && !isGated
  const displayBody = isGated
    ? post.body.slice(0, FREE_PREVIEW_CHARS)
    : isExpanded || !isLong
      ? post.body
      : post.body.slice(0, 400) + '...'

  const isAnonymous = post.is_anonymous
  const authorName = isAnonymous
    ? (post.author?.voice_name ?? 'Anonymous voice')
    : (post.author?.is_revealed && post.author?.real_name
        ? post.author.real_name
        : post.author?.voice_name ?? 'Anonymous voice')

  const handleReaction = async (type: ReactionType) => {
    if (!currentUserId) return
    const hasReacted = myReactions.includes(type)
    if (hasReacted) {
      setMyReactions(myReactions.filter(r => r !== type))
      setReactions({ ...reactions, [type]: Math.max(0, reactions[type] - 1) })
      await supabase.from('reactions').delete()
        .match({ post_id: post.id, user_id: currentUserId, reaction_type: type })
    } else {
      setMyReactions([...myReactions, type])
      setReactions({ ...reactions, [type]: reactions[type] + 1 })
      await supabase.from('reactions').insert({
        post_id: post.id, user_id: currentUserId, reaction_type: type,
      })
    }
  }

  const handlePrayer = async () => {
    if (!currentUserId || prayerLoading) return
    setPrayerLoading(true)
    if (hasPrayed) {
      setHasPrayed(false)
      setPrayerCount(c => Math.max(0, c - 1))
      await supabase.from('prayer_chains').delete()
        .match({ post_id: post.id, user_id: currentUserId })
    } else {
      setHasPrayed(true)
      setPrayerCount(c => c + 1)
      setPrayerPop(true)
      setTimeout(() => setPrayerPop(false), 600)
      await supabase.from('prayer_chains').upsert(
        { post_id: post.id, user_id: currentUserId },
        { onConflict: 'post_id,user_id' }
      )
    }
    setPrayerLoading(false)
  }

  const handleWhatsApp = () => {
    const url = `${window.location.origin}/post/${post.id}`
    const text = post.title
      ? `"${post.title}" — ${url}`
      : `A voice on Ijwi: "${post.body.slice(0, 80)}..." — ${url}`
    window.open(`https://wa.me/?text=${encodeURIComponent(text)}`, '_blank', 'noopener')
  }

  const handleBless = async () => {
    if (!blessPhone.trim()) { setBlessError('Enter your MoMo phone number.'); return }
    // Validate Rwanda phone: MTN (078/079) or Airtel (073/072)
    const cleaned = blessPhone.replace(/[\s\-().+]/g, '')
    const normalized = cleaned.startsWith('250') ? cleaned : cleaned.startsWith('0') ? `250${cleaned.slice(1)}` : `250${cleaned}`
    const isValidRwanda = /^2507[23789]\d{7}$/.test(normalized)
    if (!isValidRwanda) {
      setBlessError('Enter a valid Rwanda number. Examples: 0781234567 or 0731234567 (MTN or Airtel)')
      return
    }
    setBlessLoading(true)
    setBlessError('')
    try {
      const res = await fetch('/api/momo/bless', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          post_id: post.id,
          to_user_id: post.author_id,
          amount: blessAmount,
          phone: blessPhone,
        }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error ?? 'Payment failed')
      setBlessSent(true)
    } catch (err: any) {
      setBlessError(err.message)
    }
    setBlessLoading(false)
  }

  const authorHref = !isAnonymous && post.author ? `/profile/${post.author.id}` : null
  const isPrayerPost = post.content_type === 'prayer_request'

  return (
    <motion.article
      className="card"
      layout
      initial={{ opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -12 }}
      whileHover={{ y: -3, boxShadow: '0 12px 40px var(--ij-glow-gold)', borderColor: 'var(--ij-border-gold)' }}
      transition={{ type: 'spring', stiffness: 380, damping: 28 }}
      style={{ padding: '22px 24px', marginBottom: '12px', position: 'relative', cursor: 'default' }}
    >
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          {authorHref ? (
            <Link href={authorHref} style={{ flexShrink: 0, display: 'block' }}>
              <ProfileAvatar userId={post.author?.id ?? post.author_id} avatarUrl={post.author?.avatar_url} isRevealed={post.author?.is_revealed && !isAnonymous} size={38} voiceName={isAnonymous ? undefined : post.author?.voice_name ?? undefined} />
            </Link>
          ) : (
            <div style={{ flexShrink: 0 }}>
              <ProfileAvatar userId={post.author?.id ?? post.author_id} avatarUrl={post.author?.avatar_url} isRevealed={false} size={38} voiceName={undefined} />
            </div>
          )}
          <div>
            {authorHref ? (
              <Link href={authorHref} style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-primary)', textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                {authorName}
                {post.author?.is_verified && post.author?.is_approved_poster && <VerificationBadge size={13} />}
                {(post.author as any)?.subscription_status === 'active' && <ProBadge />}
              </Link>
            ) : (
              <div style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: 4 }}>
                {authorName}
                {post.author?.is_verified && post.author?.is_approved_poster && <VerificationBadge size={13} />}
                {(post.author as any)?.subscription_status === 'active' && <ProBadge />}
                {isAnonymous && <span style={{ fontSize: '11px', color: 'var(--text-muted)', marginLeft: '2px', fontWeight: 400 }}>· anonymous</span>}
              </div>
            )}
            <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{timeAgo(post.created_at)}</div>
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ padding: '4px 12px', borderRadius: '100px', fontSize: '11px', fontWeight: 600, letterSpacing: '0.02em' }}
            className={CONTENT_TYPE_COLORS[post.content_type]}>
            {CONTENT_TYPE_LABELS[post.content_type]}
          </span>
          {/* Three-dot menu */}
          <div style={{ position: 'relative' }} ref={menuRef}>
            <button
              onClick={() => setShowMenu(s => !s)}
              style={{
                background: 'transparent', border: 'none', cursor: 'pointer',
                padding: '4px 8px', borderRadius: 6,
                color: 'var(--ij-text-secondary)', fontSize: '1rem',
                letterSpacing: '2px', lineHeight: 1,
              }}>•••</button>
            {showMenu && (
              <div style={{
                position: 'absolute', top: '100%', right: 0,
                background: 'var(--ij-bg-elevated)',
                border: '1px solid var(--ij-border)',
                borderRadius: 12, padding: 6,
                zIndex: 50, minWidth: 190,
                boxShadow: '0 4px 20px var(--ij-shadow)',
              }}>
                {currentUserId && currentUserId !== post.author_id && (
                  <Link href={`/dms/${post.author_id}`} style={{ textDecoration: 'none' }} onClick={() => setShowMenu(false)}>
                    <button style={{
                      width: '100%', background: 'transparent', border: 'none', borderRadius: 8,
                      color: 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-body)',
                      fontSize: '0.85rem', fontWeight: 500, padding: '9px 12px', cursor: 'pointer',
                      textAlign: 'left', display: 'flex', alignItems: 'center', gap: 10,
                    }}>
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
                        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                      </svg>
                      Message creator
                    </button>
                  </Link>
                )}
                {currentUserId && post.content_type !== 'short' && (
                  <button
                    onClick={async () => {
                      const author = post.author?.voice_name ?? 'someone'
                      const body = `${post.body}\n\n— Echoed from ${post.is_anonymous ? 'an anonymous voice' : author}`
                      await supabase.from('posts').insert({ author_id: currentUserId, content_type: post.content_type, title: post.title ?? null, body, is_anonymous: false, status: 'published', tags: post.tags ?? [], verse_reference: post.verse_reference ?? null })
                      setShowMenu(false)
                    }}
                    style={{
                      width: '100%', background: 'transparent', border: 'none', borderRadius: 8,
                      color: 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-body)',
                      fontSize: '0.85rem', fontWeight: 500, padding: '9px 12px', cursor: 'pointer',
                      textAlign: 'left', display: 'flex', alignItems: 'center', gap: 10,
                    }}>
                    ↺ Echo this post
                  </button>
                )}
                {currentUserId && currentUserId !== post.author_id && (
                  <button
                    onClick={() => setShowMenu(false)}
                    style={{
                      width: '100%', background: 'transparent', border: 'none', borderRadius: 8,
                      color: '#ef4444', fontFamily: 'var(--ij-font-body)',
                      fontSize: '0.85rem', fontWeight: 500, padding: '9px 12px', cursor: 'pointer',
                      textAlign: 'left', display: 'flex', alignItems: 'center', gap: 10,
                    }}>
                    ⚑ Report
                  </button>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Verse highlight */}
      {post.verse_reference && (
        <div style={{ padding: '10px 14px', marginBottom: '14px', borderRadius: '8px', background: 'var(--ij-bg-elevated)', borderLeft: '3px solid var(--ij-gold-muted)' }}>
          {post.verse_text && (
            <p style={{ fontSize: '13px', fontStyle: 'italic', color: 'var(--ij-text-secondary)', marginBottom: '3px', lineHeight: 1.6 }}>
              "{post.verse_text}"
            </p>
          )}
          <span style={{ fontSize: '11px', color: 'var(--ij-gold)', fontWeight: 600 }}>{post.verse_reference}</span>
        </div>
      )}

      {/* Editorial row: title + body on left, thumbnail on right */}
      <div style={{
        display: 'flex', gap: 14, alignItems: 'flex-start',
        ...(post.image_url && post.content_type !== 'short' ? { flexDirection: 'row' } : {}),
      }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          {/* Title */}
          {post.title && (
            <h2 style={{ fontFamily: 'var(--ij-font-display)', fontSize: 'clamp(1.15rem, 3vw, 1.45rem)', fontWeight: 700, marginBottom: '10px', color: 'var(--ij-text-primary)', lineHeight: 1.25 }}>
              <Link href={`/post/${post.id}`} style={{ textDecoration: 'none', color: 'inherit' }}>{post.title}</Link>
            </h2>
          )}

      {/* Body */}
      {post.content_type === 'short' ? (
        <div style={{ marginBottom: '4px' }}>
          {post.video_url ? (
            <div ref={videoWrapRef} style={{ position: 'relative', width: '100%', aspectRatio: '9 / 16', maxHeight: '560px', background: '#0a0a0a', borderRadius: '12px', overflow: 'hidden', marginBottom: '10px' }}>
              <video ref={videoRef} src={post.video_url} playsInline loop={!teaserEnded} muted={muted} preload="metadata" onTimeUpdate={handleTimeUpdate}
                onClick={() => { if (videoRef.current) { videoRef.current.paused ? videoRef.current.play() : videoRef.current.pause() } }}
                style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'contain', cursor: 'pointer' }} />
              {!teaserEnded && (
                <button onClick={() => setMuted(m => !m)} style={{ position: 'absolute', bottom: '12px', right: '12px', width: '34px', height: '34px', borderRadius: '50%', background: 'rgba(0,0,0,0.55)', border: 'none', color: 'white', fontSize: '15px', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', backdropFilter: 'blur(4px)' }}>
                  {muted ? <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round"><path d="M11 5 6 9H2v6h4l5 4zM22 9l-6 6M16 9l6 6"/></svg> : <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14"/></svg>}
                </button>
              )}
              {teaserEnded && (
                <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.82)', backdropFilter: 'blur(6px)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '24px', gap: '12px' }}>
                  <div style={{ marginBottom: '4px' }}><svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><polygon points="5 3 19 12 5 21 5 3"/></svg></div>
                  <p style={{ color: 'white', fontFamily: 'var(--font-display)', fontSize: '18px', fontWeight: 500, textAlign: 'center' }}>Watch the full video</p>
                  <Link href={`/post/${post.id}`} style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '12px 24px', borderRadius: '100px', background: 'var(--flame)', color: 'white', textDecoration: 'none', fontSize: '14px', fontWeight: 600, fontFamily: 'var(--font-body)', width: '100%', justifyContent: 'center' }}>
                    Watch full on Ijwi
                  </Link>
                  <button onClick={() => { setTeaserEnded(false); if (videoRef.current) { videoRef.current.currentTime = 0; videoRef.current.play().catch(() => {}) } }} style={{ background: 'none', border: 'none', color: 'rgba(255,255,255,0.5)', fontSize: '13px', cursor: 'pointer', fontFamily: 'var(--font-body)' }}>
                    Replay preview
                  </button>
                </div>
              )}
            </div>
          ) : (
            <div style={{ width: '100%', borderRadius: '12px', aspectRatio: '9 / 16', maxHeight: '560px', background: 'linear-gradient(135deg, #1a1a1a 0%, #2a2a2a 100%)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '10px' }}>
              <span style={{ opacity: 0.5 }}><svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.5)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><path d="m22 8-6 4 6 4V8Z"/><rect width="14" height="12" x="2" y="6" rx="2" ry="2"/></svg></span>
            </div>
          )}
          {post.body && <p style={{ fontSize: '14px', color: 'var(--text-secondary)', lineHeight: 1.6 }}>{post.body}</p>}
          <Link href="/sparks" style={{ fontSize: '13px', color: 'var(--flame)', textDecoration: 'none', fontWeight: 500, display: 'inline-block', marginTop: '6px' }}>
            Watch more moments →
          </Link>
        </div>
      ) : (
        <div style={{ position: 'relative' }}>
          <div style={{ fontSize: post.content_type === 'letter' ? '16px' : '15px', fontFamily: post.content_type === 'letter' ? 'var(--ij-font-display)' : 'var(--ij-font-body)', color: 'var(--ij-text-primary)', lineHeight: 1.78, fontStyle: post.content_type === 'spoken_word' ? 'italic' : 'normal', whiteSpace: 'pre-wrap', ...(isGated ? { maxHeight: '240px', overflow: 'hidden' } : {}) }}>
            {displayBody.startsWith('<') ? (
              <div dangerouslySetInnerHTML={{ __html: displayBody }} />
            ) : (
              <div>{displayBody}</div>
            )}
          </div>
          {isGated && <PaywallOverlay />}
        </div>
      )}

      {post.content_type !== 'short' && !isGated && isLong && (
        <button onClick={() => setIsExpanded(!isExpanded)} style={{ background: 'none', border: 'none', color: 'var(--ij-gold)', fontSize: '13px', cursor: 'pointer', marginTop: '8px', padding: 0, fontFamily: 'var(--ij-font-body)', fontWeight: 600 }}>
          {isExpanded ? 'Show less' : 'Read more →'}
        </button>
      )}
        </div>

        {/* Thumbnail (right column for editorial types) */}
        {post.image_url && post.content_type !== 'short' && (
          <Link href={`/post/${post.id}`} style={{ flexShrink: 0, display: 'block', alignSelf: 'flex-start' }}>
            <Image
              src={post.image_url} alt="" width={120} height={80} unoptimized
              style={{ width: 110, height: 74, objectFit: 'cover', borderRadius: 8, border: '1px solid var(--ij-border)', display: 'block' }}
            />
          </Link>
        )}
      </div>

      {/* Full-width image for non-editorial posts (sparks, etc.) */}
      {post.image_url && post.content_type === 'short' && (
        <div style={{ marginTop: '10px', marginBottom: '4px' }}>
          <Image src={post.image_url} alt="" width={800} height={400} unoptimized style={{ width: '100%', maxHeight: '360px', objectFit: 'cover', borderRadius: '10px', border: '1px solid var(--ij-border)', display: 'block', height: 'auto' }} />
        </div>
      )}

      {/* Audio player for spoken word */}
      {post.content_type === 'spoken_word' && post.audio_url && (
        <div style={{ marginTop: '14px' }}>
          <audio
            controls
            src={post.audio_url}
            style={{ width: '100%', borderRadius: '8px', outline: 'none' }}
          />
        </div>
      )}

      {/* Tags */}
      {post.tags.length > 0 && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '5px', marginTop: '14px' }}>
          {post.tags.map(tag => (
            <Link key={tag} href={`/explore/tag/${tag}`} style={{ padding: '3px 10px', borderRadius: '100px', fontSize: '11px', background: 'var(--ij-bg-elevated)', color: 'var(--ij-gold)', fontWeight: 500, textDecoration: 'none', border: '1px solid var(--ij-border-gold)', transition: 'background 0.12s' }}>#{tag}</Link>
          ))}
        </div>
      )}

      {/* ── Prayer chain banner for prayer posts ── */}
      {isPrayerPost && (
        <div style={{ marginTop: '16px', padding: '14px 16px', borderRadius: '12px', background: hasPrayed ? 'rgba(240,74,12,0.08)' : 'var(--surface-2)', border: `1px solid ${hasPrayed ? 'var(--flame)' : 'var(--border)'}`, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px' }}>
          <div>
            <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)', marginBottom: '2px' }}>
              {prayerCount > 0 ? `${prayerCount} ${prayerCount === 1 ? 'person' : 'people'} prayed for this` : 'Be the first to pray for this'}
            </div>
            <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Tap to add your prayer to the chain</div>
          </div>
          {currentUserId ? (
            <button
              onClick={handlePrayer}
              disabled={prayerLoading}
              style={{
                padding: '8px 18px', borderRadius: '100px', fontFamily: 'var(--font-body)',
                border: `1px solid ${hasPrayed ? 'var(--flame)' : 'var(--border)'}`,
                background: hasPrayed ? 'var(--flame)' : 'var(--surface)',
                color: hasPrayed ? 'white' : 'var(--text-secondary)',
                fontSize: '13px', fontWeight: 600, cursor: prayerLoading ? 'wait' : 'pointer',
                transform: prayerPop ? 'scale(1.18)' : 'scale(1)',
                transition: 'all 0.15s', flexShrink: 0,
              } as React.CSSProperties}
            >
              {hasPrayed ? '🙏 Prayed ✓' : '🙏 I prayed'}
            </button>
          ) : (
            <Link href="/auth/login" style={{ padding: '8px 18px', borderRadius: '100px', background: 'var(--flame)', color: 'white', textDecoration: 'none', fontSize: '13px', fontWeight: 600, flexShrink: 0 }}>
              🙏 Pray
            </Link>
          )}
        </div>
      )}

      {/* ── Reactions + actions ── */}
      <div style={{ display: 'flex', gap: '6px', marginTop: '16px', paddingTop: '12px', borderTop: '1px solid var(--ij-border)', flexWrap: 'wrap', alignItems: 'center' }}>
        {REACTIONS.map(({ type, icon, label }) => {
          const count = reactions[type] || 0
          const active = myReactions.includes(type)
          return (
            <motion.button key={type} onClick={() => handleReaction(type)} title={currentUserId ? label : 'Sign in to react'}
              whileTap={{ scale: 0.82 }} whileHover={{ scale: 1.06 }}
              transition={{ type: 'spring', stiffness: 500, damping: 22 }}
              style={{ display: 'flex', alignItems: 'center', gap: '5px', padding: '5px 10px', borderRadius: '100px', border: `1px solid ${active ? 'var(--ij-gold)' : 'var(--ij-border)'}`, background: active ? 'var(--ij-glow-gold)' : 'transparent', cursor: currentUserId ? 'pointer' : 'default', fontSize: '12px', fontFamily: 'var(--ij-font-body)', color: active ? 'var(--ij-gold)' : 'var(--ij-text-secondary)', transition: 'border-color 0.12s, background 0.12s, color 0.12s' }}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                {icon === 'hand-helping' && <><path d="M11 12h1v4a2 2 0 0 0 4 0v-3a1 1 0 0 0-1-1h-1"/><path d="M4 19a2 2 0 0 0 2 2h2a2 2 0 0 0 2-2v-5"/><path d="M22 13v-2a1 1 0 0 0-1-1h-3.83l-1.68-2.52A2 2 0 0 0 13.82 6H10a4 4 0 0 0-4 4v4"/></>}
                {icon === 'heart' && <path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>}
                {icon === 'droplets' && <><path d="M7 16.3c2.2 0 4-1.83 4-4.05 0-1.16-.57-2.26-1.71-3.19S7.29 6.75 7 5.3c-.29 1.45-1.14 2.84-2.29 3.76S3 11.1 3 12.25c0 2.22 1.8 4.05 4 4.05z"/><path d="M12.56 6.6A10.97 10.97 0 0 0 14 3.02c.5 2.5 2 4.9 4 6.5s3 3.5 3 5.5a6.98 6.98 0 0 1-11.91 4.97"/></>}
                {icon === 'bird' && <><path d="M16 7h.01"/><path d="M3.4 18H12a8 8 0 0 0 8-8V7a4 4 0 0 0-7.28-2.3L2 20"/><path d="m20 7 2 .5-2 .5"/><path d="M10 18v3"/><path d="M14 17.75V21"/><path d="M7 18a6 6 0 0 0 3.84-10.61"/></>}
              </svg>
              {count > 0 && <span style={{ fontWeight: active ? 600 : 400, fontSize: '12px' }}>{count}</span>}
            </motion.button>
          )
        })}

        <Link href={`/post/${post.id}`} style={{ display: 'flex', alignItems: 'center', gap: '5px', padding: '5px 10px', borderRadius: '100px', border: '1px solid var(--ij-border)', textDecoration: 'none', fontSize: '12px', color: 'var(--ij-text-secondary)' }}>
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
          {post.comment_count ?? 0}
        </Link>

        {currentUserId && currentUserId !== post.author_id && (
          <ReportButton postId={post.id} currentUserId={currentUserId} />
        )}

        {/* Right-side action buttons */}
        <div style={{ display: 'flex', gap: '6px', marginLeft: 'auto', flexWrap: 'wrap' }}>
          {/* Bless this Voice — only for other people's non-anonymous posts */}
          {currentUserId && currentUserId !== post.author_id && !isAnonymous && post.content_type !== 'short' && (
            <button
              onClick={() => setShowBless(b => !b)}
              style={{ display: 'flex', alignItems: 'center', gap: '4px', padding: '5px 11px', borderRadius: '100px', border: `1px solid ${showBless ? 'rgba(240,168,50,0.5)' : 'rgba(240,168,50,0.25)'}`, background: showBless ? 'rgba(240,168,50,0.10)' : 'transparent', fontSize: '12px', color: '#F0A832', fontWeight: 600, cursor: 'pointer', fontFamily: 'var(--font-body)', transition: 'all 0.12s' }}
            >
              ★ Bless
            </button>
          )}

          {/* WhatsApp share */}
          <button
            onClick={handleWhatsApp}
            style={{ display: 'flex', alignItems: 'center', gap: '4px', padding: '5px 11px', borderRadius: '100px', border: '1px solid var(--border)', background: 'transparent', fontSize: '12px', color: 'var(--text-muted)', cursor: 'pointer', fontFamily: 'var(--font-body)', transition: 'border-color 0.12s' }}
            title="Share on WhatsApp"
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z"/><path d="M12 0C5.373 0 0 5.373 0 12c0 2.104.545 4.083 1.5 5.813L0 24l6.335-1.484A11.945 11.945 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 21.818a9.818 9.818 0 01-5.013-1.375l-.36-.213-3.72.871.94-3.618-.234-.372A9.818 9.818 0 0112 2.182c5.42 0 9.818 4.398 9.818 9.818 0 5.421-4.398 9.818-9.818 9.818z"/></svg>
            WA
          </button>

          {/* Echo */}
          {currentUserId && post.content_type !== 'short' && (
            <button
              onClick={async () => {
                const author = post.author?.voice_name ?? 'someone'
                const body = `${post.body}\n\n— Echoed from ${post.is_anonymous ? 'an anonymous voice' : author}`
                await supabase.from('posts').insert({ author_id: currentUserId, content_type: post.content_type, title: post.title ?? null, body, is_anonymous: false, status: 'published', tags: post.tags ?? [], verse_reference: post.verse_reference ?? null })
                const btn = document.getElementById(`repost-${post.id}`)
                if (btn) { btn.textContent = 'Echoed ✓'; setTimeout(() => { if (btn) btn.textContent = 'Echo' }, 2000) }
              }}
              id={`repost-${post.id}`}
              style={{ display: 'flex', alignItems: 'center', gap: '4px', padding: '5px 11px', borderRadius: '100px', border: '1px solid var(--border)', background: 'transparent', fontSize: '12px', color: 'var(--text-muted)', cursor: 'pointer', fontFamily: 'var(--font-body)' }}
            >
              ↺ Echo
            </button>
          )}
        </div>
      </div>

      {/* ── Bless this Voice panel ── */}
      {showBless && !isAnonymous && (
        <div style={{ marginTop: '14px', padding: '16px', borderRadius: '12px', background: 'var(--surface-2)', border: '1px solid var(--border)' }}>
          {blessSent ? (
            <div style={{ textAlign: 'center', padding: '8px' }}>
              <div style={{ fontSize: '28px', marginBottom: '8px' }}>💝</div>
              <p style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-primary)', marginBottom: '4px' }}>Blessing sent!</p>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Check your phone to approve the payment.</p>
              <button onClick={() => { setShowBless(false); setBlessSent(false); setBlessPhone(''); setBlessAmount(500) }} style={{ marginTop: '10px', background: 'none', border: 'none', color: 'var(--flame)', cursor: 'pointer', fontSize: '13px', fontFamily: 'var(--font-body)' }}>Done</button>
            </div>
          ) : (
            <>
              <p style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)', marginBottom: '4px' }}>
                Bless {authorName}&apos;s voice 💝
              </p>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '12px', lineHeight: 1.5 }}>
                Send a blessing via Mobile Money. 85% goes directly to the creator.
              </p>
              {/* Amount buttons */}
              <div style={{ display: 'flex', gap: '8px', marginBottom: '12px' }}>
                {[500, 1000, 2000, 5000].map(amt => (
                  <button key={amt} onClick={() => setBlessAmount(amt)}
                    style={{ flex: 1, padding: '8px 4px', borderRadius: '8px', border: `1px solid ${blessAmount === amt ? 'var(--flame)' : 'var(--border)'}`, background: blessAmount === amt ? 'var(--flame-soft)' : 'var(--surface)', color: blessAmount === amt ? 'var(--flame)' : 'var(--text-secondary)', fontSize: '12px', fontWeight: 600, cursor: 'pointer', fontFamily: 'var(--font-body)' }}>
                    {amt.toLocaleString()}
                  </button>
                ))}
              </div>
              <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '10px', textAlign: 'center' }}>{blessAmount.toLocaleString()} RWF ≈ ${(blessAmount / 1350).toFixed(2)}</p>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '10px' }}>
                <span style={{ fontSize: '18px', flexShrink: 0 }}>🇷🇼</span>
                <input type="tel" placeholder="07X XXX XXXX" value={blessPhone} onChange={e => setBlessPhone(e.target.value)}
                  style={{ flex: 1, padding: '10px 12px', borderRadius: '8px', border: '1px solid var(--border)', fontSize: '14px', fontFamily: 'var(--font-body)', background: 'var(--surface)', color: 'var(--text-primary)', outline: 'none' }} />
              </div>
              {blessError && <p style={{ fontSize: '12px', color: '#C0392B', marginBottom: '8px' }}>{blessError}</p>}
              <button onClick={handleBless} disabled={blessLoading}
                style={{ width: '100%', padding: '11px', borderRadius: '100px', background: blessLoading ? 'var(--border)' : 'var(--flame)', color: 'white', border: 'none', fontSize: '13px', fontWeight: 600, cursor: blessLoading ? 'not-allowed' : 'pointer', fontFamily: 'var(--font-body)' }}>
                {blessLoading ? 'Sending...' : `Send ${blessAmount.toLocaleString()} RWF blessing →`}
              </button>
            </>
          )}
        </div>
      )}
    </motion.article>
  )
}

// ── Inline report button ──────────────────────────────────────────────────────
function ReportButton({ postId, currentUserId }: { postId: string; currentUserId: string }) {
  const [reported, setReported] = useState(false)
  const [showForm, setShowForm] = useState(false)
  const [reason, setReason] = useState('inappropriate')
  const [notes, setNotes] = useState('')
  const supabase = createClient()

  const submit = async () => {
    await supabase.from('reports').insert({ post_id: postId, reporter_id: currentUserId, reason, notes: notes.trim() || null })
    setReported(true)
    setShowForm(false)
  }

  if (reported) return <span style={{ fontSize: '11px', color: 'var(--text-muted)', fontStyle: 'italic' }}>Reported ✓</span>

  return (
    <div style={{ position: 'relative' }}>
      <button onClick={() => setShowForm(f => !f)} style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: '11px', color: 'var(--text-muted)', padding: '5px 8px', fontFamily: 'var(--font-body)' }} title="Report this post">🚩</button>
      {showForm && (
        <>
          <div onClick={() => setShowForm(false)} style={{ position: 'fixed', inset: 0, zIndex: 50 }} />
          <div style={{ position: 'absolute', bottom: '32px', right: 0, zIndex: 51, background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: '12px', padding: '16px', minWidth: '220px', boxShadow: '0 4px 24px rgba(0,0,0,0.12)' }}>
            <p style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)', marginBottom: '10px' }}>Report this post</p>
            <select value={reason} onChange={e => setReason(e.target.value)} style={{ width: '100%', padding: '8px 10px', borderRadius: '8px', border: '1px solid var(--border)', fontSize: '13px', marginBottom: '8px', background: 'var(--surface)', color: 'var(--text-primary)', fontFamily: 'var(--font-body)', outline: 'none' }}>
              <option value="inappropriate">Inappropriate</option>
              <option value="hate_speech">Hate speech</option>
              <option value="spam">Spam</option>
              <option value="false_teaching">False teaching</option>
              <option value="harassment">Harassment</option>
            </select>
            <textarea placeholder="Additional notes (optional)" value={notes} onChange={e => setNotes(e.target.value)} rows={2} style={{ width: '100%', padding: '8px 10px', borderRadius: '8px', border: '1px solid var(--border)', fontSize: '13px', marginBottom: '10px', background: 'var(--surface)', color: 'var(--text-primary)', fontFamily: 'var(--font-body)', outline: 'none', resize: 'none', boxSizing: 'border-box' }} />
            <button onClick={submit} style={{ width: '100%', padding: '8px', borderRadius: '8px', background: '#E24B4A', color: 'white', border: 'none', fontSize: '13px', cursor: 'pointer', fontFamily: 'var(--font-body)', fontWeight: 600 }}>Submit report</button>
          </div>
        </>
      )}
    </div>
  )
}
