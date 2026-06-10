import { generateFlamePattern } from '@/lib/utils'
import { Profile } from '@/lib/types'

interface FlameAvatarProps {
  profile: Pick<Profile, 'id' | 'avatar_url' | 'is_revealed' | 'voice_name'>
  size?: number
}

export default function FlameAvatar({ profile, size = 38 }: FlameAvatarProps) {
  const showPhoto = profile.is_revealed && profile.avatar_url
  const bg = generateFlamePattern(profile.id)
  const fontSize = Math.round(size * 0.4)

  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        background: bg,
        flexShrink: 0,
        overflow: 'hidden',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {showPhoto ? (
        <img
          src={profile.avatar_url!}
          alt={profile.voice_name}
          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
        />
      ) : (
        <span style={{ fontSize }}></span>
      )}
    </div>
  )
}
