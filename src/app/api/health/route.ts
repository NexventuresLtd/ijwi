import { NextResponse } from 'next/server'

async function checkSupabaseResponse() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  if (!url || !anonKey) {
    return { responding: false, status: null }
  }

  try {
    const res = await fetch(`${url.replace(/\/$/, '')}/rest/v1/`, {
      method: 'GET',
      headers: {
        apikey: anonKey,
        authorization: `Bearer ${anonKey}`,
      },
      cache: 'no-store',
      signal: AbortSignal.timeout(3000),
    })

    return {
      responding: res.status < 500,
      status: res.status,
    }
  } catch {
    return { responding: false, status: null }
  }
}

export async function GET() {
  const supabaseConfigured = Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  )
  const paypackConfigured = Boolean(
    process.env.PAYPACK_APP_ID &&
    process.env.PAYPACK_APP_SECRET
  )
  const pushConfigured = Boolean(
    (process.env.NEXT_PUBLIC_VAPID_KEY || process.env.VAPID_PUBLIC_KEY) &&
    process.env.VAPID_PRIVATE_KEY
  )
  const supabase = await checkSupabaseResponse()

  return NextResponse.json({
    ok: true,
    service: 'ijwi',
    supabaseConfigured,
    supabaseResponding: supabase.responding,
    supabaseStatus: supabase.status,
    adminConfigured: Boolean(process.env.ADMIN_EMAILS || process.env.ADMIN_USER_IDS),
    paypackConfigured,
    paypackWebhookProtected: Boolean(process.env.PAYPACK_WEBHOOK_SECRET),
    emailConfigured: Boolean(process.env.RESEND_API_KEY),
    pushConfigured,
    cronProtected: Boolean(process.env.CRON_SECRET),
    appUrlConfigured: Boolean(process.env.NEXT_PUBLIC_APP_URL),
  })
}
