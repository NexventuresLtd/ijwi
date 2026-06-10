import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

const PAYPACK_URL = 'https://payments.paypack.rw/api'
const AMOUNT_RWF = 2000

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
  // Strip spaces, dashes, parentheses
  const cleaned = phone.replace(/[\s\-()]/g, '')
  if (cleaned.startsWith('+250')) return cleaned.slice(1)      // +2507X → 2507X
  if (cleaned.startsWith('250')) return cleaned                 // already formatted
  if (cleaned.startsWith('0')) return `250${cleaned.slice(1)}` // 07X → 2507X
  if (cleaned.startsWith('7')) return `250${cleaned}`          // 7X → 2507X
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

  // Check if already pro
  const { data: profile } = await supabase
    .from('profiles')
    .select('is_pro, voice_name')
    .eq('id', user.id)
    .single()

  if (profile?.is_pro) {
    return NextResponse.json({ error: 'You are already on Pro.' }, { status: 400 })
  }

  const body = await req.json()
  const rawPhone = (body.phone ?? '').trim()
  if (!rawPhone) return NextResponse.json({ error: 'Phone number is required.' }, { status: 400 })

  const phone = formatPhone(rawPhone)
  // Rwanda numbers: 2507[2389]XXXXXXX (10 digits after 250)
  if (!/^2507[2389]\d{7}$/.test(phone)) {
    return NextResponse.json({
      error: 'Enter a valid Rwanda mobile number (MTN: 078/079, Airtel: 072/073).'
    }, { status: 400 })
  }

  try {
    const token = await getPaypackToken()

    // Initiate cashin (collect payment from customer)
    const cashinRes = await fetch(`${PAYPACK_URL}/transactions/cashin`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/json',
      },
      body: JSON.stringify({ amount: AMOUNT_RWF, number: phone }),
    })

    const cashinData = await cashinRes.json()
    if (!cashinRes.ok) {
      const rawMsg: string = cashinData?.message ?? ''
      let friendlyError = 'Payment initiation failed. Try again.'
      if (rawMsg.toLowerCase().includes('not found') || rawMsg.toLowerCase().includes('payer')) {
        friendlyError = 'This number is not registered for MoMo payments. Please use a valid MTN Rwanda number (078/079) or Airtel (072/073).'
      } else if (rawMsg.toLowerCase().includes('insufficient')) {
        friendlyError = 'Insufficient balance on that number. Please top up and try again.'
      } else if (rawMsg.toLowerCase().includes('timeout') || rawMsg.toLowerCase().includes('limit')) {
        friendlyError = 'Transaction limit reached or timed out. Try again in a few minutes.'
      } else if (rawMsg) {
        friendlyError = rawMsg
      }
      return NextResponse.json({ error: friendlyError }, { status: 400 })
    }

    const ref = cashinData.ref as string

    // Save pending payment record
    await supabase.from('payments').insert({
      user_id: user.id,
      phone,
      amount: AMOUNT_RWF,
      currency: 'RWF',
      ref,
      status: 'pending',
    })

    return NextResponse.json({
      success: true,
      ref,
      message: 'Payment prompt sent to your phone. Approve it to activate Pro.',
    })
  } catch (err) {
    console.error('MoMo pay error:', err)
    return NextResponse.json({ error: 'Payment service unavailable.' }, { status: 503 })
  }
}
