import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const OPUSPAY_WEBHOOK_SECRET = Deno.env.get("OPUSPAY_WEBHOOK_SECRET")!;
const OPUSPAY_API_KEY = Deno.env.get("OPUSPAY_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  // Only accept POST requests
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const signatureHeader = req.headers.get("x-opuspay-signature") || "";
    const deliveryId = req.headers.get("x-opuspay-delivery-id") || "";
    const rawBody = await req.text();

    // 1. Verify HMAC-SHA256 Signature
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(OPUSPAY_WEBHOOK_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    const signatureBytes = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
    const expectedSignature = "sha256=" + Array.from(new Uint8Array(signatureBytes))
      .map(b => b.toString(16).padStart(2, "0"))
      .join("");

    if (signatureHeader !== expectedSignature) {
      return new Response(JSON.stringify({ error: "Invalid signature" }), { status: 401 });
    }

    const event = JSON.parse(rawBody);
    
    // Initialize Supabase Admin Client (bypasses RLS to write system logs)
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 2. Check for Idempotency (Deduplication)
    const { data: existingEvent } = await supabase
      .from('opuspay_processed_events')
      .select('delivery_id')
      .eq('delivery_id', deliveryId)
      .single();

    if (existingEvent) {
      return new Response(JSON.stringify({ received: true, note: "Duplicate event skipped" }), { status: 200 });
    }

    // 3. Process Business Logic
    if (event.event === "payment.completed") {
      const merchantRef = event.data.merchant_reference || "";
      
      // Handle Event Ticket Purchases
      if (merchantRef.startsWith("ticket_")) {
        const bookingId = merchantRef.replace("ticket_", "");
        
        // 1. Check if it's already completed to prevent double decrement
        const { data: booking } = await supabase
          .from('event_bookings')
          .select('payment_status, tier_id, event_id')
          .eq('id', bookingId)
          .single();

        if (booking && booking.payment_status === 'pending') {
          // 2. Mark as completed
          const { error: updateError } = await supabase
            .from('event_bookings')
            .update({ 
              payment_status: 'completed', 
              payment_ref: event.data.payment_id 
            })
            .eq('id', bookingId);

          if (updateError) throw updateError;
          
          // 3. Decrement Capacity
          if (booking.tier_id) {
            const { data: tier } = await supabase.from('ticket_tiers').select('capacity').eq('id', booking.tier_id).single();
            if (tier && tier.capacity > 0) {
              await supabase.from('ticket_tiers').update({ capacity: tier.capacity - 1 }).eq('id', booking.tier_id);
            }
          } else if (booking.event_id) {
            const { data: ev } = await supabase.from('events').select('max_attendees').eq('id', booking.event_id).single();
            if (ev && ev.max_attendees > 0) {
              await supabase.from('events').update({ max_attendees: ev.max_attendees - 1 }).eq('id', booking.event_id);
            }
          }
        }
      }
      // Handle Event Amplifications (Promotions)
      else if (merchantRef.startsWith("amplify_")) {
        const eventId = merchantRef.replace("amplify_", "");
        
        // Example: amplify for 7 days
        const expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + 7);

        const { error: updateError } = await supabase
          .from('events')
          .update({ 
            is_promoted: true, 
            promotion_expires_at: expiresAt.toISOString() 
          })
          .eq('id', eventId);

        if (updateError) throw updateError;
      }
      else {
        console.warn(`Unknown merchant_reference format: ${merchantRef}`);
      }
    }

    // 4. Log Delivery ID to ensure it won't process again
    await supabase
      .from('opuspay_processed_events')
      .insert([{ delivery_id: deliveryId, payment_id: event.data.payment_id }]);

    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), { status: 500 });
  }
})
