'use client'

import { useEffect, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { sendToGame, onGameMessage } from '@/lib/bridge'
import { createClient } from '@/lib/supabase/browser'

interface GameFrameProps {
  slug: string
  gameName: string
  matchId?: string
}

export function GameFrame({ slug, gameName, matchId }: GameFrameProps) {
  const iframeRef = useRef<HTMLIFrameElement>(null)
  const router = useRouter()

  useEffect(() => {
    const supabase = createClient()
    const cleanup = onGameMessage(async (msg) => {
      if (!iframeRef.current) return
      if (msg.type === 'game_ready' || msg.type === 'auth_request') {
        const { data: { session } } = await supabase.auth.getSession()
        if (session?.access_token) {
          sendToGame(iframeRef.current, 'auth_token', { token: session.access_token }, window.location.origin)
        }
      }
      if (msg.type === 'sign_in_request') {
        router.push('/login?return_to=' + encodeURIComponent(window.location.pathname))
      }
      if (msg.type === 'match_end') {
        await fetch('/api/scores', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ slug, score: msg.score, winner: msg.winner, mode: msg.mode }),
        })
      }
    }, window.location.origin)
    return cleanup
  }, [slug, router])

  const src = matchId
    ? `/games/${slug}/index.html?match=${matchId}`
    : `/games/${slug}/index.html`

  return (
    <div className="w-full h-full flex flex-col">
      <div className="font-pixel text-sm tracking-wide py-2 px-4 text-center border-b flex items-center justify-between"
           style={{
             background: 'rgba(10,10,26,0.96)',
             color: 'var(--text-secondary)',
             borderColor: 'var(--border-dim)',
             boxShadow: '0 2px 12px rgba(0,0,0,0.4)',
           }}>
        <span className="text-xs" style={{ color: 'var(--text-muted)' }}>NEXUS ARCADE</span>
        <span className="font-semibold" style={{ color: 'var(--neon-cyan)' }}>▶ {gameName.toUpperCase()}</span>
        <span className="text-xs font-semibold" style={{ color: 'var(--neon-green)' }}>● LIVE</span>
      </div>
      <iframe
        ref={iframeRef}
        src={src}
        className="w-full flex-1 border-0"
        allow="fullscreen"
        title={gameName}
      />
    </div>
  )
}
