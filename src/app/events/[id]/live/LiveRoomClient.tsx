'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import ProfileAvatar from '@/components/ui/ProfileAvatar'
import { Profile } from '@/lib/types'
import { createClient } from '@/lib/supabase/client'
import { timeAgo } from '@/lib/utils'

type Author = { voice_name: string; real_name: string | null; is_revealed: boolean; avatar_url?: string }
type LiveMsg = { id: string; user_id: string; message: string; created_at: string; author?: Author }

interface Props {
  eventId: string
  eventTitle: string
  organizerId: string
  currentUserId: string
  profile: Profile | null
  initialMessages: LiveMsg[]
}

export default function LiveRoomClient({ eventId, eventTitle, organizerId, currentUserId, profile, initialMessages }: Props) {
  const [messages, setMessages] = useState<LiveMsg[]>(initialMessages)
  const [text, setText] = useState('')
  const [sending, setSending] = useState(false)
  const [showParticipants, setShowParticipants] = useState(false)
  const [participants, setParticipants] = useState<(Author & { id: string })[]>([])
  const [followingIds, setFollowingIds] = useState<Set<string>>(new Set())
  const [followLoading, setFollowLoading] = useState<string | null>(null)
  const [viewerCount, setViewerCount] = useState(1)
  const bottomRef = useRef<HTMLDivElement>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)
  const supabase = createClient()
  const router = useRouter()

  const myName = profile?.is_revealed && profile?.real_name ? profile.real_name : (profile?.voice_name ?? 'You')

  // Scroll to bottom on new messages
  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }) }, [messages])

  // Subscribe to new messages via realtime
  useEffect(() => {
    const channel = supabase
      .channel(`live-${eventId}`)
      .on('postgres_changes', {
        event: 'INSERT', schema: 'public', table: 'live_messages',
        filter: `event_id=eq.${eventId}`,
      }, async (payload) => {
        const msg = payload.new as any
        if (msg.user_id === currentUserId) return // already optimistically added
        // Fetch author profile
        const { data: a } = await supabase.from('profiles').select('voice_name, real_name, is_revealed, avatar_url').eq('id', msg.user_id).single()
        setMessages(prev => [...prev, { ...msg, author: a ?? undefined }])
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [eventId, currentUserId, supabase])

  // Track presence for viewer count
  useEffect(() => {
    const presence = supabase.channel(`live-presence-${eventId}`)
    presence
      .on('presence', { event: 'sync' }, () => {
        setViewerCount(Object.keys(presence.presenceState()).length)
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          await presence.track({ user_id: currentUserId })
        }
      })

    return () => { supabase.removeChannel(presence) }
  }, [eventId, currentUserId, supabase])

  // Load following state
  useEffect(() => {
    supabase.from('follows').select('following_id').eq('follower_id', currentUserId)
      .then(({ data }) => {
        setFollowingIds(new Set((data ?? []).map(r => r.following_id)))
      })
  }, [currentUserId, supabase])

  // Build participants from messages
  useEffect(() => {
    const map = new Map<string, Author & { id: string }>()
    for (const m of messages) {
      if (m.author && !map.has(m.user_id)) {
        map.set(m.user_id, { id: m.user_id, ...m.author })
      }
    }
    setParticipants(Array.from(map.values()))
  }, [messages])

  const handleSend = async () => {
    const trimmed = text.trim()
    if (!trimmed || sending) return
    setSending(true)
    const optimistic: LiveMsg = {
      id: crypto.randomUUID(),
      user_id: currentUserId,
      message: trimmed,
      created_at: new Date().toISOString(),
      author: { voice_name: profile?.voice_name ?? 'You', real_name: profile?.real_name ?? null, is_revealed: profile?.is_revealed ?? false, avatar_url: profile?.avatar_url },
    }
    setMessages(prev => [...prev, optimistic])
    setText('')

    const { error } = await supabase.from('live_messages').insert({
      event_id: eventId, user_id: currentUserId, message: trimmed,
    })
    if (error) setMessages(prev => prev.filter(m => m.id !== optimistic.id))
    setSending(false)
    textareaRef.current?.focus()
  }

  const handleFollow = useCallback(async (userId: string) => {
    if (userId === currentUserId) return
    setFollowLoading(userId)
    const isFollowing = followingIds.has(userId)
    if (isFollowing) {
      await supabase.from('follows').delete().eq('follower_id', currentUserId).eq('following_id', userId)
      setFollowingIds(prev => { const s = new Set(prev); s.delete(userId); return s })
    } else {
      await supabase.from('follows').insert({ follower_id: currentUserId, following_id: userId })
      setFollowingIds(prev => new Set(prev).add(userId))
    }
    setFollowLoading(null)
  }, [currentUserId, followingIds, supabase])

  const getAuthorName = (a?: Author) => {
    if (!a) return 'Anonymous'
    return a.is_revealed && a.real_name ? a.real_name : a.voice_name
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100dvh', background: 'var(--ij-bg-base)', overflow: 'hidden' }}>

      {/* Header */}
      <div style={{
        flexShrink: 0, padding: '12px 16px',
        background: 'var(--ij-bg-surface)', borderBottom: '1px solid var(--ij-border)',
        display: 'flex', alignItems: 'center', gap: 12,
      }}>
        <button onClick={() => router.back()} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--ij-text-secondary)', padding: 4 }}>
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
            <path d="M19 12H5M12 5l-7 7 7 7"/>
          </svg>
        </button>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#ef4444', animation: 'pulse 1.5s infinite', flexShrink: 0 }} />
            <span style={{ fontFamily: 'var(--ij-font-display)', fontSize: '0.95rem', fontWeight: 700, color: 'var(--ij-text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {eventTitle}
            </span>
          </div>
          <span style={{ fontSize: '0.72rem', color: 'var(--ij-text-hint)', fontFamily: 'var(--ij-font-body)' }}>
            {viewerCount} watching
          </span>
        </div>
        <button
          onClick={() => setShowParticipants(true)}
          style={{
            background: 'var(--ij-bg-elevated)', border: '1px solid var(--ij-border)',
            borderRadius: 999, padding: '6px 12px', cursor: 'pointer',
            display: 'flex', alignItems: 'center', gap: 5,
            fontSize: '0.75rem', fontWeight: 600, color: 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-body)',
          }}
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>
            <path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
          </svg>
          {participants.length}
        </button>
      </div>

      {/* Messages */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '12px 16px', display: 'flex', flexDirection: 'column', gap: 6, WebkitOverflowScrolling: 'touch' }}>
        {messages.length === 0 && (
          <div style={{ textAlign: 'center', padding: '40px 16px' }}>
            <div style={{ width: 56, height: 56, borderRadius: '50%', background: 'rgba(240,168,50,0.08)', border: '1px solid var(--ij-border-gold)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 12px' }}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--ij-gold)" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"/>
                <path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" x2="12" y1="19" y2="22"/>
              </svg>
            </div>
            <p style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1rem', color: 'var(--ij-text-primary)', marginBottom: 4 }}>You're live!</p>
            <p style={{ fontSize: '0.82rem', color: 'var(--ij-text-secondary)', fontFamily: 'var(--ij-font-body)' }}>
              Say something to start the conversation.
            </p>
          </div>
        )}

        {messages.map(msg => {
          const isMine = msg.user_id === currentUserId
          const isOrganizer = msg.user_id === organizerId
          const name = getAuthorName(msg.author)
          return (
            <div key={msg.id} style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
              <ProfileAvatar userId={msg.user_id} avatarUrl={msg.author?.avatar_url} isRevealed={msg.author?.is_revealed ?? false} size={32} voiceName={name} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 1 }}>
                  <span style={{ fontSize: '0.78rem', fontWeight: 700, color: isMine ? 'var(--ij-gold)' : 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-body)' }}>
                    {isMine ? 'You' : name}
                  </span>
                  {isOrganizer && (
                    <span style={{ fontSize: '0.6rem', fontWeight: 700, padding: '1px 5px', borderRadius: 4, background: 'rgba(240,168,50,0.12)', color: 'var(--ij-gold)', border: '1px solid var(--ij-border-gold)' }}>
                      Host
                    </span>
                  )}
                  <span style={{ fontSize: '0.65rem', color: 'var(--ij-text-hint)', fontFamily: 'var(--ij-font-body)' }}>
                    {timeAgo(msg.created_at)}
                  </span>
                </div>
                <p style={{ fontSize: '0.85rem', color: 'var(--ij-text-primary)', margin: 0, lineHeight: 1.4, fontFamily: 'var(--ij-font-body)', wordBreak: 'break-word' }}>
                  {msg.message}
                </p>
              </div>
            </div>
          )
        })}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div style={{
        flexShrink: 0, padding: '10px 14px',
        paddingBottom: 'calc(10px + env(safe-area-inset-bottom, 0px))',
        background: 'var(--ij-bg-surface)', borderTop: '1px solid var(--ij-border)',
      }}>
        <div style={{ display: 'flex', gap: 10, alignItems: 'flex-end' }}>
          <textarea
            ref={textareaRef}
            placeholder="Say something…"
            value={text}
            onChange={e => { setText(e.target.value); e.target.style.height = 'auto'; e.target.style.height = Math.min(e.target.scrollHeight, 100) + 'px' }}
            onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSend() } }}
            rows={1}
            style={{
              flex: 1, padding: '10px 16px', borderRadius: 24,
              border: '1.5px solid var(--ij-border)',
              fontSize: '14px', fontFamily: 'var(--ij-font-body)',
              background: 'var(--ij-bg-input)', color: 'var(--ij-text-primary)',
              outline: 'none', resize: 'none', lineHeight: 1.4,
              maxHeight: 100, overflowY: 'auto', boxSizing: 'border-box',
            }}
            onFocus={e => (e.currentTarget.style.borderColor = 'var(--ij-border-gold)')}
            onBlur={e => (e.currentTarget.style.borderColor = 'var(--ij-border)')}
          />
          <button
            onClick={handleSend}
            disabled={!text.trim() || sending}
            style={{
              width: 40, height: 40, borderRadius: '50%', flexShrink: 0,
              background: text.trim() ? 'linear-gradient(135deg, #C9860A 0%, #F0A832 100%)' : 'var(--ij-bg-elevated)',
              border: 'none', cursor: text.trim() ? 'pointer' : 'default',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              transition: 'all 0.15s',
            }}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill={text.trim() ? '#0C0916' : 'var(--ij-text-hint)'} stroke="none">
              <polygon points="22 2 15 22 11 13 2 9 22 2"/>
            </svg>
          </button>
        </div>
      </div>

      {/* Participants panel */}
      {showParticipants && (
        <div
          onClick={() => setShowParticipants(false)}
          style={{ position: 'fixed', inset: 0, zIndex: 200, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(8px)', display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}
        >
          <div
            onClick={e => e.stopPropagation()}
            style={{ width: '100%', maxWidth: 480, maxHeight: '70vh', background: 'var(--ij-bg-elevated)', borderRadius: '20px 20px 0 0', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}
          >
            <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--ij-border)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <h3 style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1rem', fontWeight: 700, color: 'var(--ij-text-primary)', margin: 0 }}>
                In this room ({participants.length})
              </h3>
              <button onClick={() => setShowParticipants(false)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--ij-text-secondary)' }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                  <path d="M18 6L6 18M6 6l12 12"/>
                </svg>
              </button>
            </div>
            <div style={{ flex: 1, overflowY: 'auto', padding: '8px 0' }}>
              {participants.map(p => {
                const name = getAuthorName(p)
                const isFollowing = followingIds.has(p.id)
                const isMe = p.id === currentUserId
                return (
                  <div key={p.id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 20px' }}>
                    <ProfileAvatar userId={p.id} avatarUrl={p.avatar_url} isRevealed={p.is_revealed} size={42} voiceName={name} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <span style={{ fontWeight: 600, fontSize: '0.88rem', color: 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-body)', display: 'block' }}>{name}</span>
                      {p.id === organizerId && (
                        <span style={{ fontSize: '0.68rem', color: 'var(--ij-gold)', fontWeight: 600 }}>Host</span>
                      )}
                    </div>
                    {!isMe && (
                      <button
                        onClick={() => handleFollow(p.id)}
                        disabled={followLoading === p.id}
                        style={{
                          padding: '6px 14px', borderRadius: 8, fontSize: '0.76rem', fontWeight: 600, cursor: 'pointer',
                          fontFamily: 'var(--ij-font-body)', transition: 'all 0.15s',
                          background: isFollowing ? 'transparent' : 'var(--ij-gold)',
                          color: isFollowing ? 'var(--ij-text-secondary)' : '#0C0916',
                          border: isFollowing ? '1px solid var(--ij-border)' : 'none',
                        }}
                      >
                        {followLoading === p.id ? '…' : isFollowing ? 'Following' : 'Follow'}
                      </button>
                    )}
                  </div>
                )
              })}
              {participants.length === 0 && (
                <p style={{ textAlign: 'center', padding: '24px', fontSize: '0.85rem', color: 'var(--ij-text-hint)', fontFamily: 'var(--ij-font-body)' }}>
                  No one has chatted yet.
                </p>
              )}
            </div>
          </div>
        </div>
      )}

      <style jsx>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.4; }
        }
      `}</style>
    </div>
  )
}
