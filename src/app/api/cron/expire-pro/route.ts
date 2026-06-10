import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

// Vercel Cron calls this daily — expires Pro for users whose pro_expires_at has passed
// Protected by CRON_SECRET to prevent unauthorized calls
export async function GET(req: NextRequest) {
  const authHeader = req.headers.get('authorization')
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const supabase = await createClient()

  const { data, error } = await supabase
    .from('profiles')
    .update({ is_pro: false })
    .eq('is_pro', true)
    .lt('pro_expires_at', new Date().toISOString())
    .select('id')

  if (error) {
    console.error('expire-pro cron error:', error)
    return NextResponse.json({ error: error.message }, { status: 500 })
  }

  console.log(`expire-pro: revoked ${data?.length ?? 0} Pro accounts`)
  return NextResponse.json({ expired: data?.length ?? 0 })
}
