'use client'

import { useState } from 'react'
import Link from 'next/link'
import { motion, AnimatePresence } from 'framer-motion'
import dynamic from 'next/dynamic'
import { ContentType } from '@/lib/types'

const PostComposer = dynamic(() => import('@/components/post/PostComposer'), { ssr: false })

interface ComposeSheetProps {
  profile: any
  isOpen: boolean
  onClose: () => void
  isAdmin?: boolean
}

export default function ComposeSheet({ profile, isOpen, onClose, isAdmin = false }: ComposeSheetProps) {
  const [showComposer, setShowComposer] = useState(false)
  const [composeType, setComposeType] = useState<ContentType | undefined>()

  const canPost = profile?.is_approved_poster || isAdmin || profile?.is_admin

  const handlePickType = (type: ContentType) => {
    setComposeType(type)
    onClose()
    setShowComposer(true)
  }

  return (
    <>
      {/* Picker bottom sheet */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            key="compose-overlay"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            style={{
              position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.65)',
              zIndex: 400, display: 'flex', alignItems: 'flex-end',
              backdropFilter: 'blur(8px)',
            }}
          >
            <motion.div
              key="compose-sheet"
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', stiffness: 380, damping: 38 }}
              onClick={e => e.stopPropagation()}
              style={{
                background: 'var(--ij-bg-surface)',
                width: '100%', maxWidth: '540px',
                margin: '0 auto', borderRadius: '28px 28px 0 0',
                padding: '0 0 env(safe-area-inset-bottom)',
                border: '1px solid var(--ij-border-gold)',
                borderBottom: 'none',
                boxShadow: '0 -8px 48px rgba(0,0,0,0.4)',
              }}
            >
              {/* Handle */}
              <div style={{ paddingTop: 12, paddingBottom: 4, display: 'flex', justifyContent: 'center' }}>
                <div style={{ width: 44, height: 4, background: 'var(--ij-border-gold)', borderRadius: 2 }} />
              </div>

              {/* Header */}
              <div style={{ padding: '16px 24px 12px', borderBottom: '1px solid var(--ij-border)' }}>
                <p style={{ fontFamily: 'var(--ij-font-display)', fontSize: '1.3rem', fontWeight: 700, color: 'var(--ij-text-primary)', letterSpacing: '0.01em' }}>
                  {canPost ? 'What will you share?' : 'Ask the community'}
                </p>
                <p style={{ fontSize: '12px', color: 'var(--ij-text-secondary)', marginTop: 3 }}>
                  {canPost ? 'Your voice matters — choose your format' : 'Ask anything — voices are here to help'}
                </p>
              </div>

              <div style={{ padding: '16px 20px 0' }}>
                {canPost ? (
                  <>
                    {/* Essay — full-width banner */}
                    <Link
                      href="/write"
                      onClick={onClose}
                      style={{
                        display: 'flex', alignItems: 'center', gap: 16,
                        padding: '16px 18px', borderRadius: 18,
                        background: 'linear-gradient(135deg, var(--ij-gold-bg), rgba(242,172,58,0.04))',
                        border: '1px solid var(--ij-border-gold)',
                        textDecoration: 'none', marginBottom: 12,
                      }}
                    >
                      <div style={{
                        width: 48, height: 48, borderRadius: 14, flexShrink: 0,
                        background: 'linear-gradient(135deg, #C9860A, #F2AC3A)',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        fontSize: '22px',
                      }}>✍️</div>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: '15px', fontWeight: 700, color: 'var(--ij-text-primary)', marginBottom: 2 }}>Write an Essay</div>
                        <div style={{ fontSize: '12px', color: 'var(--ij-text-secondary)', lineHeight: 1.4 }}>Testimonies, devotionals, long-form faith writing</div>
                      </div>
                      <span style={{ fontSize: 18, color: 'var(--ij-gold)' }}>→</span>
                    </Link>

                    {/* Grid tiles */}
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, paddingBottom: 24 }}>
                      {([
                        { type: 'story' as ContentType,       icon: '📸', label: 'Photo',       desc: 'Image + caption',        color: 'rgba(52,199,89,0.12)',    border: 'rgba(52,199,89,0.25)' },
                        { type: 'question' as ContentType,    icon: '💭', label: 'Question',    desc: 'Ask the community',      color: 'rgba(139,120,240,0.12)', border: 'rgba(139,120,240,0.25)' },
                        { type: 'spoken_word' as ContentType, icon: '🎙️', label: 'Spoken Word', desc: 'Record your voice',      color: 'rgba(255,59,48,0.10)',   border: 'rgba(255,59,48,0.25)' },
                        { href: '/sparks',                    icon: '⚡', label: 'Spark',       desc: 'Short faith video',      color: 'rgba(255,149,0,0.12)',   border: 'rgba(255,149,0,0.25)' },
                      ]).map((item) => {
                        const style: React.CSSProperties = {
                          display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 10,
                          padding: '14px', borderRadius: 16,
                          border: `1px solid ${item.border}`,
                          background: item.color,
                          cursor: 'pointer', textAlign: 'left',
                          fontFamily: 'var(--ij-font-body)', textDecoration: 'none',
                        }
                        const inner = (
                          <>
                            <div style={{ fontSize: '24px', lineHeight: 1 }}>{item.icon}</div>
                            <div>
                              <div style={{ fontSize: '13px', fontWeight: 700, color: 'var(--ij-text-primary)', marginBottom: 2 }}>{item.label}</div>
                              <div style={{ fontSize: '11px', color: 'var(--ij-text-secondary)', lineHeight: 1.3 }}>{item.desc}</div>
                            </div>
                          </>
                        )
                        if ('href' in item && item.href) {
                          return <Link key={item.label} href={item.href} onClick={onClose} style={style}>{inner}</Link>
                        }
                        return (
                          <button key={(item as any).type} onClick={() => handlePickType((item as any).type)} style={style}>
                            {inner}
                          </button>
                        )
                      })}
                    </div>
                  </>
                ) : (
                  <div style={{ paddingBottom: 24 }}>
                    <button
                      onClick={() => handlePickType('question')}
                      style={{
                        width: '100%', display: 'flex', alignItems: 'center', gap: 16,
                        padding: '16px 18px', borderRadius: 18,
                        background: 'rgba(139,120,240,0.08)',
                        border: '1px solid rgba(139,120,240,0.25)',
                        cursor: 'pointer', textAlign: 'left', fontFamily: 'var(--ij-font-body)',
                      }}
                    >
                      <div style={{ width: 48, height: 48, borderRadius: 14, background: 'rgba(139,120,240,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '22px' }}>💭</div>
                      <div>
                        <div style={{ fontSize: '15px', fontWeight: 700, color: 'var(--ij-text-primary)', marginBottom: 2 }}>Ask a Question</div>
                        <div style={{ fontSize: '12px', color: 'var(--ij-text-secondary)' }}>Ask the community anything</div>
                      </div>
                    </button>
                  </div>
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* PostComposer modal */}
      {showComposer && (
        <div
          onClick={e => { if (e.target === e.currentTarget) setShowComposer(false) }}
          style={{
            position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            zIndex: 400, padding: '16px', backdropFilter: 'blur(8px)',
            overflowY: 'auto',
          }}
        >
          <PostComposer
            onClose={() => setShowComposer(false)}
            onPost={() => setShowComposer(false)}
            initialType={composeType}
          />
        </div>
      )}
    </>
  )
}
