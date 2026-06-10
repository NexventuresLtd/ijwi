'use client'

import { useState } from 'react'
import Link from 'next/link'
import { Post, Profile } from '@/lib/types'
import Navbar from '@/components/layout/Navbar'
import PostCard from '@/components/post/PostCard'
import { CONTENT_TYPE_LABELS, AVATAR_PRESETS } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import ProBadge from '@/components/ui/ProBadge'
import ProfileAvatar from '@/components/ui/ProfileAvatar'
import VerificationBadge from '@/components/ui/VerificationBadge'
import BackButton from '@/components/ui/BackButton'

interface ProfilePageClientProps {
  profile: Profile
  posts: Post[]
  followerCount: number
  followingCount: number
  postCount: number
  totalFire: number
  isFollowing: boolean
  isOwnProfile: boolean
  currentUserId?: string
  currentUserProfile?: Profile | null
  isPro?: boolean
}

function MenuIcon({ name, color }: { name: string; color: string }) {
  const props = { width: 18, height: 18, viewBox: '0 0 24 24', fill: 'none', stroke: color, strokeWidth: 2, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const }
  switch (name) {
    case 'eye': return <svg {...props}><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>
    case 'pin': return <svg {...props}><path d="M12 17v5"/><path d="M9 11V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v7"/><path d="M5 17h14"/><path d="M7 11l-2 6h14l-2-6"/></svg>
    case 'pin-off': return <svg {...props}><path d="M12 17v5"/><path d="M5 17h14"/><path d="m3 3 18 18"/><path d="M15 4.5V4a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v3"/><path d="M7 11l-2 6h5"/></svg>
    case 'link': return <svg {...props}><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
    case 'share': return <svg {...props}><path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/><polyline points="16 6 12 2 8 6"/><line x1="12" x2="12" y1="2" y2="15"/></svg>
    case 'trash': return <svg {...props}><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg>
    default: return null
  }
}

export default function ProfilePageClient({
  profile,
  posts,
  followerCount,
  followingCount,
  postCount,
  totalFire,
  isFollowing: initialIsFollowing,
  isOwnProfile,
  currentUserId,
  currentUserProfile,
  isPro = false,
}: ProfilePageClientProps) {
  const [following, setFollowing] = useState(initialIsFollowing)
  const [followers, setFollowers] = useState(followerCount)
  const [loadingFollow, setLoadingFollow] = useState(false)
  const [activeTab, setActiveTab] = useState<'posts' | 'videos'>('posts')
  const [localPosts, setLocalPosts] = useState(posts)
  const [menuPost, setMenuPost] = useState<string | null>(null)
  const [copyDone, setCopyDone] = useState(false)
  // Inline edit profile
  const [showEdit, setShowEdit] = useState(false)
  const [editName, setEditName] = useState(profile.voice_name)
  const [editBio, setEditBio] = useState(profile.bio ?? '')
  const [editAvatar, setEditAvatar] = useState(profile.avatar_url ?? '')
  const [editSaving, setEditSaving] = useState(false)
  const [editSaved, setEditSaved] = useState(false)

  const supabase = createClient()

  const handleSaveEdit = async () => {
    if (!editName.trim()) return
    setEditSaving(true)
    await supabase.from('profiles').update({
      voice_name: editName.trim(),
      bio: editBio.trim() || null,
      avatar_url: editAvatar || null,
    }).eq('id', profile.id)
    setEditSaving(false)
    setEditSaved(true)
    setTimeout(() => { setEditSaved(false); setShowEdit(false); window.location.reload() }, 1200)
  }

  const handleDeletePost = async (postId: string) => {
    if (!currentUserId) return
    if (!confirm('Delete this post? This cannot be undone.')) return
    await supabase.from('posts').delete().match({ id: postId, author_id: currentUserId })
    setLocalPosts(prev => prev.filter(p => p.id !== postId))
    setMenuPost(null)
  }

  const handlePinPost = async (postId: string) => {
    if (!currentUserId) return
    const post = localPosts.find(p => p.id === postId)
    if (!post) return
    const nowPinned = !(post as any).is_pinned
    // Unpin all others first, then pin/unpin this one
    await supabase.from('posts').update({ is_pinned: false }).eq('author_id', currentUserId)
    if (nowPinned) await supabase.from('posts').update({ is_pinned: true }).eq('id', postId)
    setLocalPosts(prev => {
      const updated = prev.map(p => ({ ...p, is_pinned: p.id === postId ? nowPinned : false }))
      return nowPinned
        ? [updated.find(p => p.id === postId)!, ...updated.filter(p => p.id !== postId)]
        : updated
    })
    setMenuPost(null)
  }

  const handleCopyLink = (postId: string) => {
    const url = `${window.location.origin}/post/${postId}`
    navigator.clipboard.writeText(url).then(() => {
      setCopyDone(true)
      setTimeout(() => { setCopyDone(false); setMenuPost(null) }, 1500)
    })
  }

  const handleShare = async (postId: string, title: string) => {
    const url = `${window.location.origin}/post/${postId}`
    if (navigator.share) {
      await navigator.share({ title, url })
    } else {
      handleCopyLink(postId)
    }
    setMenuPost(null)
  }

  const displayName = profile.is_revealed && profile.real_name
    ? profile.real_name
    : profile.voice_name

  const memberSince = new Date(profile.created_at).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })

  const handleFollow = async () => {
    if (!currentUserId || isOwnProfile) return
    setLoadingFollow(true)

    if (following) {
      await supabase.from('follows').delete()
        .match({ follower_id: currentUserId, following_id: profile.id })
      setFollowing(false)
      setFollowers(f => Math.max(0, f - 1))
    } else {
      await supabase.from('follows').insert({
        follower_id: currentUserId,
        following_id: profile.id,
      })
      setFollowing(true)
      setFollowers(f => f + 1)
    }
    setLoadingFollow(false)
  }

  // Pinned posts float to top
  const sortedPosts = [...localPosts].sort((a, b) => ((b as any).is_pinned ? 1 : 0) - ((a as any).is_pinned ? 1 : 0))
  const textPosts = sortedPosts.filter(p => p.content_type !== 'short')
  const videoPosts = sortedPosts.filter(p => p.content_type === 'short')

  const menuPostData = localPosts.find(p => p.id === menuPost)
  const menuPostPinned = !!(menuPostData as any)?.is_pinned
  const menuItems = menuPost ? [
    { icon: 'eye', label: 'View post', color: 'var(--text-primary)', action: () => { window.location.href = `/post/${menuPost}` } },
    { icon: menuPostPinned ? 'pin-off' : 'pin', label: menuPostPinned ? 'Unpin post' : 'Pin to top', color: 'var(--text-primary)', action: () => handlePinPost(menuPost) },
    { icon: 'link', label: copyDone ? 'Copied!' : 'Copy link', color: copyDone ? '#27AE60' : 'var(--text-primary)', action: () => handleCopyLink(menuPost) },
    { icon: 'share', label: 'Share', color: 'var(--text-primary)', action: () => handleShare(menuPost, menuPostData?.title || menuPostData?.body?.slice(0, 60) || 'Post') },
    { icon: 'trash', label: 'Delete post', color: '#E24B4A', action: () => handleDeletePost(menuPost) },
  ] : []

  const TYPE_GRADIENTS: Record<string, string> = {
    story:        'linear-gradient(135deg, #2D1B69 0%, #11998e 100%)',
    devotional:   'linear-gradient(135deg, #1a1a2e 0%, #b8860b 100%)',
    spoken_word:  'linear-gradient(135deg, #200122 0%, #6f0000 100%)',
    prayer_request: 'linear-gradient(135deg, #0f2027 0%, #203a43 60%, #2c5364 100%)',
    question:     'linear-gradient(135deg, #1f1c2c 0%, #928DAB 100%)',
    encouragement:'linear-gradient(135deg, #134E5E 0%, #71B280 100%)',
    letter:       'linear-gradient(135deg, #16213e 0%, #533483 100%)',
    short:        'linear-gradient(135deg, #0f0c29 0%, #302b63 50%, #24243e 100%)',
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--warm-white)' }}>
      <Navbar profile={currentUserProfile} />

      <main className="profile-main">
        {/* Top bar */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
          <BackButton />
          {isOwnProfile && (
            <Link href="/settings" style={{
              display: 'flex', alignItems: 'center', gap: '6px', textDecoration: 'none',
              fontSize: '13px', color: 'var(--text-secondary)',
              padding: '6px 14px', borderRadius: '100px', border: '1px solid var(--border)',
              background: 'var(--surface)',
            }}>
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ flexShrink: 0 }}><path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/></svg> Settings
            </Link>
          )}
        </div>

        {/* Profile card */}
        <div className="card" style={{ padding: '24px', marginBottom: '4px' }}>
          {/* Top row: avatar + stats */}
          <div className="profile-header-row">
            <ProfileAvatar
              userId={profile.id}
              avatarUrl={profile.avatar_url}
              isRevealed={profile.is_revealed}
              size={80}
            />

            {/* Stats row — Instagram style */}
            <div className="profile-stats-row">
              {[
                { value: postCount, label: 'Voices' },
                { value: followers, label: 'Listening' },
                { value: followingCount, label: 'Following' },
              ].map(({ value, label }) => (
                <div key={label} style={{ textAlign: 'center' }}>
                  <div style={{ fontSize: '20px', fontWeight: 700, color: 'var(--text-primary)', fontFamily: 'var(--font-display)' }}>
                    {value}
                  </div>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{label}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Name + bio */}
          <div style={{ marginBottom: '14px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px', flexWrap: 'wrap' }}>
              <span style={{ fontFamily: 'var(--font-display)', fontSize: '20px', fontWeight: 700, color: 'var(--text-primary)' }}>
                {displayName}
              </span>
              {profile.is_verified && <VerificationBadge size={18} />}
              {profile.is_pro && <ProBadge />}
            </div>
            {profile.is_revealed && profile.real_name && profile.voice_name !== profile.real_name && (
              <div style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '4px' }}>@{profile.voice_name}</div>
            )}

            {/* Voice role + streak row */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '10px', flexWrap: 'wrap' }}>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: '5px', padding: '4px 12px', borderRadius: '100px', background: 'rgba(240,168,50,0.10)', border: '1px solid rgba(240,168,50,0.30)', fontSize: '12px', fontWeight: 700, color: 'var(--flame)' }}>
                {(profile.voice_role?.replace(/_/g, ' ') ?? 'voice').replace(/\b\w/g, c => c.toUpperCase())}
              </span>
              {(profile.streak ?? 0) > 0 && (
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '3px 10px', borderRadius: '100px', background: 'rgba(240,74,12,0.08)', border: '1px solid rgba(240,74,12,0.25)', fontSize: '12px', fontWeight: 700, color: 'var(--flame)' }}>
                  <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="var(--flame)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg> {profile.streak} day streak
                </span>
              )}
            </div>

            <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>Member since {memberSince}</div>
            {profile.bio && <p style={{ fontSize: '14px', color: 'var(--text-secondary)', lineHeight: 1.6 }}>{profile.bio}</p>}
            <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px', display: 'flex', alignItems: 'center', gap: 4 }}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--flame)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
              {totalFire} people touched
            </div>
          </div>

          {/* Action buttons */}
          <div style={{ display: 'flex', gap: '8px' }}>
            {isOwnProfile ? (
              <>
                <button
                  onClick={() => setShowEdit(e => !e)}
                  style={{
                    flex: 1, minHeight: 44, padding: '10px', borderRadius: '10px',
                    border: `1px solid ${showEdit ? 'var(--flame)' : 'var(--border)'}`,
                    color: showEdit ? 'var(--flame)' : 'var(--text-secondary)',
                    background: showEdit ? 'var(--flame-soft)' : 'transparent',
                    fontSize: '14px', fontFamily: 'var(--font-body)',
                    textAlign: 'center', fontWeight: 500, cursor: 'pointer',
                  }}
                >
                  {showEdit ? 'Cancel' : 'Edit profile'}
                </button>
                {!profile.is_pro && !profile.is_approved_poster && !(profile as any).is_admin && (
                  <Link href="/settings#subscription" style={{
                    flex: 1, minHeight: 44, padding: '10px', borderRadius: '10px',
                    background: 'linear-gradient(135deg, #FF6B2B 0%, #FFB830 100%)',
                    color: 'white', textDecoration: 'none', fontSize: '14px',
                    fontFamily: 'var(--font-body)', textAlign: 'center', fontWeight: 600,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}>
                    ✦ Go Pro
                  </Link>
                )}
              </>
            ) : currentUserId ? (
              <button
                onClick={handleFollow}
                disabled={loadingFollow}
                style={{
                  flex: 1, minHeight: 44, padding: '10px', borderRadius: '10px', fontSize: '14px',
                  fontFamily: 'var(--font-body)', cursor: loadingFollow ? 'wait' : 'pointer',
                  border: `1px solid ${following ? 'var(--border)' : 'var(--flame)'}`,
                  background: following ? 'transparent' : 'var(--flame)',
                  color: following ? 'var(--text-secondary)' : 'white',
                  fontWeight: 600, transition: 'all 0.15s',
                }}
              >
                {following ? 'Listening ✓' : 'Listen'}
              </button>
            ) : (
              <Link href="/auth/signup" style={{
                flex: 1, minHeight: 44, padding: '10px', borderRadius: '10px',
                background: 'var(--flame)', color: 'white',
                textDecoration: 'none', fontSize: '14px', fontFamily: 'var(--font-body)',
                textAlign: 'center', fontWeight: 600,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                Listen
              </Link>
            )}
          </div>
        </div>

        {/* Inline edit panel */}
        {showEdit && isOwnProfile && (
          <div className="card" style={{ padding: '20px', marginBottom: '16px' }}>
            <h3 style={{ fontFamily: 'var(--font-display)', fontSize: '16px', marginBottom: '16px', color: 'var(--text-primary)' }}>
              Edit your profile
            </h3>

            {/* Avatar picker */}
            <div style={{ marginBottom: '16px' }}>
              <label style={{ fontSize: '12px', color: 'var(--text-muted)', fontWeight: 600, display: 'block', marginBottom: '10px' }}>
                Profile picture
              </label>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: '8px' }}>
                {AVATAR_PRESETS.map(preset => (
                  <button
                    key={preset.id}
                    onClick={() => setEditAvatar(preset.id)}
                    style={{
                      padding: 0, border: 'none', background: 'none', cursor: 'pointer',
                      outline: editAvatar === preset.id ? '3px solid var(--flame)' : '3px solid transparent',
                      outlineOffset: '2px', borderRadius: '50%',
                    }}
                    title={preset.label}
                  >
                    <div style={{
                      width: 40, height: 40, borderRadius: '50%', background: preset.gradient,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                    }}>
                      <svg width={16} height={20} viewBox="0 0 24 30" fill="none">
                        <rect x="9.5" y="0" width="5" height="30" rx="2.5" fill="white" />
                        <rect x="0" y="8" width="24" height="5" rx="2.5" fill="white" />
                      </svg>
                    </div>
                  </button>
                ))}
              </div>
            </div>

            {/* Name */}
            <div style={{ marginBottom: '12px' }}>
              <label style={{ fontSize: '12px', color: 'var(--text-muted)', fontWeight: 600, display: 'block', marginBottom: '6px' }}>
                Voice name
              </label>
              <input
                type="text"
                value={editName}
                onChange={e => setEditName(e.target.value)}
                maxLength={40}
                style={{
                  width: '100%', padding: '11px 14px', borderRadius: '10px',
                  border: '1px solid var(--border)', fontSize: '15px',
                  fontFamily: 'var(--font-body)', background: 'var(--surface)',
                  color: 'var(--text-primary)', outline: 'none', boxSizing: 'border-box',
                }}
              />
            </div>

            {/* Bio */}
            <div style={{ marginBottom: '16px' }}>
              <label style={{ fontSize: '12px', color: 'var(--text-muted)', fontWeight: 600, display: 'block', marginBottom: '6px' }}>
                Bio
              </label>
              <textarea
                value={editBio}
                onChange={e => setEditBio(e.target.value)}
                maxLength={200}
                rows={3}
                placeholder="Share a little about your faith journey..."
                style={{
                  width: '100%', padding: '11px 14px', borderRadius: '10px',
                  border: '1px solid var(--border)', fontSize: '14px',
                  fontFamily: 'var(--font-body)', background: 'var(--surface)',
                  color: 'var(--text-primary)', outline: 'none', resize: 'none',
                  boxSizing: 'border-box', lineHeight: 1.6,
                }}
              />
            </div>

            {editSaved && <p style={{ fontSize: '13px', color: '#2A9D8F', marginBottom: '10px' }}>✓ Saved! Refreshing...</p>}

            <button
              onClick={handleSaveEdit}
              disabled={editSaving || !editName.trim()}
              style={{
                width: '100%', padding: '12px', borderRadius: '100px',
                background: editSaving ? 'var(--border)' : 'var(--flame)',
                color: editSaving ? 'var(--text-muted)' : 'white',
                border: 'none', fontSize: '14px', fontWeight: 600,
                cursor: editSaving ? 'not-allowed' : 'pointer',
                fontFamily: 'var(--font-body)',
              }}
            >
              {editSaving ? 'Saving...' : 'Save changes →'}
            </button>
          </div>
        )}

        {/* Tabs */}
        <div style={{ display: 'flex', borderBottom: '1px solid var(--border)', marginBottom: '16px' }}>
          {(['posts', 'videos'] as const).map(tab => (
            <button key={tab} onClick={() => setActiveTab(tab)} style={{
              flex: 1, padding: '14px', border: 'none', background: 'transparent',
              cursor: 'pointer', fontFamily: 'var(--font-body)', fontSize: '13px',
              fontWeight: activeTab === tab ? 700 : 400,
              color: activeTab === tab ? 'var(--text-primary)' : 'var(--text-muted)',
              borderBottom: `2px solid ${activeTab === tab ? 'var(--flame)' : 'transparent'}`,
              marginBottom: '-1px',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
              transition: 'color 0.15s',
            }}>
              {tab === 'posts' ? (
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke={activeTab === 'posts' ? 'var(--flame)' : 'currentColor'} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <rect width="18" height="18" x="3" y="3" rx="2"/>
                  <path d="M7 7h10"/><path d="M7 12h10"/><path d="M7 17h6"/>
                </svg>
              ) : (
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke={activeTab === 'videos' ? 'var(--flame)' : 'currentColor'} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="m22 8-6 4 6 4V8Z"/>
                  <rect width="14" height="12" x="2" y="6" rx="2" ry="2"/>
                </svg>
              )}
              {tab === 'posts' ? 'Posts' : 'Videos'}
              {(tab === 'posts' ? textPosts : videoPosts).length > 0 && (
                <span style={{ fontSize: '11px', background: 'var(--border)', borderRadius: 999, padding: '1px 7px', color: 'var(--text-muted)' }}>
                  {(tab === 'posts' ? textPosts : videoPosts).length}
                </span>
              )}
            </button>
          ))}
        </div>

        {/* ── POSTS TAB ── */}
        {activeTab === 'posts' && (
          textPosts.length === 0 ? (
            <div className="card" style={{ padding: '52px 24px', textAlign: 'center' }}>
              <div style={{ width: 56, height: 56, borderRadius: '50%', background: 'rgba(240,168,50,0.08)', border: '1px solid rgba(240,168,50,0.25)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 14px' }}>
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--flame)" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/>
                </svg>
              </div>
              <p style={{ fontFamily: 'var(--font-display)', fontSize: '18px', color: 'var(--text-secondary)', marginBottom: '8px' }}>
                {isOwnProfile ? 'No posts shared yet' : `${profile.voice_name} hasn't posted yet`}
              </p>
              {isOwnProfile && (
                <Link href="/feed" style={{ color: 'var(--flame)', textDecoration: 'none', fontSize: '14px' }}>
                  Share your first voice →
                </Link>
              )}
            </div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '2px', margin: '0 -16px' }}>
              {textPosts.map(post => {
                const isPinned = !!(post as any).is_pinned
                const gradient = TYPE_GRADIENTS[post.content_type] ?? TYPE_GRADIENTS.story
                return (
                  <div key={post.id} style={{ position: 'relative', aspectRatio: '1', overflow: 'hidden' }}>
                    <Link href={`/post/${post.id}`} style={{ textDecoration: 'none', display: 'block', height: '100%' }}>
                      <div
                        style={{ height: '100%', background: gradient, position: 'relative', overflow: 'hidden', transition: 'transform 0.2s' }}
                        onMouseEnter={e => { (e.currentTarget as HTMLElement).style.transform = 'scale(1.05)' }}
                        onMouseLeave={e => { (e.currentTarget as HTMLElement).style.transform = 'scale(1)' }}
                      >
                        {/* Gradient overlay */}
                        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(0,0,0,0.12) 0%, transparent 30%, rgba(0,0,0,0.7) 100%)' }} />
                        {/* Type badge */}
                        <div style={{ position: 'absolute', top: 7, left: 7, fontSize: '7px', fontWeight: 800, color: 'rgba(255,255,255,0.9)', textTransform: 'uppercase', letterSpacing: '0.08em', background: 'rgba(0,0,0,0.45)', borderRadius: 4, padding: '2px 5px', backdropFilter: 'blur(6px)' }}>
                          {CONTENT_TYPE_LABELS[post.content_type]}
                        </div>
                        {/* Pin & anon indicators */}
                        {isPinned && <span style={{ position: 'absolute', top: 6, right: isOwnProfile ? 30 : 6 }}><svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="var(--flame)" strokeWidth="2.5" strokeLinecap="round"><path d="M12 17v5"/><path d="M9 11V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v7"/><path d="M5 17h14"/><path d="M7 11l-2 6h14l-2-6"/></svg></span>}
                        {isOwnProfile && post.is_anonymous && (
                          <span style={{ position: 'absolute', bottom: 26, left: 6, fontSize: '7px', fontWeight: 700, color: 'rgba(255,255,255,0.7)', background: 'rgba(0,0,0,0.45)', borderRadius: 3, padding: '1px 5px', backdropFilter: 'blur(4px)' }}>anon</span>
                        )}
                        {/* Bottom: text + fire */}
                        <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, padding: '5px 7px 7px' }}>
                          <p style={{
                            color: 'rgba(255,255,255,0.95)', fontSize: '10px', lineHeight: 1.35,
                            margin: '0 0 3px', display: '-webkit-box',
                            WebkitLineClamp: 3, WebkitBoxOrient: 'vertical', overflow: 'hidden',
                            fontFamily: (post.content_type === 'letter' || post.content_type === 'spoken_word') ? 'var(--font-display)' : 'var(--font-body)',
                            fontStyle: post.content_type === 'spoken_word' ? 'italic' : 'normal',
                            textShadow: '0 1px 4px rgba(0,0,0,0.8)',
                          }}>
                            {post.title || post.body}
                          </p>
                          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                            <span style={{ fontSize: '8px', color: 'rgba(255,255,255,0.7)', display: 'flex', alignItems: 'center', gap: 2 }}>
                            <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="var(--flame)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
                            {post.reactions.fire}
                          </span>
                          </div>
                        </div>
                      </div>
                    </Link>
                    {isOwnProfile && (
                      <button
                        onClick={e => { e.preventDefault(); e.stopPropagation(); setMenuPost(post.id) }}
                        style={{
                          position: 'absolute', top: 5, right: 5, width: 22, height: 22,
                          borderRadius: '50%', background: 'rgba(0,0,0,0.6)',
                          border: '1px solid rgba(255,255,255,0.3)', color: 'white',
                          fontSize: '12px', cursor: 'pointer', padding: 0, lineHeight: 1,
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          backdropFilter: 'blur(6px)', zIndex: 2,
                        }}
                      >⋯</button>
                    )}
                  </div>
                )
              })}
            </div>
          )
        )}

        {/* ── VIDEOS TAB ── */}
        {activeTab === 'videos' && (
          videoPosts.length === 0 ? (
            <div className="card" style={{ padding: '52px 24px', textAlign: 'center' }}>
              <div style={{ width: 56, height: 56, borderRadius: '50%', background: 'rgba(240,168,50,0.08)', border: '1px solid rgba(240,168,50,0.25)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 14px' }}>
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--flame)" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                  <path d="m22 8-6 4 6 4V8Z"/>
                  <rect width="14" height="12" x="2" y="6" rx="2" ry="2"/>
                </svg>
              </div>
              <p style={{ fontFamily: 'var(--font-display)', fontSize: '18px', color: 'var(--text-secondary)', marginBottom: '8px' }}>
                {isOwnProfile ? 'No videos yet' : `${profile.voice_name} hasn't posted videos yet`}
              </p>
              {isOwnProfile && (
                <Link href="/sparks" style={{ color: 'var(--flame)', textDecoration: 'none', fontSize: '14px' }}>
                  Post your first spark →
                </Link>
              )}
            </div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '2px', margin: '0 -16px' }}>
              {videoPosts.map(post => {
                const isPinned = !!(post as any).is_pinned
                return (
                  <div key={post.id} style={{ position: 'relative', overflow: 'hidden' }}>
                    <Link href={`/post/${post.id}`} style={{ textDecoration: 'none', display: 'block' }}>
                      <div style={{
                        aspectRatio: '9/16', maxHeight: '220px', position: 'relative',
                        overflow: 'hidden', background: TYPE_GRADIENTS.short,
                        transition: 'transform 0.2s',
                      }}
                        onMouseEnter={e => { (e.currentTarget as HTMLElement).style.transform = 'scale(1.05)' }}
                        onMouseLeave={e => { (e.currentTarget as HTMLElement).style.transform = 'scale(1)' }}
                      >
                        {/* Actual video frame or thumbnail */}
                        {(post as any).video_thumbnail ? (
                          <img src={(post as any).video_thumbnail} alt="" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
                        ) : post.video_url ? (
                          <video
                            src={post.video_url} muted playsInline preload="metadata"
                            onLoadedMetadata={e => { const v = e.target as HTMLVideoElement; v.currentTime = 0.5 }}
                            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }}
                          />
                        ) : null}
                        {/* Gradient overlay */}
                        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(0,0,0,0.65) 0%, transparent 55%)' }} />
                        {/* Play button */}
                        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                          <div style={{
                            width: 34, height: 34, borderRadius: '50%',
                            background: 'rgba(255,255,255,0.18)', border: '1.5px solid rgba(255,255,255,0.8)',
                            backdropFilter: 'blur(8px)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                          }}>
                            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                              <polygon points="5 3 19 12 5 21 5 3"/>
                            </svg>
                          </div>
                        </div>
                        {/* Bottom info */}
                        <div style={{ position: 'absolute', bottom: 5, left: 6, right: 6, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                          {isPinned && <span style={{ display: 'inline-flex' }}><svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="var(--flame)" strokeWidth="2.5" strokeLinecap="round"><path d="M12 17v5"/><path d="M9 11V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v7"/><path d="M5 17h14"/><path d="M7 11l-2 6h14l-2-6"/></svg></span>}
                          <span style={{ fontSize: '8px', color: 'rgba(255,255,255,0.85)', marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 2 }}>
                            <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="var(--flame)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
                            {post.reactions.fire}
                          </span>
                        </div>
                      </div>
                    </Link>
                    {isOwnProfile && (
                      <button
                        onClick={e => { e.preventDefault(); e.stopPropagation(); setMenuPost(post.id) }}
                        style={{
                          position: 'absolute', top: 5, right: 5, width: 22, height: 22,
                          borderRadius: '50%', background: 'rgba(0,0,0,0.6)',
                          border: '1px solid rgba(255,255,255,0.3)', color: 'white',
                          fontSize: '12px', cursor: 'pointer', padding: 0, lineHeight: 1,
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          backdropFilter: 'blur(6px)', zIndex: 2,
                        }}
                      >⋯</button>
                    )}
                  </div>
                )
              })}
            </div>
          )
        )}
      </main>

      {/* ── Post options bottom sheet ── */}
      {menuPost && (
        <div
          onClick={() => setMenuPost(null)}
          style={{
            position: 'fixed', inset: 0, zIndex: 200,
            background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(12px)',
            display: 'flex', alignItems: 'flex-end', justifyContent: 'center',
          }}
        >
          <div
            onClick={e => e.stopPropagation()}
            style={{
              width: '100%', maxWidth: 500,
              background: 'var(--surface)',
              borderRadius: '28px 28px 0 0',
              boxShadow: '0 -16px 60px rgba(0,0,0,0.5)',
              overflow: 'hidden',
            }}
          >
            {/* Handle */}
            <div style={{ width: 40, height: 4, background: 'rgba(128,128,128,0.25)', borderRadius: 99, margin: '14px auto 0' }} />

            {/* Post preview with gradient */}
            {menuPostData && (
              <div style={{
                margin: '16px 14px 4px',
                borderRadius: 18,
                background: TYPE_GRADIENTS[menuPostData.content_type] ?? TYPE_GRADIENTS.story,
                padding: '14px 16px',
                position: 'relative', overflow: 'hidden',
              }}>
                <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(135deg, rgba(0,0,0,0.25) 0%, transparent 60%)' }} />
                <div style={{ position: 'relative' }}>
                  <div style={{ fontSize: '9px', fontWeight: 800, color: 'rgba(255,255,255,0.7)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 6 }}>
                    {CONTENT_TYPE_LABELS[menuPostData.content_type]}
                  </div>
                  <div style={{ fontSize: '14px', color: 'white', fontWeight: 600, lineHeight: 1.3, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', textShadow: '0 1px 3px rgba(0,0,0,0.4)' }}>
                    {menuPostData.title || menuPostData.body?.slice(0, 70)}
                  </div>
                </div>
              </div>
            )}

            {/* Menu items */}
            <div style={{ padding: '8px 8px 0' }}>
              {menuItems.slice(0, -1).map((item, i) => (
                <button key={i} onClick={item.action}
                  style={{
                    width: '100%', display: 'flex', alignItems: 'center', gap: 16,
                    padding: '15px 16px', border: 'none', background: 'none',
                    cursor: 'pointer', textAlign: 'left', borderRadius: 16,
                    transition: 'background 0.12s',
                  }}
                  onMouseEnter={e => (e.currentTarget.style.background = 'var(--surface-2)')}
                  onMouseLeave={e => (e.currentTarget.style.background = 'none')}
                >
                  <span style={{ width: 30, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <MenuIcon name={item.icon} color={item.color} />
                  </span>
                  <span style={{ fontSize: '15px', color: item.color, fontFamily: 'var(--font-body)', fontWeight: 500 }}>{item.label}</span>
                </button>
              ))}

              {/* Separator before delete */}
              <div style={{ height: 1, background: 'var(--border)', margin: '4px 4px' }} />

              {menuItems.slice(-1).map((item, i) => (
                <button key={i} onClick={item.action}
                  style={{
                    width: '100%', display: 'flex', alignItems: 'center', gap: 16,
                    padding: '15px 16px', border: 'none', background: 'none',
                    cursor: 'pointer', textAlign: 'left', borderRadius: 16,
                  }}
                >
                  <span style={{ width: 30, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <MenuIcon name={item.icon} color={item.color} />
                  </span>
                  <span style={{ fontSize: '15px', color: '#E24B4A', fontFamily: 'var(--font-body)', fontWeight: 500 }}>{item.label}</span>
                </button>
              ))}
            </div>

            {/* Cancel */}
            <div style={{ padding: '8px 14px 36px' }}>
              <button
                onClick={() => setMenuPost(null)}
                style={{
                  width: '100%', padding: '16px', borderRadius: 18,
                  border: '1px solid var(--border)', background: 'var(--surface-2)',
                  cursor: 'pointer', fontSize: '15px', color: 'var(--text-secondary)',
                  fontFamily: 'var(--font-body)', fontWeight: 500,
                }}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
