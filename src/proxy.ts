import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function proxy(request: NextRequest) {
  const response = NextResponse.next()

  try {
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return request.cookies.getAll()
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) =>
              response.cookies.set(name, value, options)
            )
          },
        },
      }
    )

    const { data: { user } } = await supabase.auth.getUser()

    const path = request.nextUrl.pathname

    // Protect routes that require auth
    const protectedRoutes = ['/profile', '/settings']
    if (protectedRoutes.some(r => path.startsWith(r)) && !user) {
      return NextResponse.redirect(new URL('/auth/login', request.url))
    }

    // Redirect logged-in users away from auth pages
    if (user && (path.startsWith('/auth/login') || path.startsWith('/auth/signup'))) {
      return NextResponse.redirect(new URL('/feed', request.url))
    }
  } catch {
    // If Supabase fails, still serve the page — don't block routing
  }

  return response
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
