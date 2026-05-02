export default function LeaderboardPage({ params }: { params: { slug: string } }) {
  return (
    <div className="min-h-screen flex flex-col items-center px-4 py-8"
         style={{ background: 'linear-gradient(180deg, #87CEEB 0%, #82c45d 40%, #f4d03f 70%, #8B5E3C 100%)' }}>
      <div className="card-panel w-full max-w-sm text-center">
        <div className="text-4xl mb-3">🏆</div>
        <h1 className="font-pixel text-xl font-semibold text-meadow-dark">
          LEADERBOARD — {params.slug.toUpperCase()}
        </h1>
        <p className="text-meadow-earth mt-3 text-sm">Full leaderboard — coming soon.</p>
      </div>
    </div>
  )
}
