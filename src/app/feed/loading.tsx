export default function FeedLoading() {
  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--warm-white)' }}>
      {/* Sidebar skeleton */}
      <aside style={{
        width: '252px', flexShrink: 0,
        borderRight: '1px solid var(--border)',
        background: 'var(--surface)', padding: '20px 10px',
      }} />

      {/* Main skeleton */}
      <main style={{ flex: 1, maxWidth: '680px', padding: '28px 24px' }}>
        {/* Tab bar */}
        <div style={{
          display: 'flex', gap: '4px', marginBottom: '24px',
          borderBottom: '2px solid var(--border)', paddingBottom: '2px',
        }}>
          {[80, 60, 100, 90, 70, 80].map((w, i) => (
            <div key={i} className="skeleton" style={{
              width: w, height: 32, borderRadius: '6px', flexShrink: 0,
            }} />
          ))}
        </div>
        {/* Post skeletons */}
        {[1, 2, 3].map(i => (
          <div key={i} className="card" style={{ padding: '22px 24px', marginBottom: '12px' }}>
            <div style={{ display: 'flex', gap: '10px', marginBottom: '16px' }}>
              <div className="skeleton" style={{ width: 38, height: 38, borderRadius: '50%', flexShrink: 0 }} />
              <div style={{ flex: 1 }}>
                <div className="skeleton" style={{ width: '40%', height: 14, borderRadius: 4, marginBottom: 6 }} />
                <div className="skeleton" style={{ width: '25%', height: 12, borderRadius: 4 }} />
              </div>
            </div>
            <div className="skeleton" style={{ width: '70%', height: 20, borderRadius: 4, marginBottom: 12 }} />
            <div className="skeleton" style={{ width: '100%', height: 14, borderRadius: 4, marginBottom: 6 }} />
            <div className="skeleton" style={{ width: '85%', height: 14, borderRadius: 4, marginBottom: 6 }} />
            <div className="skeleton" style={{ width: '60%', height: 14, borderRadius: 4 }} />
          </div>
        ))}
      </main>
    </div>
  )
}
