'use client'

import { useEffect, useRef, useState } from 'react'
import { usePathname } from 'next/navigation'

export default function PageProgress() {
  const pathname = usePathname()
  const [visible, setVisible] = useState(false)
  const [pct, setPct] = useState(0)
  const timerRef = useRef<ReturnType<typeof setTimeout>>(undefined)
  const prevPath = useRef(pathname)

  // Start bar when a same-origin link is clicked
  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      const anchor = (e.target as Element).closest('a')
      if (!anchor) return
      const href = anchor.getAttribute('href')
      if (!href || href.startsWith('#') || href.startsWith('http') || href.startsWith('mailto') || anchor.target === '_blank') return
      setVisible(true)
      setPct(20)
      clearTimeout(timerRef.current)
      timerRef.current = setTimeout(() => setPct(65), 250)
    }
    document.addEventListener('click', handleClick)
    return () => document.removeEventListener('click', handleClick)
  }, [])

  // Complete bar when the new route renders
  useEffect(() => {
    if (pathname !== prevPath.current) {
      prevPath.current = pathname
      clearTimeout(timerRef.current)
      setPct(100)
      timerRef.current = setTimeout(() => {
        setVisible(false)
        setPct(0)
      }, 350)
    }
  }, [pathname])

  if (!visible) return null

  return (
    <div style={{
      position: 'fixed', top: 0, left: 0, right: 0, zIndex: 9999,
      height: '3px', pointerEvents: 'none',
    }}>
      <div style={{
        height: '100%',
        width: `${pct}%`,
        background: 'linear-gradient(90deg, #C9860A, #F0A832)',
        transition: pct === 100 ? 'width 0.2s ease-out' : 'width 0.5s ease',
        boxShadow: '0 0 10px rgba(240,168,50,0.5)',
      }} />
    </div>
  )
}
