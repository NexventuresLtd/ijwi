import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
import { ContentType, UserLevel } from './types'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function timeAgo(dateString: string): string {
  const date = new Date(dateString)
  const now = new Date()
  const seconds = Math.floor((now.getTime() - date.getTime()) / 1000)

  if (seconds < 60) return 'just now'
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`
  if (seconds < 604800) return `${Math.floor(seconds / 86400)}d ago`
  return date.toLocaleDateString('en-RW', { month: 'short', day: 'numeric' })
}

export const CONTENT_TYPE_LABELS: Record<ContentType, string> = {
  story: 'Story',
  devotional: 'Devotional',
  spoken_word: 'Spoken Word',
  short: 'Short',
  prayer_request: 'Prayer',
  question: 'Question',
  encouragement: 'Encouragement',
  letter: 'Letter',
}

export const CONTENT_TYPE_COLORS: Record<ContentType, string> = {
  story: 'bg-amber-500/10 text-amber-600',
  devotional: 'bg-blue-500/10 text-blue-600',
  spoken_word: 'bg-purple-500/10 text-purple-600',
  short: 'bg-red-500/10 text-red-600',
  prayer_request: 'bg-teal-500/10 text-teal-600',
  question: 'bg-orange-500/10 text-orange-600',
  encouragement: 'bg-green-500/10 text-green-600',
  letter: 'bg-rose-500/10 text-rose-600',
}

export const LEVEL_XP: Record<UserLevel, number> = {
  seeker: 0,
  believer: 500,
  voice: 1500,
  flame: 3000,
  prophet: 6000,
  pillar: 12000,
}

export function generateFlamePattern(userId: string): string {
  // Generate a consistent HSL color from user ID
  let hash = 0
  for (let i = 0; i < userId.length; i++) {
    hash = userId.charCodeAt(i) + ((hash << 5) - hash)
  }
  const hue = Math.abs(hash % 360)
  return `hsl(${hue}, 70%, 55%)`
}

// Curated avatar presets — gradient + white cross, no uploads allowed
export const AVATAR_PRESETS = [
  { id: 'preset-1',  gradient: 'linear-gradient(135deg,#FF6B2B,#FFB830)', label: 'Amber Cross' },
  { id: 'preset-2',  gradient: 'linear-gradient(135deg,#3B82F6,#1D4ED8)', label: 'Blue Cross' },
  { id: 'preset-3',  gradient: 'linear-gradient(135deg,#8B5CF6,#5B21B6)', label: 'Purple Cross' },
  { id: 'preset-4',  gradient: 'linear-gradient(135deg,#10B981,#065F46)', label: 'Emerald Cross' },
  { id: 'preset-5',  gradient: 'linear-gradient(135deg,#F43F5E,#9F1239)', label: 'Rose Cross' },
  { id: 'preset-6',  gradient: 'linear-gradient(135deg,#F59E0B,#92400E)', label: 'Gold Cross' },
  { id: 'preset-7',  gradient: 'linear-gradient(135deg,#6366F1,#312E81)', label: 'Indigo Cross' },
  { id: 'preset-8',  gradient: 'linear-gradient(135deg,#14B8A6,#0F4C41)', label: 'Teal Cross' },
  { id: 'preset-9',  gradient: 'linear-gradient(135deg,#EC4899,#831843)', label: 'Pink Cross' },
  { id: 'preset-10', gradient: 'linear-gradient(135deg,#84CC16,#365314)', label: 'Lime Cross' },
  { id: 'preset-11', gradient: 'linear-gradient(135deg,#A78BFA,#1E1B4B)', label: 'Violet Cross' },
  { id: 'preset-12', gradient: 'linear-gradient(135deg,#0EA5E9,#075985)', label: 'Sky Cross' },
]

export function getAvatarPreset(avatarUrl?: string) {
  if (!avatarUrl?.startsWith('preset-')) return null
  return AVATAR_PRESETS.find(p => p.id === avatarUrl) ?? null
}

export const REACTIONS = [
  { type: 'amen' as const, icon: 'hand-helping', label: 'Amen' },
  { type: 'healed' as const, icon: 'heart', label: 'This healed me' },
  { type: 'needed' as const, icon: 'droplets', label: 'I needed this' },
  { type: 'sharing' as const, icon: 'bird', label: 'Sharing this' },
]

export const LEVEL_INFO: Record<string, { emoji: string; color: string; next: number; label: string }> = {
  seeker:    { emoji: '🌱', color: '#6B7280', next: 100,   label: 'Seeker' },
  believer:  { emoji: '🕊️', color: '#3B82F6', next: 300,   label: 'Believer' },
  voice:     { emoji: '🎤', color: '#8B5CF6', next: 700,   label: 'Voice' },
  flame:     { emoji: '🔥', color: '#F04A0C', next: 1500,  label: 'Flame' },
  prophet:   { emoji: '⚡', color: '#F59E0B', next: 3000,  label: 'Prophet' },
  pillar:    { emoji: '🏛️', color: '#D4860A', next: 99999, label: 'Pillar' },
}

const SCRIPTURE_MAP: { keywords: string[]; ref: string; text: string }[] = [
  { keywords: ['heal', 'healing', 'sick', 'pain', 'disease', 'cancer', 'hospital'],
    ref: 'Jeremiah 17:14', text: 'Heal me, Lord, and I will be healed; save me and I will be saved, for you are the one I praise.' },
  { keywords: ['fear', 'afraid', 'anxiety', 'anxious', 'worry', 'scared', 'panic'],
    ref: 'Isaiah 41:10', text: 'Do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you.' },
  { keywords: ['strength', 'weak', 'tired', 'weary', 'exhausted', 'burned out'],
    ref: 'Isaiah 40:31', text: 'Those who hope in the Lord will renew their strength. They will soar on wings like eagles.' },
  { keywords: ['peace', 'rest', 'calm', 'troubled', 'restless'],
    ref: 'John 14:27', text: 'Peace I leave with you; my peace I give you. Do not let your hearts be troubled and do not be afraid.' },
  { keywords: ['love', 'lonely', 'alone', 'unloved', 'rejected', 'abandoned'],
    ref: 'Romans 8:38-39', text: 'Nothing in all creation will be able to separate us from the love of God that is in Christ Jesus our Lord.' },
  { keywords: ['money', 'provision', 'provide', 'financial', 'bills', 'poor', 'debt', 'job'],
    ref: 'Philippians 4:19', text: 'My God will meet all your needs according to the riches of his glory in Christ Jesus.' },
  { keywords: ['prayer', 'pray', 'praying', 'intercede', 'intercession'],
    ref: 'Matthew 7:7', text: 'Ask and it will be given to you; seek and you will find; knock and the door will be opened to you.' },
  { keywords: ['purpose', 'plan', 'future', 'direction', 'confused', 'lost', 'calling'],
    ref: 'Jeremiah 29:11', text: 'For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you.' },
  { keywords: ['faith', 'doubt', 'believe', 'trust', 'uncertain'],
    ref: 'Hebrews 11:1', text: 'Now faith is confidence in what we hope for and assurance about what we do not see.' },
  { keywords: ['forgive', 'forgiveness', 'sin', 'mercy', 'grace', 'shame', 'guilt'],
    ref: '1 John 1:9', text: 'If we confess our sins, he is faithful and just and will forgive us our sins and purify us from all unrighteousness.' },
  { keywords: ['grateful', 'thankful', 'blessed', 'blessing', 'testimony', 'miracle'],
    ref: '1 Thessalonians 5:18', text: 'Give thanks in all circumstances; for this is God\'s will for you in Christ Jesus.' },
  { keywords: ['hope', 'hopeless', 'despair', 'darkness', 'depression', 'grief', 'loss'],
    ref: 'Romans 15:13', text: 'May the God of hope fill you with all joy and peace as you trust in him, so that you may overflow with hope.' },
  { keywords: ['courage', 'brave', 'bold', 'step', 'move', 'forward'],
    ref: 'Joshua 1:9', text: 'Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.' },
  { keywords: ['worship', 'praise', 'glory', 'magnify', 'exalt'],
    ref: 'Psalm 34:1', text: 'I will extol the Lord at all times; his praise will always be on my lips.' },
]

export function scriptureMatch(text: string): { ref: string; text: string } | null {
  if (!text || text.length < 20) return null
  const lower = text.toLowerCase()
  for (const entry of SCRIPTURE_MAP) {
    if (entry.keywords.some(kw => lower.includes(kw))) return entry
  }
  return null
}
