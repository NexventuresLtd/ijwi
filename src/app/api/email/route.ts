import { NextRequest, NextResponse } from 'next/server'

// Email notifications via Resend (resend.com — free tier: 3,000/month)
// Add RESEND_API_KEY to Vercel env vars to enable
// Called internally from comment/follow actions

interface EmailPayload {
  to: string
  subject: string
  html: string
}

async function sendEmail({ to, subject, html }: EmailPayload) {
  const apiKey = process.env.RESEND_API_KEY
  if (!apiKey) return // silently skip if not configured

  await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'Ijwi <notifications@ijwi.app>',
      to,
      subject,
      html,
    }),
  })
}

// Internal use only — secured by CRON_SECRET
export async function POST(req: NextRequest) {
  const auth = req.headers.get('authorization')
  if (auth !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  const { type, to, data } = await req.json()

  if (type === 'comment') {
    await sendEmail({
      to,
      subject: `${data.commenterName} replied to your post on Ijwi`,
      html: `
        <div style="font-family: Georgia, serif; max-width: 560px; margin: 0 auto; color: #1a1a1a;">
          <div style="background: #FF6B2B; padding: 24px; border-radius: 12px 12px 0 0; text-align: center;">
            <h1 style="color: white; font-size: 28px; margin: 0; font-weight: 400;">ijwi</h1>
          </div>
          <div style="padding: 32px; background: #fff; border: 1px solid #f0ebe5; border-top: none; border-radius: 0 0 12px 12px;">
            <p style="font-size: 16px; margin-bottom: 16px;">
              <strong>${data.commenterName}</strong> commented on your post:
            </p>
            <blockquote style="border-left: 3px solid #FF6B2B; padding: 12px 16px; margin: 0 0 24px; background: #fff8f5; border-radius: 0 8px 8px 0; color: #555; font-style: italic;">
              "${data.comment}"
            </blockquote>
            <a href="${process.env.NEXT_PUBLIC_APP_URL ?? 'https://ijwi-orpin.vercel.app'}/post/${data.postId}"
               style="display: inline-block; padding: 12px 28px; background: #FF6B2B; color: white; text-decoration: none; border-radius: 100px; font-weight: 600;">
              Read & reply →
            </a>
            <p style="font-size: 12px; color: #999; margin-top: 32px;">
              You received this because someone commented on your post.
              <a href="${process.env.NEXT_PUBLIC_APP_URL ?? 'https://ijwi-orpin.vercel.app'}/settings" style="color: #FF6B2B;">Manage notifications</a>
            </p>
          </div>
        </div>
      `,
    })
  }

  if (type === 'follow') {
    await sendEmail({
      to,
      subject: `${data.followerName} is now listening to your voice on Ijwi`,
      html: `
        <div style="font-family: Georgia, serif; max-width: 560px; margin: 0 auto; color: #1a1a1a;">
          <div style="background: #FF6B2B; padding: 24px; border-radius: 12px 12px 0 0; text-align: center;">
            <h1 style="color: white; font-size: 28px; margin: 0; font-weight: 400;">ijwi</h1>
          </div>
          <div style="padding: 32px; background: #fff; border: 1px solid #f0ebe5; border-top: none; border-radius: 0 0 12px 12px;">
            <p style="font-size: 16px; margin-bottom: 24px;">
              <strong>${data.followerName}</strong> is now listening to your voice. Your words are reaching further than you know.
            </p>
            <a href="${process.env.NEXT_PUBLIC_APP_URL ?? 'https://ijwi-orpin.vercel.app'}/profile/${data.followerId}"
               style="display: inline-block; padding: 12px 28px; background: #FF6B2B; color: white; text-decoration: none; border-radius: 100px; font-weight: 600;">
              View their profile →
            </a>
          </div>
        </div>
      `,
    })
  }

  if (type === 'pro_activated') {
    await sendEmail({
      to,
      subject: 'Your Ijwi Pro is active! 🔥',
      html: `
        <div style="font-family: Georgia, serif; max-width: 560px; margin: 0 auto; color: #1a1a1a;">
          <div style="background: #FF6B2B; padding: 24px; border-radius: 12px 12px 0 0; text-align: center;">
            <h1 style="color: white; font-size: 28px; margin: 0; font-weight: 400;">ijwi ✨ Pro</h1>
          </div>
          <div style="padding: 32px; background: #fff; border: 1px solid #f0ebe5; border-top: none; border-radius: 0 0 12px 12px;">
            <p style="font-size: 16px; margin-bottom: 8px;">Your payment of 2,000 RWF was received.</p>
            <p style="font-size: 16px; margin-bottom: 24px; color: #555;">
              You now have 30 days of full access — every story, letter, and long-form post. Thank you for supporting Ijwi.
            </p>
            <a href="${process.env.NEXT_PUBLIC_APP_URL ?? 'https://ijwi-orpin.vercel.app'}/feed"
               style="display: inline-block; padding: 12px 28px; background: #FF6B2B; color: white; text-decoration: none; border-radius: 100px; font-weight: 600;">
              Go read everything →
            </a>
          </div>
        </div>
      `,
    })
  }

  return NextResponse.json({ ok: true })
}
