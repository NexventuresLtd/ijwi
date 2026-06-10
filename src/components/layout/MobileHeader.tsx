'use client'

import Link from 'next/link'
import { Profile } from '@/lib/types'
import ProfileAvatar from '@/components/ui/ProfileAvatar'

interface MobileHeaderProps {
  profile?: Profile | null
  unreadCount?: number
}

export default function MobileHeader({ profile, unreadCount = 0 }: MobileHeaderProps) {
  return (
    <header
      className="md:hidden"
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '14px 20px 10px',
        background: 'var(--surface)',
        borderBottom: '1px solid var(--border)',
        position: 'sticky',
        top: 0,
        zIndex: 50,
      }}
    >
      <span style={{
        fontFamily: 'var(--font-display)',
        fontSize: '26px',
        fontWeight: 400,
        color: 'var(--flame)',
        letterSpacing: '-0.5px',
      }}>
        ijwi
      </span>

      <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
        <Link href="/notifications" style={{
          position: 'relative',
          width: '36px', height: '36px',
          borderRadius: '50%',
          background: 'var(--surface-2)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          textDecoration: 'none',
          border: '1px solid var(--border)',
        }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none"
            stroke="var(--text-secondary)" strokeWidth="1.8" strokeLinecap="round"
            strokeLinejoin="round">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
            <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
          </svg>
          {unreadCount > 0 && (
            <span style={{
              position: 'absolute', top: '2px', right: '2px',
              width: '16px', height: '16px', borderRadius: '50%',
              background: 'var(--flame)', color: 'white',
              fontSize: '10px', fontWeight: 700,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {unreadCount > 9 ? '9+' : unreadCount}
            </span>
          )}
        </Link>

        {profile && (
          <Link href={`/profile/${profile.id}`} style={{ textDecoration: 'none' }}>
            <ProfileAvatar
              userId={profile.id}
              avatarUrl={profile.avatar_url}
              isRevealed={profile.is_revealed}
              size={34}
            />
          </Link>
        )}
      </div>
    </header>
  )
}
