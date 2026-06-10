interface IjwiLogoProps {
  size?: number
  color?: string
  gradient?: boolean
}

export default function IjwiLogo({ size = 32, color, gradient }: IjwiLogoProps) {
  const fill = color ?? 'url(#ijwi-grad)'
  const showGrad = gradient !== false

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 28 28"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-label="Ijwi logo"
    >
      {showGrad && !color && (
        <defs>
          <linearGradient id="ijwi-grad" x1="0" y1="0" x2="28" y2="28" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stopColor="#B08090" />
            <stop offset="100%" stopColor="#F0A832" />
          </linearGradient>
        </defs>
      )}
      {/* Vertical bar */}
      <rect x="11.5" y="2" width="5" height="24" rx="2.5" fill={fill} />
      {/* Horizontal bar */}
      <rect x="4" y="9" width="14" height="5" rx="2.5" fill={fill} />
      {/* Voice arc — near */}
      <path
        d="M 21 9 Q 25.5 14 21 19"
        stroke={fill}
        strokeWidth="2.5"
        strokeLinecap="round"
        fill="none"
        opacity="0.9"
      />
      {/* Voice arc — far */}
      <path
        d="M 23.5 6 Q 29 14 23.5 22"
        stroke={fill}
        strokeWidth="2"
        strokeLinecap="round"
        fill="none"
        opacity="0.45"
      />
    </svg>
  )
}
