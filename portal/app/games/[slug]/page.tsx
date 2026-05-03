import { notFound } from 'next/navigation'
import { getGameBySlug } from '@/lib/data/games'
import { GameFrame } from '@/components/GameFrame'

interface Props {
  params: { slug: string }
  searchParams: { match?: string }
}

export default async function GamePage({ params, searchParams }: Props) {
  const game = await getGameBySlug(params.slug)
  if (!game || game.status !== 'live') notFound()

  return (
    <div className="h-screen flex flex-col overflow-hidden bg-[#0a0a1a]">
      <div className="flex-1 flex flex-col">
        <GameFrame
          slug={params.slug}
          gameName={game.name}
          matchId={searchParams.match}
        />
      </div>
    </div>
  )
}
