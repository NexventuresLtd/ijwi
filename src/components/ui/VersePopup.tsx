'use client'

import { useState, useEffect } from 'react'

const DAILY_VERSES = [
  { ref: 'Psalm 46:10', text: 'Be still, and know that I am God.' },
  { ref: 'Isaiah 41:10', text: 'Do not fear, for I am with you; do not be dismayed, for I am your God.' },
  { ref: 'Jeremiah 29:11', text: 'For I know the plans I have for you, plans to prosper you and not to harm you.' },
  { ref: 'Romans 8:28', text: 'And we know that in all things God works for the good of those who love him.' },
  { ref: 'Philippians 4:13', text: 'I can do all this through him who gives me strength.' },
  { ref: 'Proverbs 3:5-6', text: 'Trust in the LORD with all your heart and lean not on your own understanding.' },
  { ref: 'Matthew 11:28', text: 'Come to me, all you who are weary and burdened, and I will give you rest.' },
  { ref: 'Joshua 1:9', text: 'Be strong and courageous. Do not be afraid; do not be discouraged.' },
  { ref: 'Psalm 23:1', text: 'The LORD is my shepherd, I lack nothing.' },
  { ref: '2 Corinthians 5:17', text: 'If anyone is in Christ, the new creation has come. The old has gone, the new is here.' },
  { ref: 'Psalm 34:18', text: 'The LORD is close to the brokenhearted and saves those who are crushed in spirit.' },
  { ref: 'Romans 5:8', text: 'But God demonstrates his own love for us: While we were still sinners, Christ died for us.' },
  { ref: 'Isaiah 40:31', text: 'Those who hope in the LORD will renew their strength. They will soar on wings like eagles.' },
  { ref: 'Lamentations 3:23', text: 'Great is your faithfulness. His mercies are new every morning.' },
]

function getVerse() {
  const now = new Date()
  const dayOfYear = Math.floor(
    (now.getTime() - new Date(now.getFullYear(), 0, 0).getTime()) / 86400000
  )
  return DAILY_VERSES[dayOfYear % DAILY_VERSES.length]
}

export default function VersePopup() {
  const [visible, setVisible] = useState(false)
  const verse = getVerse()

  useEffect(() => {
    try {
      const today = new Date().toDateString()
      const lastSeen = localStorage.getItem('verse_popup_date')
      if (lastSeen !== today) {
        const t = setTimeout(() => setVisible(true), 800)
        return () => clearTimeout(t)
      }
    } catch {
      const t = setTimeout(() => setVisible(true), 800)
      return () => clearTimeout(t)
    }
  }, [])

  const dismiss = () => {
    try { localStorage.setItem('verse_popup_date', new Date().toDateString()) } catch {}
    setVisible(false)
  }

  if (!visible) return null

  return (
    <div
      onClick={dismiss}
      style={{
        position: 'fixed', inset: 0, zIndex: 9999,
        background: 'rgba(0,0,0,0.65)',
        backdropFilter: 'blur(10px)',
        display: 'flex', alignItems: 'flex-end', justifyContent: 'center',
      }}
    >
      <div
        onClick={e => e.stopPropagation()}
        style={{
          width: '100%', maxWidth: '480px',
          background: 'linear-gradient(180deg, #1a1530 0%, #0e0c1e 100%)',
          borderRadius: '24px 24px 0 0',
          padding: '0 20px calc(env(safe-area-inset-bottom, 0px) + 28px)',
          textAlign: 'center',
          boxShadow: '0 -12px 60px rgba(0,0,0,0.6)',
        }}
      >
        {/* Handle bar */}
        <div style={{
          width: 36, height: 4,
          background: 'rgba(255,255,255,0.18)',
          borderRadius: 99, margin: '12px auto 22px',
        }} />

        {/* Icon */}
        <div style={{
          width: 50, height: 50, borderRadius: '50%',
          background: 'linear-gradient(135deg, #FF6B2B 0%, #FFB830 100%)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          margin: '0 auto 14px', fontSize: '22px',
          boxShadow: '0 4px 20px rgba(255,107,43,0.4)',
        }}>
          ✨
        </div>

        {/* Label */}
        <div style={{
          fontSize: '10px', fontWeight: 800, letterSpacing: '0.14em',
          textTransform: 'uppercase', color: '#FFB830', marginBottom: '14px',
        }}>
          Today's Word
        </div>

        {/* Verse text */}
        <p style={{
          fontFamily: 'var(--font-display)', fontSize: '17px', fontStyle: 'italic',
          lineHeight: 1.6, color: 'rgba(255,255,255,0.9)',
          marginBottom: '10px', padding: '0 4px',
        }}>
          &ldquo;{verse.text}&rdquo;
        </p>

        {/* Reference */}
        <span style={{ fontSize: '13px', color: '#FFB830', fontWeight: 700 }}>
          — {verse.ref}
        </span>

        {/* Amen button */}
        <button
          onClick={dismiss}
          style={{
            display: 'block', width: '100%', marginTop: '22px',
            padding: '15px', borderRadius: '100px',
            background: 'linear-gradient(135deg, #FF6B2B 0%, #FFB830 100%)',
            color: 'white', border: 'none',
            fontSize: '16px', fontWeight: 700, cursor: 'pointer',
            fontFamily: 'var(--font-body)',
            boxShadow: '0 6px 24px rgba(255,107,43,0.45)',
          }}
        >
          Amen 🙏
        </button>

        {/* Dismiss link */}
        <button
          onClick={dismiss}
          style={{
            background: 'none', border: 'none',
            color: 'rgba(255,255,255,0.3)',
            fontSize: '13px', cursor: 'pointer',
            marginTop: '14px', fontFamily: 'var(--font-body)', padding: '4px',
          }}
        >
          Continue to app
        </button>
      </div>
    </div>
  )
}
