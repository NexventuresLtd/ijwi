import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

// Paypack sends a POST when payment status changes
// Payload: { ref, status: 'successful'|'failed', amount, number, kind: 'CASHIN' }
// Register webhook URL in Paypack as: https://ijwi-orpin.vercel.app/api/momo/webhook?secret=YOUR_SECRET
export async function POST(req: NextRequest) {
  // Verify the secret query param matches our env var
  const secret = req.nextUrl.searchParams.get('secret')
  const expectedSecret = process.env.PAYPACK_WEBHOOK_SECRET
  if (expectedSecret && secret !== expectedSecret) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  let payload: any
  try {
    payload = await req.json()
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 })
  }

  const { ref, status, kind } = payload
  if (!ref || kind !== 'CASHIN') return NextResponse.json({ ok: true })

  const supabase = await createClient()

  // Update payment record
  const { data: payment } = await supabase
    .from('payments')
    .update({ status })
    .eq('ref', ref)
    .select('user_id, amount')
    .single()

  if (!payment) return NextResponse.json({ ok: true })

  // Grant Pro on successful payment
  if (status === 'successful') {
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()
    await supabase
      .from('profiles')
      .update({ is_pro: true, pro_expires_at: expiresAt })
      .eq('id', payment.user_id)

    // Send confirmation email if user has one
    const { data: userData } = await supabase.auth.admin.getUserById(payment.user_id)
    const email = userData?.user?.email
    const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? 'https://ijwi-orpin.vercel.app'
    if (email && process.env.CRON_SECRET) {
      fetch(`${appUrl}/api/email`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${process.env.CRON_SECRET}`,
        },
        body: JSON.stringify({ type: 'pro_activated', to: email, data: {} }),
      }).catch(() => {})
    }
  }

  return NextResponse.json({ ok: true })
}
