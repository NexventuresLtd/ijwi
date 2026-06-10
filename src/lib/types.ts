export type ContentType =
  | 'story'
  | 'devotional'
  | 'spoken_word'
  | 'short'
  | 'prayer_request'
  | 'question'
  | 'encouragement'
  | 'letter'

export type ReactionType = 'fire' | 'amen' | 'healed' | 'needed' | 'sharing'

export type UserLevel =
  | 'seeker'
  | 'believer'
  | 'voice'
  | 'flame'
  | 'prophet'
  | 'pillar'

export interface Profile {
  id: string
  voice_name: string
  is_revealed: boolean
  real_name?: string
  avatar_url?: string
  flame_pattern?: string
  level: UserLevel
  xp: number
  streak: number
  created_at: string
  bio?: string
  // Pro / paywall fields
  is_pro: boolean
  shorts_watched_today: number
  shorts_watch_date?: string
  ai_assists_used: number
  stripe_customer_id?: string
  pro_expires_at?: string
  // Voice role
  voice_role?: 'voice' | 'storyteller' | 'prayer_warrior' | 'worship_leader' | 'encourager' | 'community_builder' | 'content_creator' | 'helper'
  // Notification preferences
  notif_daily_verse?: boolean
  notif_prayer_response?: boolean
  notif_new_follower?: boolean
  notif_fire_reaction?: boolean
  notif_comment?: boolean
  notify_follows?: boolean
  notify_reactions?: boolean
  notify_comments?: boolean
  notify_prayers?: boolean
  notify_blessings?: boolean
  notify_dms?: boolean
  notify_echoes?: boolean
  // Privacy
  comment_permission?: 'everyone' | 'followers' | 'no_one'
  // Verified status
  is_verified?: boolean
  // Admin / moderation
  is_admin?: boolean
  is_banned?: boolean
  // Posting permissions
  is_approved_poster?: boolean
  // Community roles
  is_answerer?: boolean
  is_dm_listed?: boolean
  dm_title?: string
  dm_bio?: string
}

export interface Post {
  id: string
  author_id: string
  content_type: ContentType
  body: string
  title?: string
  is_anonymous: boolean
  verse_reference?: string
  verse_text?: string
  tags: string[]
  reactions: ReactionCounts
  comment_count: number
  prayer_count: number
  created_at: string
  updated_at: string
  author?: Profile
  // Media fields
  video_url?: string
  video_thumbnail?: string
  youtube_url?: string
  image_url?: string
  audio_url?: string
}

export interface ReactionCounts {
  fire: number
  amen: number
  healed: number
  needed: number
  sharing: number
}

export interface Comment {
  id: string
  post_id: string
  author_id: string
  body: string
  is_anonymous: boolean
  parent_id?: string
  reactions: { amen: number; fire: number }
  created_at: string
  author?: Profile
}

export interface UserReaction {
  post_id: string
  user_id: string
  reaction_type: ReactionType
}
