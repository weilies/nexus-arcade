import Link from 'next/link'

interface GameCardProps {
  slug: string
  name: string
  thumbnailUrl?: string
}

export function GameCard({ slug, name, thumbnailUrl }: GameCardProps) {
  return (
    <div className="bg-arcade-panel border-2 border-arcade-violet p-4 flex flex-col gap-3 font-mono">
      <div className="bg-arcade-bg border border-arcade-dim flex items-center justify-center h-32">
        {thumbnailUrl ? (
          <img src={thumbnailUrl} alt={name} className="h-full object-contain" />
        ) : (
          <span className="text-arcade-dim text-4xl">?</span>
        )}
      </div>
      <div className="text-arcade-gold font-bold text-sm tracking-wider">
        {name.toUpperCase()}
      </div>
      <Link
        href={`/games/${slug}`}
        className="bg-arcade-pink text-white text-center text-xs py-1 px-3 hover:bg-pink-400 tracking-wider"
      >
        ► PLAY NOW
      </Link>
    </div>
  )
}
