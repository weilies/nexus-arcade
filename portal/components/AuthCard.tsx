'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/browser'

interface AuthCardProps {
  mode: 'signin' | 'register'
}

export function AuthCard({ mode }: AuthCardProps) {
  const supabase = createClient()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [username, setUsername] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  const isSignIn = mode === 'signin'
  const accent = isSignIn ? '#00e5ff' : '#ff2d95'

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    setLoading(true)

    if (isSignIn) {
      const { error: err } = await supabase.auth.signInWithPassword({ email, password })
      if (err) setError(err.message)
    } else {
      const { error: err } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { username } },
      })
      if (err) setError(err.message)
    }
    setLoading(false)
  }

  function getCallbackUrl() {
    const params = new URLSearchParams(window.location.search)
    const returnTo = params.get('return_to') || '/'
    return `${window.location.origin}/auth/callback?return_to=${encodeURIComponent(returnTo)}`
  }

  async function signInWithGoogle() {
    await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: getCallbackUrl() },
    })
  }

  async function signInWithDiscord() {
    await supabase.auth.signInWithOAuth({
      provider: 'discord',
      options: { redirectTo: getCallbackUrl() },
    })
  }

  const labelStyle: React.CSSProperties = {
    fontFamily: 'Orbitron, sans-serif',
    fontSize: '9px',
    fontWeight: '700',
    color: accent + '99',
    letterSpacing: '0.18em',
    marginBottom: '6px',
  }

  const inputStyle: React.CSSProperties = {
    borderRadius: '2px',
    borderColor: accent + '28',
    background: '#04040f',
  }

  return (
    <div
      style={{
        width: '100%',
        maxWidth: '380px',
        borderTop: `3px solid ${accent}`,
        borderRight: `1px solid ${accent}30`,
        borderBottom: `1px solid ${accent}30`,
        borderLeft: `1px solid ${accent}30`,
        borderRadius: '2px',
        overflow: 'hidden',
        background: '#07071a',
      }}
    >
      {/* Stage header bar */}
      <div
        style={{
          padding: '6px 14px',
          background: accent + '12',
          borderBottom: `1px solid ${accent}22`,
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
        }}
      >
        <span style={{ fontSize: '8px', color: accent + '60', letterSpacing: '3px' }}>■ ■</span>
        <span
          style={{
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '10px',
            fontWeight: '700',
            color: accent,
            letterSpacing: '0.22em',
            flex: 1,
            textAlign: 'center',
          }}
        >
          {isSignIn ? 'PLAYER LOGIN' : 'NEW PLAYER'}
        </span>
        <span style={{ fontSize: '8px', color: accent + '60', letterSpacing: '3px' }}>■ ■</span>
      </div>

      {/* Body */}
      <div style={{ padding: '22px 20px 20px' }}>
        {/* Title */}
        <div style={{ textAlign: 'center', marginBottom: '22px' }}>
          <div
            style={{
              fontFamily: 'Orbitron, sans-serif',
              fontSize: '24px',
              fontWeight: '900',
              color: '#e8e8f0',
              textShadow: `0 0 20px ${accent}55`,
              letterSpacing: '0.1em',
            }}
          >
            {isSignIn ? 'SIGN IN' : 'REGISTER'}
          </div>
          <div
            style={{
              fontFamily: 'Orbitron, sans-serif',
              fontSize: '9px',
              color: '#333355',
              letterSpacing: '0.22em',
              marginTop: '5px',
            }}
          >
            {isSignIn ? 'ENTER YOUR CREDENTIALS' : 'CREATE YOUR PROFILE'}
          </div>
        </div>

        {/* Error */}
        {error && (
          <div
            style={{
              background: 'rgba(255,45,149,0.08)',
              border: '1px solid rgba(255,45,149,0.35)',
              borderRadius: '2px',
              padding: '10px 12px',
              marginBottom: '16px',
              fontFamily: 'Orbitron, sans-serif',
              fontSize: '10px',
              color: '#ff6b9d',
              letterSpacing: '0.05em',
            }}
          >
            ERR: {error}
          </div>
        )}

        {/* Form */}
        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          {!isSignIn && (
            <div>
              <div style={labelStyle}>USERNAME</div>
              <input
                className="input-field"
                style={inputStyle}
                placeholder="your_handle"
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                required
              />
            </div>
          )}
          <div>
            <div style={labelStyle}>EMAIL</div>
            <input
              className="input-field"
              style={inputStyle}
              placeholder="player@example.com"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          <div>
            <div style={labelStyle}>PASSWORD</div>
            <input
              className="input-field"
              style={inputStyle}
              placeholder="••••••••"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              minLength={6}
            />
          </div>
          <button
            type="submit"
            disabled={loading}
            className={isSignIn ? 'btn-primary' : 'btn-secondary'}
            style={{ marginTop: '2px', borderRadius: '2px' }}
          >
            {loading ? 'PLEASE WAIT...' : isSignIn ? 'SIGN IN' : 'CREATE ACCOUNT'}
          </button>
        </form>

        {/* Divider */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            margin: '20px 0',
          }}
        >
          <div style={{ flex: 1, height: '1px', background: '#141428' }} />
          <span
            style={{
              fontFamily: 'Orbitron, sans-serif',
              fontSize: '9px',
              color: '#2a2a44',
              letterSpacing: '0.18em',
            }}
          >
            CONTINUE WITH
          </span>
          <div style={{ flex: 1, height: '1px', background: '#141428' }} />
        </div>

        {/* OAuth */}
        <div style={{ display: 'flex', gap: '10px' }}>
          <button onClick={signInWithGoogle} className="oauth-btn google">
            GOOGLE
          </button>
          <button onClick={signInWithDiscord} className="oauth-btn discord">
            DISCORD
          </button>
        </div>

        {/* Switch link */}
        <div
          style={{
            textAlign: 'center',
            marginTop: '18px',
            paddingTop: '16px',
            borderTop: `1px solid ${accent}14`,
            fontSize: '13px',
            color: '#3a3a55',
          }}
        >
          {isSignIn ? (
            <>
              No account?{' '}
              <a
                href="/register"
                style={{
                  color: accent,
                  fontFamily: 'Orbitron, sans-serif',
                  fontSize: '10px',
                  textDecoration: 'none',
                  letterSpacing: '0.12em',
                }}
              >
                REGISTER
              </a>
            </>
          ) : (
            <>
              Already registered?{' '}
              <a
                href="/login"
                style={{
                  color: accent,
                  fontFamily: 'Orbitron, sans-serif',
                  fontSize: '10px',
                  textDecoration: 'none',
                  letterSpacing: '0.12em',
                }}
              >
                SIGN IN
              </a>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
