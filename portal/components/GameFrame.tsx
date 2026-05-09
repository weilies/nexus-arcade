'use client'

import { useCallback, useEffect, useRef } from 'react'
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

  const sendAuth = useCallback((token: string) => {
    if (iframeRef.current?.contentWindow) {
      sendToGame(iframeRef.current, 'auth_token', { token }, window.location.origin)
      return true
    }
    return false
  }, [])

  useEffect(() => {
    const supabase = createClient()
    let pendingToken: string | null = null
    let gameReady = false

    const flushToken = () => {
      if (pendingToken && gameReady) {
        const sent = sendAuth(pendingToken)
        if (sent) pendingToken = null
      }
    }

    const bufferToken = (token: string) => {
      pendingToken = token
      flushToken()
    }

    // Pre-fetch session before game loads (avoids race after OAuth redirect)
    supabase.auth.getSession().then(({ data }) => {
      if (data.session?.access_token) {
        bufferToken(data.session.access_token)
      }
    })

    const cleanup = onGameMessage(async (msg) => {
      if (!iframeRef.current) return
      if (msg.type === 'game_ready') {
        gameReady = true
        flushToken()
      }
      if (msg.type === 'auth_request') {
        // Godot explicitly requesting auth — always fetch fresh
        const { data: { session } } = await supabase.auth.getSession()
        if (session?.access_token) {
          pendingToken = session.access_token
          flushToken()
        }
      }
      if (msg.type === 'sign_in_request') {
        router.push('/login?return_to=' + encodeURIComponent(window.location.pathname))
      }
      if (msg.type === 'sign_out_request') {
        await supabase.auth.signOut()
      }
      if (msg.type === 'match_end') {
        await fetch('/api/scores', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ slug, score: msg.score, winner: msg.winner, mode: msg.mode }),
        })
      }
    }, window.location.origin)

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.access_token) {
        bufferToken(session.access_token)
      } else {
        pendingToken = null
      }
    })

    // Fallback: if iframe loads before we got game_ready, flush after short delay
    // (allows Godot JS to initialize its message listener)
    const iframeEl = iframeRef.current
    if (iframeEl) {
      const onLoad = () => {
        setTimeout(() => {
          gameReady = true
          flushToken()
        }, 300)
      }
      iframeEl.addEventListener('load', onLoad)
      return () => {
        cleanup()
        subscription.unsubscribe()
        iframeEl.removeEventListener('load', onLoad)
      }
    }

    return () => { cleanup(); subscription.unsubscribe() }
  }, [slug, router, sendAuth])

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
        <button
          onClick={() => iframeRef.current?.requestFullscreen()}
          className="text-sm hover:opacity-80 transition-opacity"
          style={{ color: 'var(--text-muted)' }}
          title="Fullscreen"
        >
          ⛶
        </button>
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
