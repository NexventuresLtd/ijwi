export function ProBadge(_props?: { size?: string }) {
  return (
    <span style={{
      display: 'inline-flex',
      alignItems: 'center',
      background: 'linear-gradient(135deg,#C9860A,#F0A832)',
      borderRadius: '999px',
      padding: '1px 7px',
      fontFamily: 'var(--ij-font-body), sans-serif',
      fontSize: '0.6rem',
      fontWeight: 700,
      color: '#0B0B1F',
      letterSpacing: '0.05em',
      textTransform: 'uppercase' as const,
      flexShrink: 0,
    }}>
      PRO
    </span>
  )
}

export default ProBadge
