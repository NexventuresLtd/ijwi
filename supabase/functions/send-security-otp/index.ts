import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
// import { Resend } from 'https://esm.sh/resend'

// const resend = new Resend(Deno.env.get('RESEND_API_KEY'))

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')!
    if (!authHeader) {
      throw new Error('No authorization header')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    // Get the user from the auth token
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) throw userError

    // Generate a 4-digit OTP
    const otp = Math.floor(1000 + Math.random() * 9000).toString()
    
    // Hash the OTP (simple SHA256 using Web Crypto API)
    const encoder = new TextEncoder()
    const data = encoder.encode(otp)
    const hashBuffer = await crypto.subtle.digest('SHA-256', data)
    const hashArray = Array.from(new Uint8Array(hashBuffer))
    const otpHash = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')

    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString()

    // Update profile
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { error: updateError } = await supabaseAdmin
      .from('profiles')
      .update({
        security_otp_code: otpHash,
        security_otp_expires_at: expiresAt
      })
      .eq('id', user.id)

    if (updateError) throw updateError

    console.log(`[DEV] Generated OTP for user ${user.id}: ${otp}`)

    // TODO: Send email using Resend
    /*
    await resend.emails.send({
      from: 'Ijwi Security <security@ijwi.app>',
      to: [user.email],
      subject: 'Your Security Reset PIN',
      text: `Your security reset PIN is: ${otp}. It expires in 15 minutes.`,
    })
    */

    return new Response(
      JSON.stringify({ success: true, message: 'OTP generated and sent (check logs in dev)' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
