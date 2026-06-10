import Link from 'next/link'

export const metadata = {
  title: 'Privacy Policy — Ijwi',
}

export default function PrivacyPage() {
  return (
    <div style={{ minHeight: '100vh', background: 'var(--warm-white)', padding: '40px 24px' }}>
      <div style={{ maxWidth: '680px', margin: '0 auto' }}>
        <Link href="/settings" style={{ fontSize: '14px', color: 'var(--flame)', textDecoration: 'none', display: 'inline-block', marginBottom: '32px' }}>
          ← Back to Settings
        </Link>

        <h1 style={{ fontFamily: 'var(--font-display)', fontSize: '36px', fontWeight: 500, color: 'var(--text-primary)', marginBottom: '8px' }}>
          Privacy Policy
        </h1>
        <p style={{ fontSize: '14px', color: 'var(--text-muted)', marginBottom: '40px' }}>
          Last updated: April 2026
        </p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '32px' }}>
          {[
            {
              title: '1. What we collect',
              body: 'We collect information you provide directly: your email address, voice name (username), bio, content you post, and any real name you choose to reveal. We also collect usage data such as which posts you react to, follow activity, and session logs for security purposes.'
            },
            {
              title: '2. How we use your information',
              body: 'We use your information to provide, maintain, and improve the Ijwi platform; to send you notifications you\'ve opted into; to moderate content and enforce our community standards; and to process Pro subscription payments. We do not sell your personal information to third parties.'
            },
            {
              title: '3. Anonymous posting',
              body: 'When you post anonymously, your real name and profile are not displayed publicly. However, your account is still linked to the post in our database for moderation purposes. If required by law or in cases of serious abuse, we may disclose this information to relevant authorities.'
            },
            {
              title: '4. Data storage',
              body: 'Your data is stored securely using Supabase (PostgreSQL), hosted on servers provided by our cloud infrastructure partners. Data is encrypted in transit (HTTPS/TLS). We implement industry-standard security measures to protect your information.'
            },
            {
              title: '5. Cookies and local storage',
              body: 'We use browser local storage to remember your preferences (such as notification last-seen dates and verse popup state). We do not use advertising cookies or third-party tracking cookies.'
            },
            {
              title: '6. Third-party services',
              body: 'We use Supabase for database and authentication, Vercel for hosting, and Paypack for Mobile Money payment processing. These services have their own privacy policies and are contractually required to protect your data.'
            },
            {
              title: '7. Your rights',
              body: 'You have the right to access, correct, or delete your personal data at any time. You can delete your account in Settings → Delete account. For data access requests or questions about your data, contact us at support@ijwi.app.'
            },
            {
              title: '8. Children\'s privacy',
              body: 'Ijwi is not intended for children under 13. We do not knowingly collect personal information from children under 13. If you believe a child has created an account, please contact us and we will promptly delete it.'
            },
            {
              title: '9. Changes to this policy',
              body: 'We may update this Privacy Policy from time to time. We will notify users of significant changes through the app. Continued use of Ijwi after changes constitutes acceptance of the updated policy.'
            },
            {
              title: '10. Contact us',
              body: 'If you have any questions about this Privacy Policy or how we handle your data, please contact us at support@ijwi.app. We take privacy seriously and will respond within 48 hours.'
            },
          ].map(({ title, body }) => (
            <div key={title} className="card" style={{ padding: '24px' }}>
              <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', fontWeight: 500, color: 'var(--text-primary)', marginBottom: '10px' }}>
                {title}
              </h2>
              <p style={{ fontSize: '15px', color: 'var(--text-secondary)', lineHeight: 1.75 }}>
                {body}
              </p>
            </div>
          ))}
        </div>

        <div style={{ textAlign: 'center', marginTop: '48px', marginBottom: '32px' }}>
          <p style={{ fontFamily: 'var(--font-display)', fontStyle: 'italic', fontSize: '16px', color: 'var(--text-muted)' }}>
            "The truth will set you free." — John 8:32
          </p>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '8px' }}>
            Built with love and faith in Rwanda 🇷🇼
          </p>
        </div>
      </div>
    </div>
  )
}
