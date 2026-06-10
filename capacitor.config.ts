import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.ijwi.app',
  appName: 'Ijwi',
  webDir: 'out',
  server: {
    // Points to the live Vercel deployment — the app loads your website inside a native shell
    url: 'https://ijwi-orpin.vercel.app',
    cleartext: false,
    androidScheme: 'https',
  },
  ios: {
    contentInset: 'automatic',
    backgroundColor: '#0F0C30',
    preferredContentMode: 'mobile',
  },
  android: {
    backgroundColor: '#0F0C30',
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 0, // We handle our own JS splash
    },
    StatusBar: {
      style: 'Light',
      backgroundColor: '#0F0C30',
    },
  },
}

export default config
