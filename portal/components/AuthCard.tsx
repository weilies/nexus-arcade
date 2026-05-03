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
    <div className="card-panel w-full max-w-sm border border-[#2a2a4a]">
      <div className="text-center mb-5">
        <span className="text-4xl block mb-2">{isSignIn ? '🔑' : '📝'}</span>
        <h2 className="font-pixel text-2xl font-semibold text-[#e8e8f0]">
          {isSignIn ? 'SIGN IN' : 'REGISTER'}
        </h2>
      </div>

      {error && (
        <div className="bg-[#330015] border border-[#ff2d95] rounded-xl p-3 mb-4 text-sm text-[#ff6b9d] text-center">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="flex flex-col gap-3">
        {!isSignIn && (
          <input
            className="input-field"
            placeholder="Username"
            type="text"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
          />
        )}
        <input
          className="input-field"
          placeholder="Email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <input
          className="input-field"
          placeholder="Password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          minLength={6}
        />
        <button
          type="submit"
          disabled={loading}
          className={isSignIn ? 'btn-primary' : 'btn-secondary'}
        >
          {loading ? 'PLEASE WAIT...' : isSignIn ? 'SIGN IN' : 'CREATE ACCOUNT'}
        </button>
      </form>

      <div className="text-center my-4 font-pixel text-sm text-[#666688]">OR</div>

      <div className="flex gap-3">
        <button onClick={signInWithGoogle} className="flex-1 bg-[#1a1a2e] border border-[#2a2a4a] rounded-xl py-3 px-3 font-pixel text-sm text-[#aaaacc] hover:border-[#3a3a66] hover:text-[#e8e8f0] min-h-[48px] transition-all">
          Google
        </button>
        <button onClick={signInWithDiscord} className="flex-1 bg-[#1a1a2e] border border-[#2a2a4a] rounded-xl py-3 px-3 font-pixel text-sm text-[#aaaacc] hover:border-[#3a3a66] hover:text-[#e8e8f0] min-h-[48px] transition-all">
          Discord
        </button>
      </div>

      <div className="text-center mt-5 text-sm text-[#666688]">
        {isSignIn ? (
          <>No account? <a href="/register" className="font-semibold text-[#00e5ff]">Register here</a></>
        ) : (
          <>Already have account? <a href="/login" className="font-semibold text-[#00e5ff]">Sign in</a></>
        )}
      </div>
    </div>
  )
}
