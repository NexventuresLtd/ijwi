'use client'

import { useEffect } from 'react'
import BackendUnavailable from '@/components/ui/BackendUnavailable'

export default function Error({
  error,
  unstable_retry,
}: {
  error: Error & { digest?: string }
  unstable_retry: () => void
}) {
  useEffect(() => {
    console.error(error)
  }, [error])

  return (
    <BackendUnavailable
      message="The frontend is online, but the backend could not complete this request. Check the Supabase env values or backend availability, then try again."
      onRetry={unstable_retry}
    />
  )
}
