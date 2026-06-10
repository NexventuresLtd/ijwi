'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import Navbar from '@/components/layout/Navbar'
import ProfileAvatar from '@/components/ui/ProfileAvatar'
import { Profile } from '@/lib/types'
import { createClient } from '@/lib/supabase/client'
import { timeAgo } from '@/lib/utils'
import { initUserCrypto, importPublicKey, encryptMessage } from '@/lib/crypto'

type DmMessage = {
  id: string
  sender_id: string
  receiver_id: string
  message: string
  created_at: string
  read_at: string | null
  encrypted?: boolean
}

type Helper = {
  id: string
  voice_name: string
  real_name: string | null
  is_revealed: boolean
  avatar_url?: string
  level: string
  dm_title?: string
  dm_bio?: string
}

interface ChatClientProps {
  currentUserId: string
  myProfile: Profile | null
  helper: Helper
  initialMessages: DmMessage[]
}

type MsgAction = { msgId: string; isMine: boolean; text: string } | null

const VERSE_BIBLES = [
  { text: 'And we know that in all things God works for the good of those who love him.', ref: 'Romans 8:28' },
  { text: 'The LORD is my shepherd, I lack nothing.', ref: 'Psalm 23:1' },
  { text: 'Do not fear, for I am with you; do not be dismayed, for I am your God.', ref: 'Isaiah 41:10' },
  { text: 'I can do all this through him who gives me strength.', ref: 'Phil. 4:13' },
]

const BG_OPTIONS = [
  { label: 'Night',   value: 'default', bg: 'var(--ij-bg-base)', verse: null },
  { label: 'Indigo',  value: 'indigo',  bg: 'linear-gradient(160deg, #1a1840 0%, #0f0f28 100%)', verse: null },
  { label: 'Warm',    value: 'warm',    bg: 'linear-gradient(160deg, #1a1020 0%, #120808 100%)', verse: null },
  { label: 'Deep',    value: 'deep',    bg: 'linear-gradient(160deg, #0a1628 0%, #0f0f28 100%)', verse: null },
  { label: 'Romans 8', value: 'romans', bg: 'linear-gradient(160deg, #1a1840 0%, #0f0f28 100%)', verse: VERSE_BIBLES[0] },
  { label: 'Psalm 23', value: 'psalm23',bg: 'linear-gradient(160deg, #0f1a10 0%, #0a1628 100%)', verse: VERSE_BIBLES[1] },
  { label: 'Isaiah 41',value: 'isaiah', bg: 'linear-gradient(160deg, #1a1010 0%, #0f0c1e 100%)', verse: VERSE_BIBLES[2] },
  { label: 'Phil 4',   value: 'phil',   bg: 'linear-gradient(160deg, #0e1a10 0%, #101810 100%)', verse: VERSE_BIBLES[3] },
]

export default function ChatClient({ currentUserId, myProfile, helper, initialMessages }: ChatClientProps) {
  const [messages, setMessages] = useState<DmMessage[]>(initialMessages)
  const [text, setText] = useState('')
  const [sending, setSending] = useState(false)
  const [showOptions, setShowOptions] = useState(false)
  const [chatBg, setChatBg] = useState('default')
  const [privateKey, setPrivateKey] = useState<CryptoKey | null>(null)
  const [msgAction, setMsgAction] = useState<MsgAction>(null)
  const bottomRef = useRef<HTMLDivElement>(null)
  const optionsRef = useRef<HTMLDivElement>(null)
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)
  const supabase = createClient()
  const router = useRouter()

  const helperName = helper.is_revealed && helper.real_name ? helper.real_name : helper.voice_name
  const currentBg = BG_OPTIONS.find(o => o.value === chatBg) ?? BG_OPTIONS[0]

  useEffect(() => {
    initUserCrypto(currentUserId).then(async ({ privateKey: pk, publicKeyB64 }) => {
      setPrivateKey(pk)
      if (publicKeyB64) {
        await supabase.from('profiles').update({ public_key: publicKeyB64 }).eq('id', currentUserId)
      }
    })
  }, [currentUserId])

  useEffect(() => {
    const saved = localStorage.getItem(`ijwi_chat_bg_${helper.id}`)
    if (saved && BG_OPTIONS.some(o => o.value === saved)) setChatBg(saved)
  }, [helper.id])

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (optionsRef.current && !optionsRef.current.contains(e.target as Node)) setShowOptions(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  useEffect(() => {
    if (!privateKey || initialMessages.length === 0) return
    Promise.all(initialMessages.map(msg => decryptIfNeeded(msg, privateKey))).then(setMessages)
  }, [privateKey])

  useEffect(() => {
    const channel = supabase
      .channel(`dm-${currentUserId}-${helper.id}`)
      .on('postgres_changes', {
        event: 'INSERT', schema: 'public', table: 'direct_messages',
        filter: `receiver_id=eq.${currentUserId}`,
      }, (payload) => {
        const msg = payload.new as DmMessage
        if (msg.sender_id === helper.id) {
          decryptIfNeeded(msg, privateKey).then(d => setMessages(m => [...m, d]))
        }
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [currentUserId, helper.id, privateKey])

  const handleSend = async () => {
    const trimmed = text.trim()
    if (!trimmed || sending) return
    setSending(true)
    const optimistic: DmMessage = {
      id: crypto.randomUUID(),
      sender_id: currentUserId, receiver_id: helper.id,
      message: trimmed, created_at: new Date().toISOString(), read_at: null,
    }
    setMessages(m => [...m, optimistic])
    setText('')
    textareaRef.current?.focus()

    const { data: rp } = await supabase.from('profiles').select('public_key').eq('id', helper.id).single()
    let messageToSend = trimmed, isEncrypted = false
    if (rp?.public_key) {
      try {
        const rpk = await importPublicKey(rp.public_key)
        messageToSend = await encryptMessage(trimmed, rpk)
        isEncrypted = true
      } catch { /* fallback plaintext */ }
    }

    const { error } = await supabase.from('direct_messages').insert({
      sender_id: currentUserId, receiver_id: helper.id,
      message: messageToSend, encrypted: isEncrypted,
    })
    if (error) { setMessages(m => m.filter(x => x.id !== optimistic.id)); setText(trimmed) }
    setSending(false)
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSend() }
  }

  const handleDeleteMessage = async (msgId: string) => {
    setMessages(m => m.filter(x => x.id !== msgId))
    setMsgAction(null)
    await supabase.from('direct_messages').delete().eq('id', msgId).eq('sender_id', currentUserId)
  }

  const handleDeleteConversation = async () => {
    if (!confirm('Delete this entire conversation? This cannot be undone.')) return
    await supabase.from('direct_messages').delete()
      .or(`and(sender_id.eq.${currentUserId},receiver_id.eq.${helper.id}),and(sender_id.eq.${helper.id},receiver_id.eq.${currentUserId})`)
    router.push('/dms')
  }

  // Long-press handlers — IG style
  const startLongPress = useCallback((msg: DmMessage) => {
    longPressTimer.current = setTimeout(() => {
      // Haptic feedback on mobile
      if (navigator.vibrate) navigator.vibrate(30)
      setMsgAction({ msgId: msg.id, isMine: msg.sender_id === currentUserId, text: msg.message })
    }, 450)
  }, [currentUserId])

  const cancelLongPress = useCallback(() => {
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current)
      longPressTimer.current = null
    }
  }, [])

  // Desktop: right-click to open actions
  const handleContextMenu = useCallback((e: React.MouseEvent, msg: DmMessage) => {
    e.preventDefault()
    setMsgAction({ msgId: msg.id, isMine: msg.sender_id === currentUserId, text: msg.message })
  }, [currentUserId])

  return (
    <div style={{ display: 'flex', height: '100dvh', background: 'var(--ij-bg-base)', overflow: 'hidden' }}>
      {/* Desktop sidebar */}
      <Navbar profile={myProfile} hideMobileTopbar hideMobileNav />

      {/* Chat column — fills remaining space */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0, overflow: 'hidden', height: '100dvh' }}>
        <div style={{ width: '100%', maxWidth: 780, margin: '0 auto', display: 'flex', flexDirection: 'column', height: '100%', minWidth: 0 }}>

          {/* ── Header ── */}
          <div style={{
            height: 60, flexShrink: 0,
            borderBottom: '1px solid var(--ij-border)',
            background: 'var(--ij-bg-surface)',
            display: 'flex', alignItems: 'center',
            padding: '0 8px 0 4px', gap: 4, zIndex: 20,
          }}>
            <button
              onClick={() => router.push('/dms')}
              style={{
                background: 'none', border: 'none', cursor: 'pointer',
                color: 'var(--ij-text-secondary)', padding: '8px 10px',
                borderRadius: 12, display: 'flex', alignItems: 'center', flexShrink: 0,
              }}
            >
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M19 12H5M12 5l-7 7 7 7"/>
              </svg>
            </button>

            <Link href={`/profile/${helper.id}`} style={{ display: 'flex', alignItems: 'center', gap: 10, textDecoration: 'none', flex: 1, minWidth: 0 }}>
              <div style={{ position: 'relative', flexShrink: 0 }}>
                <ProfileAvatar userId={helper.id} avatarUrl={helper.avatar_url} isRevealed={helper.is_revealed} size={38} voiceName={helperName} />
                <span style={{ position: 'absolute', bottom: 1, right: 1, width: 9, height: 9, borderRadius: '50%', background: '#22c55e', border: '2px solid var(--ij-bg-surface)' }} />
              </div>
              <div style={{ minWidth: 0 }}>
                <div style={{ fontSize: '15px', fontWeight: 700, color: 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-body)', lineHeight: 1.2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {helperName}
                </div>
                <div style={{ fontSize: '11px', color: '#22c55e', fontWeight: 500, fontFamily: 'var(--ij-font-body)', display: 'flex', alignItems: 'center', gap: 3 }}>
                  <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                    <rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
                  </svg>
                  Encrypted
                </div>
              </div>
            </Link>

            {/* Options */}
            <div style={{ position: 'relative', flexShrink: 0 }} ref={optionsRef}>
              <button
                onClick={() => setShowOptions(s => !s)}
                style={{
                  background: showOptions ? 'var(--ij-bg-elevated)' : 'none',
                  border: '1px solid ' + (showOptions ? 'var(--ij-border)' : 'transparent'),
                  borderRadius: 12, cursor: 'pointer',
                  color: 'var(--ij-text-secondary)', padding: '8px 12px',
                  fontSize: '18px', letterSpacing: '2px', lineHeight: 1,
                  display: 'flex', alignItems: 'center',
                }}
              >•••</button>

              {showOptions && (
                <div style={{
                  position: 'absolute', top: 50, right: 0,
                  background: 'var(--ij-bg-elevated)', border: '1px solid var(--ij-border)',
                  borderRadius: 18, padding: '12px', zIndex: 50, minWidth: 240,
                  boxShadow: '0 12px 40px rgba(0,0,0,0.45)',
                }}>
                  <p style={{ fontSize: '10px', fontWeight: 700, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--ij-text-secondary)', margin: '0 0 10px 2px', fontFamily: 'var(--ij-font-body)' }}>
                    Chat Background
                  </p>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, marginBottom: 12 }}>
                    {BG_OPTIONS.map(opt => (
                      <button
                        key={opt.value}
                        onClick={() => { setChatBg(opt.value); localStorage.setItem(`ijwi_chat_bg_${helper.id}`, opt.value) }}
                        title={opt.label}
                        style={{
                          position: 'relative', height: 44, borderRadius: 10,
                          background: opt.bg === 'var(--ij-bg-base)' ? '#0c0916' : opt.bg,
                          border: chatBg === opt.value ? '2px solid var(--ij-gold)' : '1.5px solid var(--ij-border)',
                          cursor: 'pointer', overflow: 'hidden',
                        }}
                      >
                        {opt.verse && (
                          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 2 }}>
                            <span style={{ fontSize: '5px', color: 'rgba(255,255,255,0.6)', fontFamily: 'Georgia, serif', fontStyle: 'italic', textAlign: 'center', lineHeight: 1.2 }}>{opt.verse.ref}</span>
                          </div>
                        )}
                        {chatBg === opt.value && (
                          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            <span style={{ fontSize: '11px', color: 'var(--ij-gold)' }}>✓</span>
                          </div>
                        )}
                      </button>
                    ))}
                  </div>
                  <div style={{ fontSize: '10px', color: 'var(--ij-text-hint)', textAlign: 'center', marginBottom: 12, fontFamily: 'var(--ij-font-body)' }}>
                    {currentBg.verse ? `"${currentBg.verse.ref}" watermark active` : 'No verse watermark'}
                  </div>
                  <div style={{ height: 1, background: 'var(--ij-border)', margin: '4px 0 8px' }} />
                  <Link href={`/profile/${helper.id}`} style={{ width: '100%', background: 'transparent', border: 'none', borderRadius: 10, color: 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-body)', fontSize: '13px', fontWeight: 500, padding: '10px 12px', cursor: 'pointer', textAlign: 'left', display: 'flex', alignItems: 'center', gap: 10, textDecoration: 'none' }}
                    onMouseEnter={e => (e.currentTarget.style.background = 'rgba(255,255,255,0.05)')}
                    onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                  >
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
                    View profile
                  </Link>
                  <button
                    onClick={handleDeleteConversation}
                    style={{ width: '100%', background: 'transparent', border: 'none', borderRadius: 10, color: '#ef4444', fontFamily: 'var(--ij-font-body)', fontSize: '13px', fontWeight: 500, padding: '10px 12px', cursor: 'pointer', textAlign: 'left', display: 'flex', alignItems: 'center', gap: 10 }}
                    onMouseEnter={e => (e.currentTarget.style.background = 'rgba(239,68,68,0.08)')}
                    onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                  >
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
                      <polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/>
                    </svg>
                    Delete conversation
                  </button>
                </div>
              )}
            </div>
          </div>

          {/* ── Messages — scrollable, fills remaining height ── */}
          <div
            style={{
              flex: 1, overflowY: 'auto', padding: '16px 12px 8px',
              display: 'flex', flexDirection: 'column', gap: 2,
              background: currentBg.bg === 'var(--ij-bg-base)' ? 'var(--ij-bg-base)' : currentBg.bg,
              transition: 'background 0.3s ease', position: 'relative',
              WebkitOverflowScrolling: 'touch',
            }}
            onClick={() => setMsgAction(null)}
          >
            {currentBg.verse && (
              <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', pointerEvents: 'none', padding: '40px 28px', userSelect: 'none', zIndex: 0 }}>
                <div style={{ textAlign: 'center', opacity: 0.07 }}>
                  <p style={{ fontFamily: 'Georgia, serif', fontSize: '17px', fontStyle: 'italic', lineHeight: 1.7, color: 'white', marginBottom: 6 }}>&ldquo;{currentBg.verse.text}&rdquo;</p>
                  <span style={{ fontSize: '12px', fontWeight: 700, color: 'white', letterSpacing: '0.05em' }}>— {currentBg.verse.ref}</span>
                </div>
              </div>
            )}

            {messages.length === 0 && (
              <div style={{ textAlign: 'center', padding: '48px 20px 24px', position: 'relative', zIndex: 1 }}>
                <ProfileAvatar userId={helper.id} avatarUrl={helper.avatar_url} isRevealed={helper.is_revealed} size={72} voiceName={helperName} />
                <div style={{ marginTop: 14, fontSize: '1.15rem', fontWeight: 700, color: 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-display)' }}>{helperName}</div>
                {helper.dm_title && <div style={{ fontSize: '13px', color: 'var(--ij-gold)', fontWeight: 600, marginTop: 4, fontFamily: 'var(--ij-font-body)' }}>{helper.dm_title}</div>}
                {helper.dm_bio && <p style={{ fontSize: '13px', color: 'var(--ij-text-secondary)', lineHeight: 1.7, margin: '10px auto 0', maxWidth: 300, fontFamily: 'var(--ij-font-body)' }}>{helper.dm_bio}</p>}
                <p style={{ fontSize: '11px', color: 'var(--ij-text-hint)', marginTop: 14, fontStyle: 'italic', fontFamily: 'var(--ij-font-body)' }}>Private &amp; end-to-end encrypted</p>
              </div>
            )}

            {messages.map((msg, i) => {
              const isMine = msg.sender_id === currentUserId
              const showTime = i === 0 || (new Date(msg.created_at).getTime() - new Date(messages[i - 1].created_at).getTime()) > 5 * 60 * 1000
              const prevSame = i > 0 && messages[i - 1].sender_id === msg.sender_id
              const nextSame = i < messages.length - 1 && messages[i + 1].sender_id === msg.sender_id

              return (
                <div key={msg.id} style={{ position: 'relative', zIndex: 1 }}>
                  {showTime && (
                    <div style={{ textAlign: 'center', fontSize: '11px', color: 'rgba(255,255,255,0.3)', margin: `${i > 0 ? 18 : 0}px 0 10px`, fontFamily: 'var(--ij-font-body)' }}>
                      {timeAgo(msg.created_at)}
                    </div>
                  )}

                  <div style={{
                    display: 'flex',
                    justifyContent: isMine ? 'flex-end' : 'flex-start',
                    alignItems: 'flex-end',
                    gap: 6,
                    marginBottom: nextSame ? 2 : 8,
                  }}>
                    {!isMine && (
                      <div style={{ width: 28, flexShrink: 0 }}>
                        {!nextSame && (
                          <ProfileAvatar userId={helper.id} avatarUrl={helper.avatar_url} isRevealed={helper.is_revealed} size={28} voiceName={helperName} />
                        )}
                      </div>
                    )}

                    {/* Message bubble — long-press / right-click to get actions */}
                    <div
                      onTouchStart={() => startLongPress(msg)}
                      onTouchEnd={cancelLongPress}
                      onTouchMove={cancelLongPress}
                      onContextMenu={e => handleContextMenu(e, msg)}
                      style={{
                        maxWidth: '72%',
                        padding: '9px 14px',
                        borderRadius: isMine
                          ? (prevSame ? '18px 4px 4px 18px' : '18px 18px 4px 18px')
                          : (prevSame ? '4px 18px 18px 4px' : '4px 18px 18px 18px'),
                        background: isMine
                          ? 'linear-gradient(135deg, #C9860A 0%, #F0A832 100%)'
                          : 'rgba(255,255,255,0.10)',
                        border: isMine ? 'none' : '1px solid rgba(255,255,255,0.08)',
                        color: isMine ? '#0C0916' : 'var(--ij-text-primary)',
                        fontSize: '14px', lineHeight: 1.5,
                        fontFamily: 'var(--ij-font-body)',
                        fontWeight: isMine ? 500 : 400,
                        wordBreak: 'break-word',
                        userSelect: 'text',
                        cursor: 'default',
                        WebkitUserSelect: 'text',
                        WebkitTouchCallout: 'none',
                      }}
                    >
                      {msg.message}
                    </div>
                  </div>
                </div>
              )
            })}
            <div ref={bottomRef} />
          </div>

          {/* ── Input bar — always at bottom ── */}
          <div style={{
            flexShrink: 0,
            padding: '10px 12px',
            paddingBottom: 'calc(10px + env(safe-area-inset-bottom, 0px))',
            background: 'var(--ij-bg-surface)',
            borderTop: '1px solid var(--ij-border)',
          }}>
            <div style={{ display: 'flex', gap: 10, alignItems: 'flex-end' }}>
              <textarea
                ref={textareaRef}
                placeholder="Message…"
                value={text}
                onChange={e => {
                  setText(e.target.value)
                  // Auto-resize
                  e.target.style.height = 'auto'
                  e.target.style.height = Math.min(e.target.scrollHeight, 120) + 'px'
                }}
                onKeyDown={handleKeyDown}
                rows={1}
                style={{
                  flex: 1, padding: '11px 16px', borderRadius: 24,
                  border: '1.5px solid var(--ij-border)',
                  fontSize: '14px', fontFamily: 'var(--ij-font-body)',
                  background: 'var(--ij-bg-input)', color: 'var(--ij-text-primary)',
                  outline: 'none', resize: 'none',
                  lineHeight: 1.5, maxHeight: 120, overflowY: 'auto',
                  boxSizing: 'border-box',
                  transition: 'border-color 0.15s',
                }}
                onFocus={e => (e.currentTarget.style.borderColor = 'var(--ij-border-gold)')}
                onBlur={e => (e.currentTarget.style.borderColor = 'var(--ij-border)')}
              />
              <button
                onClick={handleSend}
                disabled={!text.trim() || sending}
                style={{
                  width: 42, height: 42, borderRadius: '50%',
                  background: text.trim() && !sending
                    ? 'linear-gradient(135deg, #C9860A 0%, #F0A832 100%)'
                    : 'var(--ij-bg-elevated)',
                  border: 'none', cursor: text.trim() && !sending ? 'pointer' : 'default',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  flexShrink: 0, transition: 'all 0.2s',
                  boxShadow: text.trim() && !sending ? '0 2px 12px rgba(240,168,50,0.4)' : 'none',
                }}
              >
                <svg width="17" height="17" viewBox="0 0 24 24" fill="none"
                  stroke={text.trim() && !sending ? '#0C0916' : 'var(--ij-text-hint)'}
                  strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <line x1="22" y1="2" x2="11" y2="13"/>
                  <polygon points="22 2 15 22 11 13 2 9 22 2" fill={text.trim() && !sending ? '#0C0916' : 'var(--ij-text-hint)'} stroke="none"/>
                </svg>
              </button>
            </div>
          </div>

        </div>
      </div>

      {/* ── IG-style message action sheet (long-press / right-click) ── */}
      {msgAction && (
        <div
          onClick={() => setMsgAction(null)}
          style={{
            position: 'fixed', inset: 0, zIndex: 300,
            background: 'rgba(0,0,0,0.5)', backdropFilter: 'blur(12px)',
            display: 'flex', alignItems: 'flex-end', justifyContent: 'center',
          }}
        >
          <div
            onClick={e => e.stopPropagation()}
            style={{
              width: '100%', maxWidth: 480,
              background: 'var(--ij-bg-elevated)',
              borderRadius: '24px 24px 0 0',
              paddingBottom: 'calc(16px + env(safe-area-inset-bottom, 0px))',
              boxShadow: '0 -12px 40px rgba(0,0,0,0.5)',
            }}
          >
            <div style={{ width: 36, height: 4, background: 'rgba(128,128,128,0.25)', borderRadius: 99, margin: '12px auto 8px' }} />

            {/* Message preview */}
            <div style={{
              margin: '8px 16px 14px',
              padding: '10px 14px', borderRadius: 16,
              background: 'rgba(255,255,255,0.04)', border: '1px solid var(--ij-border)',
              fontSize: '13px', color: 'var(--ij-text-secondary)', fontFamily: 'var(--ij-font-body)',
              overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
            }}>
              {msgAction.text}
            </div>

            {/* Actions */}
            {[
              { icon: '📋', label: 'Copy', color: 'var(--ij-text-primary)', action: () => { navigator.clipboard.writeText(msgAction.text); setMsgAction(null) } },
              ...(msgAction.isMine ? [
                { icon: '↩️', label: 'Unsend', color: '#ef4444', action: () => handleDeleteMessage(msgAction.msgId) },
              ] : []),
            ].map((item, i) => (
              <button key={i} onClick={item.action}
                style={{
                  width: '100%', display: 'flex', alignItems: 'center', gap: 18,
                  padding: '16px 20px', border: 'none', background: 'none',
                  cursor: 'pointer', textAlign: 'left', borderRadius: 0,
                }}
                onMouseEnter={e => (e.currentTarget.style.background = 'rgba(255,255,255,0.05)')}
                onMouseLeave={e => (e.currentTarget.style.background = 'none')}
              >
                <span style={{ fontSize: '20px', width: 28, textAlign: 'center', flexShrink: 0 }}>{item.icon}</span>
                <span style={{ fontSize: '16px', color: item.color, fontFamily: 'var(--ij-font-body)', fontWeight: 500 }}>{item.label}</span>
              </button>
            ))}

            <div style={{ padding: '4px 12px 0' }}>
              <button onClick={() => setMsgAction(null)}
                style={{
                  width: '100%', padding: '15px', borderRadius: 18,
                  border: '1px solid var(--ij-border)', background: 'rgba(255,255,255,0.04)',
                  cursor: 'pointer', fontSize: '15px', color: 'var(--ij-text-secondary)',
                  fontFamily: 'var(--ij-font-body)', fontWeight: 500,
                }}
              >Cancel</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

async function decryptIfNeeded(msg: DmMessage, privateKey: CryptoKey | null): Promise<DmMessage> {
  if (!msg.encrypted || !privateKey) return msg
  try {
    const { decryptMessage } = await import('@/lib/crypto')
    const plain = await decryptMessage(msg.message, privateKey)
    return { ...msg, message: plain }
  } catch {
    return { ...msg, message: '[Could not decrypt]' }
  }
}
