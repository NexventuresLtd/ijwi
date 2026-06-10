interface FlameLogoProps {
  size?: number
  color?: string
  gradient?: boolean
}

// Cross + voice waves — the Word made voice. John 1:14
export default function FlameLogo({ size = 32, color = '#4F46E5', gradient = false }: FlameLogoProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 40 40"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-label="Ijwi logo"
    >
      {gradient && (
        <defs>
          <linearGradient id="ijwi-logo-grad" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="#7B72F5" />
            <stop offset="100%" stopColor="#D4960A" />
          </linearGradient>
        </defs>
      )}
      {/* Vertical bar */}
      <rect x="17" y="3" width="6" height="34" rx="3" fill={gradient ? 'url(#ijwi-logo-grad)' : color} />
      {/* Horizontal bar */}
      <rect x="6" y="13" width="22" height="6" rx="3" fill={gradient ? 'url(#ijwi-logo-grad)' : color} />
      {/* Voice arc — near */}
      <path
        d="M 31 12 Q 37 20 31 28"
        stroke={gradient ? 'url(#ijwi-logo-grad)' : color}
        strokeWidth="3"
        strokeLinecap="round"
        fill="none"
        opacity="0.9"
      />
      {/* Voice arc — far */}
      <path
        d="M 35 7 Q 43 20 35 33"
        stroke={gradient ? 'url(#ijwi-logo-grad)' : color}
        strokeWidth="2.5"
        strokeLinecap="round"
        fill="none"
        opacity="0.45"
      />
    </svg>
  )
}
