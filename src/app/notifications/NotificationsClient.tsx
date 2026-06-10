'use client'

import { useState, useEffect, ReactNode } from 'react'
import Link from 'next/link'
import { Profile } from '@/lib/types'
import Navbar from '@/components/layout/Navbar'
import ProfileAvatar from '@/components/ui/ProfileAvatar'
import { createClient } from '@/lib/supabase/client'
import { timeAgo } from '@/lib/utils'

type NotifType = 'follow' | 'fire' | 'comment'

type Notif = {
  id: string
  type: NotifType
  created_at: string
  actor_name: string
  actor_id: string
  target_title?: string
  target_id?: string
  excerpt?: string
}

interface NotificationsClientProps {
  profile: Profile
  currentUserId: string
  notifications: Notif[]
  alreadyFollowingIds: string[]
}

const TYPE_META: Record<NotifType, { label: string; verb: string; color: string; bg: string; border: string; icon: ReactNode }> = {
  follow: {
    label: 'Follows',
    verb: 'followed you',
    color: 'var(--ij-gold)',
    bg: 'rgba(240,168,50,0.10)',
    border: 'var(--ij-border-gold)',
    icon: (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
        <circle cx="9" cy="7" r="4"/>
        <line x1="19" y1="8" x2="19" y2="14"/>
        <line x1="22" y1="11" x2="16" y2="11"/>
      </svg>
    ),
  },
  fire: {
    label: 'Reactions',
    verb: 'was touched by your post',
    color: '#E8724A',
    bg: 'rgba(232,114,74,0.10)',
    border: 'rgba(232,114,74,0.30)',
    icon: (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
        <path d="M12 2c0 0-5 4-5 9a5 5 0 0 0 10 0c0-5-5-9-5-9z"/>
        <path d="M12 12c0 0-2 1.5-2 3a2 2 0 0 0 4 0c0-1.5-2-3-2-3z"/>
      </svg>
    ),
  },
  comment: {
    label: 'Comments',
    verb: 'commented on your post',
    color: 'var(--ij-prayer)',
    bg: 'rgba(139,92,246,0.10)',
    border: 'rgba(139,92,246,0.30)',
    icon: (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
      </svg>
    ),
  },
}

type Tab = 'all' | NotifType

export default function NotificationsClient({ profile, currentUserId, notifications, alreadyFollowingIds }: NotificationsClientProps) {
  const [tab, setTab] = useState<Tab>('all')
  const [followingIds, setFollowingIds] = useState<Set<string>>(new Set(alreadyFollowingIds))
  const [loadingFollow, setLoadingFollow] = useState<string | null>(null)
  const supabase = createClient()

  useEffect(() => {
    localStorage.setItem('notif_last_seen', new Date().toISOString())
  }, [])

  const handleFollowBack = async (actorId: string) => {
    setLoadingFollow(actorId)
    const isFollowing = followingIds.has(actorId)
    if (isFollowing) {
      await supabase.from('follows').delete().match({ follower_id: currentUserId, following_id: actorId })
      setFollowingIds(prev => { const next = new Set(prev); next.delete(actorId); return next })
    } else {
      await supabase.from('follows').insert({ follower_id: currentUserId, following_id: actorId })
      setFollowingIds(prev => new Set([...prev, actorId]))
    }
    setLoadingFollow(null)
  }

  const filtered = tab === 'all' ? notifications : notifications.filter(n => n.type === tab)

  const counts: Record<NotifType, number> = {
    follow: notifications.filter(n => n.type === 'follow').length,
    fire: notifications.filter(n => n.type === 'fire').length,
    comment: notifications.filter(n => n.type === 'comment').length,
  }

  const tabs: { key: Tab; label: string; count?: number }[] = [
    { key: 'all', label: 'All', count: notifications.length },
    { key: 'follow', label: 'Follows', count: counts.follow },
    { key: 'fire', label: 'Reactions', count: counts.fire },
    { key: 'comment', label: 'Comments', count: counts.comment },
  ]

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--ij-bg-base)' }}>
      <Navbar profile={profile} />

      <div style={{ flex: 1, minWidth: 0, maxWidth: 720, margin: '0 auto', padding: '32px 24px 80px', width: '100%' }}>

        {/* Header */}
        <div style={{ marginBottom: 28 }}>
          <h1 style={{
            fontFamily: 'var(--ij-font-display)',
            fontSize: 'clamp(1.6rem, 3vw, 2.2rem)',
            fontWeight: 700,
            color: 'var(--ij-text-primary)',
            marginBottom: 4,
          }}>
            Notifications
          </h1>
          <p style={{ fontSize: '0.88rem', color: 'var(--ij-text-secondary)', fontFamily: 'var(--ij-font-body)' }}>
            Activity from your community.
          </p>
        </div>

        {/* Tabs */}
        <div style={{ display: 'flex', gap: 8, marginBottom: 24, flexWrap: 'wrap' }}>
          {tabs.map(t => {
            const active = tab === t.key
            return (
              <button
                key={t.key}
                onClick={() => setTab(t.key)}
                style={{
                  background: active ? 'var(--ij-gold)' : 'var(--ij-bg-surface)',
                  border: `1px solid ${active ? 'var(--ij-gold)' : 'var(--ij-border)'}`,
                  borderRadius: 999,
                  color: active ? '#0C0916' : 'var(--ij-text-secondary)',
                  fontFamily: 'var(--ij-font-body)',
                  fontSize: '0.82rem',
                  fontWeight: active ? 700 : 500,
                  padding: '8px 16px',
                  minHeight: 36,
                  cursor: 'pointer',
                  transition: 'all 0.15s',
                  display: 'flex',
                  alignItems: 'center',
                  gap: 6,
                }}
              >
                {t.label}
                {t.count !== undefined && t.count > 0 && (
                  <span style={{
                    background: active ? 'rgba(0,0,0,0.15)' : 'var(--ij-bg-elevated)',
                    borderRadius: 999,
                    fontSize: '0.7rem',
                    fontWeight: 700,
                    padding: '1px 7px',
                    color: active ? '#0C0916' : 'var(--ij-text-secondary)',
                  }}>
                    {t.count}
                  </span>
                )}
              </button>
            )
          })}
        </div>

        {/* List */}
        {filtered.length === 0 ? (
          <div style={{
            background: 'var(--ij-bg-surface)',
            border: '1px solid var(--ij-border)',
            borderRadius: 20,
            padding: '64px 24px',
            textAlign: 'center',
          }}>
            <div style={{
              width: 56, height: 56, borderRadius: '50%',
              background: 'var(--ij-bg-elevated)',
              border: '1px solid var(--ij-border)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              margin: '0 auto 16px',
            }}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--ij-text-secondary)" strokeWidth="1.5" strokeLinecap="round">
                <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
                <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
              </svg>
            </div>
            <p style={{
              fontFamily: 'var(--ij-font-display)',
              fontSize: '1.15rem', fontStyle: 'italic', fontWeight: 600,
              color: 'var(--ij-text-primary)', marginBottom: 8,
            }}>
              {tab === 'all' ? 'Nothing yet' : `No ${TYPE_META[tab as NotifType]?.label.toLowerCase()} yet`}
            </p>
            <p style={{
              fontSize: '13px', color: 'var(--ij-text-secondary)',
              lineHeight: 1.6, maxWidth: 280, margin: '0 auto',
              fontFamily: 'var(--ij-font-body)',
            }}>
              {tab === 'all'
                ? "When people follow you, react to your posts, or comment, you'll see it here."
                : `Activity will appear here when someone ${TYPE_META[tab as NotifType]?.verb}.`}
            </p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {filtered.map(notif => {
              const meta = TYPE_META[notif.type]
              const isFollowing = followingIds.has(notif.actor_id)
              return (
                <div
                  key={notif.id}
                  style={{
                    background: 'var(--ij-bg-surface)',
                    border: '1px solid var(--ij-border)',
                    borderRadius: 16,
                    padding: '16px 18px',
                    display: 'flex',
                    alignItems: 'flex-start',
                    gap: 14,
                    transition: 'border-color 0.15s, box-shadow 0.15s',
                  }}
                  onMouseEnter={e => {
                    e.currentTarget.style.borderColor = meta.border
                    e.currentTarget.style.boxShadow = `0 4px 16px ${meta.bg}`
                  }}
                  onMouseLeave={e => {
                    e.currentTarget.style.borderColor = 'var(--ij-border)'
                    e.currentTarget.style.boxShadow = 'none'
                  }}
                >
                  {/* Type icon badge */}
                  <div style={{
                    width: 32, height: 32,
                    borderRadius: '50%',
                    background: meta.bg,
                    border: `1px solid ${meta.border}`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    flexShrink: 0,
                    color: meta.color,
                    marginTop: 4,
                  }}>
                    {meta.icon}
                  </div>

                  {/* Avatar */}
                  <Link href={`/profile/${notif.actor_id}`} style={{ flexShrink: 0, display: 'block' }}>
                    <ProfileAvatar userId={notif.actor_id} size={42} voiceName={notif.actor_name} />
                  </Link>

                  {/* Content */}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{
                      fontSize: '0.9rem',
                      color: 'var(--ij-text-primary)',
                      lineHeight: 1.5,
                      fontFamily: 'var(--ij-font-body)',
                      marginBottom: 4,
                    }}>
                      <Link href={`/profile/${notif.actor_id}`} style={{ fontWeight: 700, color: 'var(--ij-text-primary)', textDecoration: 'none' }}>
                        {notif.actor_name}
                      </Link>
                      {' '}
                      <span style={{ color: 'var(--ij-text-secondary)' }}>{meta.verb}</span>
                      {notif.target_id && notif.target_title && (
                        <>
                          {': '}
                          <Link href={`/post/${notif.target_id}`} style={{ color: meta.color, textDecoration: 'none', fontWeight: 600 }}>
                            {notif.target_title.length > 55 ? notif.target_title.slice(0, 55) + '…' : notif.target_title}
                          </Link>
                        </>
                      )}
                    </div>

                    {notif.excerpt && (
                      <div style={{
                        marginBottom: 8,
                        padding: '8px 12px',
                        borderRadius: 8,
                        background: 'var(--ij-bg-elevated)',
                        borderLeft: `3px solid ${meta.color}`,
                        fontSize: '13px',
                        color: 'var(--ij-text-secondary)',
                        lineHeight: 1.5,
                        fontStyle: 'italic',
                        fontFamily: 'var(--ij-font-body)',
                      }}>
                        "{notif.excerpt}{notif.excerpt.length >= 80 ? '…' : ''}"
                      </div>
                    )}

                    <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                      <span style={{ fontSize: '11px', color: 'var(--ij-text-hint)', fontFamily: 'var(--ij-font-body)' }}>
                        {timeAgo(notif.created_at)}
                      </span>
                      {notif.type === 'follow' && notif.actor_id !== currentUserId && (
                        <button
                          onClick={() => handleFollowBack(notif.actor_id)}
                          disabled={loadingFollow === notif.actor_id}
                          style={{
                            background: isFollowing ? 'transparent' : 'rgba(240,168,50,0.10)',
                            border: `1px solid ${isFollowing ? 'var(--ij-border)' : 'var(--ij-border-gold)'}`,
                            borderRadius: 999,
                            color: isFollowing ? 'var(--ij-text-secondary)' : 'var(--ij-gold)',
                            fontFamily: 'var(--ij-font-body)',
                            fontSize: '0.78rem',
                            fontWeight: 700,
                            padding: '7px 14px',
                            minHeight: 34,
                            cursor: loadingFollow === notif.actor_id ? 'wait' : 'pointer',
                            display: 'flex', alignItems: 'center', gap: 5,
                            transition: 'all 0.15s',
                            opacity: loadingFollow === notif.actor_id ? 0.6 : 1,
                          }}
                        >
                          {loadingFollow === notif.actor_id ? '…' : isFollowing ? '✓ Following' : '+ Follow back'}
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
