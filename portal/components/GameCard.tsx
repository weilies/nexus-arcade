import Link from 'next/link'

interface GameCardProps {
  slug: string
  name: string
  thumbnailUrl?: string
  compact?: boolean
}

export function GameCard({ slug, name, thumbnailUrl, compact = false }: GameCardProps) {
  if (compact) {
    return (
      <Link href={`/games/${slug}`}
            className="flex items-center gap-4 bg-white rounded-card p-4 border-2 border-meadow-wheat shadow-card hover:shadow-md transition-shadow">
        <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl flex-shrink-0"
             style={{ background: '#f7d4d4' }}>
          {thumbnailUrl ? <img src={thumbnailUrl} alt={name} className="w-full h-full object-cover rounded-2xl" /> : '🎮'}
        </div>
        <div className="flex-1 min-w-0">
          <div className="font-pixel text-xl font-semibold text-meadow-dark truncate">{name}</div>
          <div className="text-sm text-meadow-earth mt-0.5">🎮 Classic battle</div>
        </div>
        <span className="text-2xl flex-shrink-0">▶️</span>
      </Link>
    )
  }

  return (
    <div className="bg-white rounded-card p-4 border-2 border-amber-light shadow-card">
      <div className="flex items-center gap-4">
        <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl"
             style={{ background: '#f7d4d4' }}>
          {thumbnailUrl ? <img src={thumbnailUrl} alt={name} className="w-full h-full object-cover rounded-2xl" /> : '🎮'}
        </div>
        <div>
          <div className="font-pixel text-xl font-semibold text-meadow-dark">{name}</div>
          <div className="text-sm text-meadow-earth mt-0.5">🎮 Classic battle</div>
        </div>
      </div>
      <Link href={`/games/${slug}`}
            className="btn-primary mt-4 block text-center">
        ▶ PLAY NOW
      </Link>
    </div>
  )
}
