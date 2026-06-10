'use client'

import { useState, useRef, useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { Profile, Post } from '@/lib/types'
import { generateFlamePattern, timeAgo } from '@/lib/utils'
import Navbar from '@/components/layout/Navbar'
import { containsProfanity, MODERATION_MESSAGE } from '@/lib/moderation'

const FREE_SPARKS_LIMIT = 3
const FREE_TRIAL_DAYS = 30

interface SparksClientProps {
  sparks: Post[]
  profile: Profile | null
  currentUserId?: string
  isPro: boolean
  userSparksCount: number
  accountAgeDays: number
  userReactionMap: Record<string, string[]>
  initialFollowingIds: string[]
}

// ─── Grid Spark Card (3-column) ─────────────────────────────────────────────

function SparkCard({
  spark,
  currentUserId,
  initialReactions,
}: {
  spark: Post
  currentUserId?: string
  initialReactions: string[]
}) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const cardRef = useRef<HTMLDivElement>(null)
  const [hovered, setHovered] = useState(false)
  const [reactions, setReactions] = useState(spark.reactions)
  const [myReactions, setMyReactions] = useState<string[]>(initialReactions)
  const supabase = createClient()

  const authorName = spark.is_anonymous
    ? (spark.author?.voice_name ?? 'Anonymous')
    : (spark.author?.is_revealed && spark.author?.real_name
        ? spark.author.real_name
        : spark.author?.voice_name ?? 'Anonymous')

  const flameColor = spark.author ? generateFlamePattern(spark.author.id) : '#FF6B2B'
  const fireCount = (reactions.fire ?? 0) + (reactions.amen ?? 0) + (reactions.healed ?? 0) + (reactions.needed ?? 0) + (reactions.sharing ?? 0)

  useEffect(() => {
    if (!videoRef.current || !cardRef.current) return
    if (hovered && spark.video_url) {
      videoRef.current?.play().catch(() => {})
    } else {
      videoRef.current?.pause()
    }
  }, [hovered, spark.video_url])

  const handleReact = async (e: React.MouseEvent, type: 'fire') => {
    e.preventDefault()
    e.stopPropagation()
    if (!currentUserId) return
    const has = myReactions.includes(type)
    if (has) {
      setMyReactions(prev => prev.filter(r => r !== type))
      setReactions(prev => ({ ...prev, [type]: Math.max(0, prev[type] - 1) }))
      await supabase.from('reactions').delete()
        .match({ post_id: spark.id, user_id: currentUserId, reaction_type: type })
    } else {
      setMyReactions(prev => [...prev, type])
      setReactions(prev => ({ ...prev, [type]: prev[type] + 1 }))
      await supabase.from('reactions').insert({
        post_id: spark.id, user_id: currentUserId, reaction_type: type
      })
    }
  }

  return (
    <Link
      href={`/post/${spark.id}`}
      style={{ textDecoration: 'none', display: 'block' }}
    >
      <div
        ref={cardRef}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          position: 'relative',
          aspectRatio: '9 / 16',
          borderRadius: 16,
          overflow: 'hidden',
          background: '#0a0a0a',
          cursor: 'pointer',
          transition: 'transform 0.2s ease, box-shadow 0.2s ease',
          transform: hovered ? 'scale(1.02)' : 'scale(1)',
          boxShadow: hovered ? '0 16px 48px rgba(0,0,0,0.5)' : '0 4px 16px rgba(0,0,0,0.3)',
        }}
      >
        {spark.video_url ? (
          <video
            ref={videoRef}
            src={spark.video_url}
            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
            loop
            muted
            playsInline
            preload="metadata"
          />
        ) : (
          <div style={{
            width: '100%', height: '100%',
            background: `linear-gradient(160deg, ${flameColor}66 0%, #0d0b09 55%, #0C0916 100%)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '24px',
          }}>
            <p style={{
              fontFamily: 'var(--ij-font-display)', fontSize: '1rem', fontWeight: 500,
              color: 'rgba(255,255,255,0.85)', lineHeight: 1.6, textAlign: 'center',
            }}>
              {spark.title || spark.body.slice(0, 80)}
            </p>
          </div>
        )}

        {/* Gradient overlay */}
        <div style={{
          position: 'absolute', inset: 0,
          background: 'linear-gradient(to top, rgba(0,0,0,0.82) 0%, rgba(0,0,0,0.2) 50%, transparent 75%)',
          pointerEvents: 'none',
        }} />

        {/* Bottom info */}
        <div style={{
          position: 'absolute', bottom: 0, left: 0, right: 0,
          padding: '12px', zIndex: 2,
        }}>
          {/* Author */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
            <div style={{
              width: 24, height: 24, borderRadius: '50%',
              background: flameColor, border: '1.5px solid rgba(255,255,255,0.5)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: '10px', color: 'white', fontWeight: 700, overflow: 'hidden', flexShrink: 0,
            }}>
              {spark.author?.avatar_url && spark.author?.is_revealed && !spark.is_anonymous
                ? <Image src={spark.author.avatar_url} alt="" width={24} height={24} unoptimized style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                : authorName.charAt(0).toUpperCase()}
            </div>
            <span style={{ fontSize: '11px', fontWeight: 600, color: 'rgba(255,255,255,0.9)', textShadow: '0 1px 3px rgba(0,0,0,0.8)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {authorName}
            </span>
          </div>

          {/* Caption */}
          {(spark.title || spark.body) && (
            <p style={{
              fontSize: '12px', color: 'rgba(255,255,255,0.8)', lineHeight: 1.4,
              textShadow: '0 1px 3px rgba(0,0,0,0.8)',
              display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' as const,
              overflow: 'hidden', margin: 0,
            }}>
              {spark.title || spark.body}
            </p>
          )}

          {/* Reaction count */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 8 }}>
            <button
              onClick={(e) => handleReact(e, 'fire')}
              style={{
                display: 'flex', alignItems: 'center', gap: 4,
                background: myReactions.includes('fire') ? 'rgba(255,107,43,0.3)' : 'rgba(0,0,0,0.4)',
                border: `1px solid ${myReactions.includes('fire') ? 'var(--flame)' : 'rgba(255,255,255,0.25)'}`,
                borderRadius: 100, padding: '3px 9px',
                color: 'white', fontSize: '11px', cursor: currentUserId ? 'pointer' : 'default',
                fontFamily: 'var(--ij-font-body)', fontWeight: 500,
                backdropFilter: 'blur(4px)',
              }}
            >
              🔥 {fireCount > 0 ? fireCount : ''}
            </button>
            <span style={{ fontSize: '11px', color: 'rgba(255,255,255,0.5)' }}>
              {timeAgo(spark.created_at)}
            </span>
          </div>
        </div>

        {/* Play icon overlay on hover */}
        {hovered && !spark.video_url && (
          <div style={{
            position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
            zIndex: 3,
          }}>
            <div style={{
              width: 52, height: 52, borderRadius: '50%',
              background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(8px)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              border: '1.5px solid rgba(255,255,255,0.3)',
            }}>
              <span style={{ fontSize: 20, marginLeft: 3 }}>▶</span>
            </div>
          </div>
        )}
      </div>
    </Link>
  )
}

// ─── Upload Modal ─────────────────────────────────────────────────────────────

function UploadModal({
  currentUserId,
  isPro,
  userSparksCount,
  accountAgeDays,
  onClose,
  onUploaded,
}: {
  currentUserId: string
  isPro: boolean
  userSparksCount: number
  accountAgeDays: number
  onClose: () => void
  onUploaded: () => void
}) {
  const [file, setFile] = useState<File | null>(null)
  const [title, setTitle] = useState('')
  const [caption, setCaption] = useState('')
  const [tags, setTags] = useState('')
  const [agreed, setAgreed] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState('')
  const supabase = createClient()

  const handleUpload = async () => {
    if (!file || !caption.trim() || !agreed) {
      setError('Please fill all fields and confirm the content guideline.')
      return
    }
    const capCheck = containsProfanity(caption)
    const titleCheck = title.trim() ? containsProfanity(title) : { blocked: false }
    if (capCheck.blocked || titleCheck.blocked) {
      setError(MODERATION_MESSAGE)
      return
    }

    setUploading(true)
    setError('')

    try {
      const ext = file.name.split('.').pop() ?? 'mp4'
      const filePath = `${currentUserId}/${Date.now()}.${ext}`
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('shorts')
        .upload(filePath, file, {
          contentType: file.type,
          cacheControl: '3600',
          upsert: false,
        })

      if (uploadError) {
        const msg = uploadError.message ?? ''

        if (msg.includes('Bucket not found') || msg.includes('not found')) {
          setError(
            'The "shorts" storage bucket does not exist yet. ' +
            'Go to Supabase → Storage → New bucket → name it "shorts" → set Public → Save.'
          )
          setUploading(false)
          return
        }

        if (
          msg.includes('row-level security') ||
          msg.includes('Unauthorized') ||
          msg.includes('policy') ||
          msg.includes('403')
        ) {
          setError(
            'Storage upload blocked by Supabase policy. ' +
            'Go to Supabase → Storage → shorts bucket → Policies → ' +
            'Add a new INSERT policy for "authenticated" role with check: (bucket_id = \'shorts\'). ' +
            'Also add a SELECT policy for "public" role.'
          )
          setUploading(false)
          return
        }

        setError(`Storage error: ${msg}`)
        setUploading(false)
        return
      }

      const { data: { publicUrl } } = supabase.storage.from('shorts').getPublicUrl(uploadData.path)

      const tagArray = tags
        .split(',')
        .map(t => t.trim().toLowerCase().replace(/^#/, ''))
        .filter(Boolean)
        .slice(0, 5)

      const insertPayload: Record<string, unknown> = {
        author_id: currentUserId,
        content_type: 'short',
        title: title.trim() || null,
        body: caption.trim(),
        video_url: publicUrl,
        is_anonymous: false,
        tags: tagArray,
        reaction_fire: 0,
        reaction_amen: 0,
        reaction_healed: 0,
        reaction_needed: 0,
        reaction_sharing: 0,
      }

      let { error: postError } = await supabase.from('posts').insert(insertPayload)

      if (postError && (postError.message.includes('video_url') || postError.message.includes('column'))) {
        setError(
          '⚠️ Database migration needed. Run this SQL in Supabase → SQL Editor:\n\n' +
          'ALTER TABLE posts ADD COLUMN IF NOT EXISTS video_url text;\n\n' +
          'Then try uploading again. Your video was not posted.'
        )
        setUploading(false)
        return
      }

      if (postError) {
        if (postError.message.includes('row-level security') || postError.message.includes('policy')) {
          setError(
            'Post blocked by database policy. Make sure you are logged in and that the posts table ' +
            'has an INSERT policy allowing authenticated users.'
          )
        } else {
          setError(postError.message)
        }
        setUploading(false)
        return
      }

      onUploaded()
    } catch (err: any) {
      setError(err.message ?? 'Upload failed. Please try again.')
    }

    setUploading(false)
  }

  return (
    <div style={{
      position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)',
      display: 'flex', alignItems: 'flex-end', justifyContent: 'center',
      zIndex: 200, padding: '0',
    }}>
      <div style={{
        background: 'var(--surface)', borderRadius: '20px 20px 0 0',
        padding: '20px 24px 40px', maxWidth: '540px', width: '100%', position: 'relative',
        maxHeight: '92dvh', overflowY: 'auto',
      }}>
        <div style={{ width: 40, height: 4, background: 'var(--border)', borderRadius: 2, margin: '0 auto 16px', flexShrink: 0 }} />
        <button
          onClick={onClose}
          style={{
            position: 'absolute', top: '16px', right: '16px',
            background: 'var(--surface-2)', border: 'none', borderRadius: '50%',
            width: '36px', height: '36px', cursor: 'pointer',
            fontSize: '20px', color: 'var(--text-secondary)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            zIndex: 1,
          }}
        >×</button>

        <h2 style={{
          fontFamily: 'var(--font-display)', fontSize: '22px', fontWeight: 500,
          color: 'var(--text-primary)', marginBottom: '6px'
        }}>
          Share a Spark
        </h2>
        <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '20px' }}>
          A moment of faith — a testimony, a worship clip, a word from God.
        </p>

        <>
            <div style={{ marginBottom: '14px' }}>
              <label style={{
                display: 'block', fontSize: '13px', color: 'var(--text-muted)',
                marginBottom: '6px', fontWeight: 500
              }}>
                Video file *
              </label>
              <input
                type="file"
                accept="video/*"
                onChange={e => setFile(e.target.files?.[0] ?? null)}
                style={{
                  width: '100%', padding: '10px 14px', borderRadius: '10px',
                  border: '1px solid var(--border)', background: 'var(--surface)',
                  color: 'var(--text-primary)', fontSize: '14px', boxSizing: 'border-box'
                }}
              />
              {file && (
                <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
                  {file.name} ({(file.size / 1024 / 1024).toFixed(1)} MB)
                </p>
              )}
            </div>

            <input
              type="text"
              placeholder="Title (optional)"
              value={title}
              onChange={e => setTitle(e.target.value)}
              maxLength={80}
              style={{
                width: '100%', padding: '12px 14px', borderRadius: '10px',
                border: '1px solid var(--border)', fontSize: '15px',
                fontFamily: 'var(--font-display)', background: 'var(--surface)',
                color: 'var(--text-primary)', outline: 'none',
                boxSizing: 'border-box', marginBottom: '12px'
              }}
            />

            <textarea
              placeholder="What's happening in this video? Share the testimony, the word, the moment..."
              value={caption}
              onChange={e => setCaption(e.target.value)}
              maxLength={500}
              rows={3}
              style={{
                width: '100%', padding: '12px 14px', borderRadius: '10px',
                border: '1px solid var(--border)', lineHeight: 1.6,
                fontSize: '14px', fontFamily: 'var(--font-body)',
                background: 'var(--surface)', color: 'var(--text-primary)',
                outline: 'none', resize: 'vertical', boxSizing: 'border-box',
                marginBottom: '12px'
              }}
            />

            <input
              type="text"
              placeholder="#worship, #testimony, #healing"
              value={tags}
              onChange={e => setTags(e.target.value)}
              style={{
                width: '100%', padding: '10px 14px', borderRadius: '10px',
                border: '1px solid var(--border)', fontSize: '13px',
                fontFamily: 'var(--font-body)', background: 'var(--surface)',
                color: 'var(--text-primary)', outline: 'none',
                boxSizing: 'border-box', marginBottom: '16px'
              }}
            />

            <div
              onClick={() => setAgreed(!agreed)}
              style={{
                display: 'flex', alignItems: 'flex-start', gap: '10px',
                padding: '12px 14px', borderRadius: '10px', background: 'var(--surface-2)',
                border: agreed ? '1px solid var(--flame)' : '1px solid var(--border)',
                cursor: 'pointer', marginBottom: '16px'
              }}
            >
              <div style={{
                width: '18px', height: '18px', borderRadius: '4px', flexShrink: 0,
                border: `2px solid ${agreed ? 'var(--flame)' : 'var(--border)'}`,
                background: agreed ? 'var(--flame)' : 'transparent',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                marginTop: '1px'
              }}>
                {agreed && <span style={{ color: 'white', fontSize: '12px', lineHeight: 1 }}>✓</span>}
              </div>
              <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: 1.5, margin: 0 }}>
                I confirm this content glorifies God and is appropriate for a Christian community.
                No profanity, sexual content, or content that dishonors the Lord.{' '}
                <span style={{ fontSize: '11px', color: 'var(--flame)' }}>Ephesians 4:29</span>
              </p>
            </div>

            {error && (
              <pre style={{
                color: '#C0392B', fontSize: '12px', marginBottom: '14px', lineHeight: 1.6,
                background: '#FFF4F4', border: '1px solid #FFD0CC', borderRadius: '10px',
                padding: '12px 14px', whiteSpace: 'pre-wrap', fontFamily: 'var(--font-body)',
                wordBreak: 'break-word'
              }}>
                {error}
              </pre>
            )}

            <button
              onClick={handleUpload}
              disabled={uploading || !file || !caption.trim() || !agreed}
              style={{
                width: '100%', padding: '14px', borderRadius: '100px',
                background: uploading || !file || !caption.trim() || !agreed
                  ? 'var(--border)' : 'var(--flame)',
                color: uploading || !file || !caption.trim() || !agreed
                  ? 'var(--text-muted)' : 'white',
                fontSize: '15px', fontWeight: 600, border: 'none',
                cursor: uploading || !file || !caption.trim() || !agreed ? 'not-allowed' : 'pointer',
                fontFamily: 'var(--font-body)'
              }}
            >
              {uploading ? 'Uploading...' : 'Publish Spark →'}
            </button>
          </>
      </div>
    </div>
  )
}

// ─── Main SparksClient ────────────────────────────────────────────────────────

// ─── Go Live Modal ────────────────────────────────────────────────────────────

function GoLiveModal({ onClose, profile }: { onClose: () => void; profile: any }) {
  const [title, setTitle] = useState('')
  const [streamUrl, setStreamUrl] = useState('')
  const [going, setGoing] = useState(false)
  const [liveLink, setLiveLink] = useState('')
  const supabase = createClient()

  const handleGoLive = async () => {
    if (!title.trim()) return
    setGoing(true)
    const { data } = await supabase.from('live_streams').insert({
      host_id: profile.id,
      title: title.trim(),
      stream_url: streamUrl.trim() || null,
      status: 'live',
    }).select('id').single()
    if (data?.id) {
      setLiveLink(`${window.location.origin}/live/${data.id}`)
    }
    setGoing(false)
  }

  return (
    <div style={{
      position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)',
      display: 'flex', alignItems: 'flex-end', justifyContent: 'center', zIndex: 200,
    }}>
      <div style={{
        background: 'var(--surface)', borderRadius: '20px 20px 0 0',
        padding: '20px 24px 48px', maxWidth: '540px', width: '100%',
        maxHeight: '85dvh', overflowY: 'auto', position: 'relative',
      }}>
        <div style={{ width: 40, height: 4, background: 'var(--border)', borderRadius: 2, margin: '0 auto 16px' }} />
        <button onClick={onClose} style={{
          position: 'absolute', top: '16px', right: '16px',
          background: 'var(--surface-2)', border: 'none', borderRadius: '50%',
          width: '36px', height: '36px', cursor: 'pointer',
          fontSize: '20px', color: 'var(--text-secondary)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>×</button>

        <div style={{ marginBottom: '6px', display: 'flex', alignItems: 'center', gap: '10px' }}>
          <span style={{
            background: '#E24B4A', color: 'white', fontSize: '11px', fontWeight: 700,
            padding: '2px 10px', borderRadius: '100px', letterSpacing: '0.06em'
          }}>
            ● LIVE
          </span>
          <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '22px', fontWeight: 500, color: 'var(--text-primary)' }}>
            Go Live
          </h2>
        </div>
        <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '24px', lineHeight: 1.6 }}>
          Start a live service, sermon, or worship session. Your community will see you live in Sparks.
        </p>

        {liveLink ? (
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '48px', marginBottom: '12px' }}>📡</div>
            <p style={{ fontFamily: 'var(--font-display)', fontSize: '18px', color: 'var(--text-primary)', marginBottom: '8px' }}>
              You are live!
            </p>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '16px', lineHeight: 1.6 }}>
              Share this link with your congregation or start streaming with OBS/YouTube Live and paste the URL below.
            </p>
            <div style={{ background: 'var(--surface-2)', padding: '12px 16px', borderRadius: '10px', marginBottom: '16px', wordBreak: 'break-all', fontSize: '13px', color: 'var(--flame)', fontFamily: 'var(--font-body)' }}>
              {liveLink}
            </div>
            <button
              onClick={() => { navigator.clipboard.writeText(liveLink) }}
              style={{ width: '100%', padding: '13px', borderRadius: '100px', background: 'var(--flame)', color: 'white', border: 'none', fontSize: '14px', fontWeight: 600, cursor: 'pointer', fontFamily: 'var(--font-body)' }}
            >
              Copy live link →
            </button>
          </div>
        ) : (
          <>
            <input
              type="text"
              placeholder="Title (e.g. Sunday Worship — Live)"
              value={title}
              onChange={e => setTitle(e.target.value)}
              style={{ width: '100%', padding: '13px 16px', borderRadius: '10px', border: '1px solid var(--border)', fontSize: '15px', fontFamily: 'var(--font-display)', background: 'var(--surface)', color: 'var(--text-primary)', outline: 'none', boxSizing: 'border-box', marginBottom: '12px' }}
            />
            <input
              type="url"
              placeholder="YouTube Live / streaming URL (optional)"
              value={streamUrl}
              onChange={e => setStreamUrl(e.target.value)}
              style={{ width: '100%', padding: '13px 16px', borderRadius: '10px', border: '1px solid var(--border)', fontSize: '14px', fontFamily: 'var(--font-body)', background: 'var(--surface)', color: 'var(--text-primary)', outline: 'none', boxSizing: 'border-box', marginBottom: '16px' }}
            />
            <div style={{ padding: '12px 14px', borderRadius: '10px', background: 'var(--surface-2)', marginBottom: '20px' }}>
              <p style={{ fontSize: '12px', color: 'var(--text-secondary)', lineHeight: 1.6, margin: 0 }}>
                💡 <strong>How it works:</strong> Click Go Live below to create your room. Then stream using YouTube Live, Zoom, or OBS and paste the link above so your congregation can watch directly inside Ijwi.
              </p>
            </div>
            <button
              onClick={handleGoLive}
              disabled={going || !title.trim()}
              style={{ width: '100%', padding: '14px', borderRadius: '100px', background: going || !title.trim() ? 'var(--border)' : '#E24B4A', color: going || !title.trim() ? 'var(--text-muted)' : 'white', border: 'none', fontSize: '15px', fontWeight: 600, cursor: going || !title.trim() ? 'not-allowed' : 'pointer', fontFamily: 'var(--font-body)' }}
            >
              {going ? 'Creating room...' : '● Go Live now →'}
            </button>
          </>
        )}
      </div>
    </div>
  )
}

export default function SparksClient({
  sparks,
  profile,
  currentUserId,
  isPro,
  userSparksCount,
  accountAgeDays,
  userReactionMap,
}: SparksClientProps) {
  const [showUpload, setShowUpload] = useState(false)
  const [showGoLive, setShowGoLive] = useState(false)
  const [uploaded, setUploaded] = useState(false)
  const router = useRouter()

  const handleUploaded = () => {
    setShowUpload(false)
    setUploaded(true)
    setTimeout(() => {
      router.refresh()
      setUploaded(false)
    }, 2000)
  }

  return (
    <div style={{ minHeight: '100vh', background: 'var(--ij-bg-base)' }}>
      <Navbar profile={profile} />

      {/* Page header */}
      <div style={{
        maxWidth: 1280, margin: '0 auto',
        padding: '28px 24px 0',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
          <div>
            <h1 style={{
              fontFamily: 'var(--ij-font-display)', fontSize: 'clamp(1.6rem, 3vw, 2.2rem)',
              fontWeight: 700, color: 'var(--ij-text-primary)', marginBottom: 4,
            }}>
              Sparks ✨
            </h1>
            <p style={{ fontSize: '0.88rem', color: 'var(--ij-text-secondary)', lineHeight: 1.5 }}>
              Moments of faith — testimonies, worship, and the Word in motion.
            </p>
          </div>
          <div style={{ display: 'flex', gap: 10, flexShrink: 0 }}>
            {currentUserId && (
              <>
                <button
                  onClick={() => setShowGoLive(true)}
                  style={{
                    padding: '9px 18px', borderRadius: 999,
                    background: 'transparent', color: '#E24B4A', fontSize: '13px',
                    fontWeight: 600, border: '1px solid rgba(226,75,74,0.4)', cursor: 'pointer',
                    fontFamily: 'var(--ij-font-body)',
                    display: 'flex', alignItems: 'center', gap: 6,
                  }}
                >
                  <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#E24B4A', display: 'inline-block' }} />
                  Go Live
                </button>
                <button
                  onClick={() => setShowUpload(true)}
                  style={{
                    padding: '9px 20px', borderRadius: 999,
                    background: 'linear-gradient(135deg, #C9860A, #F0A832)',
                    color: '#0C0916', fontSize: '13px', fontWeight: 700,
                    border: 'none', cursor: 'pointer', fontFamily: 'var(--ij-font-body)',
                  }}
                >
                  + Share a Spark
                </button>
              </>
            )}
            {!currentUserId && (
              <Link href="/auth/signup" style={{
                display: 'inline-block', padding: '9px 20px', borderRadius: 999,
                background: 'linear-gradient(135deg, #C9860A, #F0A832)',
                color: '#0C0916', fontSize: '13px', fontWeight: 700,
                textDecoration: 'none', fontFamily: 'var(--ij-font-body)',
              }}>
                Join to post
              </Link>
            )}
          </div>
        </div>

        {/* Grid */}
        {sparks.length === 0 ? (
          <div style={{
            textAlign: 'center', padding: '80px 20px',
          }}>
            <div style={{ fontSize: '64px', marginBottom: '20px' }}>✨</div>
            <h2 style={{
              fontFamily: 'var(--ij-font-display)', fontSize: '24px',
              color: 'var(--ij-text-primary)', marginBottom: '12px', fontWeight: 500
            }}>
              No sparks yet
            </h2>
            <p style={{ fontSize: '15px', color: 'var(--ij-text-secondary)', lineHeight: 1.6, marginBottom: '28px' }}>
              Be the first to share a moment of faith.
            </p>
            {currentUserId && (
              <button
                onClick={() => setShowUpload(true)}
                style={{
                  padding: '14px 32px', borderRadius: '100px',
                  background: 'var(--flame)', color: 'white', border: 'none',
                  fontSize: '15px', fontWeight: 600, cursor: 'pointer',
                  fontFamily: 'var(--ij-font-body)'
                }}
              >
                Post the first one →
              </button>
            )}
          </div>
        ) : (
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 1fr)',
            gap: 12,
            paddingBottom: 80,
          }}
          className="sparks-grid"
          >
            {sparks.map(spark => (
              <SparkCard
                key={spark.id}
                spark={spark}
                currentUserId={currentUserId}
                initialReactions={userReactionMap[spark.id] ?? []}
              />
            ))}
          </div>
        )}

        {/* Upload success toast */}
        {uploaded && (
          <div style={{
            position: 'fixed', bottom: '80px', left: '50%',
            transform: 'translateX(-50%)',
            background: 'var(--ij-gold)', color: '#0C0916',
            padding: '12px 24px', borderRadius: '100px',
            fontSize: '14px', fontWeight: 600, zIndex: 100,
            boxShadow: '0 8px 24px rgba(240,168,50,0.35)',
          }}>
            ✨ Spark published — glory to God!
          </div>
        )}
      </div>

      {/* Upload modal */}
      {showUpload && currentUserId && (
        <UploadModal
          currentUserId={currentUserId}
          isPro={isPro}
          userSparksCount={userSparksCount}
          accountAgeDays={accountAgeDays}
          onClose={() => setShowUpload(false)}
          onUploaded={handleUploaded}
        />
      )}

      {/* Go Live modal */}
      {showGoLive && profile && (
        <GoLiveModal
          profile={profile}
          onClose={() => setShowGoLive(false)}
        />
      )}
    </div>
  )
}
