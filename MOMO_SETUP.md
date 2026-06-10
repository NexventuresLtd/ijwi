# Mobile Money (Paypack) Setup Guide

Ijwi uses **Paypack** (not MTN MoMo directly) as the payment gateway.
Paypack handles MTN Rwanda and Airtel Rwanda in a single API.

## Current Integration

- **Provider**: Paypack (`https://payments.paypack.rw/api`)
- **Buckets touched**: `payments` table in Supabase
- **Endpoint**: `POST /api/momo/pay` → `POST /api/momo/bless`
- **Webhook**: `POST /api/momo/webhook` (Paypack calls this on status change)

## Environment Variables

Add to `.env.local` (and to Vercel → Project → Environment Variables):

```env
PAYPACK_APP_ID=your_paypack_app_id
PAYPACK_APP_SECRET=your_paypack_app_secret
```

## Going from Sandbox to Production

### Step 1 — Get a Paypack account
1. Sign up at https://paypack.rw
2. Create a merchant account (requires business registration in Rwanda)
3. Get your production `APP_ID` and `APP_SECRET` from the dashboard

### Step 2 — Update environment variables
Replace sandbox credentials with production credentials in:
- Vercel → Settings → Environment Variables
- Local `.env.local` (for local testing with real numbers)

### Step 3 — Configure webhook URL
In Paypack dashboard → Webhooks → Add URL:
```
https://your-domain.com/api/momo/webhook
```
This is called by Paypack when payment status changes (pending → successful/failed).

### Step 4 — Test with a real number
Once on production credentials, any valid MTN/Airtel Rwanda number will work.

## Why "number not found" error in dev?

Paypack sandbox only accepts specific **test numbers** registered in their sandbox environment.
Real customer numbers will fail in sandbox mode. This is expected.

The app now shows a friendly message:
> "This number is not registered for MoMo payments. Please use a valid MTN Rwanda number (07XXXXXXXX)."

And in development mode, a note clarifies this is a sandbox limitation.

## Paypack Callback / Webhook Flow

```
User enters phone → /api/momo/pay →
Paypack sends USSD to phone →
User approves →
Paypack calls /api/momo/webhook →
App sets is_pro = true on profile →
App sends confirmation email
```

## Rwanda MTN MoMo Numbers

Valid formats: `2507[2389]XXXXXXX` (10 digits after country code)
- MTN: `078XXXXXXX` or `079XXXXXXX`
- Airtel: `072XXXXXXX` or `073XXXXXXX`
