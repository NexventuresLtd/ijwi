import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

const PAYPACK_URL = 'https://payments.paypack.rw/api'
const PLATFORM_CUT = 0.15   // 15% platform fee, 85% to creator

async function getPaypackToken(): Promise<string> {
  const res = await fetch(`${PAYPACK_URL}/auth/agents/authorize`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: process.env.PAYPACK_APP_ID,
      client_secret: process.env.PAYPACK_APP_SECRET,
    }),
  })
  if (!res.ok) throw new Error('Paypack auth failed')
  const data = await res.json()
  return data.access as string
}

function formatPhone(phone: string): string {
  const cleaned = phone.replace(/[\s\-()]/g, '')
  if (cleaned.startsWith('+250')) return cleaned.slice(1)
  if (cleaned.startsWith('250')) return cleaned
  if (cleaned.startsWith('0')) return `250${cleaned.slice(1)}`
  if (cleaned.startsWith('7')) return `250${cleaned}`
  return cleaned
}

export async function POST(req: NextRequest) {
  const appId = process.env.PAYPACK_APP_ID
  const appSecret = process.env.PAYPACK_APP_SECRET
  if (!appId || !appSecret) {
    return NextResponse.json({ error: 'Payment service not configured.' }, { status: 503 })
  }

  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const body = await req.json()
  const { post_id, to_user_id, amount, phone } = body

  if (!post_id || !to_user_id || !amount || !phone) {
    return NextResponse.json({ error: 'Missing required fields.' }, { status: 400 })
  }
  if (amount < 200 || amount > 50000) {
    return NextResponse.json({ error: 'Amount must be between 200 and 50,000 RWF.' }, { status: 400 })
  }
  if (user.id === to_user_id) {
    return NextResponse.json({ error: 'You cannot bless your own post.' }, { status: 400 })
  }

  const formattedPhone = formatPhone(phone)
  const ref = `bless_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`

  try {
    const token = await getPaypackToken()

    // Cashin from the blesser's phone
    const cashinRes = await fetch(`${PAYPACK_URL}/transactions/cashin`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        'X-Webhook-Mode': 'production',
      },
      body: JSON.stringify({
        amount,
        number: formattedPhone,
        environment: process.env.NODE_ENV === 'production' ? 'production' : 'sandbox',
      }),
    })

    if (!cashinRes.ok) {
      const err = await cashinRes.json().catch(() => ({}))
      return NextResponse.json({ error: err?.message ?? 'Payment initiation failed.' }, { status: 400 })
    }

    const cashinData = await cashinRes.json()

    // Record blessing as pending — webhook will confirm and pay out
    await supabase.from('blessings').insert({
      from_user_id: user.id,
      to_user_id,
      post_id,
      amount_rwf: amount,
      creator_amount_rwf: Math.floor(amount * (1 - PLATFORM_CUT)),
      platform_amount_rwf: Math.ceil(amount * PLATFORM_CUT),
      phone: formattedPhone,
      ref,
      paypack_ref: cashinData?.ref ?? null,
      status: 'pending',
    })

    return NextResponse.json({ success: true, message: 'Check your phone to approve the payment.' })
  } catch (err: any) {
    return NextResponse.json({ error: err.message ?? 'Unexpected error.' }, { status: 500 })
  }
}
