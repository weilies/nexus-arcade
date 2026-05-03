export default function HomePage() {
  return (
    <div className="flex-1 flex flex-col items-center justify-center px-4 py-6 bg-retro-glow">
      <div className="card-panel w-full max-w-sm text-center">
        {/* Minion + title — same row */}
        <div className="flex items-center justify-center gap-3 mb-3">
          <span className="text-5xl" style={{ textShadow: '0 0 20px rgba(255,45,149,0.6)' }}>👾</span>
          <h1 className="font-pixel text-2xl font-bold text-[#e8e8f0]">
            NEXUS <span style={{ color: 'var(--neon-cyan)' }}>ARCADE</span>
          </h1>
        </div>

        {/* Malay pantun — ABAB rhyme: fights/lights, halls/walls */}
        <div className="space-y-2 mb-5">
          <p className="font-pixel text-sm text-[#aaaacc]">
            <span style={{ color: 'var(--neon-cyan)' }}>▸</span> Neon nights ignite pixel fights.
          </p>
          <p className="font-pixel text-sm text-[#aaaacc]">
            <span style={{ color: 'var(--neon-magenta)' }}>▸</span> Coins drop loud in arcade halls.
          </p>
          <p className="font-pixel text-sm text-[#aaaacc]">
            <span style={{ color: 'var(--neon-purple)' }}>▸</span> Conquer rounds under neon lights.
          </p>
          <p className="font-pixel text-sm text-[#aaaacc]">
            <span style={{ color: 'var(--neon-gold)' }}>▸</span> Legends echo through these walls.
          </p>
        </div>

        {/* Arcade blink */}
        <div
          className="font-pixel text-sm blink-arcade"
          style={{ color: 'var(--neon-gold)', textShadow: '0 0 10px rgba(255,215,0,0.7)' }}
        >
          -INSERT COIN-
        </div>
      </div>
    </div>
  )
}
