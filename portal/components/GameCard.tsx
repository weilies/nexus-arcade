import Link from 'next/link'

interface GameCardProps {
  slug: string
  name: string
  description?: string | null
  thumbnailUrl?: string | null
  compact?: boolean
}

export function GameCard({ slug, name, description, thumbnailUrl, compact = false }: GameCardProps) {
  if (compact) {
    return (
      <Link href={`/games/${slug}`}
            className="flex items-center gap-4 bg-[#1a1a2e] rounded-xl p-4 border border-[#2a2a4a] shadow-lg hover:border-[#3a3a66] hover:shadow-[0_0_16px_rgba(0,229,255,0.1)] transition-all">
        <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl flex-shrink-0"
             style={{ background: 'rgba(0,229,255,0.1)' }}>
          {thumbnailUrl ? <img src={thumbnailUrl} alt={name} className="w-full h-full object-cover rounded-2xl" /> : '🎮'}
        </div>
        <div className="flex-1 min-w-0">
          <div className="font-pixel text-xl font-semibold text-[#e8e8f0] truncate">{name}</div>
          {description && (
            <div className="text-sm text-[#8888aa] mt-0.5 truncate">{description}</div>
          )}
        </div>
      </Link>
    )
  }

  return (
    <div className="bg-[#1a1a2e] rounded-xl p-4 border border-[#2a2a4a] shadow-lg">
      <div className="flex items-center gap-4">
        <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl"
             style={{ background: 'rgba(0,229,255,0.1)' }}>
          {thumbnailUrl ? <img src={thumbnailUrl} alt={name} className="w-full h-full object-cover rounded-2xl" /> : '🎮'}
        </div>
        <div>
          <div className="font-pixel text-xl font-semibold text-[#e8e8f0]">{name}</div>
          {description && (
            <div className="text-sm text-[#8888aa] mt-0.5">{description}</div>
          )}
        </div>
      </div>
      <Link href={`/games/${slug}`}
            className="btn-primary mt-4 block text-center">
        ▶ PLAY NOW
      </Link>
    </div>
  )
}
