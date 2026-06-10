# Ijwi Launch Checklist

## Fixed in code (no action needed)
- [x] Light mode is now the default theme (dark mode still available via toggle)
- [x] ProfileAvatar "?" fallback replaced with "✦" symbol
- [x] ProfileAvatar receives voiceName in Settings page
- [x] Role card descriptions no longer clipped (natural height, text wraps)
- [x] MoMo "number not found" shows friendly user-facing message
- [x] Dev-only sandbox note in MoMo payment form
- [x] "seeker" label removed from DMs helper directory → shows voice_role
- [x] Desktop layout uses .ij-page-container (max-width 1280px) across all pages
- [x] Explore page has two-column layout on desktop with sidebar
- [x] Storage upload errors surface real error messages (RLS, bucket not found, etc.)
- [x] PWA manifest: start_url → /feed, theme_color → #F0A832, background_color → #F4F1EC
- [x] PageProgress gold bar on every route change
- [x] PushPrompt appears after 30s, dismisses for session
- [x] Root / now redirects to /feed (landing page moved to /about)
- [x] IjwiLogo updated to simplified SVG with mauve→gold gradient
- [x] VerificationBadge component created (gold star badge for verified voices)
- [x] Navbar: Events link added, Write button added
- [x] Mobile bottom nav: Events tab replaces Sparks tab
- [x] Events system: /events, /events/[id], /events/create, purchase API, webhook
- [x] Essay editor: /write page with Tiptap editor, cover image, background music upload
- [x] EssayMusicPlayer floating pill on essay reading pages
- [x] PostCard: Substack-style with serif title, thumbnail-right for editorial posts
- [x] Sparks: "Uri Umugisha" splash screen between every 3rd video
- [x] Sparks: Ijwi watermark overlay on videos
- [x] OnboardingModal: removed XP/levels reference

---

## You must do manually

### Database (Supabase SQL Editor)
Run migrations in order from MIGRATIONS.md:
- [ ] Migration 1: `ALTER TABLE profiles ADD COLUMN IF NOT EXISTS voice_role text DEFAULT 'voice'`
- [ ] Migration 2: Notification preference columns (7 boolean columns)
- [ ] Migration 3: `ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_verified boolean DEFAULT false`
- [ ] Migration 4: `ALTER TABLE posts ADD COLUMN IF NOT EXISTS audio_url text`
- [ ] Migration 5: Create `events` table with RLS policies
- [ ] Migration 6: Create `event_tickets` table with RLS policies

### Storage bucket policies (Supabase Dashboard → Storage)
For each bucket (`images`, `voices`, `shorts`):
- [ ] Add INSERT policy: authenticated users
- [ ] Add SELECT policy: public

Or run Migration 7 from MIGRATIONS.md in SQL Editor.

### Domain
- [ ] Buy domain: `ijwi.app` or `ijwi.africa` (recommended)
- [ ] Connect to Vercel: Project → Settings → Domains → Add
- [ ] Update `MOMO_CALLBACK_URL` env var to new domain once live

### Mobile Money (Paypack)
- [ ] Sign up at https://paypack.rw with business registration
- [ ] Get production `PAYPACK_APP_ID` and `PAYPACK_APP_SECRET`
- [ ] Add to Vercel environment variables
- [ ] Configure webhook URL in Paypack dashboard:
  - MoMo blessings: `https://your-domain.com/api/momo/webhook`
  - Event tickets: `https://your-domain.com/api/events/webhook`

### Privacy Policy (REQUIRED for both app stores)
- [ ] Verify `/privacy` page covers all required points:
  1. What data you collect (email, voice name, posts, messages)
  2. How you use it (to provide the service — not sold)
  3. How users delete their account and data
  4. Contact email for privacy questions
  5. That DMs are end-to-end encrypted
  6. Rwanda Law No. 058/2021 compliance

---

## Google Play Store

### Requirements audit
| Item | Status |
|------|--------|
| PWA manifest.json with 192px + 512px icons | READY — PNG icons in /public/icons/ |
| HTTPS on custom domain | MISSING — need custom domain first |
| Service worker registered | READY — SWRegister component exists |
| App works offline / shows offline message | MISSING — no offline page yet |
| Privacy policy URL accessible | PARTIAL — check /privacy page exists |
| App content appropriate | READY |
| Screenshots (phone + tablet) | MISSING |
| App description written | MISSING |

### Steps to publish on Play Store
1. Run `node scripts/generate-icons.mjs` to regenerate PNG icons if SVG changed
2. Register Google Play Console ($25 one-time) at https://play.google.com/console
3. Use PWABuilder (https://pwabuilder.com) to package as a TWA (Trusted Web Activity)
4. Upload screenshots: phone (360×800) and tablet (1024×768) minimum
5. Fill in store listing: title, description, category (Social), content rating
6. Submit for review (usually 1–3 days)

---

## Apple App Store

### Requirements audit
| Item | Status |
|------|--------|
| apple-mobile-web-app-capable meta tag | READY — in layout.tsx |
| apple-mobile-web-app-status-bar-style | READY — black-translucent |
| Apple touch icon (180×180px) | READY — /public/icons/apple-touch-icon.png |
| Privacy policy URL (REQUIRED) | PARTIAL — check /privacy |
| Support URL | MISSING |
| No broken links visible | READY |
| Login/signup works without crashes | READY |
| Data collection disclosure | PARTIAL — needs privacy page |
| Screenshots at 6.7" and 6.1" sizes | MISSING |

### Steps to publish on App Store
1. Register Apple Developer account ($99/year) at https://developer.apple.com
2. Verify `public/icons/apple-touch-icon.png` exists (180×180px)
3. Use PWABuilder (https://pwabuilder.com) → iOS package → download Xcode project
4. Open in Xcode → set bundle ID → archive → submit via App Store Connect
5. Take screenshots on iPhone 14 Pro Max (6.7") and iPhone 14 (6.1")
6. Fill in App Store Connect: name, subtitle, description, keywords
7. Submit for review (usually 1–3 days, can be up to a week)

---

## Monitoring & Analytics
- [ ] Check Supabase usage: Dashboard → Settings → Usage (free tier: 1GB storage, 2GB bandwidth)
- [ ] Set up error tracking (Sentry optional but recommended for production)
- [ ] Check Vercel Analytics: Project → Analytics (free tier available)

---

## Quick PWA Test (do this before submitting to stores)
1. Open app on Android Chrome → three dots menu → "Add to Home screen"
2. Open app on iPhone Safari → share button → "Add to Home Screen"
3. Verify splash screen shows, navigation works, no console errors
4. Open DevTools → Application → Service Workers → confirm registered
5. Open DevTools → Application → Manifest → confirm all fields valid

---

## Events system quick test
1. Go to /events — should show empty state with "Create event" button
2. Click "Create event" → fill in details → submit
3. Go to /events/[id] — should show event detail with ticket section
4. For free events: click "Register for free →" — should work immediately
5. For paid events: enter MoMo number → click Pay → check phone for prompt
