'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { motion } from 'framer-motion'
import { createClient } from '@/lib/supabase/client'
import { Profile } from '@/lib/types'
import IjwiLogo from '@/components/IjwiLogo'
import ProfileAvatar from '@/components/ui/ProfileAvatar'
import { useTheme } from '@/lib/theme'
import ComposeSheet from '@/components/ui/ComposeSheet'

interface NavProps {
  profile?: Profile | null
  onCompose?: () => void
  isAdmin?: boolean
  hideMobileTopbar?: boolean
  hideMobileNav?: boolean
}

export default function Navbar({ profile, onCompose, isAdmin = false, hideMobileTopbar = false, hideMobileNav = false }: NavProps) {
  const pathname = usePathname()
  const router = useRouter()
  const supabase = createClient()
  const [notifDot, setNotifDot] = useState(false)
  const [showCompose, setShowCompose] = useState(false)

  const handleCompose = onCompose ?? (() => setShowCompose(true))
  const { theme, toggleTheme } = useTheme()

  useEffect(() => {
    if (!profile) return
    const lastSeen = localStorage.getItem('notif_last_seen') ?? new Date(0).toISOString()
    createClient()
      .from('follows')
      .select('*', { count: 'exact', head: true })
      .eq('following_id', profile.id)
      .gte('created_at', lastSeen)
      .then(({ count }) => { if ((count ?? 0) > 0) setNotifDot(true) })
  }, [profile?.id])

  const handleSignOut = async () => {
    await supabase.auth.signOut()
    router.push('/')
  }

  const isActive = (href: string) =>
    href === '/feed' ? pathname === '/feed' : pathname.startsWith(href)

  const NAV_LINKS = [
    { href: '/feed',    label: 'Home' },
    { href: '/explore', label: 'Explore' },
    { href: '/sparks',  label: 'Sparks' },
    { href: '/events',  label: 'Events' },
  ]

  return (
    <>
      {/* ── MOBILE: top bar with logo + DMs + notifications ──────────── */}
      <div className={hideMobileTopbar ? '' : 'mobile-topbar'} style={{
        position: 'fixed', top: 0, left: 0, right: 0,
        height: 52,
        background: 'var(--ij-bg-nav)',
        borderBottom: '1px solid var(--ij-border)',
        backdropFilter: 'blur(16px)',
        WebkitBackdropFilter: 'blur(16px)',
        zIndex: 101,
        display: 'none',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 16px',
      }}>
        <Link href="/feed" style={{ display: 'flex', alignItems: 'center', gap: 7, textDecoration: 'none' }}>
          <div style={{
            width: 26, height: 26, borderRadius: 7,
            background: 'linear-gradient(135deg, #1A1840, #0F0F26)',
            border: '1px solid rgba(240,168,50,0.40)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <IjwiLogo size={16} color="#F0A832" />
          </div>
          <span style={{
            fontFamily: 'var(--ij-font-display)', fontSize: '1.1rem',
            fontWeight: 700, color: 'var(--ij-text-primary)', letterSpacing: '1px',
          }}>ijwi</span>
        </Link>
        <div style={{ display: 'flex', alignItems: 'center', gap: 0 }}>
          <Link href="/events" style={{ display: 'flex', padding: '8px 10px', color: isActive('/events') ? 'var(--ij-gold)' : 'var(--ij-text-secondary)', textDecoration: 'none' }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
            </svg>
          </Link>
          {profile && (
            <Link
              href="/notifications"
              onClick={() => { localStorage.setItem('notif_last_seen', new Date().toISOString()); setNotifDot(false) }}
              style={{ position: 'relative', display: 'flex', padding: '8px 10px', color: notifDot ? 'var(--ij-gold)' : 'var(--ij-text-secondary)', textDecoration: 'none' }}
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
                <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
              </svg>
              {notifDot && <span style={{ position: 'absolute', top: 6, right: 6, width: 7, height: 7, borderRadius: '50%', background: '#E24B4A', border: '2px solid var(--ij-bg-nav)' }} />}
            </Link>
          )}
          <Link
            href={profile ? '/dms' : '/auth/login'}
            style={{ display: 'flex', padding: '8px 10px', color: isActive('/dms') ? 'var(--ij-gold)' : 'var(--ij-text-secondary)', textDecoration: 'none' }}
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
            </svg>
          </Link>
          <button onClick={toggleTheme} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '8px 10px', color: 'var(--ij-text-secondary)', display: 'flex', alignItems: 'center' }}>
            {theme === 'dark'
              ? <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>
              : <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
            }
          </button>
        </div>
      </div>

      {/* ── DESKTOP: fixed top bar ─────────────────────────────────── */}
      <aside className="desktop-sidebar" style={{
        display: 'flex', flexShrink: 0,
        flexDirection: 'column',
      }}>
        {/* Left: logo + wordmark */}
        <Link href="/feed" style={{
          display: 'flex', alignItems: 'center', gap: 8,
          textDecoration: 'none', marginRight: 32, flexShrink: 0,
        }}>
          <div style={{
            width: 28, height: 28, borderRadius: 7,
            background: 'linear-gradient(135deg, #1A1840, #0F0F26)',
            border: '1px solid rgba(240,168,50,0.40)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <IjwiLogo size={18} color="#F0A832" />
          </div>
          <span style={{
            fontFamily: 'var(--ij-font-display)',
            fontSize: '1.2rem', fontWeight: 700,
            color: 'var(--ij-text-primary)', letterSpacing: '1px',
          }}>
            ijwi
          </span>
        </Link>

        {/* Center: nav links — sits in center grid column, naturally centered */}
        <nav style={{ display: 'flex', gap: 4, justifyContent: 'center' }}>
          {NAV_LINKS.map(({ href, label }) => {
            const active = isActive(href)
            return (
              <Link key={href} href={href} style={{
                fontFamily: 'var(--ij-font-body)',
                fontSize: '0.88rem', fontWeight: active ? 600 : 500,
                color: active ? 'var(--ij-text-primary)' : 'var(--ij-text-secondary)',
                textDecoration: 'none',
                padding: '4px 12px',
                transition: 'color 0.15s',
                display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                gap: 4,
                height: '100%',
              }}>
                {label}
                <span style={{
                  display: 'block',
                  width: active ? 20 : 0,
                  height: 3,
                  borderRadius: 999,
                  background: 'var(--ij-gold)',
                  transition: 'width 0.2s ease',
                }} />
              </Link>
            )
          })}
          {(isAdmin || profile?.is_admin) && (
            <Link href="/admin" style={{
              fontFamily: 'var(--ij-font-body)',
              fontSize: '0.88rem', fontWeight: 500,
              color: '#C0392B',
              textDecoration: 'none',
              padding: '4px 12px',
              display: 'flex', alignItems: 'center',
              height: '100%',
            }}>
              Admin
            </Link>
          )}
        </nav>

        {/* Right: auth / profile — right-aligned in its grid column */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, justifyContent: 'flex-end' }}>
          {/* DMs icon */}
          {profile && (
            <Link href="/dms" style={{
              position: 'relative', display: 'flex',
              color: isActive('/dms') ? 'var(--ij-gold)' : 'var(--ij-text-secondary)',
              textDecoration: 'none', padding: 6,
              transition: 'color 0.15s',
            }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none"
                stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
              </svg>
            </Link>
          )}

          {/* Notification bell — desktop only */}
          {profile && (
            <div className="desktop-only">
              <Link
                href="/notifications"
                onClick={() => {
                  localStorage.setItem('notif_last_seen', new Date().toISOString())
                  setNotifDot(false)
                }}
                style={{
                  position: 'relative', display: 'flex',
                  color: notifDot ? 'var(--ij-gold)' : 'var(--ij-text-secondary)',
                  textDecoration: 'none', padding: 6,
                }}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none"
                  stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
                  <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
                </svg>
                {notifDot && (
                  <span style={{
                    position: 'absolute', top: 4, right: 4,
                    width: 7, height: 7, borderRadius: '50%',
                    background: '#C0392B', border: '1.5px solid var(--ij-bg-nav)',
                  }} />
                )}
              </Link>
            </div>
          )}

          {/* Theme toggle */}
          <button
            onClick={toggleTheme}
            title={theme === 'dark' ? 'Switch to Light mode' : 'Switch to Dark mode'}
            style={{
              background: 'transparent', border: 'none', cursor: 'pointer',
              padding: '6px', borderRadius: '50%',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: 'var(--ij-text-secondary)', transition: 'color 0.15s, background 0.15s',
            }}
            onMouseEnter={e => {
              e.currentTarget.style.color = 'var(--ij-gold)'
              e.currentTarget.style.background = 'var(--ij-glow-gold)'
            }}
            onMouseLeave={e => {
              e.currentTarget.style.color = 'var(--ij-text-secondary)'
              e.currentTarget.style.background = 'transparent'
            }}
          >
            {theme === 'dark' ? (
              <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
                <circle cx="12" cy="12" r="5"/>
                <line x1="12" y1="1" x2="12" y2="3"/>
                <line x1="12" y1="21" x2="12" y2="23"/>
                <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/>
                <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/>
                <line x1="1" y1="12" x2="3" y2="12"/>
                <line x1="21" y1="12" x2="23" y2="12"/>
                <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/>
                <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>
              </svg>
            ) : (
              <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
                <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>
              </svg>
            )}
          </button>

          {/* Divider */}
          <div style={{ width: 1, height: 20, background: 'var(--ij-border)' }} />

          {profile ? (
            <>
              {(profile.is_approved_poster || profile.is_admin) && (
                <>
                  <Link href="/write" style={{
                    fontFamily: 'var(--ij-font-body)',
                    fontSize: '0.82rem', fontWeight: 600,
                    color: 'var(--ij-text-secondary)',
                    border: '1px solid var(--ij-border)',
                    padding: '7px 14px', borderRadius: 999,
                    cursor: 'pointer', minHeight: 36,
                    whiteSpace: 'nowrap', textDecoration: 'none',
                    display: 'flex', alignItems: 'center',
                    transition: 'border-color 0.15s, color 0.15s',
                  }}>
                    ✍ Write
                  </Link>
                  <button
                    onClick={handleCompose}
                    style={{
                      background: 'linear-gradient(135deg, #C9860A, #F0A832)',
                      color: '#0C0916', border: 'none',
                      fontFamily: 'var(--ij-font-body)',
                      fontSize: '0.82rem', fontWeight: 700,
                      padding: '8px 16px', borderRadius: 999,
                      cursor: 'pointer', minHeight: 36,
                      whiteSpace: 'nowrap',
                    }}
                  >
                    Share voice
                  </button>
                </>
              )}
              {!profile.is_approved_poster && !profile.is_admin && (
                <button
                  onClick={handleCompose}
                  style={{
                    background: 'transparent',
                    border: '1px solid var(--ij-border-gold)',
                    borderRadius: 999,
                    color: 'var(--ij-gold)',
                    fontFamily: 'var(--ij-font-body)',
                    fontSize: '0.85rem', fontWeight: 600,
                    padding: '7px 16px', cursor: 'pointer',
                    minHeight: 36, whiteSpace: 'nowrap',
                  }}>
                  Ask a question
                </button>
              )}
              <Link href={`/profile/${profile.id}`} style={{ flexShrink: 0 }}>
                <ProfileAvatar
                  userId={profile.id}
                  avatarUrl={profile.avatar_url}
                  isRevealed={profile.is_revealed}
                  size={30}
                  voiceName={profile.voice_name}
                />
              </Link>
              <button
                onClick={handleSignOut}
                title="Sign out"
                style={{
                  background: 'none', border: 'none', cursor: 'pointer',
                  color: 'var(--ij-text-secondary)', padding: '4px',
                  lineHeight: 1, fontSize: '15px', flexShrink: 0,
                  opacity: 0.6,
                }}
              >
                ↩
              </button>
            </>
          ) : (
            <>
              <Link href="/auth/login" style={{
                fontFamily: 'var(--ij-font-body)',
                fontSize: '0.88rem', fontWeight: 500,
                color: 'var(--ij-text-secondary)', textDecoration: 'none',
                padding: '6px 4px', minHeight: 36,
                display: 'flex', alignItems: 'center',
              }}>
                Sign in
              </Link>
              <Link href="/auth/signup" style={{
                background: 'linear-gradient(135deg, #C9860A, #F0A832)',
                color: '#0C0916', border: 'none',
                fontFamily: 'var(--ij-font-body)',
                fontSize: '0.82rem', fontWeight: 700,
                padding: '8px 16px', borderRadius: 999,
                cursor: 'pointer', minHeight: 36,
                textDecoration: 'none',
                display: 'flex', alignItems: 'center',
                whiteSpace: 'nowrap',
              }}>
                Join Ijwi
              </Link>
            </>
          )}
        </div>
      </aside>

      {/* ── MOBILE: fixed bottom nav ───────────────────────────────── */}
      <nav className={hideMobileNav ? '' : 'mobile-nav'} style={{
        display: 'none',
        position: 'fixed', bottom: 0, left: 0, right: 0,
        background: 'var(--ij-bg-nav)',
        borderTop: '1px solid var(--ij-border)',
        height: 62,
        paddingBottom: 'env(safe-area-inset-bottom)',
        zIndex: 100,
        justifyContent: 'space-around',
        alignItems: 'center',
        backdropFilter: 'blur(16px)',
        WebkitBackdropFilter: 'blur(16px)',
      }}>
        {/* Home */}
        <motion.div whileTap={{ scale: 0.88 }} style={{ flex: 1 }}>
          <Link href="/feed" style={{
            display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center',
            gap: 3, textDecoration: 'none', minHeight: 48,
            color: isActive('/feed') ? 'var(--ij-gold)' : 'var(--ij-text-secondary)',
          }}>
            <svg width="22" height="22" viewBox="0 0 24 24" fill={isActive('/feed') ? 'var(--ij-gold)' : 'none'}
              stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <path d="M3 9.5L12 3l9 6.5V20a1 1 0 01-1 1H5a1 1 0 01-1-1z" />
              <path d="M9 21V13h6v8" fill="none" />
            </svg>
            <span style={{ fontFamily: 'var(--ij-font-body)', fontSize: '0.58rem', fontWeight: isActive('/feed') ? 700 : 500 }}>Home</span>
          </Link>
        </motion.div>

        {/* Explore */}
        <motion.div whileTap={{ scale: 0.88 }} style={{ flex: 1 }}>
          <Link href="/explore" style={{
            display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center',
            gap: 3, textDecoration: 'none', minHeight: 48,
            color: isActive('/explore') ? 'var(--ij-gold)' : 'var(--ij-text-secondary)',
          }}>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none"
              stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="11" cy="11" r="8" />
              <path d="M21 21l-4.35-4.35" />
            </svg>
            <span style={{ fontFamily: 'var(--ij-font-body)', fontSize: '0.58rem', fontWeight: isActive('/explore') ? 700 : 500 }}>Explore</span>
          </Link>
        </motion.div>

        {/* CENTER: compose / create */}
        <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
          {profile ? (
            <motion.button
              onClick={handleCompose}
              whileTap={{ scale: 0.88, y: -4 }}
              whileHover={{ scale: 1.05, boxShadow: '0 6px 24px rgba(242,172,58,0.6)' }}
              transition={{ type: 'spring', stiffness: 500, damping: 22 }}
              style={{
                width: 54, height: 54, borderRadius: '50%',
                background: 'linear-gradient(135deg, #C9860A 0%, #F2AC3A 100%)',
                border: '3px solid var(--ij-bg-nav)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                cursor: 'pointer',
                boxShadow: '0 4px 20px rgba(242,172,58,0.5)',
                transform: 'translateY(-10px)',
              }}
            >
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none"
                stroke="#0C0916" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round">
                <line x1="12" y1="5" x2="12" y2="19" />
                <line x1="5" y1="12" x2="19" y2="12" />
              </svg>
            </motion.button>
          ) : (
            <Link href="/auth/signup" style={{ textDecoration: 'none' }}>
              <motion.div
                whileTap={{ scale: 0.9 }}
                style={{
                  width: 54, height: 54, borderRadius: '50%',
                  background: 'linear-gradient(135deg, #C9860A 0%, #F2AC3A 100%)',
                  border: '3px solid var(--ij-bg-nav)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  boxShadow: '0 4px 20px rgba(242,172,58,0.5)',
                  transform: 'translateY(-10px)',
                }}
              >
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none"
                  stroke="#0C0916" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round">
                  <line x1="12" y1="5" x2="12" y2="19" />
                  <line x1="5" y1="12" x2="19" y2="12" />
                </svg>
              </motion.div>
            </Link>
          )}
        </div>

        {/* Events */}
        <motion.div whileTap={{ scale: 0.88 }} style={{ flex: 1 }}>
          <Link href="/events" style={{
            display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center',
            gap: 3, textDecoration: 'none', minHeight: 48,
            color: isActive('/events') ? 'var(--ij-gold)' : 'var(--ij-text-secondary)',
          }}>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none"
              stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2" strokeWidth={isActive('/events') ? 2.2 : 1.8}/>
              <line x1="16" y1="2" x2="16" y2="6"/>
              <line x1="8" y1="2" x2="8" y2="6"/>
              <line x1="3" y1="10" x2="21" y2="10"/>
            </svg>
            <span style={{ fontFamily: 'var(--ij-font-body)', fontSize: '0.58rem', fontWeight: isActive('/events') ? 700 : 500 }}>Events</span>
          </Link>
        </motion.div>

        {/* Account */}
        <motion.div whileTap={{ scale: 0.88 }} style={{ flex: 1 }}>
        <Link
          href={profile ? `/profile/${profile.id}` : '/auth/login'}
          style={{
            display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center',
            gap: 3, textDecoration: 'none', minHeight: 48,
            color: isActive('/profile') ? 'var(--ij-gold)' : 'var(--ij-text-secondary)',
            position: 'relative',
          }}
        >
          {profile ? (
            <div style={{
              width: 26, height: 26, borderRadius: '50%',
              border: isActive('/profile') ? '2px solid var(--ij-gold)' : '2px solid transparent',
              transition: 'border-color 0.15s',
              overflow: 'hidden',
            }}>
              <ProfileAvatar
                userId={profile.id}
                avatarUrl={profile.avatar_url}
                isRevealed={profile.is_revealed}
                size={22}
                voiceName={profile.voice_name}
              />
            </div>
          ) : (
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none"
              stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" />
              <circle cx="12" cy="7" r="4" />
            </svg>
          )}
          <span style={{ fontFamily: 'var(--ij-font-body)', fontSize: '0.58rem', fontWeight: isActive('/profile') ? 700 : 500 }}>
            {profile ? 'Me' : 'Sign in'}
          </span>
          {notifDot && (
            <span style={{
              position: 'absolute', top: 6, right: '18%',
              width: 8, height: 8, borderRadius: '50%',
              background: '#E24B4A', border: '2px solid var(--ij-bg-surface)',
            }} />
          )}
        </Link>
        </motion.div>
      </nav>

      {/* Global compose sheet — shown when no onCompose prop is provided */}
      {!onCompose && (
        <ComposeSheet
          profile={profile}
          isOpen={showCompose}
          onClose={() => setShowCompose(false)}
          isAdmin={isAdmin || profile?.is_admin}
        />
      )}
    </>
  )
}
