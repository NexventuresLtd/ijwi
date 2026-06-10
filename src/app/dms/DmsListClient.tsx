'use client'

import { useState, useEffect, useCallback } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import Navbar from '@/components/layout/Navbar'
import ProfileAvatar from '@/components/ui/ProfileAvatar'
import { Profile } from '@/lib/types'
import { timeAgo } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'

type Helper = {
  id: string
  voice_name: string
  real_name: string | null
  is_revealed: boolean
  avatar_url?: string
  voice_role?: string
  dm_title?: string
  dm_bio?: string
}

type Person = {
  id: string
  voice_name: string
  real_name: string | null
  is_revealed: boolean
  avatar_url?: string
}

interface DmsListClientProps {
  currentUserId: string
  profile: Profile | null
  helpers: Helper[]
  convMap: Record<string, { message: string; created_at: string }>
}

export default function DmsListClient({ currentUserId, profile, helpers, convMap }: DmsListClientProps) {
  const [search, setSearch] = useState('')
  const [showNewMsg, setShowNewMsg] = useState(false)
  const [newMsgSearch, setNewMsgSearch] = useState('')
  const [people, setPeople] = useState<Person[]>([])
  const [loadingPeople, setLoadingPeople] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  const activeHelpers = helpers.filter(h => convMap[h.id])
  const otherHelpers = helpers.filter(h => !convMap[h.id])

  const q = search.toLowerCase().trim()
  const filteredActive = q
    ? activeHelpers.filter(h => getName(h).toLowerCase().includes(q))
    : activeHelpers
  const filteredOthers = q
    ? otherHelpers.filter(h => getName(h).toLowerCase().includes(q))
    : otherHelpers

  // Fetch followers + following when modal opens
  const fetchPeople = useCallback(async () => {
    setLoadingPeople(true)
    const [{ data: followingRows }, { data: followerRows }] = await Promise.all([
      supabase.from('follows').select('following_id').eq('follower_id', currentUserId),
      supabase.from('follows').select('follower_id').eq('following_id', currentUserId),
    ])

    const ids = new Set<string>()
    followingRows?.forEach(r => ids.add(r.following_id))
    followerRows?.forEach(r => ids.add(r.follower_id))
    ids.delete(currentUserId)

    if (ids.size === 0) { setPeople([]); setLoadingPeople(false); return }

    const { data: profiles } = await supabase
      .from('profiles')
      .select('id, voice_name, real_name, is_revealed, avatar_url')
      .in('id', Array.from(ids))
      .order('voice_name')

    setPeople(profiles ?? [])
    setLoadingPeople(false)
  }, [currentUserId, supabase])

  useEffect(() => {
    if (showNewMsg) fetchPeople()
  }, [showNewMsg, fetchPeople])

  const filteredPeople = newMsgSearch.trim()
    ? people.filter(p => getPersonName(p).toLowerCase().includes(newMsgSearch.toLowerCase().trim()))
    : people

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--ij-bg-base)' }}>
      <Navbar profile={profile} hideMobileTopbar />

      <div style={{ flex: 1, minWidth: 0, maxWidth: 680, margin: '0 auto', width: '100%' }}>

        {/* Mobile top bar */}
        <div className="mobile-topbar" style={{
          position: 'fixed', top: 0, left: 0, right: 0, zIndex: 101,
          height: 52, background: 'var(--ij-bg-nav)', borderBottom: '1px solid var(--ij-border)',
          backdropFilter: 'blur(16px)', WebkitBackdropFilter: 'blur(16px)',
          display: 'none', alignItems: 'center', padding: '0 16px',
          justifyContent: 'space-between',
        }}>
          <span style={{ fontFamily: 'var(--ij-font-display)', fontSize: '18px', fontWeight: 700, color: 'var(--ij-text-primary)', letterSpacing: '0.5px' }}>
            Messages
          </span>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, background: 'rgba(240,168,50,0.08)', border: '1px solid var(--ij-border-gold)', borderRadius: 999, padding: '4px 10px' }}>
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="var(--ij-gold)" strokeWidth="2" strokeLinecap="round">
              <rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
            </svg>
            <span style={{ fontSize: '10px', fontWeight: 700, color: 'var(--ij-gold)', fontFamily: 'var(--ij-font-body)', letterSpacing: '0.04em' }}>Encrypted</span>
          </div>
        </div>

        <div className="dms-content" style={{ padding: '24px 20px 90px' }}>

          {/* Header — desktop only */}
          <div className="dms-header-desktop" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
            <h1 style={{ fontFamily: 'var(--ij-font-display)', fontSize: 'clamp(1.4rem, 3vw, 1.8rem)', fontWeight: 700, color: 'var(--ij-text-primary)', margin: 0 }}>
              Messages
            </h1>
            <div style={{ display: 'flex', alignItems: 'center', gap: 5, background: 'rgba(240,168,50,0.08)', border: '1px solid var(--ij-border-gold)', borderRadius: 999, padding: '4px 10px' }}>
              <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="var(--ij-gold)" strokeWidth="2" strokeLinecap="round">
                <rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
              </svg>
              <span style={{ fontSize: '0.65rem', fontWeight: 700, color: 'var(--ij-gold)', fontFamily: 'var(--ij-font-body)', letterSpacing: '0.04em' }}>
                Encrypted
              </span>
            </div>
          </div>

          {/* Search bar */}
          <div style={{ position: 'relative', marginBottom: 20 }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--ij-text-hint)" strokeWidth="2" strokeLinecap="round"
              style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }}>
              <circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>
            </svg>
            <input
              type="text"
              placeholder="Search"
              value={search}
              onChange={e => setSearch(e.target.value)}
              style={{
                width: '100%', padding: '11px 14px 11px 40px',
                borderRadius: 12, border: '1px solid var(--ij-border)',
                background: 'var(--ij-bg-elevated)', color: 'var(--ij-text-primary)',
                fontSize: '0.88rem', fontFamily: 'var(--ij-font-body)',
                outline: 'none', transition: 'border-color 0.15s',
                boxSizing: 'border-box',
              }}
              onFocus={e => (e.currentTarget.style.borderColor = 'var(--ij-border-gold)')}
              onBlur={e => (e.currentTarget.style.borderColor = 'var(--ij-border)')}
            />
          </div>

          {/* Conversations list */}
          {filteredActive.length > 0 && (
            <section style={{ marginBottom: 8 }}>
              {filteredActive.map((h, i) => {
                const name = getName(h)
                const conv = convMap[h.id]
                return (
                  <Link key={h.id} href={`/dms/${h.id}`} style={{ textDecoration: 'none', display: 'block' }}>
                    <div className="dms-row" style={{
                      display: 'flex', alignItems: 'center', gap: 14,
                      padding: '14px 4px',
                      borderBottom: i < filteredActive.length - 1 ? '1px solid var(--ij-border)' : 'none',
                      transition: 'background 0.12s',
                      borderRadius: 8,
                    }}
                      onMouseEnter={e => (e.currentTarget.style.background = 'var(--ij-bg-elevated)')}
                      onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                    >
                      <div style={{ position: 'relative', flexShrink: 0 }}>
                        <ProfileAvatar userId={h.id} avatarUrl={h.avatar_url} isRevealed={h.is_revealed} size={54} voiceName={name} />
                        <span style={{ position: 'absolute', bottom: 2, right: 2, width: 12, height: 12, borderRadius: '50%', background: '#27AE60', border: '2.5px solid var(--ij-bg-base)' }} />
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                          <span style={{ fontWeight: 600, fontSize: '0.92rem', color: 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-body)' }}>{name}</span>
                          {conv && (
                            <span style={{ fontSize: '0.72rem', color: 'var(--ij-text-hint)', fontFamily: 'var(--ij-font-body)', flexShrink: 0 }}>
                              · {timeAgo(conv.created_at)}
                            </span>
                          )}
                        </div>
                        {conv && (
                          <p style={{ fontSize: '0.82rem', color: 'var(--ij-text-secondary)', margin: '3px 0 0', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', fontFamily: 'var(--ij-font-body)', lineHeight: 1.3 }}>
                            {conv.message}
                          </p>
                        )}
                      </div>
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--ij-text-hint)" strokeWidth="2" strokeLinecap="round" style={{ flexShrink: 0, opacity: 0.5 }}>
                        <path d="M9 18l6-6-6-6"/>
                      </svg>
                    </div>
                  </Link>
                )
              })}
            </section>
          )}

          {/* Suggested / Helper directory */}
          {filteredOthers.length > 0 && (
            <section>
              <p style={{ fontSize: '0.7rem', fontWeight: 700, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--ij-text-hint)', margin: '16px 0 8px 4px', fontFamily: 'var(--ij-font-body)' }}>
                Suggested
              </p>
              {filteredOthers.map((h, i) => {
                const name = getName(h)
                return (
                  <Link key={h.id} href={`/dms/${h.id}`} style={{ textDecoration: 'none', display: 'block' }}>
                    <div className="dms-row" style={{
                      display: 'flex', alignItems: 'center', gap: 14,
                      padding: '12px 4px',
                      borderBottom: i < filteredOthers.length - 1 ? '1px solid var(--ij-border)' : 'none',
                      transition: 'background 0.12s',
                      borderRadius: 8,
                    }}
                      onMouseEnter={e => (e.currentTarget.style.background = 'var(--ij-bg-elevated)')}
                      onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                    >
                      <div style={{ position: 'relative', flexShrink: 0 }}>
                        <ProfileAvatar userId={h.id} avatarUrl={h.avatar_url} isRevealed={h.is_revealed} size={54} voiceName={name} />
                        <span style={{ position: 'absolute', bottom: 2, right: 2, width: 12, height: 12, borderRadius: '50%', background: '#27AE60', border: '2.5px solid var(--ij-bg-base)' }} />
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <span style={{ fontWeight: 600, fontSize: '0.92rem', color: 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-body)', display: 'block' }}>{name}</span>
                        <span style={{ fontSize: '0.78rem', color: 'var(--ij-text-secondary)', fontFamily: 'var(--ij-font-body)' }}>
                          {h.dm_title || (h.voice_role ? h.voice_role.replace(/_/g, ' ') : 'Counselor')}
                        </span>
                      </div>
                      <button
                        style={{
                          background: 'var(--ij-bg-elevated)', border: '1px solid var(--ij-border)',
                          borderRadius: 8, color: 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-body)',
                          fontSize: '0.78rem', fontWeight: 600, padding: '7px 14px',
                          cursor: 'pointer', flexShrink: 0, transition: 'border-color 0.15s',
                        }}
                        onMouseEnter={e => (e.currentTarget.style.borderColor = 'var(--ij-border-gold)')}
                        onMouseLeave={e => (e.currentTarget.style.borderColor = 'var(--ij-border)')}
                      >
                        Message
                      </button>
                    </div>
                  </Link>
                )
              })}
            </section>
          )}

          {/* Empty state */}
          {helpers.length === 0 && !showNewMsg && (
            <div style={{ textAlign: 'center', padding: '60px 20px' }}>
              <div style={{ width: 64, height: 64, borderRadius: '50%', background: 'var(--ij-bg-elevated)', border: '1px solid var(--ij-border)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="var(--ij-text-hint)" strokeWidth="1.5" strokeLinecap="round">
                  <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                </svg>
              </div>
              <p style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1.1rem', color: 'var(--ij-text-primary)', marginBottom: 6 }}>No messages yet</p>
              <p style={{ fontSize: '13px', color: 'var(--ij-text-secondary)', fontFamily: 'var(--ij-font-body)', lineHeight: 1.6 }}>
                Tap + to start a conversation with someone you follow.
              </p>
            </div>
          )}

          {/* No search results */}
          {q && filteredActive.length === 0 && filteredOthers.length === 0 && helpers.length > 0 && (
            <div style={{ textAlign: 'center', padding: '40px 20px' }}>
              <p style={{ fontSize: '0.88rem', color: 'var(--ij-text-secondary)', fontFamily: 'var(--ij-font-body)' }}>
                No results for &ldquo;{search}&rdquo;
              </p>
            </div>
          )}

        </div>
      </div>

      {/* Floating new message button */}
      <button
        onClick={() => setShowNewMsg(true)}
        aria-label="New message"
        className="dms-fab"
        style={{
          position: 'fixed', bottom: 90, right: 24, zIndex: 100,
          width: 56, height: 56, borderRadius: '50%',
          background: 'linear-gradient(135deg, #C9860A 0%, #F0A832 100%)',
          border: 'none', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: '0 4px 20px rgba(240,168,50,0.4)',
          transition: 'transform 0.15s, box-shadow 0.15s',
        }}
        onMouseEnter={e => { e.currentTarget.style.transform = 'scale(1.08)'; e.currentTarget.style.boxShadow = '0 6px 28px rgba(240,168,50,0.55)' }}
        onMouseLeave={e => { e.currentTarget.style.transform = 'scale(1)'; e.currentTarget.style.boxShadow = '0 4px 20px rgba(240,168,50,0.4)' }}
      >
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#0C0916" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
          <line x1="9" y1="10" x2="15" y2="10"/>
        </svg>
      </button>

      {/* New message modal */}
      {showNewMsg && (
        <div
          onClick={() => setShowNewMsg(false)}
          style={{
            position: 'fixed', inset: 0, zIndex: 200,
            background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(8px)',
            display: 'flex', alignItems: 'flex-end', justifyContent: 'center',
          }}
        >
          <div
            onClick={e => e.stopPropagation()}
            style={{
              width: '100%', maxWidth: 480, maxHeight: '80vh',
              background: 'var(--ij-bg-elevated)',
              borderRadius: '20px 20px 0 0',
              display: 'flex', flexDirection: 'column',
              overflow: 'hidden',
              boxShadow: '0 -8px 40px rgba(0,0,0,0.5)',
            }}
          >
            {/* Modal header */}
            <div style={{ padding: '16px 20px 12px', borderBottom: '1px solid var(--ij-border)', flexShrink: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
                <h2 style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1.1rem', fontWeight: 700, color: 'var(--ij-text-primary)', margin: 0 }}>
                  New message
                </h2>
                <button
                  onClick={() => setShowNewMsg(false)}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--ij-text-secondary)', padding: 4 }}
                >
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                    <path d="M18 6L6 18M6 6l12 12"/>
                  </svg>
                </button>
              </div>
              {/* Search within followers/following */}
              <div style={{ position: 'relative' }}>
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="var(--ij-text-hint)" strokeWidth="2" strokeLinecap="round"
                  style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }}>
                  <circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>
                </svg>
                <input
                  type="text"
                  placeholder="Search people you follow..."
                  value={newMsgSearch}
                  onChange={e => setNewMsgSearch(e.target.value)}
                  autoFocus
                  style={{
                    width: '100%', padding: '10px 14px 10px 36px',
                    borderRadius: 10, border: '1px solid var(--ij-border)',
                    background: 'var(--ij-bg-surface)', color: 'var(--ij-text-primary)',
                    fontSize: '0.85rem', fontFamily: 'var(--ij-font-body)',
                    outline: 'none', boxSizing: 'border-box',
                  }}
                  onFocus={e => (e.currentTarget.style.borderColor = 'var(--ij-border-gold)')}
                  onBlur={e => (e.currentTarget.style.borderColor = 'var(--ij-border)')}
                />
              </div>
            </div>

            {/* People list */}
            <div style={{ flex: 1, overflowY: 'auto', padding: '8px 0' }}>
              {loadingPeople && (
                <p style={{ textAlign: 'center', padding: '32px 20px', fontSize: '0.85rem', color: 'var(--ij-text-hint)', fontFamily: 'var(--ij-font-body)' }}>
                  Loading...
                </p>
              )}

              {!loadingPeople && filteredPeople.length === 0 && (
                <div style={{ textAlign: 'center', padding: '32px 20px' }}>
                  <p style={{ fontSize: '0.85rem', color: 'var(--ij-text-secondary)', fontFamily: 'var(--ij-font-body)' }}>
                    {newMsgSearch.trim() ? `No results for "${newMsgSearch}"` : 'No followers or following yet.'}
                  </p>
                </div>
              )}

              {!loadingPeople && filteredPeople.map(p => {
                const name = getPersonName(p)
                return (
                  <button
                    key={p.id}
                    onClick={() => router.push(`/dms/${p.id}`)}
                    style={{
                      width: '100%', display: 'flex', alignItems: 'center', gap: 12,
                      padding: '12px 20px', border: 'none', background: 'none',
                      cursor: 'pointer', textAlign: 'left',
                      transition: 'background 0.12s',
                    }}
                    onMouseEnter={e => (e.currentTarget.style.background = 'var(--ij-bg-surface)')}
                    onMouseLeave={e => (e.currentTarget.style.background = 'none')}
                  >
                    <ProfileAvatar userId={p.id} avatarUrl={p.avatar_url} isRevealed={p.is_revealed} size={46} voiceName={name} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <span style={{ fontWeight: 600, fontSize: '0.9rem', color: 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-body)', display: 'block' }}>
                        {name}
                      </span>
                    </div>
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--ij-text-hint)" strokeWidth="2" strokeLinecap="round" style={{ flexShrink: 0, opacity: 0.5 }}>
                      <path d="M9 18l6-6-6-6"/>
                    </svg>
                  </button>
                )
              })}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function getName(h: Helper): string {
  return h.is_revealed && h.real_name ? h.real_name : h.voice_name
}

function getPersonName(p: Person): string {
  return p.is_revealed && p.real_name ? p.real_name : p.voice_name
}
