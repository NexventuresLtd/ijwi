'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export default function EventCreateClient({ currentUserId }: { currentUserId: string }) {
  const router = useRouter()
  const supabase = createClient()

  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [location, setLocation] = useState('')
  const [eventDate, setEventDate] = useState('')
  const [endsAt, setEndsAt] = useState('')
  const [isFree, setIsFree] = useState(true)
  const [ticketPrice, setTicketPrice] = useState('')
  const [ticketCurrency, setTicketCurrency] = useState('RWF')
  const [maxAttendees, setMaxAttendees] = useState('')
  const [isVirtual, setIsVirtual] = useState(false)
  const [streamUrl, setStreamUrl] = useState('')
  const [coverFile, setCoverFile] = useState<File | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [amplify, setAmplify] = useState(false)
  const [amplifyPlan, setAmplifyPlan] = useState('3days')

  const amplifyPlans = [
    { key: '3days', label: '3 Days', price: '2,000 RWF', desc: 'Shown on events page' },
    { key: '7days', label: '7 Days', price: '4,500 RWF', desc: 'Events page + home feed' },
    { key: '14days', label: '14 Days', price: '8,000 RWF', desc: 'Featured everywhere' },
  ]

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!title.trim() || !description.trim() || !eventDate) {
      setError('Title, description, and date are required.')
      return
    }
    setLoading(true)
    setError('')

    try {
      let cover_image_url: string | undefined
      if (coverFile) {
        const ext = coverFile.name.split('.').pop()
        const path = `events/${Date.now()}.${ext}`
        const { error: uploadErr } = await supabase.storage.from('images').upload(path, coverFile)
        if (uploadErr) throw new Error(`Cover upload failed: ${uploadErr.message}`)
        const { data: { publicUrl } } = supabase.storage.from('images').getPublicUrl(path)
        cover_image_url = publicUrl
      }

      const { data: event, error: insertErr } = await supabase
        .from('events')
        .insert({
          organizer_id: currentUserId,
          title: title.trim(),
          description: description.trim(),
          location: location.trim() || null,
          event_date: new Date(eventDate).toISOString(),
          ends_at: endsAt ? new Date(endsAt).toISOString() : null,
          is_free: isFree,
          ticket_price: isFree ? null : parseFloat(ticketPrice) || null,
          ticket_currency: isFree ? null : ticketCurrency,
          max_attendees: maxAttendees ? parseInt(maxAttendees) : null,
          is_virtual: isVirtual,
          stream_url: isVirtual && streamUrl.trim() ? streamUrl.trim() : null,
          cover_image_url: cover_image_url ?? null,
        })
        .select('id')
        .single()

      if (insertErr) throw new Error(insertErr.message)
      router.push(`/events/${event.id}`)
    } catch (err: any) {
      setError(err.message)
    }
    setLoading(false)
  }

  return (
    <div className="ij-page-container" style={{ maxWidth: 640 }}>
      <h1 style={{ fontFamily: 'var(--ij-font-display)', fontSize: '2rem', fontWeight: 700, color: 'var(--ij-text-primary)', marginBottom: 4 }}>
        Create event
      </h1>
      <p style={{ fontSize: '14px', color: 'var(--ij-text-secondary)', marginBottom: 28 }}>
        Share a faith gathering with the Ijwi community.
      </p>

      <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div>
          <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-secondary)', display: 'block', marginBottom: 6 }}>Title *</label>
          <input className="ij-auth-input" value={title} onChange={e => setTitle(e.target.value)} placeholder="Worship Night at Kigali Arena" required />
        </div>

        <div>
          <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-secondary)', display: 'block', marginBottom: 6 }}>Description *</label>
          <textarea
            className="ij-auth-input"
            value={description}
            onChange={e => setDescription(e.target.value)}
            placeholder="Describe the event, what to expect, who it's for…"
            rows={4}
            required
            style={{ resize: 'vertical', minHeight: 100 }}
          />
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 12 }}>
          <div>
            <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-secondary)', display: 'block', marginBottom: 6 }}>Date & time *</label>
            <input className="ij-auth-input" type="datetime-local" value={eventDate} onChange={e => setEventDate(e.target.value)} required />
          </div>
          <div>
            <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-secondary)', display: 'block', marginBottom: 6 }}>Ends at</label>
            <input className="ij-auth-input" type="datetime-local" value={endsAt} onChange={e => setEndsAt(e.target.value)} />
          </div>
        </div>

        {/* Virtual toggle */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <button
            type="button"
            onClick={() => setIsVirtual(v => !v)}
            style={{
              width: 42, height: 24, borderRadius: 999, border: 'none', cursor: 'pointer',
              background: isVirtual ? 'var(--ij-gold)' : 'var(--ij-border)',
              position: 'relative', transition: 'background 0.2s',
            }}
          >
            <span style={{
              position: 'absolute', top: 3, left: isVirtual ? 20 : 3,
              width: 18, height: 18, borderRadius: '50%', background: 'white',
              transition: 'left 0.2s',
            }} />
          </button>
          <span style={{ fontSize: '13px', color: 'var(--ij-text-primary)' }}>Online / virtual event</span>
        </div>

        {isVirtual ? (
          <div>
            <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-secondary)', display: 'block', marginBottom: 6 }}>Stream URL (optional)</label>
            <input className="ij-auth-input" value={streamUrl} onChange={e => setStreamUrl(e.target.value)} placeholder="https://youtube.com/live/…" />
            <p style={{ fontSize: '12px', color: 'var(--ij-text-hint)', marginTop: 6, lineHeight: 1.5 }}>
              Leave empty to use Ijwi Live — an in-app chat room where attendees can interact and follow each other.
            </p>
          </div>
        ) : (
          <div>
            <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-secondary)', display: 'block', marginBottom: 6 }}>Location</label>
            <input className="ij-auth-input" value={location} onChange={e => setLocation(e.target.value)} placeholder="Kigali Arena, Kigali" />
          </div>
        )}

        {/* Free toggle */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <button
            type="button"
            onClick={() => setIsFree(f => !f)}
            style={{
              width: 42, height: 24, borderRadius: 999, border: 'none', cursor: 'pointer',
              background: isFree ? 'var(--ij-gold)' : 'var(--ij-border)',
              position: 'relative', transition: 'background 0.2s',
            }}
          >
            <span style={{
              position: 'absolute', top: 3, left: isFree ? 20 : 3,
              width: 18, height: 18, borderRadius: '50%', background: 'white',
              transition: 'left 0.2s',
            }} />
          </button>
          <span style={{ fontSize: '13px', color: 'var(--ij-text-primary)' }}>Free event</span>
        </div>

        {!isFree && (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))', gap: 12 }}>
            <div style={{ gridColumn: '1 / 3' }}>
              <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-secondary)', display: 'block', marginBottom: 6 }}>Ticket price</label>
              <input className="ij-auth-input" type="number" value={ticketPrice} onChange={e => setTicketPrice(e.target.value)} placeholder="5000" min="0" />
            </div>
            <div>
              <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-secondary)', display: 'block', marginBottom: 6 }}>Currency</label>
              <select className="ij-auth-input" value={ticketCurrency} onChange={e => setTicketCurrency(e.target.value)}>
                <option value="RWF">RWF</option>
                <option value="USD">USD</option>
                <option value="KES">KES</option>
              </select>
            </div>
          </div>
        )}

        <div>
          <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-secondary)', display: 'block', marginBottom: 6 }}>Max attendees (optional)</label>
          <input className="ij-auth-input" type="number" value={maxAttendees} onChange={e => setMaxAttendees(e.target.value)} placeholder="200" min="1" />
        </div>

        <div>
          <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-secondary)', display: 'block', marginBottom: 6 }}>Cover image (optional)</label>
          <input
            type="file"
            accept="image/*"
            onChange={e => setCoverFile(e.target.files?.[0] ?? null)}
            style={{ fontSize: '13px', color: 'var(--ij-text-secondary)' }}
          />
        </div>

        {error && <div style={{ fontSize: '13px', color: '#E24B4A', padding: '10px', background: 'rgba(226,75,74,0.08)', borderRadius: 8 }}>{error}</div>}

        {/* Amplify Section */}
        <div style={{
          padding: '20px', borderRadius: 16,
          border: `1.5px solid ${amplify ? 'var(--ij-gold)' : 'var(--ij-border)'}`,
          background: amplify ? 'var(--ij-gold-bg)' : 'var(--ij-bg-surface)',
          transition: 'all 0.2s',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: amplify ? 16 : 0 }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--ij-gold)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z"/><path d="m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z"/><path d="M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0"/><path d="M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5"/></svg>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: '15px', fontWeight: 600, color: 'var(--ij-text-primary)' }}>Amplify your event</div>
              <div style={{ fontSize: '12px', color: 'var(--ij-text-secondary)' }}>Get more attendees with paid promotion</div>
            </div>
            <button
              type="button"
              onClick={() => setAmplify(a => !a)}
              style={{
                width: 42, height: 24, borderRadius: 999, border: 'none', cursor: 'pointer',
                background: amplify ? 'var(--ij-gold)' : 'var(--ij-border)',
                position: 'relative', transition: 'background 0.2s',
              }}
            >
              <span style={{ position: 'absolute', top: 3, left: amplify ? 20 : 3, width: 18, height: 18, borderRadius: '50%', background: 'white', transition: 'left 0.2s' }} />
            </button>
          </div>
          {amplify && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {amplifyPlans.map(plan => (
                <label key={plan.key} onClick={() => setAmplifyPlan(plan.key)} style={{
                  display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px',
                  borderRadius: 12, cursor: 'pointer',
                  border: `1.5px solid ${amplifyPlan === plan.key ? 'var(--ij-gold)' : 'var(--ij-border)'}`,
                  background: amplifyPlan === plan.key ? 'rgba(201,134,10,0.06)' : 'transparent',
                  transition: 'all 0.15s',
                }}>
                  <div style={{ width: 18, height: 18, borderRadius: '50%', border: `2px solid ${amplifyPlan === plan.key ? 'var(--ij-gold)' : 'var(--ij-text-hint)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    {amplifyPlan === plan.key && <div style={{ width: 9, height: 9, borderRadius: '50%', background: 'var(--ij-gold)' }} />}
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: '14px', fontWeight: 600, color: 'var(--ij-text-primary)' }}>{plan.label}</div>
                    <div style={{ fontSize: '11px', color: 'var(--ij-text-secondary)' }}>{plan.desc}</div>
                  </div>
                  <div style={{ fontSize: '13px', fontWeight: 700, color: 'var(--ij-gold)' }}>{plan.price}</div>
                </label>
              ))}
              <p style={{ fontSize: '11px', color: 'var(--ij-text-hint)', marginTop: 4, fontStyle: 'italic' }}>
                Payment will be processed via MoMo after creating the event.
              </p>
            </div>
          )}
        </div>

        <button type="submit" className="ij-btn-primary" disabled={loading}>
          {loading ? 'Creating event…' : amplify ? 'Create & Amplify →' : 'Create event →'}
        </button>
      </form>
    </div>
  )
}
