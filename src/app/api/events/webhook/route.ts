import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function POST(req: NextRequest) {
  try {
    const body = await req.json()
    const { ref, status } = body

    if (!ref) return NextResponse.json({ ok: true })

    const supabase = await createClient()

    if (status === 'successful' || status === 'success') {
      await supabase
        .from('event_tickets')
        .update({ status: 'paid' })
        .eq('paypack_ref', ref)
    } else if (status === 'failed') {
      await supabase
        .from('event_tickets')
        .update({ status: 'failed' })
        .eq('paypack_ref', ref)
    }

    return NextResponse.json({ ok: true })
  } catch {
    return NextResponse.json({ ok: true })
  }
}
