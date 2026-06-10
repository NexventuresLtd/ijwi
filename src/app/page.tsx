import { redirect } from 'next/navigation'

export default async function RootPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; error_code?: string; error_description?: string }>
}) {
  const paramsFromRequest = await searchParams

  if (paramsFromRequest.error || paramsFromRequest.error_code) {
    const params = new URLSearchParams({
      error: paramsFromRequest.error ?? '',
      error_code: paramsFromRequest.error_code ?? '',
      error_description: paramsFromRequest.error_description ?? '',
    })
    redirect(`/auth/error?${params.toString()}`)
  }

  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
    redirect('/welcome')
  }

  redirect('/feed')
}
