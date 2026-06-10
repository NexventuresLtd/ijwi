import Link from 'next/link'

interface BackendUnavailableProps {
  title?: string
  message?: string
  onRetry?: () => void
}

export default function BackendUnavailable({
  title = 'Backend unavailable',
  message = 'The frontend is online, but the backend is not responding right now. Live posts, accounts, payments, messages, and notifications will work again when Supabase is reachable.',
  onRetry,
}: BackendUnavailableProps) {
  return (
    <main style={{
      minHeight: '100dvh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '32px 20px',
      background: 'var(--ij-bg-base)',
    }}>
      <section className="ij-card-featured" style={{
        width: '100%',
        maxWidth: 560,
        textAlign: 'center',
      }}>
        <div style={{
          width: 54,
          height: 54,
          borderRadius: 16,
          margin: '0 auto 18px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'var(--ij-gold-bg)',
          color: 'var(--ij-gold)',
          fontSize: 26,
          fontWeight: 700,
        }}>
          !
        </div>
        <h1 style={{
          color: 'var(--ij-text-primary)',
          fontSize: 'clamp(2rem, 6vw, 3rem)',
          lineHeight: 1,
          marginBottom: 12,
        }}>
          {title}
        </h1>
        <p style={{
          color: 'var(--ij-text-secondary)',
          fontSize: '1rem',
          lineHeight: 1.7,
          margin: '0 auto 24px',
          maxWidth: 460,
        }}>
          {message}
        </p>
        <div style={{
          display: 'grid',
          gap: 10,
          gridTemplateColumns: onRetry ? '1fr 1fr' : '1fr',
        }}>
          {onRetry && (
            <button type="button" className="ij-btn-primary" onClick={onRetry}>
              Try again
            </button>
          )}
          <Link href="/about" className="ij-btn-secondary">
            Open public frontend
          </Link>
        </div>
      </section>
    </main>
  )
}
