'use client'

import { useEffect, useState } from 'react'

export default function PushPrompt() {
  const [show, setShow] = useState(false)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (!('Notification' in window) || !('serviceWorker' in navigator)) return
    if (Notification.permission !== 'default') return
    if (sessionStorage.getItem('push-prompt-dismissed')) return
    const t = setTimeout(() => setShow(true), 30_000)
    return () => clearTimeout(t)
  }, [])

  const handleEnable = async () => {
    setLoading(true)
    const perm = await Notification.requestPermission()
    if (perm === 'granted') {
      try {
        const reg = await navigator.serviceWorker.ready
        const vapidKey = process.env.NEXT_PUBLIC_VAPID_KEY
        if (vapidKey) {
          const sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: vapidKey })
          const json = sub.toJSON()
          await fetch('/api/push/subscribe', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ endpoint: json.endpoint, keys: json.keys }),
          })
        }
      } catch {}
    }
    setLoading(false)
    setShow(false)
    sessionStorage.setItem('push-prompt-dismissed', '1')
  }

  const handleDismiss = () => {
    setShow(false)
    sessionStorage.setItem('push-prompt-dismissed', '1')
  }

  if (!show) return null

  return (
    <div style={{
      position: 'fixed', bottom: 80, left: '50%', transform: 'translateX(-50%)',
      zIndex: 9000, width: 'min(360px, calc(100vw - 32px))',
      background: 'var(--ij-bg-elevated)', border: '1px solid var(--ij-border-gold)',
      borderRadius: 16, padding: '16px 20px', boxShadow: '0 8px 32px rgba(0,0,0,0.35)',
      display: 'flex', flexDirection: 'column', gap: 12,
      animation: 'slideUp 0.3s ease',
    }}>
      <style>{`@keyframes slideUp { from { opacity:0; transform:translateX(-50%) translateY(16px) } to { opacity:1; transform:translateX(-50%) translateY(0) } }`}</style>
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
        <div style={{
          width: 40, height: 40, borderRadius: '50%', flexShrink: 0,
          background: 'rgba(240,168,50,0.12)', border: '1px solid var(--ij-border-gold)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18,
        }}>🔔</div>
        <div>
          <div style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1rem', fontWeight: 600, color: 'var(--ij-text-primary)', marginBottom: 4 }}>
            Stay connected to the community
          </div>
          <div style={{ fontSize: '13px', color: 'var(--ij-text-secondary)', lineHeight: 1.5 }}>
            Get notified when someone responds to your prayers or follows your voice.
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <button
          onClick={handleEnable}
          disabled={loading}
          style={{
            flex: 1, padding: '10px', borderRadius: 100, border: 'none',
            background: 'var(--ij-gold)', color: 'var(--ij-bg-base)',
            fontSize: '13px', fontWeight: 700, cursor: loading ? 'wait' : 'pointer',
            fontFamily: 'var(--ij-font-body)',
          }}
        >
          {loading ? '...' : 'Enable notifications'}
        </button>
        <button
          onClick={handleDismiss}
          style={{
            padding: '10px 16px', borderRadius: 100,
            border: '1px solid var(--ij-border)', background: 'transparent',
            fontSize: '13px', color: 'var(--ij-text-secondary)', cursor: 'pointer',
            fontFamily: 'var(--ij-font-body)',
          }}
        >
          Not now
        </button>
      </div>
    </div>
  )
}
