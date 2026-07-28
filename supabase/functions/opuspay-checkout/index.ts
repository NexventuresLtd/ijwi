import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const OPUSPAY_API_KEY = Deno.env.get("OPUSPAY_API_KEY")!;
const OPUSPAY_URL = "https://pay.opus.rw";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { phone, amount, merchant_reference } = await req.json();

    if (!phone || !amount || !merchant_reference) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), { 
        status: 400, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      });
    }

    const response = await fetch(`${OPUSPAY_URL}/api/v1/payments`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPUSPAY_API_KEY}`,
        "Idempotency-Key": merchant_reference,
      },
      body: JSON.stringify({
        amount,
        customer_phone: phone,
        merchant_reference,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      return new Response(JSON.stringify(data), { 
        status: response.status, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      });
    }

    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), { 
      status: 500, 
      headers: { ...corsHeaders, "Content-Type": "application/json" } 
    });
  }
});
