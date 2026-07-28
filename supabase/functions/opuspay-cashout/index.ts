import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const OPUSPAY_API_KEY = Deno.env.get("OPUSPAY_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Authenticate the User using JWT
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    const token = authHeader.replace('Bearer ', '');
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const userId = user.id;

    // 2. Parse Request Body
    const body = await req.json();
    const { amount, recipient_number } = body;
    
    if (!amount || amount <= 0 || !recipient_number) {
      return new Response(JSON.stringify({ error: "Invalid amount or recipient number" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    
    const requestedAmount = parseFloat(amount);

    // 3. Calculate Available Balance
    // Sum of successful ticket sales for their events
    const { data: events, error: eventsError } = await supabase
      .from('events')
      .select('id')
      .eq('organizer_id', userId);
      
    if (eventsError) throw eventsError;
    
    let totalGrossSales = 0;
    if (events && events.length > 0) {
      const eventIds = events.map(e => e.id);
      
      const { data: bookings, error: bookingsError } = await supabase
        .from('event_bookings')
        .select(`
          tier_id,
          events ( ticket_price ),
          ticket_tiers ( price )
        `)
        .in('event_id', eventIds)
        .eq('payment_status', 'completed');
        
      if (bookingsError) throw bookingsError;
      
      if (bookings) {
        for (const booking of bookings) {
          const price = booking.tier_id && booking.ticket_tiers 
            ? booking.ticket_tiers.price 
            : (booking.events ? booking.events.ticket_price : 0);
          totalGrossSales += (price || 0);
        }
      }
    }

    const netEarnings = Math.floor(totalGrossSales * 0.94); // Deduct 4% OpusPay + 2% Ijwi

    // Sum of successful/pending payouts
    const { data: pastPayouts, error: payoutsError } = await supabase
      .from('organizer_payouts')
      .select('amount')
      .eq('user_id', userId)
      .in('status', ['pending', 'completed']);
      
    if (payoutsError) throw payoutsError;
    
    let totalCashedOut = 0;
    if (pastPayouts) {
      for (const p of pastPayouts) {
        totalCashedOut += parseFloat(p.amount);
      }
    }
    
    const availableBalance = netEarnings - totalCashedOut;
    
    if (requestedAmount > availableBalance) {
      return new Response(JSON.stringify({ 
        error: "Insufficient balance", 
        available: availableBalance, 
        requested: requestedAmount 
      }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // 4. Create Pending Payout Record
    const { data: payoutRecord, error: insertError } = await supabase
      .from('organizer_payouts')
      .insert([{
        user_id: userId,
        amount: requestedAmount,
        recipient_number: recipient_number,
        status: 'pending'
      }])
      .select()
      .single();
      
    if (insertError) throw insertError;
    
    const payoutId = payoutRecord.id;

    // 5. Trigger OpusPay API
    let opusStatus = 'pending';
    let errorMessage = null;
    
    try {
      const payoutRes = await fetch("https://pay.opus.rw/api/v1/payouts", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${OPUSPAY_API_KEY}`,
          "Idempotency-Key": `payout_${payoutId}` 
        },
        body: JSON.stringify({
          amount: requestedAmount,
          recipient_phone: recipient_number,
          note: `Manual Cashout ID: ${payoutId}`
        })
      });
      
      if (payoutRes.ok) {
        opusStatus = 'completed';
      } else {
        opusStatus = 'failed';
        const errBody = await payoutRes.text();
        errorMessage = `OpusPay Error: ${payoutRes.status} ${errBody}`;
      }
    } catch (payoutErr) {
      opusStatus = 'failed';
      errorMessage = `Network Error: ${(payoutErr as Error).message}`;
    }
    
    // 6. Update Payout Record
    await supabase
      .from('organizer_payouts')
      .update({
        status: opusStatus,
        error_message: errorMessage
      })
      .eq('id', payoutId);
      
    if (opusStatus === 'failed') {
      return new Response(JSON.stringify({ 
        error: "Payout processing failed", 
        details: errorMessage 
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ 
      success: true, 
      message: "Payout successful",
      amount: requestedAmount,
      recipient: recipient_number
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
})
