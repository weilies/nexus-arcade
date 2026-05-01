import Link from 'next/link'

interface GameCardProps {
  slug: string
  name: string
  thumbnailUrl?: string
}

export function GameCard({ slug, name, thumbnailUrl }: GameCardProps) {
  return (
    <div className="crt-border bg-arcade-panel p-4 flex flex-col gap-4 dither-bg relative overflow-hidden">
      {/* Corner decorations */}
      <div className="absolute top-0 left-0 w-3 h-3 border-t-2 border-l-2 border-arcade-amber" />
      <div className="absolute top-0 right-0 w-3 h-3 border-t-2 border-r-2 border-arcade-amber" />
      <div className="absolute bottom-0 left-0 w-3 h-3 border-b-2 border-l-2 border-arcade-amber" />
      <div className="absolute bottom-0 right-0 w-3 h-3 border-b-2 border-r-2 border-arcade-amber" />

      {/* Thumbnail */}
      <div className="bg-arcade-bg border border-arcade-dim flex items-center justify-center h-36 relative overflow-hidden"
           style={{ boxShadow: 'inset 0 0 20px #00000088' }}>
        {thumbnailUrl ? (
          <img src={thumbnailUrl} alt={name} className="h-full w-full object-cover" />
        ) : (
          <div className="text-center">
            <div className="font-pixel text-arcade-amber-dim text-2xl mb-2">?</div>
            <div className="font-mono text-arcade-dim text-xs">NO PREVIEW</div>
          </div>
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-arcade-panel to-transparent opacity-40" />
      </div>

      {/* Name */}
      <div className="font-pixel text-arcade-amber text-[10px] tracking-widest text-glow-amber leading-relaxed">
        {name.toUpperCase()}
      </div>

      {/* Play button */}
      <Link href={`/games/${slug}`} className="btn-pixel btn-pixel-hot text-center block">
        ▶ PLAY NOW
      </Link>

      {/* Status ticker */}
      <div className="font-mono text-arcade-green text-[9px] text-glow-green tracking-widest">
        ● LIVE
      </div>
    </div>
  )
}
