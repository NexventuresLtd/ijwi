interface VerificationBadgeProps {
  size?: number
  className?: string
}

export default function VerificationBadge({ size = 18, className }: VerificationBadgeProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-label="Verified voice"
      className={className}
      style={{ display: 'inline-block', verticalAlign: 'middle', flexShrink: 0 }}
    >
      <defs>
        <linearGradient id="vbadge-grad" x1="0" y1="0" x2="24" y2="24" gradientUnits="userSpaceOnUse">
          <stop offset="0%" stopColor="#C9860A" />
          <stop offset="100%" stopColor="#F0A832" />
        </linearGradient>
      </defs>
      {/* Solid gold circle */}
      <circle cx="12" cy="12" r="10" fill="url(#vbadge-grad)" />
      {/* Bold white checkmark */}
      <path
        d="M7.5 12L10.5 15L16.5 9"
        stroke="#FFFFFF"
        strokeWidth="2.2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}
