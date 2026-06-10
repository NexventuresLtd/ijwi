import Link from 'next/link'
import IjwiLogo from '@/components/IjwiLogo'

export const metadata = {
  title: 'About Ijwi — The Voice',
  description: 'A faith-rooted platform for African Christian youth. Share stories, prayers, devotionals, and testimonies.',
}

export default function AboutPage() {
  return (
    <main style={{
      minHeight: '100dvh',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '48px 24px 40px',
    }}>
      <div className="landing-grid">
        {/* Left / center column: text + CTAs */}
        <div className="landing-cta-col" style={{
          display: 'flex', flexDirection: 'column',
          alignItems: 'center', width: '100%',
          animation: 'fadeUp 0.5s ease-out both',
        }}>
          {/* Logo */}
          <div style={{
            width: 72, height: 72, borderRadius: 18,
            background: 'var(--ij-bg-surface)',
            border: '1px solid var(--ij-border-gold)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            marginBottom: 14,
            boxShadow: '0 0 32px var(--ij-glow-gold)',
          }}>
            <IjwiLogo size={46} gradient />
          </div>

          <h1 style={{
            fontFamily: 'var(--ij-font-display)',
            fontSize: '2.1rem', fontWeight: 700,
            color: 'var(--ij-text-primary)', letterSpacing: '2px',
            marginBottom: 4,
          }}>
            ijwi
          </h1>

          <p style={{
            fontFamily: 'var(--ij-font-display)',
            fontSize: '0.95rem', fontStyle: 'italic',
            color: 'var(--ij-gold)', marginBottom: 18,
          }}>
            You are truly a blessing
          </p>

          <div style={{
            width: 48, height: 1,
            background: 'var(--ij-border-gold)',
            marginBottom: 22,
          }} />

          <h2 style={{
            fontFamily: 'var(--ij-font-display)',
            fontSize: 'clamp(1.7rem, 5vw, 2.4rem)',
            fontWeight: 700, color: 'var(--ij-text-primary)',
            textAlign: 'center', lineHeight: 1.25,
            marginBottom: 12,
          }}>
            Your voice.{' '}
            <span style={{ color: 'var(--ij-gold)' }}>Your faith.</span>{' '}
            Your community.
          </h2>

          <p style={{
            fontFamily: 'var(--ij-font-body)',
            fontSize: '1rem', color: 'var(--ij-text-secondary)',
            textAlign: 'center', lineHeight: 1.65,
            maxWidth: 320, marginBottom: 36,
          }}>
            A space for Christian youth to share stories,
            pray together, and be truly heard.
          </p>

          <div style={{ width: '100%', maxWidth: 340, display: 'flex', flexDirection: 'column', gap: 10 }}>
            <Link href="/auth/signup" className="ij-btn-primary">
              Find your voice →
            </Link>
            <Link href="/auth/login" className="ij-btn-secondary">
              Sign in
            </Link>
            <div style={{ textAlign: 'center', marginTop: 4 }}>
              <Link href="/feed" className="ij-btn-ghost">
                Browse without an account
              </Link>
            </div>
          </div>

          <p style={{
            fontFamily: 'var(--ij-font-body)',
            fontSize: '0.72rem',
            color: 'var(--ij-text-hint)',
            marginTop: 48,
          }}>
            Built with love and faith in Rwanda 🇷🇼
          </p>
        </div>

        {/* Right column: preview cards (desktop only) */}
        <div className="landing-preview-col">
          <div style={{
            position: 'absolute', inset: -40,
            background: 'radial-gradient(circle at center, var(--ij-glow-gold), transparent 70%)',
            pointerEvents: 'none',
          }} />
          <div className="ij-card-featured" style={{ padding: '20px', position: 'relative' }}>
            <span style={{
              position: 'absolute', top: -12, left: 8,
              fontFamily: 'var(--ij-font-display)', fontSize: 80, lineHeight: 1,
              color: 'var(--ij-glow-gold)', pointerEvents: 'none', userSelect: 'none',
            }}>"</span>
            <div style={{ fontSize: '0.6rem', fontWeight: 700, color: 'var(--ij-gold)', letterSpacing: '0.12em', textTransform: 'uppercase', marginBottom: 8 }}>Today's Verse</div>
            <p style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1rem', fontStyle: 'italic', color: 'var(--ij-text-primary)', lineHeight: 1.6, marginBottom: 8, position: 'relative' }}>
              Be still, and know that I am God.
            </p>
            <p style={{ fontSize: '0.7rem', color: 'var(--ij-gold)', fontWeight: 500, textTransform: 'uppercase', letterSpacing: '0.05em' }}>— Psalm 46:10</p>
          </div>
          <div className="ij-card" style={{ padding: '16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
              <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'conic-gradient(from 160deg, hsl(220,55%,35%), hsl(260,65%,50%))', flexShrink: 0 }} />
              <div>
                <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-primary)' }}>A voice from Kigali</div>
                <div style={{ fontSize: '11px', color: 'var(--ij-text-hint)' }}>2h ago</div>
              </div>
            </div>
            <p style={{ fontSize: '13px', color: 'var(--ij-text-secondary)', lineHeight: 1.6 }}>
              God doesn't call the qualified — He qualifies the called. Keep going, your story is not finished.
            </p>
          </div>
          <div className="ij-card" style={{ padding: '16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
              <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'conic-gradient(from 160deg, hsl(40,55%,35%), hsl(80,65%,50%))', flexShrink: 0 }} />
              <div>
                <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--ij-text-primary)' }}>Still waters</div>
                <div style={{ fontSize: '11px', color: 'var(--ij-text-hint)' }}>5h ago</div>
              </div>
            </div>
            <p style={{ fontSize: '13px', color: 'var(--ij-text-secondary)', lineHeight: 1.6 }}>
              Praying for anyone who feels unseen tonight. You are known. You are loved.
            </p>
            <div style={{ marginTop: 8, fontSize: '11px', color: 'var(--ij-prayer)' }}>🙏 24 praying</div>
          </div>
        </div>
      </div>
    </main>
  )
}
