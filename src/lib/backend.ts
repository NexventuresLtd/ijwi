export const BACKEND_UNAVAILABLE_MESSAGE =
  'The Ijwi backend is not available right now. The public frontend is still online, but live posts, accounts, payments, messages, and notifications need Supabase to respond.'

export class BackendUnavailableError extends Error {
  constructor(message = BACKEND_UNAVAILABLE_MESSAGE) {
    super(message)
    this.name = 'BackendUnavailableError'
  }
}

export function isSupabaseConfigured() {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  )
}

export function assertSupabaseConfigured() {
  if (!isSupabaseConfigured()) {
    throw new BackendUnavailableError(
      'Supabase is not configured. Add NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY to the env file, then restart the app.'
    )
  }
}

export function assertSupabaseAdminConfigured() {
  assertSupabaseConfigured()
  if (!process.env.SUPABASE_SERVICE_ROLE_KEY) {
    throw new BackendUnavailableError(
      'Supabase admin access is not configured. Add SUPABASE_SERVICE_ROLE_KEY to enable admin backend actions.'
    )
  }
}
