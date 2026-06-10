'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { Profile } from '@/lib/types'
import Navbar from '@/components/layout/Navbar'
import { AVATAR_PRESETS, getAvatarPreset } from '@/lib/utils'
import ProfileAvatar from '@/components/ui/ProfileAvatar'
import { createClient } from '@/lib/supabase/client'
import ProBadge from '@/components/ui/ProBadge'
import BackButton from '@/components/ui/BackButton'

interface SettingsClientProps {
  profile: Profile
  userEmail: string
}

export default function SettingsClient({ profile, userEmail }: SettingsClientProps) {
  const router = useRouter()
  const supabase = createClient()

  // Voice / identity
  const [voiceName, setVoiceName] = useState(profile.voice_name)
  const [bio, setBio] = useState(profile.bio ?? '')
  const [realName, setRealName] = useState(profile.real_name ?? '')
  const [isRevealed, setIsRevealed] = useState(profile.is_revealed)
  const [voiceRole, setVoiceRole] = useState<string>(profile.voice_role ?? 'voice')

  // Notifications (legacy)
  const [notifDailyVerse, setNotifDailyVerse] = useState(profile.notif_daily_verse ?? true)
  const [notifPrayerResponse, setNotifPrayerResponse] = useState(profile.notif_prayer_response ?? true)
  const [notifNewFollower, setNotifNewFollower] = useState(profile.notif_new_follower ?? true)
  const [notifFireReaction, setNotifFireReaction] = useState(profile.notif_fire_reaction ?? true)
  const [notifComment, setNotifComment] = useState(profile.notif_comment ?? true)
  // Notifications (extended)
  const [notifyFollows, setNotifyFollows] = useState(profile.notify_follows ?? true)
  const [notifyReactions, setNotifyReactions] = useState(profile.notify_reactions ?? true)
  const [notifyComments, setNotifyComments] = useState(profile.notify_comments ?? true)
  const [notifyPrayers, setNotifyPrayers] = useState(profile.notify_prayers ?? true)
  const [notifyBlessings, setNotifyBlessings] = useState(profile.notify_blessings ?? true)
  const [notifyDms, setNotifyDms] = useState(profile.notify_dms ?? true)
  const [notifyEchoes, setNotifyEchoes] = useState(profile.notify_echoes ?? true)

  // Privacy
  const [commentPermission, setCommentPermission] = useState<'everyone' | 'followers' | 'no_one'>(
    profile.comment_permission ?? 'everyone'
  )

  // Avatar
  const [selectedAvatar, setSelectedAvatar] = useState(profile.avatar_url ?? '')
  const [showAvatarPicker, setShowAvatarPicker] = useState(false)

  // Password change
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [passwordSaving, setPasswordSaving] = useState(false)
  const [passwordMsg, setPasswordMsg] = useState('')
  const [passwordError, setPasswordError] = useState('')

  // UI state
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const [error, setError] = useState('')
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [deleteInput, setDeleteInput] = useState('')
  const [deleting, setDeleting] = useState(false)
  const [pushEnabled, setPushEnabled] = useState(false)
  const [pushLoading, setPushLoading] = useState(false)
  const [pushMessage, setPushMessage] = useState('')

  // Mobile Money payment state
  const [showMomoForm, setShowMomoForm] = useState(false)
  const [momoPhone, setMomoPhone] = useState('')
  const [momoLoading, setMomoLoading] = useState(false)
  const [momoSent, setMomoSent] = useState(false)
  const [momoError, setMomoError] = useState('')

  const handleMomoPay = async () => {
    setMomoError('')
    setMomoLoading(true)
    try {
      const res = await fetch('/api/momo/pay', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: momoPhone }),
      })
      const data = await res.json()
      if (!res.ok || data.error) {
        setMomoError(data.error ?? 'Payment failed. Please try again.')
      } else {
        setMomoSent(true)
      }
    } catch {
      setMomoError('Payment service unavailable. Please try again.')
    } finally {
      setMomoLoading(false)
    }
  }

  const showPushMsg = (msg: string) => {
    setPushMessage(msg)
    setTimeout(() => setPushMessage(''), 4000)
  }

  const handleTogglePush = async () => {
    if (!('Notification' in window) || !('serviceWorker' in navigator)) {
      showPushMsg('To get push notifications, add Ijwi to your home screen first.')
      return
    }
    setPushLoading(true)
    try {
      if (pushEnabled) {
        const reg = await navigator.serviceWorker.ready
        const sub = await reg.pushManager.getSubscription()
        if (sub) {
          await sub.unsubscribe()
          await fetch('/api/push/subscribe', {
            method: 'DELETE',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ endpoint: sub.endpoint }),
          })
        }
        setPushEnabled(false)
        showPushMsg('Notifications disabled.')
      } else {
        const perm = await Notification.requestPermission()
        if (perm !== 'granted') {
          showPushMsg('You can enable notifications in your phone settings.')
          setPushLoading(false)
          return
        }
        const reg = await navigator.serviceWorker.ready
        const vapidKey = process.env.NEXT_PUBLIC_VAPID_KEY
        if (!vapidKey) {
          showPushMsg('Push notifications not configured on this server yet.')
          setPushLoading(false)
          return
        }
        const sub = await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: vapidKey,
        })
        const json = sub.toJSON()
        await fetch('/api/push/subscribe', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ endpoint: json.endpoint, keys: json.keys }),
        })
        setPushEnabled(true)
        showPushMsg('Notifications enabled!')
      }
    } catch {
      showPushMsg('Could not enable notifications on this browser.')
    }
    setPushLoading(false)
  }

  const handleSave = async () => {
    if (!voiceName.trim()) {
      setError('Voice name cannot be empty.')
      return
    }
    setSaving(true)
    setError('')
    setSaved(false)

    const updates: Record<string, unknown> = {
      voice_name: voiceName.trim(),
      bio: bio.trim() || null,
      is_revealed: isRevealed,
      real_name: isRevealed ? (realName.trim() || null) : (profile.real_name ?? null),
      avatar_url: selectedAvatar || null,
      voice_role: voiceRole,
      notif_daily_verse: notifDailyVerse,
      notif_prayer_response: notifPrayerResponse,
      notif_new_follower: notifNewFollower,
      notif_fire_reaction: notifFireReaction,
      notif_comment: notifComment,
      notify_follows: notifyFollows,
      notify_reactions: notifyReactions,
      notify_comments: notifyComments,
      notify_prayers: notifyPrayers,
      notify_blessings: notifyBlessings,
      notify_dms: notifyDms,
      notify_echoes: notifyEchoes,
      comment_permission: commentPermission,
      updated_at: new Date().toISOString(),
    }

    const { error: updateError } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', profile.id)

    if (updateError) {
      setError(updateError.message)
    } else {
      setSaved(true)
      setTimeout(() => setSaved(false), 3000)
    }
    setSaving(false)
  }

  const handlePasswordChange = async () => {
    setPasswordError('')
    setPasswordMsg('')
    if (newPassword.length < 8) { setPasswordError('Password must be at least 8 characters.'); return }
    if (newPassword !== confirmPassword) { setPasswordError('Passwords do not match.'); return }
    setPasswordSaving(true)
    const { error } = await supabase.auth.updateUser({ password: newPassword })
    if (error) { setPasswordError(error.message) }
    else { setPasswordMsg('Password updated successfully.'); setNewPassword(''); setConfirmPassword('') }
    setPasswordSaving(false)
  }

  const handleSignOut = async () => {
    await supabase.auth.signOut()
    router.push('/')
  }

  const handleDeleteAccount = async () => {
    if (deleteInput !== profile.voice_name) return
    setDeleting(true)
    await supabase.from('posts').delete().eq('author_id', profile.id)
    await supabase.from('comments').delete().eq('author_id', profile.id)
    await supabase.from('follows').delete().eq('follower_id', profile.id)
    await supabase.from('follows').delete().eq('following_id', profile.id)
    await supabase.from('profiles').update({
      voice_name: `deleted-${profile.id.slice(0, 6)}`,
      bio: null, real_name: null, is_revealed: false, avatar_url: null,
    }).eq('id', profile.id)
    await supabase.auth.signOut()
    router.push('/')
  }

  const inputStyle = {
    width: '100%', padding: '12px 16px', borderRadius: '10px',
    border: '1px solid var(--border)', fontSize: '15px',
    fontFamily: 'var(--font-body)', background: 'var(--surface)',
    color: 'var(--text-primary)', outline: 'none', boxSizing: 'border-box' as const
  }

  const sectionStyle = {
    marginBottom: '32px', paddingBottom: '32px', borderBottom: '1px solid var(--border)'
  }

  const Toggle = ({ value, onChange }: { value: boolean; onChange: (v: boolean) => void }) => (
    <div
      onClick={() => onChange(!value)}
      style={{
        width: '36px', height: '20px', borderRadius: '100px',
        background: value ? 'var(--flame)' : 'var(--border)',
        position: 'relative', transition: 'background 0.2s', flexShrink: 0, cursor: 'pointer'
      }}
    >
      <div style={{
        width: '16px', height: '16px', borderRadius: '50%', background: 'white',
        position: 'absolute', top: '2px',
        left: value ? '18px' : '2px',
        transition: 'left 0.2s'
      }} />
    </div>
  )

  const NotifRow = ({
    label, desc, value, onChange
  }: { label: string; desc: string; value: boolean; onChange: (v: boolean) => void }) => (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      gap: '16px', marginBottom: '16px'
    }}>
      <div>
        <div style={{ fontSize: '14px', fontWeight: 500, color: 'var(--text-primary)' }}>{label}</div>
        <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{desc}</div>
      </div>
      <Toggle value={value} onChange={onChange} />
    </div>
  )

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--warm-white)' }}>
      <Navbar profile={profile} />

      <main className="ij-page-container" style={{ flex: 1, maxWidth: '760px' }}>
        <BackButton href="/feed" />
        {/* Header */}
        <div style={{ marginBottom: '32px' }}>
          <h1 style={{
            fontFamily: 'var(--font-display)', fontSize: '32px', fontWeight: 500,
            color: 'var(--text-primary)', marginBottom: '6px'
          }}>
            Settings
          </h1>
          <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
            Manage your voice, identity, and account.
          </p>
        </div>

        <div className="card" style={{ padding: '32px' }}>

          {/* ── IDENTITY ── */}
          <div style={sectionStyle}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '20px' }}>
              Your voice
            </h2>

            {/* Avatar picker */}
            <div style={{ marginBottom: '24px' }}>
              <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '10px', fontWeight: 500 }}>
                Profile picture
              </label>
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                <ProfileAvatar
                  userId={profile.id}
                  avatarUrl={selectedAvatar || undefined}
                  isRevealed={false}
                  size={60}
                  voiceName={voiceName}
                />
                <button
                  type="button"
                  onClick={() => setShowAvatarPicker(v => !v)}
                  style={{
                    padding: '8px 18px', borderRadius: '100px',
                    border: '1px solid var(--border)', background: 'transparent',
                    fontSize: '13px', color: 'var(--text-secondary)', cursor: 'pointer',
                    fontFamily: 'var(--font-body)'
                  }}
                >
                  {showAvatarPicker ? 'Close' : 'Change picture'}
                </button>
              </div>

              {showAvatarPicker && (
                <div style={{
                  marginTop: '14px', padding: '16px', borderRadius: '14px',
                  background: 'var(--surface-2)', border: '1px solid var(--border)'
                }}>
                  <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '12px' }}>
                    Choose a cross avatar — each one represents a different aspect of Christ's character.
                  </p>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: '10px' }}>
                    {AVATAR_PRESETS.map(preset => {
                      const active = selectedAvatar === preset.id
                      return (
                        <button
                          key={preset.id}
                          type="button"
                          onClick={() => { setSelectedAvatar(preset.id); setShowAvatarPicker(false) }}
                          title={preset.label}
                          style={{
                            padding: 0, border: 'none', background: 'none',
                            cursor: 'pointer', display: 'flex', flexDirection: 'column',
                            alignItems: 'center', gap: '4px',
                          }}
                        >
                          <div style={{
                            width: 48, height: 48, borderRadius: '50%',
                            background: preset.gradient,
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            outline: active ? '3px solid var(--flame)' : '3px solid transparent',
                            outlineOffset: '2px', transition: 'outline 0.15s',
                          }}>
                            <svg width={20} height={25} viewBox="0 0 24 30" fill="none">
                              <rect x="9.5" y="0" width="5" height="30" rx="2.5" fill="white" />
                              <rect x="0" y="8" width="24" height="5" rx="2.5" fill="white" />
                            </svg>
                          </div>
                          <span style={{ fontSize: '9px', color: 'var(--text-muted)', textAlign: 'center', lineHeight: 1.2 }}>
                            {preset.label}
                          </span>
                        </button>
                      )
                    })}
                  </div>
                </div>
              )}
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '20px' }}>
              <div>
                <div style={{ fontSize: '15px', fontWeight: 500, color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  {voiceName || profile.voice_name}
                  {profile.is_pro && <ProBadge size="xs" />}
                </div>
                <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{userEmail}</div>
              </div>
            </div>

            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '6px', fontWeight: 500 }}>
                Voice name
              </label>
              <input
                type="text"
                value={voiceName}
                onChange={e => setVoiceName(e.target.value)}
                maxLength={40}
                style={inputStyle}
                placeholder="Your anonymous voice name"
              />
            </div>

            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '6px', fontWeight: 500 }}>
                Bio
              </label>
              <textarea
                value={bio}
                onChange={e => setBio(e.target.value)}
                rows={3}
                maxLength={200}
                placeholder="Tell the community a little about your faith journey..."
                style={{ ...inputStyle, resize: 'vertical', lineHeight: 1.6 }}
              />
              <div style={{ fontSize: '12px', color: 'var(--text-muted)', textAlign: 'right', marginTop: '4px' }}>
                {bio.length}/200
              </div>
            </div>

            {/* Voice Role */}
            <div>
              <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '8px', fontWeight: 500 }}>
                Your role in the community
              </label>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {[
                  { value: 'voice', label: 'Voice' },
                  { value: 'storyteller', label: 'Storyteller' },
                  { value: 'content_creator', label: 'Content Creator' },
                ].map(role => {
                  const active = voiceRole === role.value
                  return (
                    <button
                      key={role.value}
                      type="button"
                      onClick={() => setVoiceRole(role.value)}
                      style={{
                        padding: '13px 16px', borderRadius: '12px', textAlign: 'left',
                        border: `1px solid ${active ? 'var(--flame)' : 'var(--border)'}`,
                        background: active ? 'var(--flame-soft)' : 'var(--surface-2)',
                        cursor: 'pointer', transition: 'all 0.15s',
                        width: '100%',
                      }}
                    >
                      <span style={{ fontSize: '14px', fontWeight: 600, color: active ? 'var(--flame)' : 'var(--text-primary)', fontFamily: 'var(--font-body)' }}>
                        {role.label}
                      </span>
                    </button>
                  )
                })}
              </div>
            </div>
          </div>

          {/* ── IDENTITY REVEAL ── */}
          <div style={sectionStyle}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '8px' }}>
              Your identity
            </h2>
            <p style={{ fontSize: '14px', color: 'var(--text-secondary)', marginBottom: '20px', lineHeight: 1.6 }}>
              By default, only your voice name is shown. You can choose to reveal your real name — your posts will still be yours, but people can know who you are.
            </p>

            <div
              style={{
                display: 'flex', alignItems: 'center', gap: '12px',
                padding: '14px 16px', borderRadius: '12px', background: 'var(--surface-2)',
                marginBottom: '16px', cursor: 'pointer'
              }}
              onClick={() => setIsRevealed(!isRevealed)}
            >
              <Toggle value={isRevealed} onChange={setIsRevealed} />
              <div>
                <div style={{ fontSize: '14px', fontWeight: 500, color: 'var(--text-primary)' }}>
                  {isRevealed ? 'Identity revealed' : 'Stay anonymous'}
                </div>
                <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                  {isRevealed
                    ? 'Your real name appears on your non-anonymous posts and profile'
                    : 'Only your voice name is visible to others'}
                </div>
              </div>
            </div>

            {isRevealed && (
              <div>
                <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '6px', fontWeight: 500 }}>
                  Your real name
                </label>
                <input
                  type="text"
                  value={realName}
                  onChange={e => setRealName(e.target.value)}
                  placeholder="Your full name"
                  maxLength={80}
                  style={inputStyle}
                />
              </div>
            )}
          </div>

          {/* ── SUBSCRIPTION ── */}
          <div style={sectionStyle} id="subscription">
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '8px' }}>
              Subscription
            </h2>
            {(profile.is_pro || (profile as any).is_approved_poster || (profile as any).is_admin) ? (
              <div style={{
                padding: '20px', borderRadius: '12px',
                background: 'linear-gradient(135deg, #FFF3EE 0%, #FFF8F0 100%)',
                border: '1px solid #FFD4B8'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px' }}>
                  <ProBadge />
                  <span style={{ fontFamily: 'var(--font-display)', fontSize: '16px', color: 'var(--text-primary)' }}>
                    You're on Pro
                  </span>
                </div>
                <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: 1.6, margin: 0 }}>
                  You have unlimited reading, full story access, and early features. Thank you for supporting Ijwi.
                  {profile.pro_expires_at && (
                    <> Your Pro access expires on {new Date(profile.pro_expires_at).toLocaleDateString('en-RW', { month: 'long', day: 'numeric', year: 'numeric' })}.</>
                  )}
                </p>
              </div>
            ) : (
              <div>
                <p style={{ fontSize: '14px', color: 'var(--text-secondary)', marginBottom: '16px', lineHeight: 1.6 }}>
                  You're on the <strong>Free</strong> plan. Stories and letters over 600 words are partially hidden. Upgrade to read everything and support the community.
                </p>
                <div style={{
                  padding: '20px', borderRadius: '12px',
                  background: 'linear-gradient(135deg, #FFF3EE 0%, #FFF8F0 100%)',
                  border: '1px solid #FFD4B8', marginBottom: '16px'
                }}>
                  <div style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '12px', color: 'var(--text-primary)' }}>
                    Ijwi Pro ✨
                  </div>
                  <ul style={{ margin: 0, paddingLeft: '18px', fontSize: '14px', color: 'var(--text-secondary)', lineHeight: 2 }}>
                    <li>Read every story, letter, and long-form post in full</li>
                    <li>Support voices that matter</li>
                    <li>Early access to new features</li>
                    <li>Pro badge on your profile</li>
                  </ul>

                  {/* Price badge */}
                  <div style={{
                    display: 'inline-flex', alignItems: 'center', gap: '8px',
                    marginTop: '16px', marginBottom: '16px',
                    padding: '8px 16px', borderRadius: '100px',
                    background: 'var(--flame)', color: 'white',
                    fontSize: '15px', fontWeight: 700,
                  }}>
                    2,000 RWF <span style={{ fontWeight: 400, opacity: 0.8, fontSize: '13px' }}>≈ $1.50 · 30 days</span>
                  </div>

                  {!showMomoForm && !momoSent && (
                    <div>
                      <button
                        onClick={() => setShowMomoForm(true)}
                        style={{
                          display: 'block', width: '100%', padding: '13px 28px', borderRadius: '100px',
                          background: 'var(--flame)', color: 'white', border: 'none',
                          fontSize: '15px', fontWeight: 600, cursor: 'pointer',
                          fontFamily: 'var(--font-body)',
                        }}
                      >
                        Pay with Mobile Money →
                      </button>
                      <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '8px', textAlign: 'center' }}>
                        MTN MoMo or Airtel Money · Rwanda only
                      </p>
                      {process.env.NODE_ENV === 'development' && (
                        <p style={{ fontSize: '12px', color: 'rgba(240,168,50,0.6)', marginTop: '6px', textAlign: 'center', fontStyle: 'italic' }}>
                          Dev mode: Paypack sandbox only accepts registered test numbers.
                        </p>
                      )}
                    </div>
                  )}

                  {showMomoForm && !momoSent && (
                    <div style={{ marginTop: '4px' }}>
                      <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '6px', fontWeight: 500 }}>
                        Your MTN / Airtel number
                      </label>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <div style={{ position: 'relative', flex: 1 }}>
                          <span style={{
                            position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)',
                            fontSize: '14px', color: 'var(--text-muted)', pointerEvents: 'none',
                          }}>
                            🇷🇼
                          </span>
                          <input
                            type="tel"
                            value={momoPhone}
                            onChange={e => setMomoPhone(e.target.value)}
                            placeholder="078 000 0000"
                            maxLength={12}
                            autoFocus
                            style={{
                              ...inputStyle,
                              paddingLeft: '40px',
                            }}
                          />
                        </div>
                        <button
                          onClick={handleMomoPay}
                          disabled={momoLoading || momoPhone.replace(/\s/g,'').length < 9}
                          style={{
                            padding: '12px 20px', borderRadius: '100px', border: 'none',
                            background: momoLoading || momoPhone.replace(/\s/g,'').length < 9 ? 'var(--border)' : 'var(--flame)',
                            color: momoLoading || momoPhone.replace(/\s/g,'').length < 9 ? 'var(--text-muted)' : 'white',
                            fontSize: '14px', fontWeight: 600,
                            cursor: momoLoading || momoPhone.replace(/\s/g,'').length < 9 ? 'not-allowed' : 'pointer',
                            fontFamily: 'var(--font-body)', whiteSpace: 'nowrap',
                          }}
                        >
                          {momoLoading ? 'Sending...' : 'Pay 2,000 RWF'}
                        </button>
                      </div>
                      {momoError && (
                        <p style={{ color: '#E24B4A', fontSize: '13px', marginTop: '8px' }}>{momoError}</p>
                      )}
                      <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '8px' }}>
                        You&apos;ll receive a USSD prompt on your phone. Approve it to activate Pro.
                      </p>
                      <button
                        onClick={() => { setShowMomoForm(false); setMomoError('') }}
                        style={{
                          marginTop: '8px', background: 'none', border: 'none',
                          color: 'var(--text-muted)', fontSize: '13px', cursor: 'pointer',
                          fontFamily: 'var(--font-body)',
                        }}
                      >
                        Cancel
                      </button>
                    </div>
                  )}

                  {momoSent && (
                    <div style={{
                      marginTop: '4px', padding: '16px', borderRadius: '12px',
                      background: '#F0FDF4', border: '1px solid #86EFAC', textAlign: 'center'
                    }}>
                      <div style={{ fontSize: '32px', marginBottom: '8px' }}>📱</div>
                      <p style={{ fontSize: '14px', fontWeight: 600, color: '#15803D', marginBottom: '4px' }}>
                        Payment prompt sent!
                      </p>
                      <p style={{ fontSize: '13px', color: '#166534' }}>
                        Check your phone and approve the 2,000 RWF request. Your Pro access activates instantly after approval.
                      </p>
                      <button
                        onClick={() => router.refresh()}
                        style={{
                          marginTop: '12px', padding: '8px 20px', borderRadius: '100px',
                          background: '#15803D', color: 'white', border: 'none',
                          fontSize: '13px', cursor: 'pointer', fontFamily: 'var(--font-body)'
                        }}
                      >
                        I&apos;ve approved — refresh
                      </button>
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* ── NOTIFICATIONS ── */}
          <div style={sectionStyle}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '8px' }}>
              Notifications
            </h2>
            <p style={{ fontSize: '14px', color: 'var(--text-secondary)', marginBottom: '20px', lineHeight: 1.6 }}>
              Choose what you want to be notified about.
            </p>
            <NotifRow
              label="Daily verse"
              desc="A curated scripture every morning"
              value={notifDailyVerse}
              onChange={setNotifDailyVerse}
            />
            <NotifRow
              label="Prayer response"
              desc="When someone responds to your prayer request"
              value={notifPrayerResponse}
              onChange={setNotifPrayerResponse}
            />
            <NotifRow
              label="New follower"
              desc="When someone follows your voice"
              value={notifNewFollower}
              onChange={setNotifNewFollower}
            />
            <NotifRow
              label="Post reactions"
              desc="When someone is touched by your post"
              value={notifFireReaction}
              onChange={setNotifFireReaction}
            />
            <NotifRow
              label="Comments"
              desc="When someone replies to your post"
              value={notifComment}
              onChange={setNotifComment}
            />

            <div style={{ borderTop: '1px solid var(--border)', paddingTop: '16px', marginTop: '4px', marginBottom: '16px' }}>
              <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '14px' }}>
                Activity
              </div>
              <NotifRow
                label="New followers"
                desc="When someone follows your voice"
                value={notifyFollows}
                onChange={setNotifyFollows}
              />
              <NotifRow
                label="Reactions"
                desc="Fire, amen, and other reactions to your posts"
                value={notifyReactions}
                onChange={setNotifyReactions}
              />
              <NotifRow
                label="Comment replies"
                desc="When someone replies in a thread you're in"
                value={notifyComments}
                onChange={setNotifyComments}
              />
              <NotifRow
                label="Prayer responses"
                desc="When someone prays for your request"
                value={notifyPrayers}
                onChange={setNotifyPrayers}
              />
              <NotifRow
                label="Blessings"
                desc="When someone blesses your voice"
                value={notifyBlessings}
                onChange={setNotifyBlessings}
              />
              <NotifRow
                label="Direct messages"
                desc="New messages from helpers and community"
                value={notifyDms}
                onChange={setNotifyDms}
              />
              <NotifRow
                label="Echoes"
                desc="When someone echoes your post"
                value={notifyEchoes}
                onChange={setNotifyEchoes}
              />
            </div>

            {/* Browser push toggle */}
            <div style={{
              marginTop: '16px', paddingTop: '16px',
              borderTop: '1px solid var(--border)',
              display: 'flex', alignItems: 'center', justifyContent: 'space-between'
            }}>
              <div>
                <div style={{ fontSize: '14px', fontWeight: 500, color: 'var(--text-primary)' }}>
                  Browser / app notifications
                </div>
                <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '2px' }}>
                  Real-time push alerts on this device
                </div>
              </div>
              <button
                onClick={handleTogglePush}
                disabled={pushLoading}
                style={{
                  padding: '8px 18px', borderRadius: '100px', fontSize: '13px',
                  border: `1px solid ${pushEnabled ? 'var(--flame)' : 'var(--border)'}`,
                  background: pushEnabled ? 'var(--flame-soft)' : 'transparent',
                  color: pushEnabled ? 'var(--flame)' : 'var(--text-secondary)',
                  cursor: pushLoading ? 'wait' : 'pointer',
                  fontFamily: 'var(--font-body)', fontWeight: 500,
                }}
              >
                {pushLoading ? '...' : pushEnabled ? 'Enabled ✓' : 'Enable'}
              </button>
            </div>
            {pushMessage && (
              <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginTop: '10px', lineHeight: 1.5 }}>
                {pushMessage}
              </p>
            )}
          </div>

          {/* ── PRIVACY ── */}
          <div style={sectionStyle}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '8px' }}>
              Privacy
            </h2>
            <p style={{ fontSize: '14px', color: 'var(--text-secondary)', marginBottom: '16px', lineHeight: 1.6 }}>
              Control who can comment on your posts.
            </p>
            <div>
              <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '8px', fontWeight: 500 }}>
                Who can comment on your posts?
              </label>
              {(['everyone', 'followers', 'no_one'] as const).map(opt => (
                <label key={opt} style={{
                  display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '10px',
                  cursor: 'pointer', fontSize: '14px', color: 'var(--text-primary)'
                }}>
                  <input
                    type="radio"
                    name="comment_permission"
                    value={opt}
                    checked={commentPermission === opt}
                    onChange={() => setCommentPermission(opt)}
                    style={{ accentColor: 'var(--flame)', width: '16px', height: '16px' }}
                  />
                  {opt === 'everyone' && 'Everyone'}
                  {opt === 'followers' && 'Followers only'}
                  {opt === 'no_one' && 'No one (disable comments)'}
                </label>
              ))}
            </div>
          </div>

          {/* ── ANONYMOUS POSTS NOTE ── */}
          <div style={sectionStyle}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '8px' }}>
              Anonymous posts
            </h2>
            <p style={{ fontSize: '14px', color: 'var(--text-secondary)', lineHeight: 1.6 }}>
              When you post, you can toggle "Post anonymously" in the composer. Those posts will never appear on your profile and your name won't be linked — even if you reveal your identity here.
            </p>
          </div>

          {/* ── SAVE ── */}
          {error && (
            <p style={{ color: '#E24B4A', fontSize: '14px', marginBottom: '16px' }}>{error}</p>
          )}
          {saved && (
            <p style={{ color: '#2A9D8F', fontSize: '14px', marginBottom: '16px' }}>✓ Changes saved</p>
          )}
          <button
            onClick={handleSave}
            disabled={saving}
            style={{
              width: '100%', padding: '14px', borderRadius: '100px',
              background: saving ? 'var(--border)' : 'var(--flame)',
              color: saving ? 'var(--text-muted)' : 'white',
              fontSize: '15px', fontWeight: 500, border: 'none',
              cursor: saving ? 'not-allowed' : 'pointer',
              fontFamily: 'var(--font-body)', marginBottom: '32px'
            }}
          >
            {saving ? 'Saving...' : 'Save changes'}
          </button>

          {/* ── CHANGE PASSWORD ── */}
          <div style={sectionStyle}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '8px' }}>
              Change password
            </h2>
            <p style={{ fontSize: '14px', color: 'var(--text-secondary)', marginBottom: '16px', lineHeight: 1.6 }}>
              Choose a new password for your account. Must be at least 8 characters.
            </p>
            <div style={{ marginBottom: '12px' }}>
              <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '6px', fontWeight: 500 }}>
                New password
              </label>
              <input
                type="password"
                value={newPassword}
                onChange={e => setNewPassword(e.target.value)}
                placeholder="New password"
                style={inputStyle}
              />
            </div>
            <div style={{ marginBottom: '14px' }}>
              <label style={{ display: 'block', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '6px', fontWeight: 500 }}>
                Confirm new password
              </label>
              <input
                type="password"
                value={confirmPassword}
                onChange={e => setConfirmPassword(e.target.value)}
                placeholder="Confirm password"
                style={inputStyle}
              />
            </div>
            {passwordError && <p style={{ color: '#E24B4A', fontSize: '13px', marginBottom: '10px' }}>{passwordError}</p>}
            {passwordMsg && <p style={{ color: '#2A9D8F', fontSize: '13px', marginBottom: '10px' }}>✓ {passwordMsg}</p>}
            <button
              onClick={handlePasswordChange}
              disabled={passwordSaving || !newPassword}
              style={{
                padding: '10px 24px', borderRadius: '100px',
                background: !newPassword ? 'var(--border)' : 'var(--flame)',
                color: !newPassword ? 'var(--text-muted)' : 'white',
                border: 'none', fontSize: '14px', cursor: !newPassword ? 'not-allowed' : 'pointer',
                fontFamily: 'var(--font-body)', fontWeight: 500
              }}
            >
              {passwordSaving ? 'Updating...' : 'Update password'}
            </button>
          </div>

          {/* ── SIGN OUT ── */}
          <div style={{ marginBottom: '32px', paddingBottom: '32px', borderBottom: '1px solid var(--border)' }}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '12px' }}>
              Sign out
            </h2>
            <button
              onClick={handleSignOut}
              style={{
                padding: '10px 24px', borderRadius: '100px',
                border: '1px solid var(--border)', background: 'transparent',
                color: 'var(--text-secondary)', fontSize: '14px',
                cursor: 'pointer', fontFamily: 'var(--font-body)'
              }}
            >
              Sign out of Ijwi
            </button>
          </div>

          {/* ── ABOUT ── */}
          <div style={{ marginBottom: '32px', paddingBottom: '32px', borderBottom: '1px solid var(--border)' }}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '16px' }}>
              About
            </h2>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>App version</span>
                <span style={{ fontSize: '14px', color: 'var(--text-muted)' }}>1.0.0</span>
              </div>
              <a href="/terms" style={{ fontSize: '14px', color: 'var(--flame)', textDecoration: 'none' }}>
                Terms of use →
              </a>
              <a href="/privacy" style={{ fontSize: '14px', color: 'var(--flame)', textDecoration: 'none' }}>
                Privacy policy →
              </a>
            </div>
            <div style={{
              marginTop: '20px', padding: '16px', borderRadius: '12px',
              background: 'var(--surface-2)', textAlign: 'center'
            }}>
              <p style={{ fontSize: '13px', color: 'var(--text-muted)', lineHeight: 1.7 }}>
                Built with love and faith in Rwanda 🇷🇼<br />
                <span style={{ fontFamily: 'var(--font-display)', fontStyle: 'italic', fontSize: '13px' }}>
                  "Your voice was made for this moment."
                </span>
              </p>
            </div>
          </div>

          {/* ── INVITE A BELIEVER ── */}
          <div>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '6px', color: 'var(--text-primary)' }}>
              Invite a Believer
            </h2>
            <p style={{ fontSize: '14px', color: 'var(--text-secondary)', lineHeight: 1.6, marginBottom: '16px' }}>
              Share Ijwi with someone whose faith story deserves to be heard. When they join using your link, you both get 30 days of Pro free.
            </p>
            <div className="card" style={{ padding: '16px 20px', marginBottom: '8px' }}>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '8px', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Your invite link</div>
              <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                <div style={{ flex: 1, padding: '10px 14px', borderRadius: '8px', background: 'var(--surface-2)', border: '1px solid var(--border)', fontSize: '13px', color: 'var(--text-secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', fontFamily: 'monospace' }}>
                  {typeof window !== 'undefined' ? `${window.location.origin}/auth/signup?ref=${profile.id.slice(0, 8)}` : `ijwi.app/auth/signup?ref=${profile.id.slice(0, 8)}`}
                </div>
                <button
                  onClick={() => {
                    const url = `${window.location.origin}/auth/signup?ref=${profile.id.slice(0, 8)}`
                    navigator.clipboard.writeText(url).then(() => {
                      const el = document.getElementById('copy-ref-btn')
                      if (el) { el.textContent = 'Copied!'; setTimeout(() => { if (el) el.textContent = 'Copy' }, 2000) }
                    })
                  }}
                  id="copy-ref-btn"
                  style={{ padding: '10px 18px', borderRadius: '8px', background: 'var(--flame)', color: 'white', border: 'none', fontSize: '13px', fontWeight: 600, cursor: 'pointer', fontFamily: 'var(--font-body)', flexShrink: 0 }}
                >
                  Copy
                </button>
              </div>
              <button
                onClick={() => {
                  const url = `${window.location.origin}/auth/signup?ref=${profile.id.slice(0, 8)}`
                  const text = `Join me on Ijwi — a Christian community where your faith story matters. Use my link and we both get Pro free: ${url}`
                  window.open(`https://wa.me/?text=${encodeURIComponent(text)}`, '_blank', 'noopener')
                }}
                style={{ marginTop: '10px', width: '100%', padding: '11px', borderRadius: '10px', background: '#25D366', color: 'white', border: 'none', fontSize: '14px', fontWeight: 600, cursor: 'pointer', fontFamily: 'var(--font-body)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="white"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z"/><path d="M12 0C5.373 0 0 5.373 0 12c0 2.104.545 4.083 1.5 5.813L0 24l6.335-1.484A11.945 11.945 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 21.818a9.818 9.818 0 01-5.013-1.375l-.36-.213-3.72.871.94-3.618-.234-.372A9.818 9.818 0 0112 2.182c5.42 0 9.818 4.398 9.818 9.818 0 5.421-4.398 9.818-9.818 9.818z"/></svg>
                Share on WhatsApp
              </button>
            </div>
          </div>

          {/* ── DELETE ACCOUNT ── */}
          <div>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', marginBottom: '8px', color: '#E24B4A' }}>
              Delete account
            </h2>
            <p style={{ fontSize: '14px', color: 'var(--text-secondary)', lineHeight: 1.6, marginBottom: '16px' }}>
              This removes all your posts, comments, and follows, and anonymizes your profile. This cannot be undone.
            </p>

            {!showDeleteConfirm ? (
              <button
                onClick={() => setShowDeleteConfirm(true)}
                style={{
                  padding: '10px 24px', borderRadius: '100px',
                  border: '1px solid #E24B4A', background: 'transparent',
                  color: '#E24B4A', fontSize: '14px',
                  cursor: 'pointer', fontFamily: 'var(--font-body)'
                }}
              >
                Delete my account
              </button>
            ) : (
              <div style={{
                padding: '20px', borderRadius: '12px',
                background: '#FFF5F5', border: '1px solid #FFCDD2'
              }}>
                <p style={{ fontSize: '14px', color: '#E24B4A', marginBottom: '12px', fontWeight: 500 }}>
                  Type your voice name to confirm: <strong>{profile.voice_name}</strong>
                </p>
                <input
                  type="text"
                  value={deleteInput}
                  onChange={e => setDeleteInput(e.target.value)}
                  placeholder={profile.voice_name}
                  style={{ ...inputStyle, marginBottom: '12px', borderColor: '#FFCDD2' }}
                />
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button
                    onClick={handleDeleteAccount}
                    disabled={deleteInput !== profile.voice_name || deleting}
                    style={{
                      padding: '10px 20px', borderRadius: '100px',
                      background: deleteInput === profile.voice_name ? '#E24B4A' : 'var(--border)',
                      color: deleteInput === profile.voice_name ? 'white' : 'var(--text-muted)',
                      border: 'none', fontSize: '14px',
                      cursor: deleteInput === profile.voice_name ? 'pointer' : 'not-allowed',
                      fontFamily: 'var(--font-body)'
                    }}
                  >
                    {deleting ? 'Deleting...' : 'Yes, delete everything'}
                  </button>
                  <button
                    onClick={() => { setShowDeleteConfirm(false); setDeleteInput('') }}
                    style={{
                      padding: '10px 20px', borderRadius: '100px',
                      border: '1px solid var(--border)', background: 'transparent',
                      color: 'var(--text-secondary)', fontSize: '14px',
                      cursor: 'pointer', fontFamily: 'var(--font-body)'
                    }}
                  >
                    Cancel
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  )
}
