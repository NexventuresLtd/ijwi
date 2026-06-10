import Image from 'next/image'

interface ProfileAvatarProps {
  userId: string
  avatarUrl?: string | null
  isRevealed?: boolean
  size?: number
  voiceName?: string
}

// Only brand-safe color pairs
const BRAND_PAIRS: [string, string][] = [
  ['#1e2a7a', '#c9860a'],  // indigo → gold
  ['#4a1a6e', '#b08090'],  // deep purple → mauve
  ['#0f3a5e', '#7b68ee'],  // navy → indigo
  ['#3a1a4e', '#f0a832'],  // deep plum → gold
  ['#1a2a4a', '#b08090'],  // deep navy → mauve
]

function getAvatarBackground(userId: string): string {
  const clean = (userId || 'aabbcc').replace(/-/g, '')
  const seed = parseInt(clean.slice(0, 6), 16) || 0
  const pair = BRAND_PAIRS[seed % 5]
  return `conic-gradient(from 160deg, ${pair[0]}, ${pair[1]})`
}

function getInitials(name?: string | null): string {
  if (!name || name.trim() === '') return '✦'
  const parts = name.trim().split(/\s+/)
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase()
  return name.slice(0, 2).toUpperCase()
}

export default function ProfileAvatar({
  userId,
  avatarUrl,
  isRevealed,
  size = 38,
  voiceName,
}: ProfileAvatarProps) {
  const fontSize = Math.max(10, Math.round(size * 0.38))

  if (isRevealed && avatarUrl && !avatarUrl.startsWith('preset-')) {
    return (
      <div style={{
        width: size, height: size, borderRadius: '50%',
        overflow: 'hidden', flexShrink: 0,
        border: '1px solid rgba(255,255,255,0.10)',
      }}>
        <Image src={avatarUrl} alt="" width={size} height={size}
          style={{ width: '100%', height: '100%', objectFit: 'cover' }} unoptimized />
      </div>
    )
  }

  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: getAvatarBackground(userId),
      border: '1px solid rgba(255,255,255,0.10)',
      flexShrink: 0,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      color: '#F5F0E8',
      fontFamily: 'DM Sans, sans-serif',
      fontWeight: 600,
      fontSize: fontSize,
      userSelect: 'none',
    }}>
      {getInitials(voiceName)}
    </div>
  )
}
