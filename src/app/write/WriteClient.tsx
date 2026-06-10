'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import dynamic from 'next/dynamic'
import { createClient } from '@/lib/supabase/client'

const EssayEditor = dynamic(() => import('@/components/editor/EssayEditor'), { ssr: false })

interface Profile {
  id: string
  voice_name: string
  avatar_url?: string
  is_revealed: boolean
}

const CONTENT_TYPES = [
  { value: 'story', label: 'Story' },
  { value: 'devotional', label: 'Devotional' },
  { value: 'letter', label: 'Letter' },
  { value: 'encouragement', label: 'Encouragement' },
]

const TAGS_SUGGESTIONS = ['faith', 'healing', 'testimony', 'prayer', 'worship', 'grace', 'hope', 'Rwanda', 'youth', 'Africa']

export default function WriteClient({ profile }: { profile: Profile | null }) {
  const router = useRouter()
  const supabase = createClient()

  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [contentType, setContentType] = useState('story')
  const [tags, setTags] = useState<string[]>([])
  const [tagInput, setTagInput] = useState('')
  const [isAnonymous, setIsAnonymous] = useState(false)
  const [verseRef, setVerseRef] = useState('')
  const [verseText, setVerseText] = useState('')
  const [coverFile, setCoverFile] = useState<File | null>(null)
  const [coverPreview, setCoverPreview] = useState<string | null>(null)
  const [musicFile, setMusicFile] = useState<File | null>(null)
  const [musicName, setMusicName] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const musicInputRef = useRef<HTMLInputElement>(null)
  const coverInputRef = useRef<HTMLInputElement>(null)

  const addTag = (t: string) => {
    const clean = t.trim().toLowerCase().replace(/\s+/g, '-')
    if (clean && !tags.includes(clean) && tags.length < 5) setTags([...tags, clean])
    setTagInput('')
  }

  const handleCoverChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0]
    if (!f) return
    setCoverFile(f)
    setCoverPreview(URL.createObjectURL(f))
  }

  const handleMusicChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0]
    if (!f) return
    setMusicFile(f)
    setMusicName(f.name.replace(/\.[^.]+$/, ''))
  }

  const handleSubmit = async () => {
    if (!title.trim()) { setError('Please add a title.'); return }
    if (!body || body === '<p></p>') { setError('Please write something.'); return }
    setLoading(true)
    setError('')

    try {
      let image_url: string | undefined
      let audio_url: string | undefined

      if (coverFile) {
        const ext = coverFile.name.split('.').pop()
        const path = `posts/${Date.now()}-cover.${ext}`
        const { error: upErr } = await supabase.storage.from('images').upload(path, coverFile)
        if (upErr) throw new Error(`Cover upload: ${upErr.message}`)
        const { data: { publicUrl } } = supabase.storage.from('images').getPublicUrl(path)
        image_url = publicUrl
      }

      if (musicFile) {
        const ext = musicFile.name.split('.').pop()
        const path = `essays/${Date.now()}-music.${ext}`
        const { error: upErr } = await supabase.storage.from('voices').upload(path, musicFile)
        if (upErr) throw new Error(`Music upload: ${upErr.message}`)
        const { data: { publicUrl } } = supabase.storage.from('voices').getPublicUrl(path)
        audio_url = publicUrl
      }

      const { data: post, error: insertErr } = await supabase
        .from('posts')
        .insert({
          content_type: contentType,
          title: title.trim(),
          body,
          is_anonymous: isAnonymous,
          tags,
          verse_reference: verseRef.trim() || null,
          verse_text: verseText.trim() || null,
          image_url: image_url ?? null,
          audio_url: audio_url ?? null,
        })
        .select('id')
        .single()

      if (insertErr) throw new Error(insertErr.message)
      router.push(`/post/${post.id}`)
    } catch (err: any) {
      setError(err.message)
    }
    setLoading(false)
  }

  return (
    <div style={{ minHeight: '100vh', background: 'var(--ij-bg-base)' }}>
      {/* ── Sticky top bar ── */}
      <div style={{
        position: 'sticky', top: 0, zIndex: 50,
        background: 'var(--ij-bg-nav)',
        borderBottom: '1px solid var(--ij-border)',
        backdropFilter: 'blur(16px)',
        WebkitBackdropFilter: 'blur(16px)',
        height: 56,
        display: 'flex', alignItems: 'center',
        padding: '0 16px', gap: 12,
      }}>
        <button
          onClick={() => router.back()}
          style={{
            background: 'none', border: 'none', cursor: 'pointer',
            color: 'var(--ij-text-secondary)', padding: '6px 8px',
            borderRadius: 10, display: 'flex', alignItems: 'center',
            transition: 'color 0.15s',
          }}
          onMouseEnter={e => (e.currentTarget.style.color = 'var(--ij-text-primary)')}
          onMouseLeave={e => (e.currentTarget.style.color = 'var(--ij-text-secondary)')}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M19 12H5M12 5l-7 7 7 7"/>
          </svg>
        </button>

        <span style={{
          flex: 1, textAlign: 'center',
          fontFamily: 'var(--ij-font-display)', fontSize: '15px', fontWeight: 700,
          color: 'var(--ij-text-primary)', letterSpacing: '0.3px',
        }}>
          Write
        </span>

        <button
          onClick={handleSubmit}
          disabled={loading}
          style={{
            padding: '8px 20px', borderRadius: 999, border: 'none',
            background: loading
              ? 'var(--ij-bg-elevated)'
              : 'linear-gradient(135deg, #C9860A 0%, #F0A832 100%)',
            color: loading ? 'var(--ij-text-hint)' : '#0C0916',
            fontFamily: 'var(--ij-font-body)', fontSize: '13px', fontWeight: 700,
            cursor: loading ? 'default' : 'pointer',
            boxShadow: loading ? 'none' : '0 2px 12px rgba(240,168,50,0.35)',
            transition: 'all 0.2s',
          }}
        >
          {loading ? 'Publishing…' : 'Publish →'}
        </button>
      </div>

      {/* ── Content ── */}
      <div style={{ maxWidth: 720, margin: '0 auto', padding: '36px 24px 100px' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 22 }}>

          {/* Content type */}
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {CONTENT_TYPES.map(ct => (
              <button
                key={ct.value}
                type="button"
                onClick={() => setContentType(ct.value)}
                className={`ij-chip${contentType === ct.value ? ' active' : ''}`}
              >
                {ct.label}
              </button>
            ))}
          </div>

          {/* Title */}
          <input
            value={title}
            onChange={e => setTitle(e.target.value)}
            placeholder="Your title…"
            style={{
              fontFamily: 'var(--ij-font-display)',
              fontSize: 'clamp(1.5rem, 4vw, 2.1rem)',
              fontWeight: 700,
              color: 'var(--ij-text-primary)',
              background: 'transparent',
              border: 'none',
              borderBottom: '1px solid var(--ij-border)',
              outline: 'none',
              width: '100%',
              paddingBottom: 12,
              lineHeight: 1.3,
            }}
          />

          {/* Cover image */}
          <div>
            {coverPreview ? (
              <div style={{ position: 'relative', width: '100%', aspectRatio: '16/7', borderRadius: 'var(--ij-radius-md)', overflow: 'hidden', marginBottom: 4 }}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={coverPreview} alt="Cover" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                <button
                  type="button"
                  onClick={() => { setCoverFile(null); setCoverPreview(null) }}
                  style={{ position: 'absolute', top: 8, right: 8, background: 'rgba(0,0,0,0.55)', border: 'none', color: 'white', borderRadius: '50%', width: 28, height: 28, cursor: 'pointer', fontSize: 14 }}
                >×</button>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => coverInputRef.current?.click()}
                style={{
                  width: '100%', padding: '14px', borderRadius: 'var(--ij-radius-md)',
                  border: '1px dashed var(--ij-border)', background: 'transparent',
                  color: 'var(--ij-text-secondary)', fontSize: '13px', cursor: 'pointer',
                  fontFamily: 'var(--ij-font-body)', transition: 'border-color 0.15s',
                }}
                onMouseEnter={e => e.currentTarget.style.borderColor = 'var(--ij-border-gold)'}
                onMouseLeave={e => e.currentTarget.style.borderColor = 'var(--ij-border)'}
              >
                + Add cover image (optional)
              </button>
            )}
            <input ref={coverInputRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={handleCoverChange} />
          </div>

          {/* Verse highlight */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: 10 }}>
            <input
              className="ij-auth-input"
              value={verseRef}
              onChange={e => setVerseRef(e.target.value)}
              placeholder="Verse ref (e.g. Psalm 23:1)"
            />
            <input
              className="ij-auth-input"
              value={verseText}
              onChange={e => setVerseText(e.target.value)}
              placeholder="Verse text (optional)"
            />
          </div>

          {/* Essay body */}
          <EssayEditor
            content={body}
            onChange={setBody}
            placeholder="Begin writing your essay…"
          />

          {/* Background music */}
          <div style={{ background: 'var(--ij-bg-elevated)', borderRadius: 'var(--ij-radius-md)', padding: '14px 16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: musicFile ? 8 : 0 }}>
              <div>
                <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-primary)' }}>Background music</div>
                <div style={{ fontSize: '11px', color: 'var(--ij-text-secondary)' }}>Plays softly while readers read</div>
              </div>
              <button
                type="button"
                onClick={() => musicInputRef.current?.click()}
                style={{
                  fontSize: '12px', padding: '6px 14px', borderRadius: 999,
                  border: '1px solid var(--ij-border-gold)', background: 'transparent',
                  color: 'var(--ij-gold)', cursor: 'pointer', fontFamily: 'var(--ij-font-body)', fontWeight: 600,
                }}
              >
                {musicFile ? 'Change' : '+ Add music'}
              </button>
              <input ref={musicInputRef} type="file" accept="audio/*" style={{ display: 'none' }} onChange={handleMusicChange} />
            </div>
            {musicFile && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontSize: '16px' }}>🎵</span>
                <span style={{ fontSize: '13px', color: 'var(--ij-text-primary)', flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{musicName}</span>
                <button type="button" onClick={() => { setMusicFile(null); setMusicName('') }} style={{ background: 'none', border: 'none', color: 'var(--ij-text-secondary)', cursor: 'pointer', fontSize: '16px' }}>×</button>
              </div>
            )}
          </div>

          {/* Tags */}
          <div>
            <div style={{ fontSize: '12px', fontWeight: 600, color: 'var(--ij-text-secondary)', marginBottom: 8 }}>Tags (up to 5)</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 10 }}>
              {tags.map(t => (
                <span key={t} style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '4px 10px', borderRadius: 999, background: 'rgba(201,134,10,0.10)', border: '1px solid var(--ij-border-gold)', fontSize: '12px', color: 'var(--ij-gold)' }}>
                  #{t}
                  <button type="button" onClick={() => setTags(tags.filter(x => x !== t))} style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer', lineHeight: 1, padding: 0, fontSize: '14px' }}>×</button>
                </span>
              ))}
            </div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <input
                className="ij-auth-input"
                style={{ flex: 1, minWidth: 160 }}
                value={tagInput}
                onChange={e => setTagInput(e.target.value)}
                onKeyDown={e => { if (e.key === 'Enter' || e.key === ',') { e.preventDefault(); addTag(tagInput) } }}
                placeholder="Add tag…"
              />
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 8 }}>
              {TAGS_SUGGESTIONS.filter(t => !tags.includes(t)).map(t => (
                <button key={t} type="button" onClick={() => addTag(t)} style={{ fontSize: '11px', padding: '3px 9px', borderRadius: 999, border: '1px solid var(--ij-border)', background: 'transparent', color: 'var(--ij-text-secondary)', cursor: 'pointer', fontFamily: 'var(--ij-font-body)' }}>
                  #{t}
                </button>
              ))}
            </div>
          </div>

          {/* Anonymous toggle */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <button
              type="button"
              onClick={() => setIsAnonymous(a => !a)}
              style={{
                width: 42, height: 24, borderRadius: 999, border: 'none', cursor: 'pointer',
                background: isAnonymous ? 'var(--ij-gold)' : 'var(--ij-border)',
                position: 'relative', transition: 'background 0.2s',
              }}
            >
              <span style={{ position: 'absolute', top: 3, left: isAnonymous ? 20 : 3, width: 18, height: 18, borderRadius: '50%', background: 'white', transition: 'left 0.2s' }} />
            </button>
            <span style={{ fontSize: '13px', color: 'var(--ij-text-primary)' }}>Publish anonymously</span>
          </div>

          {error && (
            <div style={{ fontSize: '13px', color: '#E24B4A', padding: '12px 16px', background: 'rgba(226,75,74,0.08)', borderRadius: 8 }}>
              {error}
            </div>
          )}

          <button onClick={handleSubmit} disabled={loading} className="ij-btn-primary">
            {loading ? 'Publishing…' : 'Publish essay →'}
          </button>

        </div>
      </div>
    </div>
  )
}
