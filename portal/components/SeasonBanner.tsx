'use client'

interface SeasonBannerProps {
  name: string
  endsAt: string
}

function daysLeft(endsAt: string): number {
  const end = new Date(endsAt)
  const now = new Date()
  return Math.max(0, Math.ceil((end.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)))
}

export function SeasonBanner({ name, endsAt }: SeasonBannerProps) {
  const days = daysLeft(endsAt)
  const urgent = days <= 3
  return (
    <div className={`px-4 py-2 flex justify-between items-center font-mono text-[10px] border-b ${urgent ? 'border-arcade-hot' : 'border-arcade-amber'}`}
         style={{ background: urgent ? '#1a0010' : '#0d0a00', boxShadow: urgent ? '0 2px 12px #ff008055' : '0 2px 12px #ffb30033' }}>
      <div className="marquee-wrap flex-1 mr-4">
        <span className={`marquee-inner tracking-widest ${urgent ? 'text-arcade-hot text-glow-hot' : 'text-arcade-amber text-glow-amber'}`}>
          ★ {name.toUpperCase()} &nbsp;•&nbsp; {days} DAY{days !== 1 ? 'S' : ''} REMAINING &nbsp;•&nbsp;
          COMPETE NOW &nbsp;•&nbsp; ★ {name.toUpperCase()} &nbsp;•&nbsp; {days} DAY{days !== 1 ? 'S' : ''} REMAINING &nbsp;•&nbsp; COMPETE NOW &nbsp;•&nbsp;
        </span>
      </div>
      <button className={`btn-pixel shrink-0 ${urgent ? 'btn-pixel-hot' : ''} py-1 px-3 text-[8px]`}>
        JOIN ▶
      </button>
    </div>
  )
}
