'use client'

import React from 'react'
import { useRouter } from 'next/navigation'
import { motion } from 'framer-motion'

interface BackButtonProps {
  href?: string
  label?: string
  style?: React.CSSProperties
}

export default function BackButton({ href, label = 'Back', style: styleProp }: BackButtonProps) {
  const router = useRouter()

  const handleClick = () => {
    if (href) {
      router.push(href)
    } else {
      router.back()
    }
  }

  return (
    <motion.button
      onClick={handleClick}
      whileTap={{ scale: 0.94 }}
      whileHover={{ x: -2 }}
      transition={{ type: 'spring', stiffness: 500, damping: 30 }}
      style={{
        display: 'inline-flex', alignItems: 'center', gap: 6,
        background: 'var(--ij-bg-elevated)',
        border: '1px solid var(--ij-border)',
        borderRadius: 999, padding: '8px 16px',
        fontFamily: 'var(--ij-font-body)', fontSize: '13px',
        color: 'var(--ij-text-secondary)', cursor: 'pointer',
        marginBottom: 20,
        transition: 'border-color 0.15s, color 0.15s',
        ...styleProp,
      }}
      onMouseEnter={e => {
        e.currentTarget.style.borderColor = 'var(--ij-border-gold)'
        e.currentTarget.style.color = 'var(--ij-gold)'
      }}
      onMouseLeave={e => {
        e.currentTarget.style.borderColor = 'var(--ij-border)'
        e.currentTarget.style.color = 'var(--ij-text-secondary)'
      }}
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M19 12H5M12 5l-7 7 7 7"/>
      </svg>
      {label}
    </motion.button>
  )
}
