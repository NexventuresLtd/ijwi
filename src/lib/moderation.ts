/**
 * Content moderation for Ijwi — a Christian community platform.
 * Ephesians 4:29: "Do not let any unwholesome talk come out of your mouths,
 * but only what is helpful for building others up."
 *
 * This filter catches obvious profanity and offensive language before
 * content is submitted. It is not exhaustive — community reporting
 * handles edge cases that pass through.
 */

const BLOCKED_WORDS = new Set([
  // Profanity
  'fuck', 'fck', 'fuuck', 'fuk', 'f u c k',
  'shit', 'sht', 'sh1t',
  'bitch', 'btch', 'b1tch',
  'ass', 'a55',
  'asshole', 'a**hole',
  'bastard',
  'cunt', 'c*nt',
  'cock', 'c0ck',
  'dick', 'd1ck',
  'pussy', 'p*ssy',
  'whore', 'wh0re',
  'slut', 'sl*t',
  'piss',
  'crap',
  'bullshit',
  'motherfucker',
  'mf',
  // Hate speech / slurs
  'nigga', 'nigger',
  'faggot', 'fag',
  'retard',
  'kike',
  'spic',
  // Sexual explicit
  'porn', 'porno', 'pornography',
  'sex', 'sexting', // note: 'sex' may have false positives in certain contexts
  'nude', 'nudes',
  // Common bypass patterns
  'wtf',
  'stfu',
  'gtfo',
  'af',     // as f***
])

// Words that are allowed even if they look like blocked words (biblical/theological use)
const ALLOW_LIST = new Set([
  'sexism', 'sexuality', 'sexual abuse', 'sexual assault', // for testimonies
])

function normalize(text: string): string {
  return text
    .toLowerCase()
    .replace(/\*/g, '')        // f*ck → fck
    .replace(/0/g, 'o')       // 0 → o
    .replace(/3/g, 'e')       // 3 → e
    .replace(/1/g, 'i')       // 1 → i
    .replace(/4/g, 'a')       // 4 → a
    .replace(/5/g, 's')       // 5 → s
    .replace(/[@]/g, 'a')     // @ → a
    .replace(/\$/g, 's')      // $ → s
    .replace(/\+/g, 't')      // + → t
    .replace(/[^a-z\s]/g, ' ') // strip remaining non-alpha
}

export function containsProfanity(text: string): { blocked: boolean; word?: string } {
  if (!text) return { blocked: false }

  const normalized = normalize(text)
  const words = normalized.split(/\s+/).filter(Boolean)

  for (const word of words) {
    if (BLOCKED_WORDS.has(word) && !ALLOW_LIST.has(word)) {
      return { blocked: true, word }
    }
  }

  return { blocked: false }
}

export const MODERATION_MESSAGE =
  'Your post contains language that isn\'t appropriate for this community. ' +
  'Ijwi is a space where every word builds up, not tears down. ' +
  'Please review your post. (Ephesians 4:29)'
