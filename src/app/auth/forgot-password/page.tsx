'use client'

import { useState } from 'react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import IjwiLogo from '@/components/IjwiLogo'

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('')
  const [loading, setLoading] = useState(false)
  const [sent, setSent] = useState(false)
  const [error, setError] = useState('')

  const supabase = createClient()

  const handleReset = async () => {
    if (!email) return
    setLoading(true)
    setError('')

    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/reset-password`,
    })

    if (error) {
      setError(error.message)
    } else {
      setSent(true)
    }
    setLoading(false)
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
            Reset password
          </h1>
          <p style={{ fontFamily: 'var(--ij-font-body)', fontSize: '0.88rem', color: 'var(--ij-text-secondary)', marginBottom: 28, lineHeight: 1.5 }}>
            Enter your email and we'll send you a link to reset your password.
          </p>

          {sent ? (
            <div style={{ padding: '16px', borderRadius: 12, background: 'var(--ij-gold-bg)', border: '1px solid var(--ij-border-gold)' }}>
              <p style={{ fontSize: '14px', color: 'var(--ij-text-secondary)', lineHeight: 1.6, fontFamily: 'var(--ij-font-body)' }}>
                ✓ Check your inbox at <strong>{email}</strong>. Click the link to set a new password.
              </p>
            </div>
          ) : (
            <>
              <input
                type="email"
                placeholder="Email address"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleReset()}
                className="ij-auth-input"
                style={{ marginBottom: 16 }}
              />

              {error && (
                <p style={{ color: '#C0392B', fontSize: '14px', marginBottom: 16, fontFamily: 'var(--ij-font-body)' }}>{error}</p>
              )}

              <button
                onClick={handleReset}
                disabled={loading || !email}
                className="ij-btn-primary"
                style={{ opacity: loading || !email ? 0.5 : 1, cursor: loading ? 'not-allowed' : 'pointer' }}
              >
                {loading ? 'Sending...' : 'Send reset link →'}
              </button>
            </>
          )}

          <p style={{ textAlign: 'center', fontSize: '14px', color: 'var(--ij-text-secondary)', marginTop: 24, fontFamily: 'var(--ij-font-body)' }}>
            <Link href="/auth/login" style={{ color: 'var(--ij-gold)', textDecoration: 'none', fontWeight: 500 }}>
              ← Back to sign in
            </Link>
          </p>
        </div>
      </div>
    </main>
  )
}
