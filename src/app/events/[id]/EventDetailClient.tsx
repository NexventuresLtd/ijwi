'use client'

import { useState } from 'react'
import Image from 'next/image'
import Link from 'next/link'
import Navbar from '@/components/layout/Navbar'
import { Profile } from '@/lib/types'

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
  cover_image_url?: string
  is_free: boolean
  is_virtual: boolean
  stream_url?: string
  tags?: string[]
  organizer_id: string
  organizer?: {
    id: string
    voice_name: string
    avatar_url?: string
    is_verified?: boolean
    bio?: string
  }
}

interface Props {
  event: Event
  attendeeCount: number
  currentUserId?: string
  userTicket?: { id: string; status: string } | null
  profile?: Profile | null
}

function formatEventDate(dateStr: string) {
  return new Date(dateStr).toLocaleDateString('en-US', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

export default function EventDetailClient({ event, attendeeCount, currentUserId, userTicket, profile }: Props) {
  const [phone, setPhone] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)

  const hasPaid = userTicket?.status === 'paid'
  const isSoldOut = event.max_attendees != null && attendeeCount >= event.max_attendees

  const handlePurchase = async () => {
    if (!currentUserId) return
    if (!event.is_free && !phone.trim()) { setError('Enter your MoMo phone number'); return }
    const cleaned = phone.replace(/[\s\-().+]/g, '')
    const normalized = cleaned.startsWith('250') ? cleaned : cleaned.startsWith('0') ? `250${cleaned.slice(1)}` : `250${cleaned}`
    if (!event.is_free && !/^2507[23789]\d{7}$/.test(normalized)) {
      setError('Enter a valid Rwanda phone (MTN or Airtel)')
      return
    }
    setLoading(true)
    setError('')
    try {
      const res = await fetch('/api/events/purchase', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ event_id: event.id, phone: event.is_free ? undefined : normalized }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error ?? 'Payment failed')
      setSuccess(true)
    } catch (err: any) {
      setError(err.message)
    }
    setLoading(false)
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--ij-bg-base)' }}>
      <Navbar profile={profile} />

      <div className="ij-page-container" style={{ maxWidth: 800 }}>

        {/* Back button */}
        <Link href="/events" style={{ textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: 6, marginBottom: 20 }}>
          <button style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            background: 'var(--ij-bg-surface)', border: '1px solid var(--ij-border)',
            borderRadius: 999, padding: '8px 16px',
            fontFamily: 'var(--ij-font-body)', fontSize: '13px',
            color: 'var(--ij-text-secondary)', cursor: 'pointer',
            transition: 'border-color 0.15s, color 0.15s',
          }}
            onMouseEnter={e => { e.currentTarget.style.borderColor = 'var(--ij-border-gold)'; e.currentTarget.style.color = 'var(--ij-gold)' }}
            onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--ij-border)'; e.currentTarget.style.color = 'var(--ij-text-secondary)' }}
          >
            ← Back to Events
          </button>
        </Link>

        {/* Cover */}
        {event.cover_image_url ? (
          <div style={{ position: 'relative', width: '100%', aspectRatio: '16/7', borderRadius: 'var(--ij-radius-lg)', overflow: 'hidden', marginBottom: 28 }}>
            <Image src={event.cover_image_url} alt={event.title} fill style={{ objectFit: 'cover' }} unoptimized />
          </div>
        ) : (
          <div style={{
            width: '100%', aspectRatio: '16/7', borderRadius: 'var(--ij-radius-lg)',
            background: 'linear-gradient(135deg, var(--ij-bg-elevated), var(--ij-bg-surface))',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            marginBottom: 28,
          }}>
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--ij-text-hint)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/>
              <line x1="4" x2="4" y1="22" y2="15"/>
            </svg>
          </div>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 32 }}>

          {/* Left: event info */}
          <div>
            {/* Tags */}
            {event.tags && event.tags.length > 0 && (
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 14 }}>
                {event.tags.map(t => (
                  <span key={t} className="ij-chip" style={{ fontSize: '11px' }}>{t}</span>
                ))}
              </div>
            )}

            <h1 style={{
              fontFamily: 'var(--ij-font-display)',
              fontSize: 'clamp(1.8rem, 5vw, 2.8rem)',
              fontWeight: 700, color: 'var(--ij-text-primary)',
              lineHeight: 1.15, marginBottom: 18,
            }}>
              {event.title}
            </h1>

            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, marginBottom: 24 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 16px', background: 'var(--ij-bg-surface)', border: '1px solid var(--ij-border)', borderRadius: 'var(--ij-radius-md)' }}>
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="var(--ij-gold)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <rect width="18" height="18" x="3" y="4" rx="2" ry="2"/>
                  <line x1="16" x2="16" y1="2" y2="6"/><line x1="8" x2="8" y1="2" y2="6"/>
                  <line x1="3" x2="21" y1="10" y2="10"/>
                </svg>
                <span style={{ fontFamily: 'var(--ij-font-body)', fontSize: '13px', color: 'var(--ij-text-primary)', fontWeight: 500 }}>
                  {formatEventDate(event.event_date)}
                </span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 16px', background: 'var(--ij-bg-surface)', border: '1px solid var(--ij-border)', borderRadius: 'var(--ij-radius-md)' }}>
                {event.is_virtual ? (
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="var(--ij-gold)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>
                  </svg>
                ) : (
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="var(--ij-gold)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>
                  </svg>
                )}
                <span style={{ fontFamily: 'var(--ij-font-body)', fontSize: '13px', color: 'var(--ij-text-primary)', fontWeight: 500 }}>
                  {event.is_virtual ? 'Online event' : (event.location ?? 'TBA')}
                </span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 16px', background: 'var(--ij-bg-surface)', border: '1px solid var(--ij-border)', borderRadius: 'var(--ij-radius-md)' }}>
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="var(--ij-gold)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>
                  <path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                </svg>
                <span style={{ fontFamily: 'var(--ij-font-body)', fontSize: '13px', color: 'var(--ij-text-primary)', fontWeight: 500 }}>
                  {attendeeCount} attending{event.max_attendees ? ` of ${event.max_attendees}` : ''}
                </span>
              </div>
            </div>

            {/* Description */}
            <div style={{
              fontFamily: 'var(--ij-font-body)', fontSize: '15px',
              color: 'var(--ij-text-primary)', lineHeight: 1.8,
              marginBottom: 28, whiteSpace: 'pre-wrap',
            }}>
              {event.description}
            </div>

            {/* Organizer */}
            {event.organizer && (
              <div style={{
                display: 'flex', alignItems: 'center', gap: 12,
                padding: '16px 18px',
                background: 'var(--ij-bg-elevated)',
                borderRadius: 'var(--ij-radius-md)',
                border: '1px solid var(--ij-border)',
                marginBottom: 24,
              }}>
                <div style={{
                  width: 44, height: 44, borderRadius: '50%',
                  background: 'conic-gradient(from 160deg, hsl(40,55%,35%), hsl(80,65%,50%))',
                  flexShrink: 0,
                }} />
                <div>
                  <div style={{ fontSize: '11px', fontWeight: 600, color: 'var(--ij-text-secondary)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 2 }}>
                    Organized by
                  </div>
                  <div style={{ fontSize: '14px', fontWeight: 700, color: 'var(--ij-text-primary)', display: 'flex', alignItems: 'center', gap: 6 }}>
                    {event.organizer.voice_name}
                    {event.organizer.is_verified && (
                      <span style={{ color: 'var(--ij-gold)', fontSize: '12px', fontWeight: 600 }}>✓ Verified</span>
                    )}
                  </div>
                  {event.organizer.bio && (
                    <div style={{ fontSize: '13px', color: 'var(--ij-text-secondary)', marginTop: 2, lineHeight: 1.4 }}>
                      {event.organizer.bio}
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* Ticket card */}
          <div style={{
            background: 'var(--ij-bg-surface)',
            border: '1px solid var(--ij-border-gold)',
            borderRadius: 'var(--ij-radius-lg)',
            padding: 28,
            boxShadow: '0 4px 24px var(--ij-glow-gold)',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
              <div>
                <div style={{ fontSize: '28px', fontWeight: 800, color: 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-display)', lineHeight: 1 }}>
                  {event.is_free ? 'Free' : `${event.ticket_currency ?? 'RWF'} ${(event.ticket_price ?? 0).toLocaleString()}`}
                </div>
                <div style={{ fontSize: '12px', color: 'var(--ij-text-secondary)', marginTop: 4 }}>
                  {event.is_free ? 'Register at no cost' : 'per ticket · paid via MoMo'}
                </div>
              </div>
              {isSoldOut && (
                <span style={{
                  fontSize: '11px', fontWeight: 700, padding: '5px 12px', borderRadius: 999,
                  background: 'rgba(226,75,74,0.10)', color: '#E24B4A',
                  border: '1px solid rgba(226,75,74,0.25)',
                }}>
                  SOLD OUT
                </span>
              )}
            </div>

            {hasPaid ? (
              <div style={{ padding: '18px', background: 'rgba(39,174,96,0.08)', border: '1px solid rgba(39,174,96,0.25)', borderRadius: 'var(--ij-radius-md)', textAlign: 'center' }}>
                <div style={{ width: 40, height: 40, borderRadius: '50%', background: 'rgba(39,174,96,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 8px' }}>
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#27AE60" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <polyline points="20 6 9 17 4 12"/>
                  </svg>
                </div>
                <div style={{ fontSize: '15px', fontWeight: 700, color: '#27AE60', marginBottom: 4 }}>You're registered!</div>
                <div style={{ fontSize: '13px', color: 'var(--ij-text-secondary)', marginBottom: 12 }}>See you there. Spread the word!</div>
                {event.is_virtual && (
                  event.stream_url ? (
                    <a href={event.stream_url} target="_blank" rel="noopener" style={{ fontSize: '13px', color: 'var(--ij-gold)', fontWeight: 600 }}>
                      Join stream →
                    </a>
                  ) : (
                    <Link href={`/events/${event.id}/live`} className="ij-btn-primary" style={{ display: 'inline-flex', justifyContent: 'center', width: 'auto', padding: '10px 24px', fontSize: '0.88rem', marginTop: 4 }}>
                      Join Ijwi Live →
                    </Link>
                  )
                )}
              </div>
            ) : success ? (
              <div style={{ padding: '18px', background: 'rgba(39,174,96,0.08)', border: '1px solid rgba(39,174,96,0.25)', borderRadius: 'var(--ij-radius-md)', textAlign: 'center' }}>
                <div style={{ width: 40, height: 40, borderRadius: '50%', background: 'rgba(39,174,96,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 8px' }}>
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#27AE60" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.127.96.362 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.907.338 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/>
                  </svg>
                </div>
                <div style={{ fontSize: '14px', fontWeight: 600, color: '#27AE60' }}>Payment initiated!</div>
                <div style={{ fontSize: '13px', color: 'var(--ij-text-secondary)', marginTop: 4 }}>Check your phone for the MoMo prompt.</div>
              </div>
            ) : !currentUserId ? (
              <Link href="/auth/signup" className="ij-btn-primary" style={{ display: 'flex', justifyContent: 'center' }}>
                Sign up to get tickets →
              </Link>
            ) : isSoldOut ? (
              <button className="ij-btn-secondary" disabled style={{ cursor: 'not-allowed', opacity: 0.5 }}>
                Sold out
              </button>
            ) : event.is_free ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                <button className="ij-btn-primary" onClick={handlePurchase} disabled={loading}>
                  {loading ? 'Registering…' : 'Register for free →'}
                </button>
                {event.is_virtual && !event.stream_url && (
                  <Link href={`/events/${event.id}/live`} style={{ textDecoration: 'none', textAlign: 'center', fontSize: '0.82rem', color: 'var(--ij-gold)', fontWeight: 600 }}>
                    or join the live room directly →
                  </Link>
                )}
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <input
                  type="tel"
                  placeholder="MoMo number (e.g. 0781234567)"
                  value={phone}
                  onChange={e => setPhone(e.target.value)}
                  className="ij-auth-input"
                />
                {error && <div style={{ fontSize: '13px', color: '#E24B4A', fontFamily: 'var(--ij-font-body)' }}>{error}</div>}
                <button className="ij-btn-primary" onClick={handlePurchase} disabled={loading}>
                  {loading ? 'Processing…' : `Pay ${event.ticket_currency ?? 'RWF'} ${(event.ticket_price ?? 0).toLocaleString()} →`}
                </button>
              </div>
            )}
          </div>

        </div>
      </div>
    </div>
  )
}
