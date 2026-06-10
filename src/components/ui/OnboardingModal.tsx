'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'

const STEPS = [
  {
    icon: '🔥',
    title: 'Welcome to Ijwi',
    subtitle: 'The Voice',
    body: 'This is a faith space for African Christian youth — a place to share testimonies, prayers, devotionals, and spoken word. Your voice was made for this moment.',
    cta: 'Next →',
  },
  {
    icon: '🎭',
    title: 'You can be anonymous',
    subtitle: 'Your voice. Your rules.',
    body: 'Every post can be shared anonymously using just your voice name. No one will know it\'s you — unless you choose to reveal yourself.',
    cta: 'Next →',
  },
  {
    icon: '✨',
    title: 'Grow as you share',
    subtitle: 'Your voice. Your role. Your community.',
    body: 'Post testimonies, devotionals, prayers, and spoken word. The more you share, the deeper your impact in the community.',
    cta: 'Start sharing →',
    final: true,
  },
]

interface OnboardingModalProps {
  onDone: () => void
}

export default function OnboardingModal({ onDone }: OnboardingModalProps) {
  const [step, setStep] = useState(0)
  const current = STEPS[step]

  const handleNext = () => {
    if (current.final) {
      localStorage.setItem('ijwi_onboarded', '1')
      onDone()
    } else {
      setStep(s => s + 1)
    }
  }

  return (
    <div style={{
      position: 'fixed', inset: 0, zIndex: 999,
      background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(6px)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: '20px',
    }}>
      <div className="card modal-enter" style={{
        maxWidth: '420px', width: '100%', padding: '48px 36px',
        textAlign: 'center', position: 'relative',
      }}>
        {/* Progress dots */}
        <div style={{ display: 'flex', justifyContent: 'center', gap: '6px', marginBottom: '32px' }}>
          {STEPS.map((_, i) => (
            <div key={i} style={{
              width: i === step ? '20px' : '7px', height: '7px',
              borderRadius: '100px', transition: 'all 0.3s',
              background: i <= step ? 'var(--flame)' : 'var(--border)',
            }} />
          ))}
        </div>

        <div style={{ fontSize: '56px', marginBottom: '20px' }}>{current.icon}</div>

        <h2 style={{
          fontFamily: 'var(--font-display)', fontSize: '26px', fontWeight: 500,
          color: 'var(--text-primary)', marginBottom: '6px',
        }}>
          {current.title}
        </h2>
        <p style={{
          fontSize: '12px', fontWeight: 600, color: 'var(--flame)',
          textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '16px',
        }}>
          {current.subtitle}
        </p>
        <p style={{
          fontSize: '15px', color: 'var(--text-secondary)', lineHeight: 1.7,
          marginBottom: '32px',
        }}>
          {current.body}
        </p>

        <button
          onClick={handleNext}
          style={{
            width: '100%', padding: '14px', borderRadius: '100px',
            background: 'var(--flame)', color: 'white', border: 'none',
            fontSize: '15px', fontWeight: 600, cursor: 'pointer',
            fontFamily: 'var(--font-body)',
            boxShadow: '0 4px 16px rgba(255,107,43,0.3)',
          }}
        >
          {current.cta}
        </button>

        <button
          onClick={() => { localStorage.setItem('ijwi_onboarded', '1'); onDone() }}
          style={{
            marginTop: '12px', background: 'none', border: 'none',
            color: 'var(--text-muted)', fontSize: '13px', cursor: 'pointer',
            fontFamily: 'var(--font-body)',
          }}
        >
          Skip
        </button>
      </div>
    </div>
  )
}
