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
    <div className="bg-white rounded-card p-6 border-2 border-amber-light shadow-card w-full max-w-sm">
      <div className="text-center mb-5">
        <span className="text-4xl block mb-2">{isSignIn ? '🔑' : '📝'}</span>
        <h2 className="font-pixel text-2xl font-semibold text-meadow-dark">
          {isSignIn ? 'SIGN IN' : 'REGISTER'}
        </h2>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 rounded-input p-3 mb-4 text-sm text-red-700 text-center">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="flex flex-col gap-3">
        {!isSignIn && (
          <input
            className="input-field"
            placeholder="👤 Username"
            type="text"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
          />
        )}
        <input
          className="input-field"
          placeholder="📧 Email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <input
          className="input-field"
          placeholder="🔒 Password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          minLength={6}
        />
        <button
          type="submit"
          disabled={loading}
          className={isSignIn ? 'btn-primary' : 'btn-primary'}
          style={isSignIn ? {} : { background: 'linear-gradient(180deg, #82c45d, #5a8a3d)', boxShadow: '0 4px 0 #4a7a2d' }}
        >
          {loading ? '⏳ Please wait...' : isSignIn ? '🔑 SIGN IN' : '📝 CREATE ACCOUNT'}
        </button>
      </form>

      <div className="text-center my-4 font-pixel text-sm text-ui-muted">— OR —</div>

      <div className="flex gap-3">
        <button onClick={signInWithGoogle} className="flex-1 bg-gray-100 rounded-btn py-3 px-3 font-pixel text-sm hover:bg-gray-200 min-h-[48px]">
          🔵 Google
        </button>
        <button onClick={signInWithDiscord} className="flex-1 bg-gray-100 rounded-btn py-3 px-3 font-pixel text-sm hover:bg-gray-200 min-h-[48px]">
          🟣 Discord
        </button>
      </div>

      <div className="text-center mt-5 text-sm" style={{ color: '#888' }}>
        {isSignIn ? (
          <>No account? <a href="/register" className="font-semibold" style={{ color: '#e8a040' }}>📝 Register here</a></>
        ) : (
          <>Already have account? <a href="/login" className="font-semibold" style={{ color: '#e8a040' }}>🔑 Sign in</a></>
        )}
      </div>
    </div>
  )
}
