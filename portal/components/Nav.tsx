import Link from 'next/link'

export function Nav() {
  return (
    <nav className="bg-arcade-panel border-b-2 border-arcade-gold px-4 py-2 flex justify-between items-center font-mono">
      <Link
        href="/"
        className="text-arcade-gold text-lg font-bold tracking-widest hover:text-arcade-pink"
      >
        NEXUS ARCADE
      </Link>
      <div className="flex gap-4 text-arcade-purple text-sm">
        <Link href="/leaderboard" className="hover:text-arcade-gold">
          LEADERBOARD
        </Link>
        <span className="text-arcade-dim">|</span>
        <Link href="/login" className="text-arcade-pink hover:text-arcade-gold">
          LOGIN
        </Link>
      </div>
    </nav>
  )
}
