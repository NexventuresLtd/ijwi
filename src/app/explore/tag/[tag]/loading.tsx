export default function TagLoading() {
  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--warm-white)' }}>
      <aside style={{
        width: '252px', flexShrink: 0,
        borderRight: '1px solid var(--border)',
        background: 'var(--surface)', padding: '20px 10px',
      }} />

      <main style={{ flex: 1, maxWidth: '680px', padding: '28px 24px' }}>
        <div className="skeleton" style={{ width: 60, height: 13, borderRadius: 4, marginBottom: 20 }} />
        <div className="skeleton" style={{ width: 80, height: 28, borderRadius: 100, marginBottom: 12 }} />
        <div className="skeleton" style={{ width: 200, height: 32, borderRadius: 6, marginBottom: 6 }} />
        <div className="skeleton" style={{ width: 160, height: 14, borderRadius: 4, marginBottom: 28 }} />

        {[1, 2, 3].map(i => (
          <div key={i} className="card" style={{ padding: '22px 24px', marginBottom: '12px' }}>
            <div style={{ display: 'flex', gap: '10px', marginBottom: '16px' }}>
              <div className="skeleton" style={{ width: 38, height: 38, borderRadius: '50%', flexShrink: 0 }} />
              <div style={{ flex: 1 }}>
                <div className="skeleton" style={{ width: '40%', height: 14, borderRadius: 4, marginBottom: 6 }} />
                <div className="skeleton" style={{ width: '25%', height: 12, borderRadius: 4 }} />
              </div>
            </div>
            <div className="skeleton" style={{ width: '100%', height: 14, borderRadius: 4, marginBottom: 6 }} />
            <div className="skeleton" style={{ width: '75%', height: 14, borderRadius: 4 }} />
          </div>
        ))}
      </main>
    </div>
  )
}
