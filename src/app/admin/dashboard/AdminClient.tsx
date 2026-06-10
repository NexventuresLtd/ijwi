'use client'

import { useState } from 'react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { timeAgo } from '@/lib/utils'

type AdminPost = {
  id: string; content_type: string; title: string | null; body: string
  created_at: string; is_anonymous: boolean
  author: { id: string; voice_name: string; is_banned: boolean } | null
}
type AdminUser = {
  id: string; voice_name: string; real_name: string | null; level: string
  xp: number; voice_role: string | null; is_banned: boolean; is_admin: boolean; is_answerer: boolean
  is_dm_listed: boolean; is_approved_poster: boolean; created_at: string
}
type AdminReport = {
  id: string; reason: string; notes: string | null; reviewed: boolean; created_at: string
  post: { id: string; title: string | null; body: string; content_type: string } | null
  reporter: { id: string; voice_name: string } | null
}

type AdminPayment = {
  id: string; phone: string; amount: number; currency: string
  ref: string | null; status: string; created_at: string
  user: { id: string; voice_name: string } | null
}

interface AdminClientProps {
  posts: AdminPost[]
  users: AdminUser[]
  reports: AdminReport[]
  payments: AdminPayment[]
}

type Tab = 'overview' | 'reports' | 'payments' | 'posts' | 'users' | 'events'

const TABS: { id: Tab; label: string }[] = [
  { id: 'overview', label: '📊 Overview' },
  { id: 'reports', label: '🚩 Reports' },
  { id: 'payments', label: '💳 Payments' },
  { id: 'posts', label: '📝 Posts' },
  { id: 'users', label: '👥 Users' },
  { id: 'events', label: '📅 Events' },
]

export default function AdminClient({ posts: initialPosts, users: initialUsers, reports: initialReports, payments: initialPayments }: AdminClientProps) {
  const [tab, setTab] = useState<Tab>('overview')
  const [posts, setPosts] = useState(initialPosts)
  const [users, setUsers] = useState(initialUsers)
  const [reports, setReports] = useState(initialReports)
  const [payments, setPayments] = useState(initialPayments)
  const [loading, setLoading] = useState<string | null>(null)
  const supabase = createClient()

  const deletePost = async (id: string) => {
    if (!confirm('Delete this post permanently?')) return
    setLoading(id)
    await supabase.from('posts').delete().eq('id', id)
    setPosts(p => p.filter(x => x.id !== id))
    setLoading(null)
  }

  const adminUpdate = async (targetId: string, field: string, value: unknown) => {
    const res = await fetch('/api/admin/profile', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetId, field, value }),
    })
    if (!res.ok) {
      const { error } = await res.json()
      alert(`Update failed: ${error}`)
      return false
    }
    return true
  }

  const toggleBan = async (userId: string, current: boolean) => {
    const action = current ? 'Unban' : 'Ban'
    if (!confirm(`${action} this user?`)) return
    setLoading(userId)
    if (await adminUpdate(userId, 'is_banned', !current)) {
      setUsers(u => u.map(x => x.id === userId ? { ...x, is_banned: !current } : x))
    }
    setLoading(null)
  }

  const toggleAnswerer = async (userId: string, current: boolean) => {
    setLoading(userId + '-ans')
    if (await adminUpdate(userId, 'is_answerer', !current)) {
      setUsers(u => u.map(x => x.id === userId ? { ...x, is_answerer: !current } : x))
    }
    setLoading(null)
  }

  const toggleDmListed = async (userId: string, current: boolean) => {
    setLoading(userId + '-dm')
    if (await adminUpdate(userId, 'is_dm_listed', !current)) {
      setUsers(u => u.map(x => x.id === userId ? { ...x, is_dm_listed: !current } : x))
    }
    setLoading(null)
  }

  const toggleApproval = async (userId: string, approve: boolean) => {
    setLoading(userId + '-poster')
    const supaClient = createClient()
    if (approve) {
      // Approving: set all three fields at once
      const { error } = await supaClient.from('profiles')
        .update({ is_approved_poster: true, is_verified: true, is_dm_listed: true })
        .eq('id', userId)
      if (!error) {
        setUsers(u => u.map(x => x.id === userId ? { ...x, is_approved_poster: true, is_dm_listed: true } : x))
      }
    } else {
      if (await adminUpdate(userId, 'is_approved_poster', false)) {
        setUsers(u => u.map(x => x.id === userId ? { ...x, is_approved_poster: false } : x))
      }
    }
    setLoading(null)
  }

  const dismissReport = async (reportId: string, deletePostId?: string) => {
    setLoading(reportId)
    if (deletePostId) {
      await supabase.from('posts').delete().eq('id', deletePostId)
      setPosts(p => p.filter(x => x.id !== deletePostId))
    }
    await supabase.from('reports').update({ reviewed: true }).eq('id', reportId)
    setReports(r => r.filter(x => x.id !== reportId))
    setLoading(null)
  }

  const grantPro = async (paymentId: string, userId: string) => {
    if (!confirm('Manually grant Pro to this user?')) return
    setLoading(paymentId)
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()
    await adminUpdate(userId, 'is_pro' as any, true)
    await supabase.from('payments').update({ status: 'successful' }).eq('id', paymentId)
    setPayments(p => p.map(x => x.id === paymentId ? { ...x, status: 'successful' } : x))
    setLoading(null)
  }

  const revokePayment = async (paymentId: string) => {
    if (!confirm('Mark this payment as failed?')) return
    setLoading(paymentId)
    await supabase.from('payments').update({ status: 'failed' }).eq('id', paymentId)
    setPayments(p => p.map(x => x.id === paymentId ? { ...x, status: 'failed' } : x))
    setLoading(null)
  }

  const unreviewedCount = reports.length
  const pendingPayments = payments.filter(p => p.status === 'pending').length

  return (
    <div style={{ minHeight: '100vh', background: 'var(--warm-white)' }}>
      {/* Header */}
      <div style={{
        background: '#111', color: 'white', padding: '16px 24px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          <Link href="/feed" style={{ color: 'rgba(255,255,255,0.6)', textDecoration: 'none', fontSize: '14px' }}>
            ← Back to app
          </Link>
          <span style={{ fontFamily: 'var(--font-display)', fontSize: '20px', color: 'var(--flame)' }}>
            Admin
          </span>
        </div>
        <div style={{ fontSize: '13px', color: 'rgba(255,255,255,0.4)' }}>
          {posts.length} posts · {users.length} users · {payments.filter(p => p.status === 'successful').length} paid
        </div>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', borderBottom: '2px solid var(--border)', background: 'var(--surface)', padding: '0 24px' }}>
        {TABS.map(t => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            style={{
              padding: '14px 20px', border: 'none', background: 'transparent', cursor: 'pointer',
              fontSize: '14px', fontWeight: tab === t.id ? 700 : 400,
              color: tab === t.id ? 'var(--text-primary)' : 'var(--text-muted)',
              borderBottom: `2px solid ${tab === t.id ? 'var(--flame)' : 'transparent'}`,
              marginBottom: '-2px', fontFamily: 'var(--font-body)',
              position: 'relative'
            }}
          >
            {t.label}
            {t.id === 'payments' && pendingPayments > 0 && (
              <span style={{
                marginLeft: '8px', background: '#F59E0B', color: 'white',
                borderRadius: '100px', padding: '1px 7px', fontSize: '11px', fontWeight: 700
              }}>
                {pendingPayments}
              </span>
            )}
            {t.id === 'reports' && unreviewedCount > 0 && (
              <span style={{
                marginLeft: '8px', background: '#E24B4A', color: 'white',
                borderRadius: '100px', padding: '1px 7px', fontSize: '11px', fontWeight: 700
              }}>
                {unreviewedCount}
              </span>
            )}
          </button>
        ))}
      </div>

      <div style={{ padding: '24px', maxWidth: '900px' }}>

        {/* ── OVERVIEW TAB ── */}
        {tab === 'overview' && (
          <div>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '20px', color: 'var(--text-primary)' }}>Dashboard Overview</h2>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '12px', marginBottom: '28px' }}>
              {[{label:'Total Users',value:users.length,color:'var(--flame)'},{label:'Total Posts',value:posts.length,color:'#4F46E5'},{label:'Open Reports',value:unreviewedCount,color:'#E24B4A'},{label:'Pending Payments',value:pendingPayments,color:'#F59E0B'},{label:'Revenue (RWF)',value:payments.filter(p=>p.status==='successful').reduce((s,p)=>s+p.amount,0).toLocaleString(),color:'#2A9D8F'},{label:'Approved Posters',value:users.filter(u=>u.is_approved_poster).length,color:'#C9860A'}].map(s=>(
                <div key={s.label} className="card" style={{ padding: '18px 16px', textAlign: 'center' }}>
                  <div style={{ fontSize: '24px', fontWeight: 700, color: s.color }}>{s.value}</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>{s.label}</div>
                </div>
              ))}
            </div>
            <div className="card" style={{ padding: '20px' }}>
              <h3 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '12px', color: 'var(--text-primary)' }}>Quick Actions</h3>
              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                <button onClick={()=>setTab('reports')} style={{padding:'8px 16px',borderRadius:'8px',border:'1px solid var(--border)',background:unreviewedCount>0?'#FEE2E2':'transparent',color:unreviewedCount>0?'#E24B4A':'var(--text-secondary)',fontSize:'13px',cursor:'pointer',fontFamily:'var(--font-body)'}}>Review {unreviewedCount} reports</button>
                <button onClick={()=>setTab('payments')} style={{padding:'8px 16px',borderRadius:'8px',border:'1px solid var(--border)',background:pendingPayments>0?'#FEF3C7':'transparent',color:pendingPayments>0?'#92400E':'var(--text-secondary)',fontSize:'13px',cursor:'pointer',fontFamily:'var(--font-body)'}}>{pendingPayments} pending payments</button>
                <button onClick={()=>setTab('users')} style={{padding:'8px 16px',borderRadius:'8px',border:'1px solid var(--border)',background:'transparent',color:'var(--text-secondary)',fontSize:'13px',cursor:'pointer',fontFamily:'var(--font-body)'}}>Manage users</button>
                <button onClick={()=>setTab('events')} style={{padding:'8px 16px',borderRadius:'8px',border:'1px solid var(--border)',background:'transparent',color:'var(--text-secondary)',fontSize:'13px',cursor:'pointer',fontFamily:'var(--font-body)'}}>Manage events</button>
              </div>
            </div>
          </div>
        )}

        {/* ── REPORTS TAB ── */}
        {tab === 'reports' && (
          <div>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '20px', color: 'var(--text-primary)' }}>
              Open reports {unreviewedCount > 0 && `(${unreviewedCount})`}
            </h2>
            {reports.length === 0 ? (
              <div className="card" style={{ padding: '48px', textAlign: 'center' }}>
                <div style={{ fontSize: '40px', marginBottom: '12px' }}>✅</div>
                <p style={{ color: 'var(--text-muted)' }}>No open reports. Community is clean.</p>
              </div>
            ) : reports.map(r => (
              <div key={r.id} className="card" style={{ padding: '20px', marginBottom: '12px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '12px' }}>
                  <div>
                    <span style={{ fontSize: '12px', fontWeight: 700, color: '#E24B4A', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
                      {r.reason}
                    </span>
                    <span style={{ fontSize: '12px', color: 'var(--text-muted)', marginLeft: '12px' }}>
                      reported by {r.reporter?.voice_name ?? 'unknown'} · {timeAgo(r.created_at)}
                    </span>
                  </div>
                  <Link href={`/post/${r.post?.id}`} target="_blank" style={{ fontSize: '12px', color: 'var(--flame)', textDecoration: 'none' }}>
                    View post →
                  </Link>
                </div>
                {r.post && (
                  <p style={{ fontSize: '14px', color: 'var(--text-secondary)', lineHeight: 1.6, marginBottom: '14px', padding: '12px', background: 'var(--surface-2)', borderRadius: '8px' }}>
                    {r.post.title ? <strong>{r.post.title}: </strong> : null}
                    {r.post.body.slice(0, 200)}{r.post.body.length > 200 ? '…' : ''}
                  </p>
                )}
                {r.notes && (
                  <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '12px', fontStyle: 'italic' }}>
                    "{r.notes}"
                  </p>
                )}
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button
                    onClick={() => dismissReport(r.id, r.post?.id)}
                    disabled={loading === r.id}
                    style={{
                      padding: '8px 16px', borderRadius: '8px', border: 'none',
                      background: '#E24B4A', color: 'white', fontSize: '13px',
                      cursor: 'pointer', fontFamily: 'var(--font-body)', fontWeight: 600,
                    }}
                  >
                    🗑 Delete post & close
                  </button>
                  <button
                    onClick={() => dismissReport(r.id)}
                    disabled={loading === r.id}
                    style={{
                      padding: '8px 16px', borderRadius: '8px', border: '1px solid var(--border)',
                      background: 'transparent', color: 'var(--text-secondary)', fontSize: '13px',
                      cursor: 'pointer', fontFamily: 'var(--font-body)',
                    }}
                  >
                    Dismiss
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* ── PAYMENTS TAB ── */}
        {tab === 'payments' && (
          <div>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '6px', color: 'var(--text-primary)' }}>
              Mobile Money Payments
            </h2>
            <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '20px' }}>
              Successful payments auto-activate Pro via webhook. Use "Grant Pro" for pending ones where the user approved but webhook was missed.
            </p>

            {/* Stats row */}
            <div style={{ display: 'flex', gap: '12px', marginBottom: '24px', flexWrap: 'wrap' }}>
              {[
                { label: 'Total', value: payments.length, color: 'var(--flame)' },
                { label: 'Successful', value: payments.filter(p => p.status === 'successful').length, color: '#15803D' },
                { label: 'Pending', value: payments.filter(p => p.status === 'pending').length, color: '#F59E0B' },
                { label: 'Failed', value: payments.filter(p => p.status === 'failed').length, color: '#E24B4A' },
                { label: 'Revenue (RWF)', value: `${payments.filter(p => p.status === 'successful').reduce((s, p) => s + p.amount, 0).toLocaleString()}`, color: '#2A9D8F' },
              ].map(s => (
                <div key={s.label} className="card" style={{ padding: '14px 20px', flex: '1 1 100px', minWidth: '100px' }}>
                  <div style={{ fontSize: '22px', fontWeight: 700, color: s.color }}>{s.value}</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '2px' }}>{s.label}</div>
                </div>
              ))}
            </div>

            {payments.length === 0 ? (
              <div className="card" style={{ padding: '48px', textAlign: 'center' }}>
                <div style={{ fontSize: '40px', marginBottom: '12px' }}>💳</div>
                <p style={{ color: 'var(--text-muted)' }}>No payments yet.</p>
              </div>
            ) : payments.map(p => (
              <div key={p.id} className="card" style={{ padding: '16px 20px', marginBottom: '10px' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px', flexWrap: 'wrap' }}>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap', marginBottom: '4px' }}>
                      <span style={{
                        fontSize: '11px', fontWeight: 700, padding: '2px 8px', borderRadius: '100px',
                        background: p.status === 'successful' ? '#DCFCE7' : p.status === 'pending' ? '#FEF3C7' : '#FEE2E2',
                        color: p.status === 'successful' ? '#15803D' : p.status === 'pending' ? '#92400E' : '#E24B4A',
                      }}>
                        {p.status.toUpperCase()}
                      </span>
                      <span style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-primary)' }}>
                        {p.amount.toLocaleString()} {p.currency}
                      </span>
                      <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
                        {p.phone.replace(/(\d{3})(\d{3})(\d{4})/, '$1 $2 $3')}
                      </span>
                    </div>
                    <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                      {p.user?.voice_name ?? 'Unknown user'} · {timeAgo(p.created_at)}
                      {p.ref && <span style={{ marginLeft: '8px', opacity: 0.6 }}>ref: {p.ref.slice(0, 12)}…</span>}
                    </div>
                  </div>
                  {p.status === 'pending' && p.user && (
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        onClick={() => grantPro(p.id, p.user!.id)}
                        disabled={loading === p.id}
                        style={{
                          padding: '6px 14px', borderRadius: '8px', border: 'none',
                          background: '#15803D', color: 'white', fontSize: '12px',
                          cursor: 'pointer', fontFamily: 'var(--font-body)', fontWeight: 600,
                        }}
                      >
                        Grant Pro
                      </button>
                      <button
                        onClick={() => revokePayment(p.id)}
                        disabled={loading === p.id}
                        style={{
                          padding: '6px 14px', borderRadius: '8px', border: '1px solid var(--border)',
                          background: 'transparent', color: 'var(--text-muted)', fontSize: '12px',
                          cursor: 'pointer', fontFamily: 'var(--font-body)',
                        }}
                      >
                        Fail
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* ── POSTS TAB ── */}
        {tab === 'posts' && (
          <div>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '20px', color: 'var(--text-primary)' }}>
              Recent posts ({posts.length})
            </h2>
            {posts.map(p => (
              <div key={p.id} className="card" style={{ padding: '16px 20px', marginBottom: '10px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '12px' }}>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px', flexWrap: 'wrap' }}>
                      <span style={{ fontSize: '11px', fontWeight: 700, color: 'var(--flame)', textTransform: 'uppercase' }}>
                        {p.content_type}
                      </span>
                      <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                        by {p.is_anonymous ? 'Anonymous' : (p.author?.voice_name ?? 'unknown')} · {timeAgo(p.created_at)}
                      </span>
                      {p.author?.is_banned && (
                        <span style={{ fontSize: '11px', background: '#E24B4A', color: 'white', padding: '1px 6px', borderRadius: '4px' }}>
                          banned
                        </span>
                      )}
                    </div>
                    <p style={{ fontSize: '14px', color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {p.title ? <strong>{p.title}: </strong> : null}{p.body.slice(0, 120)}
                    </p>
                  </div>
                  <div style={{ display: 'flex', gap: '8px', flexShrink: 0 }}>
                    <Link href={`/post/${p.id}`} target="_blank" style={{ padding: '6px 12px', borderRadius: '8px', border: '1px solid var(--border)', fontSize: '12px', color: 'var(--text-secondary)', textDecoration: 'none' }}>
                      View
                    </Link>
                    <button
                      onClick={() => deletePost(p.id)}
                      disabled={loading === p.id}
                      style={{ padding: '6px 12px', borderRadius: '8px', border: 'none', background: '#E24B4A', color: 'white', fontSize: '12px', cursor: 'pointer', fontFamily: 'var(--font-body)' }}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* ── USERS TAB ── */}
        {tab === 'users' && (
          <div>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '4px', color: 'var(--text-primary)' }}>
              Users ({users.length})
            </h2>
            <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '20px' }}>
              <strong>Answerer</strong> — can answer Questions tab posts &nbsp;·&nbsp; <strong>Helper</strong> — appears in the DMs helper directory
            </p>
            {users.map(u => (
              <div key={u.id} className="card" style={{ padding: '14px 20px', marginBottom: '10px' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px', flexWrap: 'wrap' }}>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                      <Link href={`/profile/${u.id}`} style={{ fontSize: '15px', fontWeight: 600, color: 'var(--text-primary)', textDecoration: 'none' }}>
                        {u.voice_name}
                      </Link>
                      {u.real_name && <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>{u.real_name}</span>}
                      {u.is_admin && <span style={{ fontSize: '11px', background: '#2A9D8F', color: 'white', padding: '1px 6px', borderRadius: '4px' }}>admin</span>}
                      {u.is_answerer && <span style={{ fontSize: '11px', background: '#4F46E5', color: 'white', padding: '1px 6px', borderRadius: '4px' }}>answerer</span>}
                      {u.is_dm_listed && <span style={{ fontSize: '11px', background: '#0891B2', color: 'white', padding: '1px 6px', borderRadius: '4px' }}>helper</span>}
                      {u.is_approved_poster && <span style={{ fontSize: '11px', background: 'linear-gradient(135deg,#C9860A,#F0A832)', color: '#0B0B1F', padding: '1px 6px', borderRadius: '4px' }}>poster</span>}
                      {u.is_banned && <span style={{ fontSize: '11px', background: '#E24B4A', color: 'white', padding: '1px 6px', borderRadius: '4px' }}>banned</span>}
                    </div>
                    <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '2px' }}>
                      {u.voice_role ? u.voice_role.replace(/_/g, ' ') : 'voice'} · joined {timeAgo(u.created_at)}
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                    {/* Approved Poster toggle */}
                    <button
                      onClick={() => toggleApproval(u.id, !u.is_approved_poster)}
                      disabled={loading === u.id + '-poster'}
                      title="Approved posters can publish content. Also sets verified + helper."
                      style={{
                        padding: '6px 12px', borderRadius: '8px', fontSize: '12px', fontWeight: 600,
                        border: `1px solid ${u.is_approved_poster ? '#C9860A' : 'var(--border)'}`,
                        background: u.is_approved_poster ? '#FEF3C7' : 'transparent',
                        color: u.is_approved_poster ? '#92400E' : 'var(--text-muted)',
                        cursor: 'pointer', fontFamily: 'var(--font-body)',
                      }}
                    >
                      {u.is_approved_poster ? '✓ Poster' : '+ Approve'}
                    </button>
                    {/* Answerer toggle */}
                    <button
                      onClick={() => toggleAnswerer(u.id, u.is_answerer)}
                      disabled={loading === u.id + '-ans'}
                      title="Can answer questions in the Questions tab"
                      style={{
                        padding: '6px 12px', borderRadius: '8px', fontSize: '12px', fontWeight: 600,
                        border: `1px solid ${u.is_answerer ? '#4F46E5' : 'var(--border)'}`,
                        background: u.is_answerer ? '#EEF2FF' : 'transparent',
                        color: u.is_answerer ? '#4F46E5' : 'var(--text-muted)',
                        cursor: 'pointer', fontFamily: 'var(--font-body)',
                      }}
                    >
                      {u.is_answerer ? '✓ Answerer' : '+ Answerer'}
                    </button>
                    {/* DM helper toggle */}
                    <button
                      onClick={() => toggleDmListed(u.id, u.is_dm_listed)}
                      disabled={loading === u.id + '-dm'}
                      title="Appears in DMs helper directory"
                      style={{
                        padding: '6px 12px', borderRadius: '8px', fontSize: '12px', fontWeight: 600,
                        border: `1px solid ${u.is_dm_listed ? '#0891B2' : 'var(--border)'}`,
                        background: u.is_dm_listed ? '#ECFEFF' : 'transparent',
                        color: u.is_dm_listed ? '#0891B2' : 'var(--text-muted)',
                        cursor: 'pointer', fontFamily: 'var(--font-body)',
                      }}
                    >
                      {u.is_dm_listed ? '✓ Helper' : '+ Helper'}
                    </button>
                    {/* Ban toggle */}
                    <button
                      onClick={() => toggleBan(u.id, u.is_banned)}
                      disabled={loading === u.id || u.is_admin}
                      style={{
                        padding: '6px 12px', borderRadius: '8px', border: 'none', fontSize: '12px',
                        background: u.is_banned ? '#2A9D8F' : '#E24B4A',
                        color: 'white', cursor: u.is_admin ? 'not-allowed' : 'pointer',
                        opacity: u.is_admin ? 0.4 : 1, fontFamily: 'var(--font-body)',
                      }}
                    >
                      {u.is_banned ? 'Unban' : 'Ban'}
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* ── EVENTS TAB ── */}
        {tab === 'events' && (
          <div>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '20px', color: 'var(--text-primary)' }}>Events Management</h2>
            <div className="card" style={{ padding: '20px', marginBottom: '16px' }}>
              <p style={{ fontSize: '13px', color: 'var(--text-muted)', lineHeight: 1.6, marginBottom: '12px' }}>
                Manage community events. Amplified events (paid promotion) have the <strong>early_access</strong> flag and are featured on the home feed and events page.
              </p>
              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                <Link href="/events" style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', padding: '8px 16px', borderRadius: '8px', background: 'var(--flame)', color: 'white', textDecoration: 'none', fontSize: '13px', fontWeight: 600, fontFamily: 'var(--font-body)' }}>View all events →</Link>
                <Link href="/events/create" style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', padding: '8px 16px', borderRadius: '8px', border: '1px solid var(--border)', color: 'var(--text-secondary)', textDecoration: 'none', fontSize: '13px', fontFamily: 'var(--font-body)' }}>+ Create event</Link>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
