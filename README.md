# Ijwi — Faith Community Platform

A full-stack faith community platform for African Christian youth. Share testimonies, prayers, devotionals, and spoken word, create events Built with Next.js (web), Flutter (mobile), and Supabase (backend).

---

## 🔐 Admin Credentials

| Field | Value |
|-------|-------|
| **Admin URL** | `/admin` |
| **Email** | `armandkayiranga7@gmail.com` |
| **Password** | *(set during Supabase auth signup)* |

Admins are determined by:
1. `ADMIN_EMAILS` env var (comma-separated)
2. `ADMIN_USER_IDS` env var (comma-separated Supabase user IDs)
3. `is_admin = true` flag in the `profiles` table

---

## 📁 Project Structure

```
ijwi/
├── src/                        # Next.js web application
│   ├── app/
│   │   ├── admin/              # Admin login + dashboard
│   │   │   ├── page.tsx        # Admin login page (/admin)
│   │   │   └── dashboard/      # Admin panel (/admin/dashboard)
│   │   ├── auth/               # Authentication (login, signup, forgot/reset password)
│   │   ├── feed/               # Home feed
│   │   ├── explore/            # Search & browse
│   │   ├── events/             # Events (list, detail, create, live room)
│   │   ├── dms/                # Direct messages (inbox, chat)
│   │   ├── notifications/      # Notifications
│   │   ├── profile/[id]/       # User profiles
│   │   ├── post/[id]/          # Post detail
│   │   ├── sparks/             # Short-form video content
│   │   ├── settings/           # User settings
│   │   ├── write/              # Post composer
│   │   └── api/                # API routes
│   │       ├── cron/           # Cron jobs (expire-pro)
│   │       ├── email/          # Email notifications (Resend)
│   │       ├── momo/           # Paypack MoMo (pay, webhook, bless)
│   │       ├── events/         # Event purchase + webhook
│   │       ├── push/           # Web push notifications
│   │       └── admin/          # Admin profile management
│   ├── components/             # Shared UI components
│   ├── lib/                    # Utilities, types, Supabase clients
│   └── globals.css             # Theme & global styles
├── mobile/                     # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart           # App entry point
│   │   ├── core/
│   │   │   ├── supabase.dart   # Supabase client config
│   │   │   ├── theme.dart      # Colors & typography (Fraunces + DM Sans)
│   │   │   ├── theme_notifier.dart # Dark/light mode toggle
│   │   │   └── router.dart     # GoRouter navigation
│   │   ├── shared/widgets/
│   │   │   ├── app_shell.dart  # Bottom nav + drawer + create menu
│   │   │   ├── splash_screen.dart
│   │   │   └── onboarding_screen.dart
│   │   └── features/
│   │       ├── auth/           # Login, signup, forgot password
│   │       ├── feed/           # Home feed with verse card, tabs, posts
│   │       ├── explore/        # Search people & posts
│   │       ├── events/         # Events list, detail, create, live room
│   │       ├── dms/            # Inbox, chat
│   │       ├── notifications/  # Notifications
│   │       ├── profile/        # User profile
│   │       ├── settings/       # App settings
│   │       └── write/          # Post composer
│   ├── assets/images/          # Logo & splash assets
│   ├── android/                # Android config
│   └── ios/                    # iOS config
├── supabase/                   # Database schema & migrations
├── public/                     # Static assets (icons, manifest, SW)
├── MIGRATIONS*.sql             # Database migration files
├── vercel.json                 # Vercel cron config
└── .env.local                  # Environment variables
```

---

## 🚀 Getting Started

### Prerequisites

- Node.js 18+
- Flutter 3.8+
- Supabase account (or local instance)

### Web Setup

```bash
cd ijwi
npm install
cp .env.example .env.local
# Fill in your Supabase credentials in .env.local
npm run dev
```

Open http://localhost:3000

### Mobile Setup

```bash
cd ijwi/mobile
flutter pub get
flutter run
```

The mobile app connects to the same Supabase backend (configured in `lib/core/supabase.dart`).

---

## 🔧 Environment Variables

| Variable | Description | Source |
|----------|-------------|--------|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase project URL | Supabase Dashboard → Settings → API |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase anon/public key | Supabase Dashboard → Settings → API |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role (server-only) | Supabase Dashboard → Settings → API |
| `NEXT_PUBLIC_APP_URL` | App URL (`http://localhost:3000`) | Your deployment |
| `ADMIN_EMAILS` | Comma-separated admin emails | You define |
| `ADMIN_USER_IDS` | Comma-separated admin Supabase user IDs | You define |
| `PAYPACK_APP_ID` | Paypack API client ID | [Paypack Dashboard](https://dashboard.paypack.rw) |
| `PAYPACK_APP_SECRET` | Paypack API secret | Paypack Dashboard |
| `PAYPACK_WEBHOOK_SECRET` | Webhook verification secret | You define, register at Paypack |
| `CRON_SECRET` | Protects cron API routes | Auto-generated (see .env.local) |
| `PUSH_SECRET` | Protects push notification routes | Auto-generated |
| `NEXT_PUBLIC_VAPID_KEY` | VAPID public key for web push | Auto-generated |
| `VAPID_PUBLIC_KEY` | Same as above (server alias) | Auto-generated |
| `VAPID_PRIVATE_KEY` | VAPID private key | Auto-generated |
| `VAPID_EMAIL` | Contact email for push service | Your email |
| `RESEND_API_KEY` | Email API key | [Resend Dashboard](https://resend.com/api-keys) |

---

## 🗄️ Database

### Setup

Run the SQL migration files in order against your Supabase project:

```bash
# In Supabase SQL editor, run:
MIGRATIONS.sql          # Base schema
MIGRATIONS_V2.sql       # through
MIGRATIONS_V9.sql       # Latest (live_messages table)
```

### Key Tables

| Table | Purpose |
|-------|---------|
| `profiles` | User profiles, roles, settings |
| `posts` | All content (stories, devotionals, spoken word, sparks) |
| `comments` | Post comments |
| `follows` | Follower/following relationships |
| `direct_messages` | Private DMs |
| `events` | Community events |
| `event_tickets` | Event registrations/payments |
| `live_messages` | Real-time live room chat |
| `notifications` | User notifications |
| `payments` | MoMo payment records |
| `push_subscriptions` | Web push endpoints |
| `reports` | Content moderation reports |

---

## 👤 Admin Dashboard

### Access
1. Navigate to `/admin`
2. Login with an admin email (listed in `ADMIN_EMAILS` env var)
3. Redirects to `/admin/dashboard`

### Features
- **Overview** — Platform stats at a glance (users, posts, reports, revenue)
- **Reports** — Review flagged content, delete posts, dismiss reports
- **Payments** — MoMo transaction tracking, manual Pro grants
- **Posts** — Moderate all content, delete violations
- **Users** — Manage roles:
  - *Approved Poster* — can publish content
  - *Answerer* — can answer in Questions tab
  - *Helper* — listed in DMs helper directory
  - *Ban/Unban* — restrict access
- **Events** — View and manage community events

---

## 📱 Mobile App Features

| Feature | Description |
|---------|-------------|
| Onboarding | 3-step welcome flow (first launch only) |
| Splash screen | Animated logo + tagline |
| Feed | Verse of the day, scrollable tabs (For You, Voices, Questions, Sparks) |
| Reactions | 🙏 ❤️ 💧 🕊️ on posts (functional, persisted) |
| Explore | Search people + posts, browse topics + types |
| Events | LinkedIn-inspired cards, search, filter, host + amplify |
| DMs | Instagram-inspired inbox, real-time chat |
| Notifications | Categorized with colored icons |
| Profile | Stats, posts, follow/unfollow |
| Create | Voice (post), Question, Spark (camera/gallery) |
| Settings | Edit profile, dark mode toggle, sign out |
| Sidebar | Full navigation drawer with all settings |
| Bottom nav | Frosted glass pill with blur effect |
| Theme | Light/dark mode with persistent toggle |

---

## 🌐 Web Features

All mobile features plus:
- Server-side rendering (SEO)
- Paywall/Pro content
- MoMo payments for Pro subscription
- Event ticket purchases via MoMo
- Ijwi Live (in-app event chat rooms)
- Web push notifications
- Email notifications (Resend)
- Forgot/reset password flow
- Admin dashboard

---

## 💰 Monetization

| Feature | Price | Method |
|---------|-------|--------|
| Ijwi Pro | 2,000 RWF/month | Paypack MoMo |
| Event tickets | Set by organizer | Paypack MoMo |
| Amplify (event promotion) | 2,000–8,000 RWF | Paypack MoMo |

---

## 🚢 Deployment

### Web (Vercel)
```bash
vercel deploy
```
Set all env vars in Vercel dashboard. Cron job runs daily at 3AM (expire Pro).

### Mobile
```bash
cd mobile
flutter build apk --release          # Android
flutter build ios --release          # iOS
```

---

## 📄 License

Private — Nexventures © 2024
