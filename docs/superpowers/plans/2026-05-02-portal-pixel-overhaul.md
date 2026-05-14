# Portal Pixel Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace dark CRT/retro-arcade theme with cute 2D pixel art Stardew+Terraria aesthetic across all portal screens.

**Architecture:** Next.js 14 App Router with Tailwind CSS 3.4. Foundation tasks (config, CSS, font, layout) come first, then leaf components (BottomTabBar, GameCard, AuthCard, ContactCard), then page rewrites consuming those components. Route cleanup happens last.

**Tech Stack:** Next.js 14.2.35, React 18, Tailwind CSS 3.4.1, Supabase SSR, Vitest + @testing-library/react

**Spec:** `docs/superpowers/specs/2026-05-02-portal-pixel-overhaul-design.md`

---

### Task 1: Tailwind Config — Meadow Palette + Pixelify Sans

**Files:**
- Modify: `portal/tailwind.config.ts`

Replace the arcade color palette with Warm Meadows palette and swap font family from Press Start 2P to Pixelify Sans.

- [ ] **Step 1: Replace tailwind config**

Replace entire file content:

```typescript
import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        meadow: {
          sky: '#87CEEB',
          grass: '#82c45d',
          wheat: '#f4d03f',
          earth: '#8B5E3C',
          dark: '#5a3a1f',
          cream: '#FFF8EB',
          pink: '#f7d4d4',
        },
        amber: {
          light: '#e8a040',
          DEFAULT: '#c07a20',
          dark: '#8B5E3C',
        },
        ui: {
          card: '#FFFFFF',
          panel: 'rgba(255,248,235,0.92)',
          muted: '#aaa',
          border: '#e0d5c0',
        },
      },
      fontFamily: {
        pixel: ['"Pixelify Sans"', 'sans-serif'],
      },
      borderRadius: {
        card: '16px',
        btn: '14px',
        input: '12px',
      },
      boxShadow: {
        card: '0 3px 12px rgba(139,94,60,0.2)',
        btn: '0 4px 0 #8B5E3C',
      },
    },
  },
  plugins: [],
}
export default config
```

- [ ] **Step 2: Commit**

```bash
git add portal/tailwind.config.ts
git commit -m "feat: replace arcade palette with Warm Meadows + Pixelify Sans in Tailwind config"
```

---

### Task 2: Global CSS Rewrite — Remove CRT, Add Meadow Theme

**Files:**
- Modify: `portal/app/globals.css`

Remove all scanline overlays, CRT borders, glow utilities, pixel button styles, marquee/dither/blink. Replace with meadow theme: Pixelify Sans import, rounded utility classes, gradient button styles, background base.

- [ ] **Step 1: Replace globals.css**

Replace entire file content:

```css
@import url('https://fonts.googleapis.com/css2?family=Pixelify+Sans:wght@400..700&display=swap');
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --meadow-sky: #87CEEB;
  --meadow-grass: #82c45d;
  --meadow-wheat: #f4d03f;
  --meadow-earth: #8B5E3C;
  --meadow-dark: #5a3a1f;
  --meadow-cream: #FFF8EB;
  --amber-light: #e8a040;
  --amber: #c07a20;
}

html, body {
  background: var(--meadow-dark);
  color: var(--meadow-dark);
  font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
  overflow-x: hidden;
}

*:focus-visible {
  outline: 2px solid var(--amber-light);
  outline-offset: 2px;
}

/* Rounded card base */
.card-panel {
  background: rgba(255,248,235,0.93);
  border-radius: 16px;
  padding: 20px;
}

/* Primary CTA button — amber gradient */
.btn-primary {
  display: block;
  width: 100%;
  background: linear-gradient(180deg, #e8a040, #c07a20);
  color: white;
  border-radius: 14px;
  padding: 14px;
  text-align: center;
  font-family: 'Pixelify Sans', sans-serif;
  font-size: 17px;
  font-weight: 600;
  box-shadow: 0 4px 0 #8B5E3C;
  cursor: pointer;
  border: none;
  text-decoration: none;
  min-height: 48px;
}
.btn-primary:hover {
  background: linear-gradient(180deg, #f0a848, #c88028);
}
.btn-primary:active {
  transform: translateY(2px);
  box-shadow: 0 2px 0 #8B5E3C;
}

/* Secondary button — green */
.btn-secondary {
  display: inline-block;
  background: #82c45d;
  color: white;
  border-radius: 14px;
  padding: 12px 22px;
  font-family: 'Pixelify Sans', sans-serif;
  font-size: 16px;
  font-weight: 500;
  box-shadow: 0 4px 0 #5a8a3d;
  cursor: pointer;
  border: none;
  text-decoration: none;
  min-height: 48px;
}
.btn-secondary:hover {
  background: #8fd068;
}
.btn-secondary:active {
  transform: translateY(2px);
  box-shadow: 0 2px 0 #5a8a3d;
}

/* Form inputs */
.input-field {
  padding: 14px;
  border: 2px solid #e0d5c0;
  border-radius: 12px;
  font-size: 15px;
  width: 100%;
  box-sizing: border-box;
  font-family: system-ui, -apple-system, sans-serif;
  min-height: 48px;
}
.input-field:focus {
  outline: none;
  border-color: #e8a040;
}

/* Scrollbar */
::-webkit-scrollbar { width: 8px; background: #5a3a1f; }
::-webkit-scrollbar-thumb { background: #8B5E3C; border-radius: 4px; }
::-webkit-scrollbar-thumb:hover { background: #e8a040; }
```

- [ ] **Step 2: Commit**

```bash
git add portal/app/globals.css
git commit -m "feat: replace CRT/scanline theme with Warm Meadows rounded UI styles"
```

---

### Task 3: Data Layer — Add getAllLiveGames Query

**Files:**
- Modify: `portal/lib/data/games.ts`

Add a new function to fetch all live games for the `/games` listing page.

- [ ] **Step 1: Add getAllLiveGames function**

Append after `getFeaturedGame()` (line 31):

```typescript
export async function getAllLiveGames(): Promise<Game[]> {
  const supabase = createClient()
  const { data } = await supabase
    .from('games')
    .select('*')
    .eq('status', 'live')
    .order('launched_at', { ascending: true })
  return data ?? []
}
```

- [ ] **Step 2: Commit**

```bash
git add portal/lib/data/games.ts
git commit -m "feat: add getAllLiveGames query for games listing page"
```

---

### Task 4: BottomTabBar Component

**Files:**
- Create: `portal/components/BottomTabBar.tsx`
- Create: `portal/components/__tests__/BottomTabBar.test.tsx`
- Delete: `portal/components/__tests__/Nav.test.tsx`

Bottom tab bar with 4 tabs (Home, Games, Contact, Sign In). Fixed to bottom on mobile, centered top bar on desktop. Hidden on game play screen via `hideOn` prop.

- [ ] **Step 1: Create BottomTabBar component**

```typescript
import Link from 'next/link'
import { usePathname } from 'next/navigation'

const TABS = [
  { href: '/', label: 'HOME', icon: '🏠' },
  { href: '/games', label: 'GAMES', icon: '🕹️' },
  { href: '/contact', label: 'CONTACT', icon: '📧' },
  { href: '/login', label: 'SIGN IN', icon: '👤' },
] as const

interface BottomTabBarProps {
  hideOn?: string[]
}

export function BottomTabBar({ hideOn = [] }: BottomTabBarProps) {
  const pathname = usePathname()

  if (hideOn.includes(pathname)) return null

  const isActive = (href: string) => {
    if (href === '/') return pathname === '/'
    return pathname.startsWith(href)
  }

  return (
    <>
      {/* Mobile: fixed bottom bar */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 z-50 flex justify-around py-3 px-2"
           style={{ background: 'rgba(90,58,31,0.96)' }}>
        {TABS.map((tab) => {
          const active = isActive(tab.href)
          return (
            <Link key={tab.href} href={tab.href} className="flex flex-col items-center gap-0.5 min-w-[64px] min-h-[48px] justify-center">
              <span className="text-2xl" style={{ opacity: active ? 1 : 0.5 }}>{tab.icon}</span>
              <span
                className="font-pixel text-xs font-semibold"
                style={{ color: active ? '#f4d03f' : 'rgba(244,208,63,0.45)' }}
              >
                {tab.label}
              </span>
            </Link>
          )
        })}
      </nav>

      {/* Desktop: centered top bar */}
      <nav className="hidden md:flex justify-center gap-8 py-4 px-4"
           style={{ background: 'rgba(90,58,31,0.96)' }}>
        {TABS.map((tab) => {
          const active = isActive(tab.href)
          return (
            <Link key={tab.href} href={tab.href} className="flex items-center gap-2 px-4 py-2 min-h-[48px]">
              <span className="text-xl" style={{ opacity: active ? 1 : 0.5 }}>{tab.icon}</span>
              <span
                className="font-pixel text-sm font-semibold"
                style={{ color: active ? '#f4d03f' : 'rgba(244,208,63,0.45)' }}
              >
                {tab.label}
              </span>
            </Link>
          )
        })}
      </nav>
    </>
  )
}
```

- [ ] **Step 2: Create test file**

```typescript
import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { BottomTabBar } from '../BottomTabBar'

vi.mock('next/navigation', () => ({
  usePathname: () => '/',
}))

describe('BottomTabBar', () => {
  it('renders all 4 tabs', () => {
    render(<BottomTabBar />)
    expect(screen.getByText('HOME')).toBeDefined()
    expect(screen.getByText('GAMES')).toBeDefined()
    expect(screen.getByText('CONTACT')).toBeDefined()
    expect(screen.getByText('SIGN IN')).toBeDefined()
  })

  it('hides when current path is in hideOn', () => {
    const { container } = render(<BottomTabBar hideOn={['/']} />)
    expect(container.firstChild).toBeNull()
  })
})
```

- [ ] **Step 3: Run tests**

```bash
npx vitest run portal/components/__tests__/BottomTabBar.test.tsx
```

Expected: PASS

- [ ] **Step 4: Delete old Nav test**

Delete file `portal/components/__tests__/Nav.test.tsx`.

- [ ] **Step 5: Commit**

```bash
git add portal/components/BottomTabBar.tsx portal/components/__tests__/BottomTabBar.test.tsx
git rm portal/components/__tests__/Nav.test.tsx
git commit -m "feat: add BottomTabBar component with tests, remove Nav test"
```

---

### Task 5: Layout Update — Font + Background + BottomTabBar

**Files:**
- Modify: `portal/app/layout.tsx`

Integrate BottomTabBar into root layout. Update metadata. Remove old `bg-arcade-bg` class.

- [ ] **Step 1: Rewrite layout.tsx**

Replace entire file content:

```typescript
import type { Metadata } from 'react'
import './globals.css'
import { BottomTabBar } from '@/components/BottomTabBar'

export const metadata: Metadata = {
  title: 'Nexus Arcade',
  description: 'Casual games. Compete. Conquer.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen flex flex-col" style={{ background: '#5a3a1f' }}>
        <BottomTabBar hideOn={['/games/tictactoe']} />
        <main className="flex-1 pb-16 md:pb-0">
          {children}
        </main>
      </body>
    </html>
  )
}
```

Note: The `hideOn` array uses a hardcoded slug. After the `/games` listing page and specific game routes, the path `/games/tictactoe` matches the game play page. For a future-proof approach, this should use a path pattern check (`/games/[slug]` where slug is an actual game, not the listing page), but the simple approach works for now with the single live game.

- [ ] **Step 2: Commit**

```bash
git add portal/app/layout.tsx
git commit -m "feat: integrate BottomTabBar into layout, update metadata and body background"
```

---

### Task 6: GameCard Revision — Rounded + Pixelify Sans

**Files:**
- Modify: `portal/components/GameCard.tsx`
- Modify: `portal/components/__tests__/GameCard.test.tsx`

Redesign GameCard with rounded corners, 64x64 icon area, Pixelify Sans title, amber border, white card background.

- [ ] **Step 1: Rewrite GameCard.tsx**

Replace entire file content:

```typescript
import Link from 'next/link'

interface GameCardProps {
  slug: string
  name: string
  thumbnailUrl?: string
  compact?: boolean
}

export function GameCard({ slug, name, thumbnailUrl, compact = false }: GameCardProps) {
  if (compact) {
    return (
      <Link href={`/games/${slug}`}
            className="flex items-center gap-4 bg-white rounded-card p-4 border-2 border-meadow-wheat shadow-card hover:shadow-md transition-shadow">
        <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl flex-shrink-0"
             style={{ background: '#f7d4d4' }}>
          {thumbnailUrl ? <img src={thumbnailUrl} alt={name} className="w-full h-full object-cover rounded-2xl" /> : '🎮'}
        </div>
        <div className="flex-1 min-w-0">
          <div className="font-pixel text-xl font-semibold text-meadow-dark truncate">{name}</div>
          <div className="text-sm text-meadow-earth mt-0.5">🎮 Classic battle</div>
        </div>
        <span className="text-2xl flex-shrink-0">▶️</span>
      </Link>
    )
  }

  return (
    <div className="bg-white rounded-card p-4 border-2 border-amber-light shadow-card">
      <div className="flex items-center gap-4">
        <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl"
             style={{ background: '#f7d4d4' }}>
          {thumbnailUrl ? <img src={thumbnailUrl} alt={name} className="w-full h-full object-cover rounded-2xl" /> : '🎮'}
        </div>
        <div>
          <div className="font-pixel text-xl font-semibold text-meadow-dark">{name}</div>
          <div className="text-sm text-meadow-earth mt-0.5">🎮 Classic battle</div>
        </div>
      </div>
      <Link href={`/games/${slug}`}
            className="btn-primary mt-4 block text-center">
        ▶ PLAY NOW
      </Link>
    </div>
  )
}
```

- [ ] **Step 2: Update GameCard test**

Replace entire file content:

```typescript
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { GameCard } from '../GameCard'

describe('GameCard', () => {
  it('renders game name', () => {
    render(<GameCard slug="test-game" name="Test Game" />)
    expect(screen.getByText('Test Game')).toBeDefined()
  })

  it('renders play button linking to game page', () => {
    render(<GameCard slug="test-game" name="Test Game" />)
    const link = screen.getByText('▶ PLAY NOW').closest('a')
    expect(link?.getAttribute('href')).toBe('/games/test-game')
  })

  it('renders compact variant without play button', () => {
    render(<GameCard slug="test-game" name="Test Game" compact />)
    expect(screen.queryByText('▶ PLAY NOW')).toBeNull()
    const link = screen.getByText('Test Game').closest('a')
    expect(link?.getAttribute('href')).toBe('/games/test-game')
  })
})
```

- [ ] **Step 3: Run tests**

```bash
npx vitest run portal/components/__tests__/GameCard.test.tsx
```

Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add portal/components/GameCard.tsx portal/components/__tests__/GameCard.test.tsx
git commit -m "feat: redesign GameCard with rounded corners, Pixelify Sans, compact variant"
```

---

### Task 7: AuthCard Component — Shared Sign In / Register

**Files:**
- Create: `portal/components/AuthCard.tsx`
- Create: `portal/components/__tests__/AuthCard.test.tsx`

Shared auth form component. Props: `mode: 'signin' | 'register'`. Handles email/password fields, Google/Discord SSO buttons, form submission to Supabase.

- [ ] **Step 1: Create AuthCard component**

```typescript
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
```

- [ ] **Step 2: Create test file**

```typescript
import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { AuthCard } from '../AuthCard'

vi.mock('@/lib/supabase/browser', () => ({
  createClient: () => ({
    auth: {
      signInWithPassword: vi.fn(),
      signUp: vi.fn(),
      signInWithOAuth: vi.fn(),
    },
  }),
}))

describe('AuthCard', () => {
  it('renders sign in form when mode is signin', () => {
    render(<AuthCard mode="signin" />)
    expect(screen.getByText('SIGN IN')).toBeDefined()
    expect(screen.getByPlaceholderText('📧 Email')).toBeDefined()
    expect(screen.getByPlaceholderText('🔒 Password')).toBeDefined()
  })

  it('renders register form when mode is register', () => {
    render(<AuthCard mode="register" />)
    expect(screen.getByText('REGISTER')).toBeDefined()
    expect(screen.getByPlaceholderText('👤 Username')).toBeDefined()
    expect(screen.getByPlaceholderText('📧 Email')).toBeDefined()
    expect(screen.getByPlaceholderText('🔒 Password')).toBeDefined()
  })

  it('renders Google and Discord SSO buttons', () => {
    render(<AuthCard mode="signin" />)
    expect(screen.getByText('🔵 Google')).toBeDefined()
    expect(screen.getByText('🟣 Discord')).toBeDefined()
  })

  it('shows register link in signin mode', () => {
    render(<AuthCard mode="signin" />)
    const link = screen.getByText('📝 Register here')
    expect(link.closest('a')?.getAttribute('href')).toBe('/register')
  })

  it('shows sign in link in register mode', () => {
    render(<AuthCard mode="register" />)
    const link = screen.getByText('🔑 Sign in')
    expect(link.closest('a')?.getAttribute('href')).toBe('/login')
  })
})
```

- [ ] **Step 3: Run tests**

```bash
npx vitest run portal/components/__tests__/AuthCard.test.tsx
```

Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add portal/components/AuthCard.tsx portal/components/__tests__/AuthCard.test.tsx
git commit -m "feat: add AuthCard component with email/password + Google/Discord SSO"
```

---

### Task 8: Home Page Rewrite

**Files:**
- Modify: `portal/app/page.tsx`

Complete rewrite. Pixel art background placeholder (solid meadow gradient until Leonardo.ai art ready), semi-transparent content panel, castle emoji + "NEXUS ARCADE" heading, featured game card, "More Games" button. Removes SeasonBanner, LeaderboardWidget, marquee footer imports.

- [ ] **Step 1: Rewrite home page**

Replace entire file content:

```typescript
import { GameCard } from '@/components/GameCard'
import { getFeaturedGame } from '@/lib/data/games'
import Link from 'next/link'

export default async function HomePage() {
  const game = await getFeaturedGame()

  return (
    <div
      className="min-h-screen flex flex-col items-center justify-center px-4 py-8"
      style={{
        background: 'linear-gradient(180deg, #87CEEB 0%, #82c45d 40%, #f4d03f 70%, #8B5E3C 100%)',
      }}
    >
      <div className="card-panel w-full max-w-sm">
        {/* Hero */}
        <div className="text-center mb-5">
          <div className="text-5xl">🏰</div>
          <h1 className="font-pixel text-2xl font-bold text-meadow-dark mt-2">NEXUS ARCADE</h1>
          <p className="font-pixel text-base text-meadow-earth mt-1">🎮 Casual games. Compete. Conquer.</p>
        </div>

        {/* Featured game */}
        {game ? (
          <GameCard slug={game.slug} name={game.name} />
        ) : (
          <div className="bg-white rounded-card p-6 border-2 border-meadow-wheat shadow-card text-center">
            <div className="text-4xl mb-3">🎮</div>
            <div className="font-pixel text-lg text-ui-muted">No games live yet</div>
            <div className="text-sm text-meadow-earth mt-1">Check back soon!</div>
          </div>
        )}

        {/* More Games link */}
        <div className="text-center mt-4">
          <Link href="/games" className="btn-secondary inline-block">
            🕹️ MORE GAMES
          </Link>
        </div>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add portal/app/page.tsx
git commit -m "feat: rewrite home page with meadow theme, pixel art background, featured game"
```

---

### Task 9: Games Listing Page — New `/games` Route

**Files:**
- Create: `portal/app/games/page.tsx`

Simple loop fetching all live games. Each game as compact GameCard. Empty state with "Coming Soon" placeholder.

- [ ] **Step 1: Create games listing page**

```typescript
import { getAllLiveGames } from '@/lib/data/games'
import { GameCard } from '@/components/GameCard'

export default async function GamesPage() {
  const games = await getAllLiveGames()

  return (
    <div
      className="min-h-screen flex flex-col items-center px-4 py-8"
      style={{
        background: 'linear-gradient(180deg, #87CEEB 0%, #82c45d 40%, #f4d03f 70%, #8B5E3C 100%)',
      }}
    >
      <div className="card-panel w-full max-w-sm">
        <div className="text-center mb-5">
          <div className="text-4xl">🕹️</div>
          <h1 className="font-pixel text-2xl font-bold text-meadow-dark mt-2">GAMES</h1>
          <p className="font-pixel text-base text-meadow-earth mt-1">Pick your adventure!</p>
        </div>

        {games.length > 0 ? (
          <div className="flex flex-col gap-3">
            {games.map((game) => (
              <GameCard key={game.id} slug={game.slug} name={game.name} compact />
            ))}
          </div>
        ) : (
          <div className="flex flex-col gap-3">
            <div className="flex items-center gap-4 bg-white rounded-card p-4 border-2 border-meadow-wheat shadow-card opacity-50">
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl flex-shrink-0"
                   style={{ background: '#d4e7f7' }}>
                ❓
              </div>
              <div className="flex-1">
                <div className="font-pixel text-xl font-semibold" style={{ color: '#bbb' }}>Coming Soon</div>
                <div className="text-sm" style={{ color: '#bbb' }}>🕹️ More games on the way</div>
              </div>
              <span className="text-sm font-pixel" style={{ color: '#ccc' }}>SOON</span>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add portal/app/games/page.tsx
git commit -m "feat: add games listing page with live game loop and empty state"
```

---

### Task 10: Contact Page — New `/contact` Route

**Files:**
- Create: `portal/app/contact/page.tsx`

Two external action buttons: Facebook link + Email mailto link. Placeholder URLs — user provides real values.

- [ ] **Step 1: Create contact page**

```typescript
export default function ContactPage() {
  return (
    <div
      className="min-h-screen flex flex-col items-center px-4 py-8"
      style={{
        background: 'linear-gradient(180deg, #87CEEB 0%, #82c45d 40%, #f4d03f 70%, #8B5E3C 100%)',
      }}
    >
      <div className="card-panel w-full max-w-sm">
        <div className="text-center mb-5">
          <div className="text-4xl">📧</div>
          <h1 className="font-pixel text-2xl font-bold text-meadow-dark mt-2">CONTACT</h1>
          <p className="font-pixel text-base text-meadow-earth mt-1">Get in touch!</p>
        </div>

        <div className="flex flex-col gap-3">
          <a
            href="https://facebook.com/YOUR_PROFILE"
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary text-center"
            style={{ background: 'linear-gradient(180deg, #4267B2, #365899)', boxShadow: '0 4px 0 #29487d' }}
          >
            📘 Facebook
          </a>
          <a
            href="mailto:hello@nexusarcade.com"
            className="btn-primary text-center"
          >
            ✉️ hello@nexusarcade.com
          </a>
        </div>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add portal/app/contact/page.tsx
git commit -m "feat: add contact page with Facebook and email buttons"
```

---

### Task 11: Login Page Rewrite — Email/Password + SSO

**Files:**
- Modify: `portal/app/login/page.tsx`

Replace SSO-only login with AuthCard component using `mode="signin"`.

- [ ] **Step 1: Rewrite login page**

Replace entire file content:

```typescript
import { AuthCard } from '@/components/AuthCard'
import { Suspense } from 'react'

function LoginContent() {
  return (
    <div
      className="min-h-screen flex flex-col items-center justify-center px-4 py-8"
      style={{
        background: 'linear-gradient(180deg, #87CEEB 0%, #82c45d 40%, #f4d03f 70%, #8B5E3C 100%)',
      }}
    >
      <AuthCard mode="signin" />
    </div>
  )
}

export default function LoginPage() {
  return (
    <Suspense fallback={null}>
      <LoginContent />
    </Suspense>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add portal/app/login/page.tsx
git commit -m "feat: rewrite login page with email/password auth + SSO via AuthCard"
```

---

### Task 12: Register Page — New `/register` Route

**Files:**
- Create: `portal/app/register/page.tsx`

New registration page using AuthCard with `mode="register"`.

- [ ] **Step 1: Create register page**

```typescript
import { AuthCard } from '@/components/AuthCard'

export default function RegisterPage() {
  return (
    <div
      className="min-h-screen flex flex-col items-center justify-center px-4 py-8"
      style={{
        background: 'linear-gradient(180deg, #87CEEB 0%, #82c45d 40%, #f4d03f 70%, #8B5E3C 100%)',
      }}
    >
      <AuthCard mode="register" />
    </div>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add portal/app/register/page.tsx
git commit -m "feat: add registration page with email signup via AuthCard"
```

---

### Task 13: GameFrame Minimal Update — Font + Colors

**Files:**
- Modify: `portal/components/GameFrame.tsx`

Update title bar to use Pixelify Sans and meadow colors. Everything else stays the same.

- [ ] **Step 1: Update GameFrame title bar styles**

Replace lines 44-48 (the title bar div):

The old code:
```tsx
      <div className="font-pixel text-arcade-amber text-[8px] tracking-widest py-2 px-4 text-center border-b border-arcade-amber flex items-center justify-between"
           style={{ background: '#0d0a00', boxShadow: '0 2px 0 #7a5500, 0 4px 12px #ffb30022' }}>
        <span className="text-arcade-dim text-[7px]">◄ NEXUS ARCADE</span>
        <span className="text-glow-amber">▶ {gameName.toUpperCase()}</span>
        <span className="text-arcade-green text-[7px] text-glow-green">● LIVE</span>
      </div>
```

Replace with:
```tsx
      <div className="font-pixel text-sm tracking-wide py-2 px-4 text-center border-b flex items-center justify-between"
           style={{ background: '#5a3a1f', color: '#FFF8EB', borderColor: '#8B5E3C', boxShadow: '0 2px 8px rgba(0,0,0,0.3)' }}>
        <span className="text-xs opacity-60">◄ NEXUS ARCADE</span>
        <span className="font-semibold">▶ {gameName.toUpperCase()}</span>
        <span className="text-xs font-semibold" style={{ color: '#82c45d' }}>● LIVE</span>
      </div>
```

- [ ] **Step 2: Commit**

```bash
git add portal/components/GameFrame.tsx
git commit -m "feat: update GameFrame title bar to Pixelify Sans + meadow colors"
```

---

### Task 14: Game Play + Leaderboard Page Updates

**Files:**
- Modify: `portal/app/games/[slug]/page.tsx`
- Modify: `portal/app/leaderboard/[slug]/page.tsx`

Replace Nav import with nothing (layout provides BottomTabBar). Apply new theme classes.

- [ ] **Step 1: Update game play page**

Replace entire file content of `portal/app/games/[slug]/page.tsx`:

```typescript
import { notFound } from 'next/navigation'
import { getGameBySlug } from '@/lib/data/games'
import { GameFrame } from '@/components/GameFrame'

interface Props {
  params: { slug: string }
  searchParams: { match?: string }
}

export default async function GamePage({ params, searchParams }: Props) {
  const game = await getGameBySlug(params.slug)
  if (!game || game.status !== 'live') notFound()

  return (
    <div className="h-screen flex flex-col overflow-hidden" style={{ background: '#5a3a1f' }}>
      <div className="flex-1 flex flex-col">
        <GameFrame
          slug={params.slug}
          gameName={game.name}
          matchId={searchParams.match}
        />
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Update leaderboard page**

Replace entire file content of `portal/app/leaderboard/[slug]/page.tsx`:

```typescript
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
```

- [ ] **Step 3: Commit**

```bash
git add portal/app/games/[slug]/page.tsx portal/app/leaderboard/[slug]/page.tsx
git commit -m "feat: apply meadow theme to game play and leaderboard pages, remove Nav dependency"
```

---

### Task 15: Route Cleanup — Remove Stub Routes + Old Nav Component

**Files:**
- Delete: `portal/app/seasons/page.tsx`
- Delete: `portal/app/profile/[username]/page.tsx`
- Delete: `portal/components/Nav.tsx`
- Delete: `portal/components/SeasonBanner.tsx`
- Delete: `portal/components/LeaderboardWidget.tsx`
- Delete: `portal/components/__tests__/SeasonBanner.test.tsx`
- Delete: `portal/components/__tests__/LeaderboardWidget.test.tsx`

Remove stub pages that are out of scope for this overhaul. Remove Nav component (replaced by BottomTabBar). Remove components no longer used.

- [ ] **Step 1: Delete all files**

```bash
git rm portal/app/seasons/page.tsx
git rm portal/app/profile/\[username\]/page.tsx
git rm portal/components/Nav.tsx
git rm portal/components/SeasonBanner.tsx
git rm portal/components/LeaderboardWidget.tsx
git rm portal/components/__tests__/SeasonBanner.test.tsx
git rm portal/components/__tests__/LeaderboardWidget.test.tsx
```

- [ ] **Step 2: Remove empty directories if needed**

```bash
if (Test-Path "portal/app/seasons") { Remove-Item "portal/app/seasons" -Force }
if (Test-Path "portal/app/profile") { Remove-Item "portal/app/profile" -Recurse -Force }
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat: remove stub routes (/seasons, /profile), old Nav, unused components"
```

---

### Task 16: Final Verification — Build + Test

**Files:**
- None (verification only)

Run full test suite and build to verify no breakage.

- [ ] **Step 1: Run all tests**

```bash
npx vitest run
```

Expected: All tests PASS.

- [ ] **Step 2: Run Next.js build**

```bash
npx next build
```

Expected: Successful build with no errors. May have warnings about unused CSS classes from old arcade theme — that's expected until all references are cleaned up.

- [ ] **Step 3: Fix any build errors**

If build fails, fix the issues. If tests fail, fix the issues. Do not proceed until clean.

- [ ] **Step 4: Final commit (if any fixes were needed)**

```bash
git add -A
git commit -m "chore: fix build/test issues from portal overhaul"
```

---

## Manual Steps (Not Automated)

These must be done by the user outside of code:

1. **Generate background images via Leonardo.ai** — Use prompts from spec. Save to `portal/public/bg/` as:
   - `home-bg.png`
   - `games-bg.png`
   - `contact-bg.png`
   - `signin-bg.png`
   - `register-bg.png`

2. **Update background references** — After images are generated, replace the inline `linear-gradient` backgrounds on each page with actual images:
   ```css
   background: url('/bg/home-bg.png') center/cover no-repeat;
   ```

3. **Enable Email auth in Supabase dashboard** — Authentication → Providers → Email → Enable

4. **Update Contact page URLs** — Replace `YOUR_PROFILE` and `hello@nexusarcade.com` with real values

5. **Configure Google + Discord OAuth in Supabase** — Already configured for existing SSO flow (should still work)

6. **Update layout `hideOn`** — When new game slugs are added, update the `hideOn` array in `layout.tsx` to hide BottomTabBar on those game play pages
