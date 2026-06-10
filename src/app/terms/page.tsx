import Link from 'next/link'

export const metadata = {
  title: 'Terms of Use — Ijwi',
}

export default function TermsPage() {
  return (
    <div style={{ minHeight: '100vh', background: 'var(--warm-white)', padding: '40px 24px' }}>
      <div style={{ maxWidth: '680px', margin: '0 auto' }}>
        <Link href="/settings" style={{ fontSize: '14px', color: 'var(--flame)', textDecoration: 'none', display: 'inline-block', marginBottom: '32px' }}>
          ← Back to Settings
        </Link>

        <h1 style={{ fontFamily: 'var(--font-display)', fontSize: '36px', fontWeight: 500, color: 'var(--text-primary)', marginBottom: '8px' }}>
          Terms of Use
        </h1>
        <p style={{ fontSize: '14px', color: 'var(--text-muted)', marginBottom: '40px' }}>
          Last updated: April 2026
        </p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '32px' }}>
          {[
            {
              title: '1. Who we are',
              body: 'Ijwi ("The Voice") is a faith-rooted social platform built for African Christian youth to share testimonies, devotionals, prayers, spoken word, and encouragement. Ijwi is operated by Armand Kayiranga and based in Rwanda.'
            },
            {
              title: '2. Accepting these terms',
              body: 'By creating an account or using Ijwi, you agree to these Terms of Use. If you do not agree, please do not use the platform. We may update these terms from time to time — continued use after changes means you accept the updated terms.'
            },
            {
              title: '3. Your account',
              body: 'You must be at least 13 years old to use Ijwi. You are responsible for keeping your account credentials secure. Do not share your password. You are responsible for all activity that happens under your account.'
            },
            {
              title: '4. Content you post',
              body: 'You own the content you post on Ijwi. By posting, you grant Ijwi a non-exclusive, worldwide, royalty-free license to display, distribute, and promote your content within the platform. You may delete your content at any time. You agree not to post content that is hateful, sexually explicit, abusive, or violates any applicable law.'
            },
            {
              title: '5. Community standards',
              body: 'Ijwi is a faith space. We expect all users to treat each other with love, respect, and dignity — consistent with the teachings of Jesus Christ. Harassment, bullying, hate speech, blasphemy, and spam are not tolerated and will result in account suspension or termination.'
            },
            {
              title: '6. Content moderation',
              body: 'We reserve the right to remove any content that violates our community standards or these terms, without prior notice. We are not obligated to monitor all content but will act on reports and flagged violations.'
            },
            {
              title: '7. Anonymous posting',
              body: 'Ijwi allows anonymous posting via a "voice name." While your identity is not publicly linked to anonymous posts, we do store account-level records for safety and moderation purposes. True anonymity cannot be guaranteed.'
            },
            {
              title: '8. Pro subscription',
              body: 'Ijwi Pro is a paid subscription that unlocks additional features. Payments are processed securely. Subscriptions auto-renew unless cancelled. Refunds are handled on a case-by-case basis — contact us at support@ijwi.app.'
            },
            {
              title: '9. Intellectual property',
              body: 'The Ijwi name, logo, brand, and all platform design are the property of Ijwi. You may not copy, reproduce, or use them without written permission.'
            },
            {
              title: '10. Disclaimer of warranties',
              body: 'Ijwi is provided "as is" without warranties of any kind. We do not guarantee the platform will be available at all times or free from errors. We are not responsible for any loss or damage resulting from your use of the platform.'
            },
            {
              title: '11. Governing law',
              body: 'These terms are governed by the laws of Rwanda. Any disputes will be resolved in Rwandan courts.'
            },
            {
              title: '12. Contact us',
              body: 'For questions about these terms, contact us at support@ijwi.app or reach out through the app.'
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
            "Let your yes be yes and your no be no." — Matthew 5:37
          </p>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '8px' }}>
            Built with love and faith in Rwanda 🇷🇼
          </p>
        </div>
      </div>
    </div>
  )
}
