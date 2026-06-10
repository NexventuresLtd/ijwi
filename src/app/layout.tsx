import type { Metadata, Viewport } from 'next'
import { Cormorant_Garamond, DM_Sans } from 'next/font/google'
import './globals.css'
import VersePopup from '@/components/ui/VersePopup'
import SWRegister from '@/components/ui/SWRegister'
import SplashScreen from '@/components/ui/SplashScreen'
import PageProgress from '@/components/PageProgress'
import PushPrompt from '@/components/ui/PushPrompt'
import { ThemeProvider } from '@/lib/theme'

const cormorant = Cormorant_Garamond({
  subsets: ['latin'],
  weight: ['400', '600', '700'],
  style: ['normal', 'italic'],
  variable: '--ij-font-display',
  display: 'swap',
})

const dmSans = DM_Sans({
  subsets: ['latin'],
  weight: ['400', '500', '600'],
  variable: '--ij-font-body',
  display: 'swap',
})

export const metadata: Metadata = {
  title: 'Ijwi — The Voice',
  description: 'A faith-rooted platform for African Christian youth. Share stories, prayers, devotionals, and testimonies.',
  manifest: '/manifest.json',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'default',
    title: 'Ijwi',
  },
  formatDetection: { telephone: false },
  openGraph: {
    title: 'Ijwi — The Voice',
    description: 'Where your faith story matters.',
    type: 'website',
  },
}

export const viewport: Viewport = {
  themeColor: '#0C0916',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" data-theme="dark" className={`${cormorant.variable} ${dmSans.variable}`}>
      <head>
        <link rel="apple-touch-icon" href="/icons/apple-touch-icon.png" />
        <link rel="icon" type="image/png" sizes="32x32" href="/icons/favicon-32.png" />
        <link rel="icon" type="image/svg+xml" href="/ijwi-logo.svg" />
        <meta name="mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
        <meta name="apple-mobile-web-app-title" content="Ijwi" />
      </head>
      <body>
        <ThemeProvider>
          <PageProgress />
          <SplashScreen />
          <SWRegister />
          <VersePopup />
          <PushPrompt />
          {children}
        </ThemeProvider>
      </body>
    </html>
  )
}
