'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import IjwiLogo from '@/components/IjwiLogo'

export default function ResetPasswordPage() {
  const router = useRouter()
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [ready, setReady] = useState(false)

  const supabase = createClient()

  useEffect(() => {
    // Supabase auto-exchanges the token from the URL hash on load
    supabase.auth.onAuthStateChange((event) => {
      if (event === 'PASSWORD_RECOVERY') setReady(true)
    })
  }, [supabase.auth])

  const handleUpdate = async () => {
    if (password.length < 6) { setError('Password must be at least 6 characters.'); return }
    if (password !== confirm) { setError('Passwords do not match.'); return }
    setLoading(true)
    setError('')

    const { error } = await supabase.auth.updateUser({ password })

    if (error) {
      setError(error.message)
      setLoading(false)
      return
    }

    router.push('/auth/login?message=Password updated. Sign in with your new password.')
  }

  if (!ready) {
    return (
      <main style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '40px 20px' }}>
        <div style={{ textAlign: 'center' }}>
          <p style={{ fontFamily: 'var(--ij-font-body)', color: 'var(--ij-text-secondary)', fontSize: '14px' }}>
            Verifying reset link...
          </p>
        </div>
      </main>
    )
  }

  return (
    <main style={{
      minHeight: '100vh', display: 'flex',
      alignItems: 'center', justifyContent: 'center', padding: '40px 20px',
    }}>
      <div style={{ width: '100%', maxWidth: 480, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 32 }}>
        <Link href="/" style={{ textDecoration: 'none', display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 36, height: 36, borderRadius: 9, background: 'var(--ij-bg-elevated)', border: '1px solid var(--ij-border-gold)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <IjwiLogo size={22} gradient />
          </div>
          <span style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1.6rem', fontWeight: 700, color: 'var(--ij-text-primary)', letterSpacing: '1px' }}>ijwi</span>
        </Link>

        <div className="ij-auth-card">
          <h1 style={{
            fontFamily: 'var(--ij-font-display)', fontSize: '1.7rem', fontWeight: 700,
            color: 'var(--ij-text-primary)', marginBottom: 6,
          }}>
            New password
          </h1>
          <p style={{ fontFamily: 'var(--ij-font-body)', fontSize: '0.88rem', color: 'var(--ij-text-secondary)', marginBottom: 28, lineHeight: 1.5 }}>
            Choose a new password for your account.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginBottom: 16 }}>
            <input
              type="password"
              placeholder="New password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="ij-auth-input"
            />
            <input
              type="password"
              placeholder="Confirm password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleUpdate()}
              className="ij-auth-input"
            />
          </div>

          {error && (
            <p style={{ color: '#C0392B', fontSize: '14px', marginBottom: 16, fontFamily: 'var(--ij-font-body)' }}>{error}</p>
          )}

          <button
            onClick={handleUpdate}
            disabled={loading || !password || !confirm}
            className="ij-btn-primary"
            style={{ opacity: loading || !password || !confirm ? 0.5 : 1, cursor: loading ? 'not-allowed' : 'pointer' }}
          >
            {loading ? 'Updating...' : 'Update password →'}
          </button>
        </div>
      </div>
    </main>
  )
}
