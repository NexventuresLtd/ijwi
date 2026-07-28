'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export default function AdminLoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    const { error: authError } = await supabase.auth.signInWithPassword({ email, password })
    if (authError) {
      setError(authError.message)
      setLoading(false)
      return
    }

    // Verify admin access
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { setError('Authentication failed.'); setLoading(false); return }

    const adminEmails = ['armandkayiranga7@gmail.com', 'niyonshutidavid49@gmail.com']
    const { data: profile } = await supabase.from('profiles').select('is_admin').eq('id', user.id).single()

    if (!adminEmails.includes(user.email ?? '') && !profile?.is_admin) {
      await supabase.auth.signOut()
      setError('Access denied. Admin credentials required.')
      setLoading(false)
      return
    }

    router.push('/admin/dashboard')
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#0C0916', padding: 20 }}>
      <div style={{ width: '100%', maxWidth: 400 }}>
        <div style={{ textAlign: 'center', marginBottom: 40 }}>
          <div style={{ fontFamily: 'var(--ij-font-display, Georgia)', fontSize: '2rem', fontWeight: 700, color: '#F2AC3A', marginBottom: 8 }}>
            ijwi
          </div>
          <div style={{ fontSize: 14, color: '#A89CB8' }}>Admin Panel</div>
        </div>

        <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <input
            type="email"
            placeholder="Admin email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            required
            style={{
              width: '100%', padding: '14px 16px', borderRadius: 12,
              border: '1px solid rgba(255,255,255,0.1)', background: '#14102A',
              color: '#F2EEE8', fontSize: 15, outline: 'none', boxSizing: 'border-box',
            }}
          />
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            required
            style={{
              width: '100%', padding: '14px 16px', borderRadius: 12,
              border: '1px solid rgba(255,255,255,0.1)', background: '#14102A',
              color: '#F2EEE8', fontSize: 15, outline: 'none', boxSizing: 'border-box',
            }}
          />

          {error && (
            <div style={{ padding: '10px 14px', borderRadius: 8, background: 'rgba(226,75,74,0.1)', border: '1px solid rgba(226,75,74,0.3)', color: '#E24B4A', fontSize: 13 }}>
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            style={{
              width: '100%', padding: '14px', borderRadius: 999,
              background: loading ? '#333' : '#F2AC3A', color: loading ? '#666' : '#0C0916',
              border: 'none', fontSize: 15, fontWeight: 700, cursor: loading ? 'not-allowed' : 'pointer',
              marginTop: 8,
            }}
          >
            {loading ? 'Authenticating...' : 'Access Admin Panel →'}
          </button>
        </form>

        <p style={{ textAlign: 'center', marginTop: 24, fontSize: 12, color: '#6A6358' }}>
          Only authorized administrators can access this panel.
        </p>
      </div>
    </div>
  )
}
