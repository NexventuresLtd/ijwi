import { NextRequest, NextResponse } from 'next/server'
import webpush from 'web-push'
import { createClient } from '@/lib/supabase/server'

// Accept either NEXT_PUBLIC_VAPID_KEY or VAPID_PUBLIC_KEY for the public key
const VAPID_PUBLIC = process.env.NEXT_PUBLIC_VAPID_KEY ?? process.env.VAPID_PUBLIC_KEY ?? ''
const VAPID_PRIVATE = process.env.VAPID_PRIVATE_KEY ?? ''
if (VAPID_PUBLIC && VAPID_PRIVATE) {
  webpush.setVapidDetails(
    `mailto:${process.env.VAPID_EMAIL ?? 'admin@ijwi.app'}`,
    VAPID_PUBLIC,
    VAPID_PRIVATE,
  )
}

export async function POST(req: NextRequest) {
  // Only allow server-to-server calls (verify a simple secret)
  const authHeader = req.headers.get('authorization')
  if (authHeader !== `Bearer ${process.env.PUSH_SECRET}`) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  if (!VAPID_PUBLIC || !VAPID_PRIVATE) {
    return NextResponse.json({ error: 'Push not configured' }, { status: 503 })
  }

  const { userId, title, body, url } = await req.json()
  const supabase = await createClient()

  const { data: subs } = await supabase
    .from('push_subscriptions')
    .select('endpoint, p256dh, auth')
    .eq('user_id', userId)

  const payload = JSON.stringify({ title, body, url: url ?? '/feed', tag: 'ijwi' })
  const results = await Promise.allSettled(
    (subs ?? []).map(sub =>
      webpush.sendNotification(
        { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
        payload,
      )
    )
  )

  const sent = results.filter(r => r.status === 'fulfilled').length
  return NextResponse.json({ sent })
}
