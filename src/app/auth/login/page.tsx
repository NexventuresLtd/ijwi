'use client'

import { useState, useEffect, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import IjwiLogo from '@/components/IjwiLogo'

function LoginForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const redirectTo = searchParams.get('redirect') ?? '/feed'
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [info, setInfo] = useState('')
  const [loading, setLoading] = useState(false)
  const [resending, setResending] = useState(false)
  const [resent, setResent] = useState(false)
  const [emailNotConfirmed, setEmailNotConfirmed] = useState(false)

  const supabase = createClient()

  useEffect(() => {
    const message = searchParams.get('message')
    if (message) setInfo(message)
  }, [searchParams])

  const handleLogin = async () => {
    setLoading(true)
    setError('')
    setEmailNotConfirmed(false)

    const { error } = await supabase.auth.signInWithPassword({ email, password })

    if (error) {
      if (error.message.toLowerCase().includes('email not confirmed') ||
          error.message.toLowerCase().includes('not confirmed')) {
        setEmailNotConfirmed(true)
      } else {
        setError(error.message)
      }
      setLoading(false)
      return
    }

    router.push(redirectTo)
  }

  const handleResend = async () => {
    if (!email) { setError('Enter your email address above first.'); return }
    setResending(true)
    await supabase.auth.resend({ type: 'signup', email })
    setResending(false)
    setResent(true)
  }

  return (
    <main style={{
      minHeight: '100vh', display: 'flex',
      alignItems: 'center', justifyContent: 'center', padding: '40px 20px',
    }}>
      <div style={{ width: '100%', maxWidth: 480, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 32 }}>
        {/* Logo */}
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
            Welcome back
          </h1>
          <p style={{ fontFamily: 'var(--ij-font-body)', fontSize: '0.88rem', color: 'var(--ij-text-secondary)', marginBottom: 28, lineHeight: 1.5 }}>
            Your voice is waiting for you.
          </p>

          {info && (
            <div style={{ padding: '12px 16px', borderRadius: 10, background: 'var(--ij-gold-bg)', border: '1px solid var(--ij-border-gold)', fontSize: '14px', color: 'var(--ij-text-secondary)', marginBottom: 20, lineHeight: 1.5 }}>
              {info}
            </div>
          )}

          <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginBottom: 20 }}>
            <input
              type="email"
              placeholder="Email address"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="ij-auth-input"
            />
            <input
              type="password"
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleLogin()}
              className="ij-auth-input"
            />
          </div>

          {error && (
            <p style={{ color: '#C0392B', fontSize: '14px', marginBottom: 16, fontFamily: 'var(--ij-font-body)' }}>{error}</p>
          )}

          {emailNotConfirmed && (
            <div style={{ padding: '16px', borderRadius: 12, background: 'var(--ij-gold-bg)', border: '1px solid var(--ij-border-gold)', marginBottom: 20 }}>
              <p style={{ fontSize: '14px', color: 'var(--ij-text-secondary)', lineHeight: 1.6, marginBottom: 12, fontFamily: 'var(--ij-font-body)' }}>
                Your email isn't confirmed yet. Check your inbox for the link we sent when you signed up.
              </p>
              {resent ? (
                <p style={{ fontSize: '13px', color: 'var(--ij-gold)', fontWeight: 500 }}>✓ Confirmation email resent!</p>
              ) : (
                <button
                  onClick={handleResend}
                  disabled={resending}
                  style={{
                    padding: '8px 18px', borderRadius: 999,
                    border: '1px solid var(--ij-border-gold)', background: 'transparent',
                    color: 'var(--ij-gold)', fontSize: '13px', fontWeight: 600,
                    cursor: resending ? 'wait' : 'pointer', fontFamily: 'var(--ij-font-body)',
                  }}
                >
                  {resending ? 'Sending...' : 'Resend confirmation email'}
                </button>
              )}
            </div>
          )}

          <div style={{ textAlign: 'right', marginBottom: 16 }}>
            <Link href="/auth/forgot-password" style={{ fontSize: '13px', color: 'var(--ij-gold)', textDecoration: 'none', fontFamily: 'var(--ij-font-body)' }}>
              Forgot password?
            </Link>
          </div>

          <button
            onClick={handleLogin}
            disabled={loading || !email || !password}
            className="ij-btn-primary"
            style={{ opacity: loading || !email || !password ? 0.5 : 1, cursor: loading ? 'not-allowed' : 'pointer' }}
          >
            {loading ? 'Signing in...' : 'Sign in →'}
          </button>

          <p style={{ textAlign: 'center', fontSize: '14px', color: 'var(--ij-text-secondary)', marginTop: 24, fontFamily: 'var(--ij-font-body)' }}>
            New to Ijwi?{' '}
            <Link href="/auth/signup" style={{ color: 'var(--ij-gold)', textDecoration: 'none', fontWeight: 500 }}>
              Find your voice
            </Link>
          </p>
        </div>
      </div>
    </main>
  )
}

export default function LoginPage() {
  return (
    <Suspense>
      <LoginForm />
    </Suspense>
  )
}
