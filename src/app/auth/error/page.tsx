'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useSearchParams } from 'next/navigation'
import { Suspense } from 'react'
import { createClient } from '@/lib/supabase/client'

function AuthErrorContent() {
  const searchParams = useSearchParams()
  const errorCode = searchParams.get('error_code')
  const description = searchParams.get('error_description')
  const isExpired = errorCode === 'otp_expired'

  const [email, setEmail] = useState('')
  const [resending, setResending] = useState(false)
  const [resent, setResent] = useState(false)
  const [resendError, setResendError] = useState('')

  const supabase = createClient()

  const handleResend = async () => {
    if (!email.trim()) {
      setResendError('Enter your email address first.')
      return
    }
    setResending(true)
    setResendError('')
    const { error } = await supabase.auth.resend({ type: 'signup', email: email.trim() })
    setResending(false)
    if (error) {
      setResendError(error.message)
    } else {
      setResent(true)
    }
  }

  return (
    <main style={{
      minHeight: '100vh', background: 'var(--warm-white)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: '40px 20px'
    }}>
      <div style={{ width: '100%', maxWidth: '440px', textAlign: 'center' }}>
        <Link href="/" style={{
          fontFamily: 'var(--font-display)', fontSize: '32px',
          fontWeight: 500, color: 'var(--flame)', textDecoration: 'none',
          display: 'block', marginBottom: '40px'
        }}>
          ijwi
        </Link>

        <div className="card" style={{ padding: '40px' }}>
          <div style={{ fontSize: '48px', marginBottom: '20px' }}>
            {isExpired ? '⏰' : '⚠️'}
          </div>
          <h1 style={{
            fontFamily: 'var(--font-display)', fontSize: '24px', fontWeight: 500,
            color: 'var(--text-primary)', marginBottom: '12px'
          }}>
            {isExpired ? 'Link expired' : 'Something went wrong'}
          </h1>
          <p style={{ fontSize: '14px', color: 'var(--text-secondary)', lineHeight: 1.7, marginBottom: '28px' }}>
            {isExpired
              ? 'Confirmation links expire after a short time. Enter your email below and we\'ll send you a fresh one — open it on this computer.'
              : 'The link didn\'t work. Enter your email and we\'ll send a new confirmation.'}
          </p>

          {resent ? (
            <div style={{
              padding: '20px', borderRadius: '12px',
              background: '#F0FBF8', border: '1px solid #A8E6D8',
              marginBottom: '20px'
            }}>
              <div style={{ fontSize: '28px', marginBottom: '10px' }}>✉️</div>
              <p style={{ fontSize: '14px', color: '#2A9D8F', fontWeight: 600, marginBottom: '4px' }}>
                Confirmation email sent!
              </p>
              <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: 1.6 }}>
                Open your inbox on <strong>this computer</strong> and click the link. Check spam if you don't see it.
              </p>
            </div>
          ) : (
            <div style={{ marginBottom: '20px' }}>
              <input
                type="email"
                placeholder="Your email address"
                value={email}
                onChange={e => setEmail(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && handleResend()}
                style={{
                  width: '100%', padding: '14px 16px', borderRadius: '12px',
                  border: '1px solid var(--border)', fontSize: '15px',
                  fontFamily: 'var(--font-body)', background: 'var(--surface)',
                  color: 'var(--text-primary)', outline: 'none',
                  marginBottom: '12px', boxSizing: 'border-box'
                }}
              />
              {resendError && (
                <p style={{ color: '#E24B4A', fontSize: '13px', marginBottom: '10px' }}>{resendError}</p>
              )}
              <button
                onClick={handleResend}
                disabled={resending}
                style={{
                  width: '100%', padding: '13px', borderRadius: '100px',
                  background: resending ? 'var(--border)' : 'var(--flame)',
                  color: resending ? 'var(--text-muted)' : 'white',
                  border: 'none', fontSize: '15px', fontWeight: 600,
                  cursor: resending ? 'wait' : 'pointer',
                  fontFamily: 'var(--font-body)'
                }}
              >
                {resending ? 'Sending...' : 'Resend confirmation email'}
              </button>
            </div>
          )}

          <Link href="/auth/login" style={{
            display: 'block', padding: '12px', borderRadius: '100px',
            border: '1px solid var(--border)', color: 'var(--text-secondary)',
            textDecoration: 'none', fontSize: '14px', fontFamily: 'var(--font-body)'
          }}>
            Back to sign in
          </Link>
        </div>
      </div>
    </main>
  )
}

export default function AuthErrorPage() {
  return (
    <Suspense>
      <AuthErrorContent />
    </Suspense>
  )
}
