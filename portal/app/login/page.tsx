'use client'

import { Nav } from '@/components/Nav'
import { createClient } from '@/lib/supabase/browser'
import { useSearchParams } from 'next/navigation'
import { Suspense } from 'react'

function LoginForm() {
  const supabase = createClient()
  const searchParams = useSearchParams()
  const error = searchParams.get('error')

  async function signInWithGoogle() {
    await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: `${window.location.origin}/auth/callback` },
    })
  }

  async function signInWithDiscord() {
    await supabase.auth.signInWithOAuth({
      provider: 'discord',
      options: { redirectTo: `${window.location.origin}/auth/callback` },
    })
  }

  return (
    <div className="flex flex-col items-center justify-center flex-1 px-4 py-16">
      {/* Cabinet frame */}
      <div className="crt-border bg-arcade-panel p-8 w-full max-w-sm dither-bg relative">
        {/* Corner pins */}
        <div className="absolute top-0 left-0 w-3 h-3 border-t-2 border-l-2 border-arcade-amber" />
        <div className="absolute top-0 right-0 w-3 h-3 border-t-2 border-r-2 border-arcade-amber" />
        <div className="absolute bottom-0 left-0 w-3 h-3 border-b-2 border-l-2 border-arcade-amber" />
        <div className="absolute bottom-0 right-0 w-3 h-3 border-b-2 border-r-2 border-arcade-amber" />

        {/* Title */}
        <div className="text-center mb-8">
          <div className="font-pixel text-arcade-amber text-glow-amber text-[10px] leading-loose tracking-widest">
            INSERT<br/>PLAYER ONE
          </div>
          <div className="mt-3 h-px" style={{ background: 'linear-gradient(90deg,transparent,#ffb300,transparent)' }} />
        </div>

        {/* Error */}
        {error && (
          <div className="crt-border-hot bg-arcade-bg p-2 mb-4 font-mono text-arcade-hot text-[9px] tracking-wider text-center">
            ✗ AUTH FAILED — TRY AGAIN
          </div>
        )}

        {/* Auth buttons */}
        <div className="flex flex-col gap-4">
          <button onClick={signInWithGoogle}
                  className="btn-pixel w-full text-center text-[9px] py-3 flex items-center justify-center gap-3">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
              <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
              <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
              <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
              <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
            </svg>
            LOGIN WITH GOOGLE
          </button>

          <div className="flex items-center gap-2 font-mono text-arcade-dim text-[9px]">
            <div className="flex-1 h-px bg-arcade-border" />
            OR
            <div className="flex-1 h-px bg-arcade-border" />
          </div>

          <button onClick={signInWithDiscord}
                  className="btn-pixel btn-pixel-ghost w-full text-center text-[9px] py-3 flex items-center justify-center gap-3">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
              <path d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057.1 18.079.11 18.1.12 18.12a19.916 19.916 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028c.462-.63.874-1.295 1.226-1.994a.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03z"/>
            </svg>
            LOGIN WITH DISCORD
          </button>
        </div>

        {/* Footer note */}
        <div className="mt-6 font-mono text-arcade-dim text-[8px] text-center leading-relaxed">
          LOGIN = SUBMIT SCORES<br/>TO GLOBAL LEADERBOARD
        </div>
      </div>

      {/* Blinking insert prompt */}
      <div className="mt-8 font-pixel text-arcade-amber-dim text-[8px] tracking-widest"
           style={{ animation: 'blink 1.2s step-end infinite' }}>
        ◄ PRESS START ►
      </div>
    </div>
  )
}

export default function LoginPage() {
  return (
    <div className="min-h-screen bg-arcade-bg flex flex-col">
      <Nav />
      <Suspense fallback={null}>
        <LoginForm />
      </Suspense>
    </div>
  )
}
