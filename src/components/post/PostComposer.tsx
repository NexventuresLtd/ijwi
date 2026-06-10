'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { ContentType } from '@/lib/types'
import { containsProfanity, MODERATION_MESSAGE } from '@/lib/moderation'
import { scriptureMatch } from '@/lib/utils'

// ── Compress image on client before upload ────────────────────────────────────
async function compressImage(file: File, maxPx = 1600, quality = 0.82): Promise<File> {
  return new Promise(resolve => {
    const reader = new FileReader()
    reader.onload = e => {
      const img = new Image()
      img.onload = () => {
        const scale = Math.min(1, maxPx / Math.max(img.width, img.height))
        const canvas = document.createElement('canvas')
        canvas.width = Math.round(img.width * scale)
        canvas.height = Math.round(img.height * scale)
        canvas.getContext('2d')!.drawImage(img, 0, 0, canvas.width, canvas.height)
        canvas.toBlob(blob => {
          if (!blob) { resolve(file); return }
          resolve(new File([blob], file.name.replace(/\.\w+$/, '.jpg'), { type: 'image/jpeg' }))
        }, 'image/jpeg', quality)
      }
      img.src = e.target!.result as string
    }
    reader.readAsDataURL(file)
  })
}

// ── Post type tiles ───────────────────────────────────────────────────────────
const TILES: {
  type: ContentType
  icon: string
  label: string
  desc: string
  href?: string
}[] = [
  { type: 'short',       icon: '📹', label: 'Short Video',   desc: 'Share a video moment',         href: '/shorts' },
  { type: 'story',       icon: '📷', label: 'Photo',         desc: 'Image + caption'               },
  { type: 'spoken_word', icon: '🎙️', label: 'Spoken Word',   desc: 'Record or upload your voice'   },
  { type: 'question',    icon: '💭', label: 'Question',      desc: 'Ask the community'             },
]

const PLACEHOLDERS: Partial<Record<ContentType, string>> = {
  story:       'Write your caption...',
  spoken_word: 'Describe your voice message — what is God laying on your heart?',
  question:    'Ask it honestly. God is not afraid of your questions — and neither is this community.',
}

interface ComposerProps {
  onClose?: () => void
  onPost?: () => void
  initialType?: ContentType
}

export default function PostComposer({ onClose, onPost, initialType }: ComposerProps) {
  const router = useRouter()
  const [step, setStep] = useState<1 | 2>(initialType ? 2 : 1)
  const [contentType, setContentType] = useState<ContentType | null>(initialType ?? null)
  const [body, setBody] = useState('')
  const [isAnonymous, setIsAnonymous] = useState(false)
  const [imageFile, setImageFile] = useState<File | null>(null)
  const [imagePreview, setImagePreview] = useState<string | null>(null)
  const [audioFile, setAudioFile] = useState<File | null>(null)
  const [loading, setLoading] = useState(false)
  const [uploadProgress, setUploadProgress] = useState(0)
  const [error, setError] = useState('')
  const [showSuccess, setShowSuccess] = useState(false)
  const [suggestedVerse, setSuggestedVerse] = useState<{ ref: string; text: string } | null>(null)
  const [verseDismissed, setVerseDismissed] = useState(false)
  const imageInputRef = useRef<HTMLInputElement>(null)
  const audioInputRef = useRef<HTMLInputElement>(null)
  const supabase = createClient()

  const isPhoto = contentType === 'story'
  const isAudio = contentType === 'spoken_word'
  const isQuestion = contentType === 'question'

  const handleSelectType = (type: ContentType) => {
    if (type === 'short') return
    setContentType(type)
    setStep(2)
  }

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (file.size > 20 * 1024 * 1024) { setError('Image must be under 20 MB.'); return }
    setImageFile(file)
    setImagePreview(URL.createObjectURL(file))
    setError('')
  }

  const handleAudioSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (file.size > 50 * 1024 * 1024) { setError('Audio file must be under 50 MB.'); return }
    setAudioFile(file)
    setError('')
  }

  const handlePost = async () => {
    if (!contentType) return
    if (isPhoto && !imageFile && !body.trim()) { setError('Add a photo or write a caption.'); return }
    if (isAudio && !audioFile && !body.trim()) { setError('Upload an audio file or write something.'); return }
    if (isQuestion && !body.trim()) { setError('Write your question first.'); return }

    const bodyCheck = containsProfanity(body)
    if (bodyCheck.blocked) { setError(MODERATION_MESSAGE); return }

    setLoading(true)
    setUploadProgress(0)
    setError('')

    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { router.push('/auth/login'); return }

    // Upload image (compress first)
    let imageUrl: string | null = null
    if (imageFile) {
      setUploadProgress(10)
      const compressed = await compressImage(imageFile)
      const ext = 'jpg'
      const path = `${user.id}/${Date.now()}.${ext}`
      const { data: up, error: upErr } = await supabase.storage
        .from('images')
        .upload(path, compressed, { contentType: 'image/jpeg', cacheControl: '3600' })
      if (upErr) {
        const msg = upErr.message ?? ''
        if (msg.includes('row-level security') || msg.includes('policy') || msg.includes('not authorized')) {
          setError('Upload failed: storage permissions not configured. Check Supabase Storage → images bucket → Policies.')
        } else if (msg.includes('Bucket not found') || msg.includes('not found')) {
          setError('Storage bucket "images" not found. Go to Supabase → Storage → New bucket → "images" → Public.')
        } else {
          setError('Image upload failed: ' + msg)
        }
        setLoading(false); return
      }
      imageUrl = supabase.storage.from('images').getPublicUrl(up.path).data.publicUrl
      setUploadProgress(60)
    }

    // Upload audio
    let audioUrl: string | null = null
    if (audioFile) {
      setUploadProgress(10)
      const ext = audioFile.name.split('.').pop() ?? 'mp3'
      const path = `${user.id}/${Date.now()}.${ext}`
      const { data: up, error: upErr } = await supabase.storage
        .from('voices')
        .upload(path, audioFile, { contentType: audioFile.type, cacheControl: '3600' })
      if (upErr) {
        const msg = upErr.message ?? ''
        if (msg.includes('Bucket not found') || msg.includes('not found')) {
          setError('Storage bucket "voices" not found. Go to Supabase → Storage → New bucket → name it "voices" → Public → Save.')
        } else {
          setError('Audio upload failed: ' + msg)
        }
        setLoading(false)
        return
      }
      audioUrl = supabase.storage.from('voices').getPublicUrl(up.path).data.publicUrl
      setUploadProgress(60)
    }

    setUploadProgress(75)

    // Scripture suggestion for question type
    const verseMatch = isQuestion && !verseDismissed ? scriptureMatch(body) : null

    const { error: postError } = await supabase.from('posts').insert({
      author_id: user.id,
      content_type: contentType,
      body: body.trim() || (isPhoto ? '' : body.trim()),
      is_anonymous: isAnonymous,
      status: 'published',
      tags: [],
      reaction_fire: 0, reaction_amen: 0, reaction_healed: 0,
      reaction_needed: 0, reaction_sharing: 0,
      ...(imageUrl ? { image_url: imageUrl } : {}),
      ...(audioUrl ? { audio_url: audioUrl } : {}),
      ...(verseMatch ? { verse_reference: verseMatch.ref, verse_text: verseMatch.text } : {}),
    })

    if (postError) { setError(postError.message); setLoading(false); return }

    setUploadProgress(100)

    // Award XP
    const { data: prof } = await supabase.from('profiles').select('xp').eq('id', user.id).single()
    if (prof) {
      const newXp = (prof.xp ?? 0) + 10
      const level = newXp >= 3000 ? 'pillar' : newXp >= 1500 ? 'prophet' : newXp >= 700 ? 'flame' : newXp >= 300 ? 'voice' : newXp >= 100 ? 'believer' : 'seeker'
      await supabase.from('profiles').update({ xp: newXp, level }).eq('id', user.id)
    }

    setShowSuccess(true)
    setTimeout(() => {
      if (onPost) onPost()
      else if (isQuestion) router.push('/feed?tab=Questions')
      else router.push('/feed')
    }, 1200)
  }

  if (showSuccess) {
    return (
      <div className="card modal-enter" style={{ padding: '60px 40px', maxWidth: '520px', width: '100%', textAlign: 'center' }}>
        <div style={{ fontSize: '56px', marginBottom: '20px' }}>✨</div>
        <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '26px', fontWeight: 500, color: 'var(--text-primary)', marginBottom: '10px' }}>
          {isQuestion ? 'Question posted!' : 'Your voice is out there'}
        </h2>
        <p style={{ fontSize: '15px', color: 'var(--text-secondary)' }}>
          {isQuestion ? 'The community will see it in the Questions tab.' : 'Someone needed to hear what you just shared.'}
        </p>
      </div>
    )
  }

  return (
    <div className="card modal-enter" style={{ padding: '0', maxWidth: '540px', width: '100%', overflow: 'hidden', maxHeight: '90dvh', display: 'flex', flexDirection: 'column' }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '18px 24px', borderBottom: '1px solid var(--border)', flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          {step === 2 && !initialType && (
            <button onClick={() => setStep(1)} style={{ background: 'none', border: 'none', color: 'var(--text-muted)', fontSize: '18px', cursor: 'pointer', padding: 0 }}>←</button>
          )}
          <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '20px', fontWeight: 500, color: 'var(--text-primary)' }}>
            {step === 1 ? 'Share your voice' : isPhoto ? '📷 Photo' : isAudio ? '🎙️ Spoken Word' : isQuestion ? '💭 Question' : 'Share'}
          </h2>
        </div>
        {onClose && (
          <button onClick={onClose} style={{ background: 'var(--surface-2)', border: 'none', width: '32px', height: '32px', borderRadius: '50%', fontSize: '18px', cursor: 'pointer', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>×</button>
        )}
      </div>

      {/* STEP 1: Type picker */}
      {step === 1 && (
        <div style={{ padding: '24px', overflowY: 'auto', flex: 1 }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            {TILES.map(({ type, icon, label, desc, href }) => {
              const style: React.CSSProperties = {
                padding: '20px 14px', borderRadius: '16px',
                border: '1px solid var(--border)', background: 'var(--surface)',
                cursor: 'pointer', textAlign: 'center',
                display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '10px',
                textDecoration: 'none', transition: 'all 0.15s',
              }
              const inner = (
                <>
                  <span style={{ fontSize: '32px', lineHeight: 1 }}>{icon}</span>
                  <div>
                    <div style={{ fontSize: '14px', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '3px' }}>{label}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)', lineHeight: 1.4 }}>{desc}</div>
                  </div>
                </>
              )
              if (href) return (
                <Link key={type} href={href} onClick={onClose} style={style}>{inner}</Link>
              )
              return (
                <button key={type} onClick={() => handleSelectType(type)} style={style}
                  onMouseEnter={e => { (e.currentTarget as HTMLButtonElement).style.borderColor = 'var(--flame)'; (e.currentTarget as HTMLButtonElement).style.background = 'var(--flame-soft)' }}
                  onMouseLeave={e => { (e.currentTarget as HTMLButtonElement).style.borderColor = 'var(--border)'; (e.currentTarget as HTMLButtonElement).style.background = 'var(--surface)' }}
                >
                  {inner}
                </button>
              )
            })}
          </div>
        </div>
      )}

      {/* STEP 2: Compose */}
      {step === 2 && contentType && (
        <div style={{ padding: '24px', overflowY: 'auto', flex: 1 }}>

          {/* Anonymous toggle */}
          <div onClick={() => setIsAnonymous(!isAnonymous)} style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '12px 16px', borderRadius: '10px', background: 'var(--surface-2)', marginBottom: '18px', cursor: 'pointer', border: isAnonymous ? '1px solid var(--flame)' : '1px solid transparent' }}>
            <div style={{ width: '36px', height: '20px', borderRadius: '100px', background: isAnonymous ? 'var(--flame)' : 'var(--border)', position: 'relative', transition: 'background 0.2s', flexShrink: 0 }}>
              <div style={{ width: '16px', height: '16px', borderRadius: '50%', background: 'white', position: 'absolute', top: '2px', left: isAnonymous ? '18px' : '2px', transition: 'left 0.2s' }} />
            </div>
            <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)' }}>
              {isAnonymous ? 'Posting anonymously' : 'Posting as yourself'}
            </div>
          </div>

          {/* PHOTO: image first */}
          {isPhoto && (
            <div style={{ marginBottom: '14px' }}>
              <input ref={imageInputRef} type="file" accept="image/jpeg,image/png,image/webp,image/heic" onChange={handleImageSelect} style={{ display: 'none' }} />
              {imagePreview ? (
                <div style={{ position: 'relative' }}>
                  <img src={imagePreview} alt="Preview" style={{ width: '100%', maxHeight: '300px', objectFit: 'cover', borderRadius: '12px', border: '1px solid var(--border)', display: 'block' }} />
                  <button type="button" onClick={() => { setImageFile(null); setImagePreview(null); if (imageInputRef.current) imageInputRef.current.value = '' }}
                    style={{ position: 'absolute', top: '8px', right: '8px', width: '28px', height: '28px', borderRadius: '50%', background: 'rgba(0,0,0,0.6)', border: 'none', color: 'white', cursor: 'pointer', fontSize: '14px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>×</button>
                </div>
              ) : (
                <button type="button" onClick={() => imageInputRef.current?.click()} style={{ width: '100%', padding: '40px 20px', borderRadius: '12px', border: '2px dashed var(--border)', background: 'var(--surface-2)', cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '10px', color: 'var(--text-muted)' }}>
                  <span style={{ fontSize: '40px' }}>📷</span>
                  <div style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-secondary)' }}>Tap to add a photo</div>
                  <div style={{ fontSize: '12px' }}>JPEG, PNG, WEBP — auto-compressed</div>
                </button>
              )}
            </div>
          )}

          {/* AUDIO: voice upload */}
          {isAudio && (
            <div style={{ marginBottom: '14px' }}>
              <input ref={audioInputRef} type="file" accept="audio/mp3,audio/mpeg,audio/wav,audio/m4a,audio/ogg,audio/*" onChange={handleAudioSelect} style={{ display: 'none' }} />
              {audioFile ? (
                <div style={{ padding: '12px 16px', borderRadius: '12px', background: 'var(--surface-2)', border: '1px solid var(--flame)', display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px' }}>
                  <span style={{ fontSize: '24px' }}>🎙️</span>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{audioFile.name}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{(audioFile.size / 1024 / 1024).toFixed(1)} MB</div>
                  </div>
                  <button type="button" onClick={() => { setAudioFile(null); if (audioInputRef.current) audioInputRef.current.value = '' }} style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', fontSize: '18px' }}>×</button>
                </div>
              ) : (
                <button type="button" onClick={() => audioInputRef.current?.click()} style={{ width: '100%', padding: '32px 20px', borderRadius: '12px', border: '2px dashed var(--border)', background: 'var(--surface-2)', cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '10px', color: 'var(--text-muted)', marginBottom: '8px' }}>
                  <span style={{ fontSize: '36px' }}>🎙️</span>
                  <div style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-secondary)' }}>Upload voice message</div>
                  <div style={{ fontSize: '12px' }}>MP3, WAV, M4A — max 50 MB</div>
                </button>
              )}
            </div>
          )}

          {/* Body text */}
          <div style={{ position: 'relative', marginBottom: '14px' }}>
            <textarea
              placeholder={isPhoto ? 'Write a caption...' : isAudio ? 'Describe what you shared...' : isQuestion ? 'Ask your question honestly...' : 'Share your voice...'}
              value={body}
              onChange={e => {
                setBody(e.target.value)
                if (isQuestion && !verseDismissed) setSuggestedVerse(scriptureMatch(e.target.value))
              }}
              rows={isPhoto ? 3 : 6}
              style={{ width: '100%', padding: '14px 16px', borderRadius: '10px', border: '1px solid var(--border)', lineHeight: 1.75, fontSize: '15px', fontFamily: isAudio ? 'var(--font-display)' : 'var(--font-body)', background: 'var(--surface)', color: 'var(--text-primary)', outline: 'none', resize: 'vertical', boxSizing: 'border-box' }}
            />
          </div>

          {/* Scripture suggestion for questions */}
          {suggestedVerse && !verseDismissed && (
            <div style={{ marginBottom: '14px', padding: '12px 16px', borderRadius: '10px', background: 'var(--surface-2)', borderLeft: '3px solid var(--flame)', display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: '12px' }}>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: '10px', fontWeight: 700, color: 'var(--flame)', letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: '5px' }}>Scripture ✨</div>
                <p style={{ fontSize: '13px', fontStyle: 'italic', color: 'var(--text-secondary)', lineHeight: 1.55, marginBottom: '4px' }}>"{suggestedVerse.text}"</p>
                <span style={{ fontSize: '12px', color: 'var(--flame)', fontWeight: 600 }}>— {suggestedVerse.ref}</span>
              </div>
              <button type="button" onClick={() => { setVerseDismissed(true); setSuggestedVerse(null) }} style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', fontSize: '16px' }}>×</button>
            </div>
          )}

          {/* Upload progress */}
          {loading && uploadProgress > 0 && uploadProgress < 100 && (
            <div style={{ marginBottom: '14px' }}>
              <div style={{ height: '4px', background: 'var(--border)', borderRadius: '2px', overflow: 'hidden' }}>
                <div style={{ height: '100%', background: 'var(--flame)', borderRadius: '2px', width: `${uploadProgress}%`, transition: 'width 0.4s ease' }} />
              </div>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '6px', textAlign: 'center' }}>
                Uploading... {uploadProgress}%
              </p>
            </div>
          )}

          {error && <p style={{ color: '#E24B4A', fontSize: '13px', marginBottom: '12px' }}>{error}</p>}

          <button onClick={handlePost} disabled={loading} style={{ width: '100%', padding: '14px', borderRadius: '100px', background: loading ? 'var(--border)' : 'var(--flame)', color: loading ? 'var(--text-muted)' : 'white', fontSize: '15px', fontWeight: 600, border: 'none', cursor: loading ? 'not-allowed' : 'pointer', fontFamily: 'var(--font-body)' }}>
            {loading ? (uploadProgress > 0 ? `Uploading ${uploadProgress}%...` : 'Publishing...') : isQuestion ? 'Post question →' : isPhoto ? 'Post photo →' : isAudio ? 'Post voice →' : 'Publish →'}
          </button>

          {isQuestion && (
            <p style={{ fontSize: '12px', color: 'var(--text-muted)', textAlign: 'center', marginTop: '10px' }}>
              Only approved voices can answer. Everyone can react and pray.
            </p>
          )}
        </div>
      )}
    </div>
  )
}
