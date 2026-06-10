'use client'

import { useEffect, useState } from 'react'
import IjwiLogo from '@/components/IjwiLogo'

export default function SplashScreen() {
  const [visible, setVisible] = useState(false)
  const [fading, setFading] = useState(false)

  useEffect(() => {
    if (sessionStorage.getItem('ijwi_splash_shown')) return
    setVisible(true)
    const fadeTimer = setTimeout(() => setFading(true), 2000)
    const hideTimer = setTimeout(() => {
      setVisible(false)
      sessionStorage.setItem('ijwi_splash_shown', 'true')
    }, 2600)
    return () => { clearTimeout(fadeTimer); clearTimeout(hideTimer) }
  }, [])

  if (!visible) return null

  return (
    <div style={{
      position: 'fixed', inset: 0, zIndex: 9999,
      background: '#0C0916',
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      gap: '20px',
      transition: 'opacity 0.6s ease',
      opacity: fading ? 0 : 1,
      pointerEvents: fading ? 'none' : 'auto',
    }}>
      <div style={{
        display: 'flex', flexDirection: 'column',
        alignItems: 'center', gap: '16px',
        animation: 'fadeUp 0.5s ease-out both',
      }}>
        <IjwiLogo size={72} color="white" gradient />
        <div style={{
          fontFamily: 'var(--ij-font-display)',
          fontSize: '42px', fontWeight: 400,
          color: '#F2EEE8', letterSpacing: '-0.01em',
        }}>
          ijwi
        </div>
        <div style={{ textAlign: 'center' }}>
          <div style={{
            fontFamily: 'var(--ij-font-body)',
            fontSize: '15px',
            color: 'rgba(245,240,232,0.65)',
            letterSpacing: '0.05em', fontWeight: 400,
          }}>
            Uri Umugisha
          </div>
          <div style={{
            fontFamily: 'var(--ij-font-display)',
            fontSize: '12px',
            color: 'rgba(245,240,232,0.32)',
            fontStyle: 'italic', marginTop: '3px',
            letterSpacing: '0.02em',
          }}>
            You are truly a blessing
          </div>
        </div>
      </div>
    </div>
  )
}
