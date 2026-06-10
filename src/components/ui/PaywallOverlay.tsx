'use client'

import Link from 'next/link'

interface PaywallOverlayProps {
  message?: string
  ctaLabel?: string
  ctaHref?: string
  onDismiss?: () => void
}

export default function PaywallOverlay({
  message = 'This story is too powerful to skim. Go deeper with Ijwi Pro.',
  ctaLabel = 'Go Pro →',
  ctaHref = '/settings#subscription',
  onDismiss,
}: PaywallOverlayProps) {
  return (
    <div
      style={{
        position: 'absolute',
        bottom: 0,
        left: 0,
        right: 0,
        height: '180px',
        background: 'linear-gradient(to bottom, transparent 0%, var(--warm-white) 55%)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'flex-end',
        paddingBottom: '20px',
        gap: '10px',
      }}
    >
      <p
        style={{
          fontSize: '13px',
          color: 'var(--text-secondary)',
          textAlign: 'center',
          maxWidth: '300px',
          lineHeight: 1.5,
          margin: 0,
        }}
      >
        {message}
      </p>
      <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
        <Link
          href={ctaHref}
          style={{
            padding: '8px 20px',
            borderRadius: '100px',
            background: 'var(--flame)',
            color: 'white',
            textDecoration: 'none',
            fontSize: '13px',
            fontWeight: 600,
            fontFamily: 'var(--font-body)',
          }}
        >
          {ctaLabel}
        </Link>
        {onDismiss && (
          <button
            onClick={onDismiss}
            style={{
              padding: '8px 16px',
              borderRadius: '100px',
              border: '1px solid var(--border)',
              background: 'transparent',
              color: 'var(--text-muted)',
              fontSize: '12px',
              cursor: 'pointer',
              fontFamily: 'var(--font-body)',
            }}
          >
            Maybe later
          </button>
        )}
      </div>
    </div>
  )
}
