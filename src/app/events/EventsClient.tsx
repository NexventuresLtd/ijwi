'use client'

import Link from 'next/link'
import Image from 'next/image'
import { useState } from 'react'
import Navbar from '@/components/layout/Navbar'
import { Profile } from '@/lib/types'

interface Organizer {
  id: string
  voice_name: string
  avatar_url?: string
  is_verified?: boolean
}

interface Event {
  id: string
  title: string
  description: string
  location?: string
  event_date: string
  ends_at?: string
  ticket_price?: number
  ticket_currency?: string
  max_attendees?: number
  created_at: string
  cover_image_url?: string
  is_free: boolean
  is_virtual: boolean
  stream_url?: string
  tags?: string[]
  organizer?: Organizer
}

interface Props {
  events: Event[]
  currentUserId?: string
  profile?: Profile | null
  isAdmin: boolean
}

function formatEventDate(dateStr: string) {
  const d = new Date(dateStr)
  return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function EventCard({ event }: { event: Event }) {
  return (
    <Link href={`/events/${event.id}`} style={{ textDecoration: 'none', display: 'block' }}>
      <article style={{
        background: 'var(--ij-bg-surface)',
        border: '1px solid var(--ij-border)',
        borderRadius: 'var(--ij-radius-lg)',
        overflow: 'hidden',
        transition: 'border-color 0.2s, box-shadow 0.2s, transform 0.15s',
        cursor: 'pointer',
      }}
        onMouseEnter={e => {
          e.currentTarget.style.borderColor = 'var(--ij-border-gold)'
          e.currentTarget.style.boxShadow = '0 8px 32px var(--ij-glow-gold)'
          e.currentTarget.style.transform = 'translateY(-2px)'
        }}
        onMouseLeave={e => {
          e.currentTarget.style.borderColor = 'var(--ij-border)'
          e.currentTarget.style.boxShadow = 'none'
          e.currentTarget.style.transform = 'translateY(0)'
        }}
      >
        {/* Cover image */}
        {event.cover_image_url ? (
          <div style={{ position: 'relative', width: '100%', aspectRatio: '16/8', background: 'var(--ij-bg-elevated)' }}>
            <Image src={event.cover_image_url} alt={event.title} fill style={{ objectFit: 'cover' }} unoptimized />
          </div>
        ) : (
          <div style={{
            width: '100%', aspectRatio: '16/8',
            background: 'linear-gradient(135deg, var(--ij-bg-elevated), var(--ij-bg-surface))',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="var(--ij-text-hint)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/>
              <line x1="4" x2="4" y1="22" y2="15"/>
            </svg>
          </div>
        )}

        <div style={{ padding: '18px 20px' }}>
          {/* Date + price badge */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
            <span style={{ fontSize: '11px', color: 'var(--ij-gold)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em' }}>
              {formatEventDate(event.event_date)}
            </span>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
              {event.is_virtual && !event.stream_url && (
                <span style={{
                  fontSize: '9px', fontWeight: 800, padding: '3px 7px',
                  borderRadius: 4, letterSpacing: '0.06em',
                  background: 'rgba(239,68,68,0.12)', color: '#ef4444',
                  border: '1px solid rgba(239,68,68,0.3)',
                  display: 'flex', alignItems: 'center', gap: 3,
                }}>
                  <span style={{ width: 5, height: 5, borderRadius: '50%', background: '#ef4444' }} />
                  LIVE
                </span>
              )}
              <span style={{
                fontSize: '10px', fontWeight: 700, padding: '4px 10px',
                borderRadius: 999, letterSpacing: '0.04em',
                background: event.is_free ? 'rgba(39,174,96,0.12)' : 'var(--ij-gold-bg)',
                color: event.is_free ? '#27AE60' : 'var(--ij-gold)',
                border: `1px solid ${event.is_free ? 'rgba(39,174,96,0.3)' : 'var(--ij-border-gold)'}`,
              }}>
                {event.is_free ? '✓ FREE' : `${event.ticket_currency ?? 'RWF'} ${(event.ticket_price ?? 0).toLocaleString()}`}
              </span>
            </div>
          </div>

          <h3 style={{
            fontFamily: 'var(--ij-font-display)',
            fontSize: '1.25rem', fontWeight: 700,
            color: 'var(--ij-text-primary)', lineHeight: 1.25,
            marginBottom: 8,
            display: '-webkit-box', WebkitLineClamp: 2,
            WebkitBoxOrient: 'vertical', overflow: 'hidden',
          }}>
            {event.title}
          </h3>

          <p style={{
            fontSize: '13px', color: 'var(--ij-text-secondary)',
            lineHeight: 1.55, marginBottom: 14,
            display: '-webkit-box', WebkitLineClamp: 2,
            WebkitBoxOrient: 'vertical', overflow: 'hidden',
          }}>
            {event.description}
          </p>

          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: '12px', color: 'var(--ij-text-secondary)' }}>
              {event.is_virtual ? (
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>
                </svg>
              ) : (
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>
                </svg>
              )}
              <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', maxWidth: 140 }}>
                {event.is_virtual ? 'Online event' : (event.location ?? 'TBA')}
              </span>
            </div>
            {event.organizer && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: '11px', color: 'var(--ij-text-hint)' }}>
                <span>by</span>
                <span style={{ color: 'var(--ij-text-secondary)', fontWeight: 600, maxWidth: 80, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {event.organizer.voice_name}
                </span>
                {event.organizer.is_verified && <span style={{ color: 'var(--ij-gold)', fontSize: 10 }}>✓</span>}
              </div>
            )}
          </div>
        </div>
      </article>
    </Link>
  )
}

export default function EventsClient({ events, currentUserId, profile, isAdmin }: Props) {
  const [filter, setFilter] = useState<'all' | 'free' | 'virtual' | 'in-person'>('all')
  const [search, setSearch] = useState('')

  const filtered = events.filter(e => {
    if (filter === 'free' && !e.is_free) return false
    if (filter === 'virtual' && !e.is_virtual) return false
    if (filter === 'in-person' && e.is_virtual) return false
    if (search.trim()) {
      const q = search.toLowerCase()
      const matchTitle = e.title.toLowerCase().includes(q)
      const matchOrg = e.organizer?.voice_name?.toLowerCase().includes(q)
      if (!matchTitle && !matchOrg) return false
    }
    return true
  })

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--ij-bg-base)' }}>
      <Navbar profile={profile} />

      <div className="ij-page-container">
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 28, flexWrap: 'wrap', gap: 12 }}>
          <div>
            <p style={{ fontFamily: 'var(--ij-font-body)', fontSize: '0.65rem', fontWeight: 700, letterSpacing: '0.14em', textTransform: 'uppercase', color: 'var(--ij-gold)', marginBottom: 6 }}>
              Ijwi Events
            </p>
            <h1 style={{ fontFamily: 'var(--ij-font-display)', fontSize: 'clamp(1.8rem, 4vw, 2.6rem)', fontWeight: 700, color: 'var(--ij-text-primary)', lineHeight: 1.15, marginBottom: 6 }}>
              Gather. Worship. Grow.
            </h1>
            <p style={{ fontSize: '14px', color: 'var(--ij-text-secondary)', maxWidth: 400, lineHeight: 1.55 }}>
              Faith gatherings, worship nights, prayer summits, and community events near you.
            </p>
          </div>
          {currentUserId && (
            <Link href="/events/create" style={{ textDecoration: 'none', flexShrink: 0 }}>
              <button className="ij-btn-primary" style={{ width: 'auto', padding: '10px 22px', fontSize: '0.88rem' }}>
                + Host event
              </button>
            </Link>
          )}
        </div>

        {/* Search bar */}
        <div style={{ position: 'relative', marginBottom: 20 }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--ij-text-hint)" strokeWidth="2" strokeLinecap="round"
            style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }}>
            <circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>
          </svg>
          <input
            type="text"
            placeholder="Search events or organizers..."
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

        {/* Filter chips */}
        <div style={{ display: 'flex', gap: 8, marginBottom: 28, flexWrap: 'wrap' }}>
          {([
            { key: 'all', label: 'All events' },
            { key: 'free', label: '✓ Free' },
            { key: 'virtual', label: 'Online' },
            { key: 'in-person', label: 'In-person' },
          ] as const).map(f => (
            <button
              key={f.key}
              onClick={() => setFilter(f.key)}
              className={`ij-chip${filter === f.key ? ' active' : ''}`}
            >
              {f.label}
            </button>
          ))}
        </div>

        {/* Grid */}
        {filtered.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '80px 24px', color: 'var(--ij-text-secondary)' }}>
            <div style={{ width: 64, height: 64, borderRadius: '50%', background: 'var(--ij-bg-elevated)', border: '1px solid var(--ij-border)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="var(--ij-text-hint)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                <rect width="18" height="18" x="3" y="4" rx="2" ry="2"/>
                <line x1="16" x2="16" y1="2" y2="6"/><line x1="8" x2="8" y1="2" y2="6"/>
                <line x1="3" x2="21" y1="10" y2="10"/>
              </svg>
            </div>
            <p style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1.4rem', fontStyle: 'italic', fontWeight: 600, color: 'var(--ij-text-primary)', marginBottom: 8 }}>
              No upcoming events yet
            </p>
            <p style={{ fontSize: '14px', marginBottom: 24, lineHeight: 1.6 }}>Be the first to host one — your community is waiting.</p>
            {currentUserId && (
              <Link href="/events/create" style={{ textDecoration: 'none' }}>
                <button className="ij-btn-primary" style={{ width: 'auto', display: 'inline-flex', padding: '12px 28px' }}>
                  Host an event →
                </button>
              </Link>
            )}
          </div>
        ) : (
          <div className="events-grid" style={{ gap: 22 }}>
            {filtered.map(event => (
              <EventCard key={event.id} event={event} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
