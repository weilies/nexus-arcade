
export default function HomePage() {
  return (
    <div className="flex-1 flex items-center justify-center px-4 py-6 bg-retro-glow">
      <div className="flex flex-col md:flex-row items-center justify-center gap-8 w-full max-w-3xl">

        {/* Left: text card */}
        <div className="card-panel w-full max-w-sm text-center">
          <div className="flex items-center justify-center gap-3 mb-3">
            <span className="text-5xl" style={{ textShadow: '0 0 20px rgba(255,45,149,0.6)' }}>👾</span>
            <h1 className="font-pixel text-2xl font-bold text-[#e8e8f0]">
              NEXUS <span style={{ color: 'var(--neon-cyan)' }}>ARCADE</span>
            </h1>
          </div>

          <div className="space-y-2 mb-5 text-left">
            <p className="font-pixel text-sm text-[#aaaacc]">
              <span className="blink-star" style={{ color: 'var(--neon-cyan)', animationDuration: '1.3s', animationDelay: '0s' }}>▸</span> Neon nights ignite pixel fights.
            </p>
            <p className="font-pixel text-sm text-[#aaaacc]">
              <span className="blink-star" style={{ color: 'var(--neon-magenta)', animationDuration: '2.1s', animationDelay: '0.7s' }}>▸</span> Coins drop loud in arcade halls.
            </p>
            <p className="font-pixel text-sm text-[#aaaacc]">
              <span className="blink-star" style={{ color: 'var(--neon-purple)', animationDuration: '1.7s', animationDelay: '1.5s' }}>▸</span> Conquer rounds under neon lights.
            </p>
            <p className="font-pixel text-sm text-[#aaaacc]">
              <span className="blink-star" style={{ color: 'var(--neon-gold)', animationDuration: '2.4s', animationDelay: '0.4s' }}>▸</span> Legends echo through these walls.
            </p>
          </div>

          <div
            className="font-pixel text-sm blink-insert text-right"
            style={{ color: 'var(--neon-gold)', textShadow: '0 0 10px rgba(255,215,0,0.7)' }}
          >
            -INSERT COIN-
          </div>
        </div>

        {/* Right: arcade cabinet */}
        <div className="flex-shrink-0 flex items-center justify-center">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/images/arcade-cabinet.png"
            alt="Nexus Arcade cabinet"
            width={320}
            height={480}
            className="object-contain max-h-[480px] w-auto"
            style={{ filter: 'drop-shadow(0 0 24px rgba(0,229,255,0.35))' }}
          />
        </div>

      </div>
    </div>
  )
}
