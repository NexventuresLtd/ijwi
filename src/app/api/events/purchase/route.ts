import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function POST(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Not authenticated' }, { status: 401 })

  const { event_id, phone } = await req.json()
  if (!event_id) return NextResponse.json({ error: 'event_id required' }, { status: 400 })

  const { data: event, error: eventErr } = await supabase
    .from('events')
    .select('id, title, ticket_price, ticket_currency, is_free, max_attendees')
    .eq('id', event_id)
    .single()

  if (eventErr || !event) return NextResponse.json({ error: 'Event not found' }, { status: 404 })

  // Check sold out
  if (event.max_attendees) {
    const { count } = await supabase
      .from('event_tickets')
      .select('*', { count: 'exact', head: true })
      .eq('event_id', event_id)
      .eq('status', 'paid')
    if ((count ?? 0) >= event.max_attendees) {
      return NextResponse.json({ error: 'Event is sold out' }, { status: 409 })
    }
  }

  // Check already registered
  const { data: existing } = await supabase
    .from('event_tickets')
    .select('id, status')
    .eq('event_id', event_id)
    .eq('user_id', user.id)
    .single()

  if (existing?.status === 'paid') {
    return NextResponse.json({ error: 'You already have a ticket' }, { status: 409 })
  }

  // Free event — register directly
  if (event.is_free) {
    if (existing) {
      await supabase.from('event_tickets').update({ status: 'paid' }).eq('id', existing.id)
    } else {
      await supabase.from('event_tickets').insert({
        event_id, user_id: user.id, status: 'paid',
        amount: 0, currency: 'RWF',
      })
    }
    return NextResponse.json({ success: true, free: true })
  }

  // Paid event — initiate Paypack payment
  if (!phone) return NextResponse.json({ error: 'phone required for paid events' }, { status: 400 })

  const appId = process.env.PAYPACK_APP_ID
  const appSecret = process.env.PAYPACK_APP_SECRET
  if (!appId || !appSecret) {
    return NextResponse.json({ error: 'Payment not configured' }, { status: 503 })
  }

  try {
    // Get Paypack access token
    const authRes = await fetch('https://payments.paypack.rw/api/auth/agents/authorize', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify({ client_id: appId, client_secret: appSecret }),
    })
    const authData = await authRes.json()
    if (!authRes.ok) throw new Error('Paypack auth failed')

    const amount = event.ticket_price ?? 0
    const ref = `ijwi-event-${event_id}-${user.id}-${Date.now()}`

    // Create pending ticket record
    const { data: ticket } = await supabase.from('event_tickets').upsert({
      event_id, user_id: user.id, status: 'pending',
      amount, currency: event.ticket_currency ?? 'RWF',
      paypack_ref: ref,
    }, { onConflict: 'event_id,user_id' }).select('id').single()

    // Initiate Paypack cashin
    const payRes = await fetch('https://payments.paypack.rw/api/cashin', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': `Bearer ${authData.access}`,
      },
      body: JSON.stringify({
        amount,
        number: phone,
        environment: process.env.NODE_ENV === 'production' ? 'production' : 'sandbox',
      }),
    })
    const payData = await payRes.json()
    if (!payRes.ok) {
      const msg = payData?.message?.toLowerCase() ?? ''
      if (msg.includes('not found') || msg.includes('account')) {
        throw new Error('Phone number not found on MoMo. Make sure you use a registered MTN or Airtel Rwanda number.')
      }
      throw new Error(payData?.message ?? 'Payment request failed')
    }

    return NextResponse.json({ success: true, ref: payData.ref })
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Payment request failed'
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
