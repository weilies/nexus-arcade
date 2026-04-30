'use client'

import { Nav } from '@/components/Nav'
import { createClient } from '@/lib/supabase/browser'

export default function LoginPage() {
  const supabase = createClient()

  async function signInWithDiscord() {
    await supabase.auth.signInWithOAuth({
      provider: 'discord',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    })
  }

  return (
    <div className="min-h-screen bg-arcade-bg">
      <Nav />
      <div className="flex flex-col items-center justify-center mt-32 gap-6 font-mono">
        <h1 className="text-arcade-gold text-2xl font-bold tracking-widest">
          INSERT PLAYER
        </h1>
        <p className="text-arcade-purple text-sm">Login to compete on the leaderboard</p>
        <button
          onClick={signInWithDiscord}
          className="bg-[#5865F2] text-white px-8 py-3 text-sm tracking-wider hover:bg-[#4752C4]"
        >
          LOGIN WITH DISCORD
        </button>
      </div>
    </div>
  )
}
