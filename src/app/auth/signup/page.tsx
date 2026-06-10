'use client'

import { useState, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { generateFlamePattern } from '@/lib/utils'
import IjwiLogo from '@/components/IjwiLogo'
import ProfileAvatar from '@/components/ui/ProfileAvatar'

const SUGGESTED_VOICE_NAMES = [
  'A voice from Kigali',
  'Firekeeper',
  'Still waters',
  'The quiet flame',
  'Dawn seeker',
  'Valley voice',
  'Burning bush',
  'Desert rain',
]

function SignupForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const referralCode = searchParams.get('ref') ?? null
  const redirectTo = searchParams.get('redirect') ?? '/feed'
  const [step, setStep] = useState<'identity' | 'credentials'>('identity')
  const [voiceName, setVoiceName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [emailSent, setEmailSent] = useState(false)

  const supabase = createClient()

  const handleContinue = () => {
    if (!voiceName.trim()) { setError('Choose a voice name to continue'); return }
    setError('')
    setStep('credentials')
  }

  const handleSignup = async () => {
    setLoading(true)
    setError('')

    const flamePattern = generateFlamePattern(email)

    const { error, data: signupData } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { voice_name: voiceName, flame_pattern: flamePattern } },
    })

    if (!error && signupData?.user && referralCode) {
      await supabase.from('referrals').insert({
        referrer_code: referralCode,
        referred_user_id: signupData.user.id,
      })
    }

    if (error) { setError(error.message); setLoading(false); return }
    setEmailSent(true)
    setLoading(false)
  }

  if (emailSent) {
    return (
      <main style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '40px 20px' }}>
        <div style={{ width: '100%', maxWidth: 480, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 32 }}>
          <Link href="/" style={{ textDecoration: 'none', display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 36, height: 36, borderRadius: 9, background: 'var(--ij-bg-elevated)', border: '1px solid var(--ij-border-gold)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <IjwiLogo size={22} gradient />
            </div>
            <span style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1.6rem', fontWeight: 700, color: 'var(--ij-text-primary)', letterSpacing: '1px' }}>ijwi</span>
          </Link>
          <div className="ij-auth-card" style={{ textAlign: 'center' }}>
            <div style={{ fontSize: 52, marginBottom: 20 }}>✉️</div>
            <h1 style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1.6rem', fontWeight: 700, color: 'var(--ij-text-primary)', marginBottom: 12 }}>
              Check your email
            </h1>
            <p style={{ fontSize: '15px', color: 'var(--ij-text-secondary)', lineHeight: 1.7, marginBottom: 8, fontFamily: 'var(--ij-font-body)' }}>
              We sent a confirmation link to <strong style={{ color: 'var(--ij-text-primary)' }}>{email}</strong>
            </p>
            <p style={{ fontSize: '14px', color: 'var(--ij-text-hint)', lineHeight: 1.6, marginBottom: 28, fontFamily: 'var(--ij-font-body)' }}>
              Click the link to activate your account. Check your spam folder if you don't see it.
            </p>
            <Link href="/auth/login" className="ij-btn-primary">
              I confirmed my email →
            </Link>
          </div>
        </div>
      </main>
    )
  }

  return (
    <main style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '40px 20px' }}>
      <div style={{ width: '100%', maxWidth: 480, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 32 }}>
        {/* Logo */}
        <Link href="/" style={{ textDecoration: 'none', display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 36, height: 36, borderRadius: 9, background: 'var(--ij-bg-elevated)', border: '1px solid var(--ij-border-gold)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <IjwiLogo size={22} gradient />
          </div>
          <span style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1.6rem', fontWeight: 700, color: 'var(--ij-text-primary)', letterSpacing: '1px' }}>ijwi</span>
        </Link>

        <div className="ij-auth-card">
          {step === 'identity' ? (
            <>
              <h1 style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1.7rem', fontWeight: 700, color: 'var(--ij-text-primary)', marginBottom: 6 }}>
                Choose your voice name
              </h1>
              <p style={{ fontSize: '0.88rem', color: 'var(--ij-text-secondary)', marginBottom: 28, lineHeight: 1.6, fontFamily: 'var(--ij-font-body)' }}>
                This is how the community will know you. Your real identity stays private — always.
              </p>

              <div style={{ marginBottom: 20 }}>
                <input
                  type="text"
                  placeholder="e.g. A voice from Kigali"
                  value={voiceName}
                  onChange={(e) => setVoiceName(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleContinue()}
                  maxLength={40}
                  className="ij-auth-input"
                  style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1rem' }}
                />
                {voiceName && (
                  <div style={{ marginTop: 12, padding: '12px 16px', borderRadius: 12, background: 'var(--ij-gold-bg)', border: '1px solid var(--ij-border-gold)', display: 'flex', alignItems: 'center', gap: 12 }}>
                    <ProfileAvatar userId={voiceName} size={36} voiceName={voiceName} />
                    <div>
                      <div style={{ fontSize: '14px', fontWeight: 500, color: 'var(--ij-text-primary)', fontFamily: 'var(--ij-font-body)' }}>{voiceName}</div>
                      <div style={{ fontSize: '12px', color: 'var(--ij-text-hint)', fontFamily: 'var(--ij-font-body)' }}>Your avatar — yours alone</div>
                    </div>
                  </div>
                )}
              </div>

              <div style={{ marginBottom: 24 }}>
                <div style={{ fontSize: '11px', color: 'var(--ij-text-hint)', marginBottom: 10, fontFamily: 'var(--ij-font-body)' }}>Or choose one</div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                  {SUGGESTED_VOICE_NAMES.map((name) => (
                    <button
                      key={name}
                      onClick={() => setVoiceName(name)}
                      style={{
                        padding: '6px 14px', borderRadius: 999,
                        border: `1px solid ${voiceName === name ? 'var(--ij-border-gold)' : 'var(--ij-border)'}`,
                        background: voiceName === name ? 'var(--ij-gold-bg)' : 'transparent',
                        color: voiceName === name ? 'var(--ij-gold)' : 'var(--ij-text-secondary)',
                        fontSize: '13px', cursor: 'pointer', fontFamily: 'var(--ij-font-body)',
                        transition: 'all 0.15s',
                      }}
                    >
                      {name}
                    </button>
                  ))}
                </div>
              </div>

              {error && <p style={{ color: '#C0392B', fontSize: '14px', marginBottom: 16, fontFamily: 'var(--ij-font-body)' }}>{error}</p>}

              <button onClick={handleContinue} className="ij-btn-primary">
                This is my voice →
              </button>
            </>
          ) : (
            <>
              <button
                onClick={() => setStep('identity')}
                style={{ background: 'none', border: 'none', color: 'var(--ij-text-hint)', fontSize: '14px', cursor: 'pointer', marginBottom: 20, fontFamily: 'var(--ij-font-body)', padding: 0 }}
              >
                ← Back
              </button>

              <h1 style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1.7rem', fontWeight: 700, color: 'var(--ij-text-primary)', marginBottom: 6 }}>
                Secure your account
              </h1>
              <p style={{ fontSize: '0.88rem', color: 'var(--ij-text-secondary)', marginBottom: 28, lineHeight: 1.6, fontFamily: 'var(--ij-font-body)' }}>
                Your email is only for account recovery — it will never be shown to anyone.
              </p>

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
                  placeholder="Password (min. 8 characters)"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="ij-auth-input"
                />
              </div>

              {error && <p style={{ color: '#C0392B', fontSize: '14px', marginBottom: 16, fontFamily: 'var(--ij-font-body)' }}>{error}</p>}

              <button
                onClick={handleSignup}
                disabled={loading || !email || password.length < 8}
                className="ij-btn-primary"
                style={{ opacity: loading || !email || password.length < 8 ? 0.5 : 1, cursor: loading ? 'not-allowed' : 'pointer' }}
              >
                {loading ? 'Creating your voice...' : 'Enter Ijwi →'}
              </button>
            </>
          )}

          <p style={{ textAlign: 'center', fontSize: '14px', color: 'var(--ij-text-secondary)', marginTop: 24, fontFamily: 'var(--ij-font-body)' }}>
            Already have a voice?{' '}
            <Link href="/auth/login" style={{ color: 'var(--ij-gold)', textDecoration: 'none', fontWeight: 500 }}>
              Sign in
            </Link>
          </p>
        </div>
      </div>
    </main>
  )
}

export default function SignupPage() {
  return (
    <Suspense>
      <SignupForm />
    </Suspense>
  )
}
