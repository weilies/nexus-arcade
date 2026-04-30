'use client'

import { useEffect, useRef } from 'react'
import { sendToGame, onGameMessage } from '@/lib/bridge'
import { createClient } from '@/lib/supabase/browser'

interface GameFrameProps {
  slug: string
  gameName: string
  matchId?: string
}

export function GameFrame({ slug, gameName, matchId }: GameFrameProps) {
  const iframeRef = useRef<HTMLIFrameElement>(null)

  useEffect(() => {
    const supabase = createClient()

    const cleanup = onGameMessage(async (msg) => {
      if (!iframeRef.current) return

      if (msg.type === 'game_ready' || msg.type === 'auth_request') {
        const { data: { session } } = await supabase.auth.getSession()
        if (session?.access_token) {
          sendToGame(iframeRef.current, 'auth_token', {
            token: session.access_token,
          }, window.location.origin)
        }
      }

      if (msg.type === 'match_end') {
        await fetch('/api/scores', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            slug,
            score: msg.score,
            winner: msg.winner,
            mode: msg.mode,
          }),
        })
      }
    }, window.location.origin)

    return cleanup
  }, [slug])

  const src = matchId
    ? `/games/${slug}/index.html?match=${matchId}`
    : `/games/${slug}/index.html`

  return (
    <div className="w-full h-full flex flex-col">
      <div className="font-mono text-arcade-gold text-xs tracking-widest py-2 text-center bg-arcade-panel border-b border-arcade-border">
        ► {gameName.toUpperCase()}
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
