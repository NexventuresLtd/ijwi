'use client'

import { useState, useRef, useEffect } from 'react'

interface EssayMusicPlayerProps {
  audioUrl: string
  title?: string
}

export default function EssayMusicPlayer({ audioUrl, title }: EssayMusicPlayerProps) {
  const audioRef = useRef<HTMLAudioElement>(null)
  const [playing, setPlaying] = useState(false)
  const [volume, setVolume] = useState(0.35)
  const [dismissed, setDismissed] = useState(false)

  useEffect(() => {
    if (audioRef.current) {
      audioRef.current.volume = volume
      audioRef.current.loop = true
    }
  }, [volume])

  const toggle = () => {
    if (!audioRef.current) return
    if (playing) {
      audioRef.current.pause()
    } else {
      audioRef.current.play().catch(() => {})
    }
    setPlaying(p => !p)
  }

  if (dismissed) return null

  return (
    <div style={{
      position: 'fixed',
      bottom: 80,
      right: 20,
      zIndex: 200,
      background: 'var(--ij-bg-surface)',
      border: '1px solid var(--ij-border-gold)',
      borderRadius: 'var(--ij-radius-pill)',
      boxShadow: '0 4px 24px var(--ij-glow-gold)',
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      padding: '8px 14px',
      maxWidth: 260,
      animation: 'fadeUp 0.3s ease-out both',
    }}>
      <audio ref={audioRef} src={audioUrl} preload="none" />

      {/* Play/pause */}
      <button
        onClick={toggle}
        style={{
          width: 32, height: 32, borderRadius: '50%', border: 'none', cursor: 'pointer',
          background: 'var(--ij-gold)', color: '#0B0B1F',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          flexShrink: 0, fontSize: '13px',
        }}
      >
        {playing ? '⏸' : '▶'}
      </button>

      {/* Track info */}
      <div style={{ flex: 1, overflow: 'hidden' }}>
        <div style={{ fontSize: '11px', color: 'var(--ij-gold)', fontWeight: 600, marginBottom: 2 }}>Background music</div>
        {title && (
          <div style={{ fontSize: '11px', color: 'var(--ij-text-secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {title}
          </div>
        )}
        <input
          type="range"
          min={0}
          max={1}
          step={0.05}
          value={volume}
          onChange={e => {
            const v = parseFloat(e.target.value)
            setVolume(v)
            if (audioRef.current) audioRef.current.volume = v
          }}
          style={{ width: '100%', accentColor: 'var(--ij-gold)', height: 3, marginTop: 4 }}
        />
      </div>

      {/* Dismiss */}
      <button
        onClick={() => { audioRef.current?.pause(); setDismissed(true) }}
        style={{ background: 'none', border: 'none', color: 'var(--ij-text-secondary)', cursor: 'pointer', fontSize: '16px', lineHeight: 1, padding: 2 }}
      >
        ×
      </button>
    </div>
  )
}
