export default function LeaderboardPage({ params }: { params: { slug: string } }) {
  return (
    <div className="min-h-screen flex flex-col items-center px-4 py-8 bg-retro-glow">
      <div className="card-panel w-full max-w-sm text-center">
        <div className="text-4xl mb-3">🏆</div>
        <h1 className="font-pixel text-xl font-semibold text-[#e8e8f0]">
          LEADERBOARD — {params.slug.toUpperCase()}
        </h1>
        <p className="text-[#8888aa] mt-3 text-sm">Full leaderboard — coming soon.</p>
      </div>
    </div>
  )
}
