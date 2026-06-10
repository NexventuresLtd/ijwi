export default function ExploreLoading() {
  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--warm-white)' }}>
      <aside style={{
        width: '252px', flexShrink: 0,
        borderRight: '1px solid var(--border)',
        background: 'var(--surface)', padding: '20px 10px',
      }} />

      <main style={{ flex: 1, maxWidth: '680px', padding: '28px 24px' }}>
        <div className="skeleton" style={{ width: 140, height: 36, borderRadius: 6, marginBottom: 10 }} />
        <div className="skeleton" style={{ width: 260, height: 16, borderRadius: 4, marginBottom: 28 }} />

        {/* Tag pills */}
        <div className="card" style={{ padding: '20px', marginBottom: '28px' }}>
          <div className="skeleton" style={{ width: 100, height: 13, borderRadius: 4, marginBottom: 14 }} />
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
            {[60, 90, 72, 60, 96, 68, 54, 66, 56, 80, 80, 92, 64, 58, 82].map((w, i) => (
              <div key={i} className="skeleton" style={{ width: w, height: 30, borderRadius: 100 }} />
            ))}
          </div>
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
            <div className="skeleton" style={{ width: '100%', height: 14, borderRadius: 4, marginBottom: 6 }} />
            <div className="skeleton" style={{ width: '80%', height: 14, borderRadius: 4 }} />
          </div>
        ))}
      </main>
    </div>
  )
}
