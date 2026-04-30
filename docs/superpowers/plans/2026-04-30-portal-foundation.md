# Nexus Arcade — Plan 1 of 3: Portal Foundation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** NextJS portal with Supabase backend, retro pixel theme, auth, homepage, and game iframe page — fully deployable to Railway. No game content required.

**Architecture:** Next.js 14 App Router. Server components for data fetching (homepage, leaderboard). Client components for interactivity (bridge, auth). Supabase SSR for session management via middleware. postMessage bridge wired in `GameFrame` client component. Score submission via Next.js API route using service role key (server-side anti-cheat gate).

**Tech Stack:** Next.js 14, TypeScript, Tailwind CSS v3, @supabase/ssr, @supabase/supabase-js, Vitest, @testing-library/react, jsdom

**Plans 2 and 3:** Plan 2 = Ultimate TTT Godot game. Plan 3 = full leaderboard, seasons, achievements pages.

---

## File Map

Files created in this plan:

```
nexus-arcade/
  .gitignore
  portal/
    next.config.js
    tailwind.config.ts
    vitest.config.ts
    vitest.setup.ts
    package.json                               ← scaffold output, modified
    middleware.ts
    app/
      layout.tsx                               ← root layout + global styles
      globals.css
      page.tsx                                 ← homepage (split play/leaderboard)
      login/page.tsx
      auth/callback/route.ts
      games/[slug]/page.tsx
      leaderboard/[slug]/page.tsx
      profile/[username]/page.tsx
      seasons/page.tsx
      api/scores/route.ts
    components/
      Nav.tsx
      GameCard.tsx
      LeaderboardWidget.tsx
      SeasonBanner.tsx
      GameFrame.tsx                            ← client component, iframe + bridge
      __tests__/
        Nav.test.tsx
        GameCard.test.tsx
        LeaderboardWidget.test.tsx
        SeasonBanner.test.tsx
    lib/
      supabase/
        server.ts
        browser.ts
      bridge.ts
      data/
        games.ts
        leaderboard.ts
        seasons.ts
      __tests__/
        bridge.test.ts
  supabase/
    migrations/
      001_initial_schema.sql
      002_seed_games.sql
```

---

## Task 1: Git init + root .gitignore

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Init repo**

```bash
cd C:/Projects/claude/nexus-arcade
git init
```

Expected: `Initialized empty Git repository in ...`

- [ ] **Step 2: Create .gitignore**

```
# Node
node_modules/
.next/
.env.local
.env*.local

# Godot
games/*/web-export/
games/*/.godot/
*.import

# Build artifacts
portal/public/games/

# Superpowers brainstorm
.superpowers/

# OS
.DS_Store
Thumbs.db
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore CLAUDE.md docs/
git commit -m "chore: init repo with spec, GDD template, gitignore"
```

---

## Task 2: Supabase cloud project + schema

**Files:**
- Create: `supabase/migrations/001_initial_schema.sql`
- Create: `supabase/migrations/002_seed_games.sql`

- [ ] **Step 1: Create Supabase project**

Go to https://supabase.com/dashboard → New project. Name: `nexus-arcade`. Note the Project URL and anon key — needed in Task 5.

- [ ] **Step 2: Write migration SQL**

Create `supabase/migrations/001_initial_schema.sql`:

```sql
create extension if not exists "uuid-ossp";

create table public.users (
  id uuid primary key default gen_random_uuid(),
  username text unique not null,
  avatar_url text,
  discord_id text,
  created_at timestamptz default now()
);

create table public.games (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  status text not null default 'coming_soon'
    check (status in ('coming_soon', 'live', 'retired')),
  launched_at date
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games(id),
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  prize_label text not null
);

create table public.scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  game_id uuid not null references public.games(id),
  season_id uuid references public.seasons(id),
  score integer not null check (score >= 0 and score <= 1000000),
  mode text not null check (mode in ('solo', 'local', 'online')),
  created_at timestamptz default now()
);

create table public.achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  game_id uuid not null references public.games(id),
  type text not null,
  label text not null,
  awarded_at timestamptz default now()
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games(id),
  player1_id uuid not null references public.users(id),
  player2_id uuid references public.users(id),
  winner_id uuid references public.users(id),
  mode text not null check (mode in ('solo', 'local', 'online')),
  created_at timestamptz default now()
);

-- Indexes
create index scores_game_score_idx on public.scores(game_id, score desc);
create index scores_user_idx on public.scores(user_id);
create index seasons_game_idx on public.seasons(game_id);
create index matches_game_idx on public.matches(game_id);

-- RLS
alter table public.users enable row level security;
alter table public.games enable row level security;
alter table public.scores enable row level security;
alter table public.seasons enable row level security;
alter table public.achievements enable row level security;
alter table public.matches enable row level security;

create policy "public read games" on public.games for select using (true);
create policy "public read scores" on public.scores for select using (true);
create policy "public read seasons" on public.seasons for select using (true);
create policy "public read achievements" on public.achievements for select using (true);
create policy "public read matches" on public.matches for select using (true);
create policy "public read users" on public.users for select using (true);
create policy "users update own" on public.users for update using (auth.uid() = id);
create policy "auth insert matches" on public.matches
  for insert with check (auth.uid() = player1_id);

-- Sync auth.users → public.users on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, username, avatar_url)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(new.email, '@', 1)
    ),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
```

- [ ] **Step 3: Write seed SQL**

Create `supabase/migrations/002_seed_games.sql`:

```sql
insert into public.games (slug, name, status, launched_at)
values ('ultimate-ttt', 'Ultimate Tic Tac Toe', 'live', '2026-05-01')
on conflict (slug) do nothing;

insert into public.seasons (game_id, name, starts_at, ends_at, prize_label)
values (
  (select id from public.games where slug = 'ultimate-ttt'),
  'Q2 2026',
  '2026-04-01T00:00:00Z',
  '2026-06-30T23:59:59Z',
  'Q2 2026 Champion'
);
```

- [ ] **Step 4: Apply migrations**

In Supabase dashboard → SQL editor. Paste and run `001_initial_schema.sql` first, then `002_seed_games.sql`.

Expected: No errors. Tables visible in Table Editor.

- [ ] **Step 5: Enable Discord OAuth**

Supabase dashboard → Authentication → Providers → Discord. Enable it. Add a Discord OAuth app at https://discord.com/developers (redirect URI: `https://<your-supabase-url>/auth/v1/callback`). Paste Client ID and Client Secret into Supabase.

- [ ] **Step 6: Commit migrations**

```bash
git add supabase/
git commit -m "feat: add initial schema migrations and game seed"
```

---

## Task 3: NextJS scaffold

**Files:**
- Create: `portal/` (entire NextJS project)

- [ ] **Step 1: Scaffold**

```bash
cd C:/Projects/claude/nexus-arcade
npx create-next-app@14 portal --typescript --tailwind --app --no-src-dir --import-alias "@/*" --no-eslint
```

Expected: Portal directory created, `npm run dev` works.

- [ ] **Step 2: Install dependencies**

```bash
cd portal
npm install @supabase/ssr @supabase/supabase-js
npm install -D vitest @vitejs/plugin-react @testing-library/react @testing-library/user-event jsdom @types/testing-library__jest-dom
```

- [ ] **Step 3: Verify dev server**

```bash
npm run dev
```

Expected: `ready - started server on http://localhost:3000`. Open browser, see default Next.js page.

Stop the server (`Ctrl+C`).

- [ ] **Step 4: Commit**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/
git commit -m "feat: scaffold NextJS portal with Supabase and Vitest dependencies"
```

---

## Task 4: Tailwind retro pixel theme

**Files:**
- Modify: `portal/tailwind.config.ts`
- Modify: `portal/app/globals.css`

- [ ] **Step 1: Update tailwind config**

Replace contents of `portal/tailwind.config.ts`:

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
        arcade: {
          bg: '#1a0a2e',
          panel: '#2d1b4e',
          border: '#3b1f5e',
          gold: '#fbbf24',
          violet: '#7c3aed',
          pink: '#ec4899',
          purple: '#a78bfa',
          dim: '#4b2d7e',
          green: '#4ade80',
          cyan: '#06b6d4',
        },
      },
      fontFamily: {
        mono: ['Courier New', 'Courier', 'monospace'],
      },
    },
  },
  plugins: [],
}
export default config
```

- [ ] **Step 2: Update globals.css**

Replace contents of `portal/app/globals.css`:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --bg: #1a0a2e;
}

body {
  background-color: var(--bg);
  color: #e2e8f0;
}

/* Pixel-style focus ring */
*:focus-visible {
  outline: 2px solid #fbbf24;
  outline-offset: 2px;
}

/* Pixel border utility */
.pixel-border {
  border: 2px solid #fbbf24;
  border-radius: 0;
}
```

- [ ] **Step 3: Update root layout**

Replace `portal/app/layout.tsx`:

```tsx
import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'NEXUS ARCADE',
  description: 'Casual games. Compete. Conquer.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-arcade-bg antialiased">{children}</body>
    </html>
  )
}
```

- [ ] **Step 4: Commit**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/tailwind.config.ts portal/app/globals.css portal/app/layout.tsx
git commit -m "feat: retro pixel theme — arcade colors and monospace fonts"
```

---

## Task 5: Supabase client libs + middleware + env

**Files:**
- Create: `portal/lib/supabase/server.ts`
- Create: `portal/lib/supabase/browser.ts`
- Create: `portal/middleware.ts`
- Create: `portal/.env.local`

- [ ] **Step 1: Create server client**

Create `portal/lib/supabase/server.ts`:

```typescript
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export function createClient() {
  const cookieStore = cookies()
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {}
        },
      },
    }
  )
}
```

- [ ] **Step 2: Create browser client**

Create `portal/lib/supabase/browser.ts`:

```typescript
import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}
```

- [ ] **Step 3: Create middleware**

Create `portal/middleware.ts`:

```typescript
import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          )
          supabaseResponse = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  await supabase.auth.getUser()
  return supabaseResponse
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
```

- [ ] **Step 4: Create .env.local**

Create `portal/.env.local` (fill in values from Supabase dashboard → Settings → API):

```
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
```

- [ ] **Step 5: Commit (without .env.local — it's gitignored)**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/lib/ portal/middleware.ts
git commit -m "feat: add Supabase SSR client, browser client, and auth middleware"
```

---

## Task 6: Vitest test infrastructure

**Files:**
- Create: `portal/vitest.config.ts`
- Create: `portal/vitest.setup.ts`
- Modify: `portal/package.json`

- [ ] **Step 1: Create vitest config**

Create `portal/vitest.config.ts`:

```typescript
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import { resolve } from 'path'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.ts'],
    globals: true,
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, '.'),
    },
  },
})
```

- [ ] **Step 2: Create setup file**

Create `portal/vitest.setup.ts`:

```typescript
import '@testing-library/react'
```

- [ ] **Step 3: Add test script to package.json**

In `portal/package.json`, add to `"scripts"`:

```json
"test": "vitest run",
"test:watch": "vitest"
```

- [ ] **Step 4: Run tests to verify setup (no tests yet — should pass with 0 tests)**

```bash
cd portal
npm test
```

Expected: `No test files found` or `0 tests passed`. No errors.

- [ ] **Step 5: Commit**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/vitest.config.ts portal/vitest.setup.ts portal/package.json
git commit -m "feat: add Vitest + React Testing Library test infrastructure"
```

---

## Task 7: postMessage bridge + tests

**Files:**
- Create: `portal/lib/bridge.ts`
- Create: `portal/lib/__tests__/bridge.test.ts`

- [ ] **Step 1: Write failing tests**

Create `portal/lib/__tests__/bridge.test.ts`:

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { sendToGame, onGameMessage } from '../bridge'

describe('sendToGame', () => {
  it('posts message to iframe contentWindow', () => {
    const postMessage = vi.fn()
    const iframe = { contentWindow: { postMessage } } as unknown as HTMLIFrameElement
    sendToGame(iframe, 'auth_token', { token: 'abc123' })
    expect(postMessage).toHaveBeenCalledWith(
      { type: 'auth_token', token: 'abc123' },
      '*'
    )
  })

  it('does nothing when contentWindow is null', () => {
    const iframe = { contentWindow: null } as unknown as HTMLIFrameElement
    expect(() => sendToGame(iframe, 'auth_token', { token: 'abc' })).not.toThrow()
  })
})

describe('onGameMessage', () => {
  it('calls handler when message event fires with type', () => {
    const handler = vi.fn()
    const cleanup = onGameMessage(handler)
    window.dispatchEvent(
      new MessageEvent('message', { data: { type: 'game_ready' } })
    )
    expect(handler).toHaveBeenCalledWith({ type: 'game_ready' })
    cleanup()
  })

  it('ignores messages without type', () => {
    const handler = vi.fn()
    const cleanup = onGameMessage(handler)
    window.dispatchEvent(new MessageEvent('message', { data: { foo: 'bar' } }))
    expect(handler).not.toHaveBeenCalled()
    cleanup()
  })

  it('ignores null data messages', () => {
    const handler = vi.fn()
    const cleanup = onGameMessage(handler)
    window.dispatchEvent(new MessageEvent('message', { data: null }))
    expect(handler).not.toHaveBeenCalled()
    cleanup()
  })

  it('cleanup removes listener', () => {
    const handler = vi.fn()
    const cleanup = onGameMessage(handler)
    cleanup()
    window.dispatchEvent(
      new MessageEvent('message', { data: { type: 'game_ready' } })
    )
    expect(handler).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd portal
npm test
```

Expected: FAIL — `Cannot find module '../bridge'`

- [ ] **Step 3: Implement bridge**

Create `portal/lib/bridge.ts`:

```typescript
export type PortalMessageType = 'auth_token' | 'season_info'

export interface GameReadyMessage { type: 'game_ready' }
export interface MatchEndMessage {
  type: 'match_end'
  score: number
  winner: 'player' | 'opponent' | 'draw'
  mode: 'solo' | 'local' | 'online'
}
export interface AuthRequestMessage { type: 'auth_request' }
export type GameMessage = GameReadyMessage | MatchEndMessage | AuthRequestMessage

export function sendToGame(
  iframe: HTMLIFrameElement,
  type: PortalMessageType,
  payload: Record<string, unknown>
): void {
  iframe.contentWindow?.postMessage({ type, ...payload }, '*')
}

export function onGameMessage(handler: (msg: GameMessage) => void): () => void {
  const listener = (event: MessageEvent) => {
    if (event.data && typeof event.data.type === 'string') {
      handler(event.data as GameMessage)
    }
  }
  window.addEventListener('message', listener)
  return () => window.removeEventListener('message', listener)
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
npm test
```

Expected: `5 tests passed`

- [ ] **Step 5: Commit**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/lib/bridge.ts portal/lib/__tests__/
git commit -m "feat: add postMessage bridge with full test coverage"
```

---

## Task 8: Data helpers

**Files:**
- Create: `portal/lib/data/games.ts`
- Create: `portal/lib/data/leaderboard.ts`
- Create: `portal/lib/data/seasons.ts`

These call Supabase and are validated by running the app in Task 13.

- [ ] **Step 1: Create games data helper**

Create `portal/lib/data/games.ts`:

```typescript
import { createClient } from '@/lib/supabase/server'

export interface Game {
  id: string
  slug: string
  name: string
  status: 'coming_soon' | 'live' | 'retired'
  launched_at: string | null
}

export async function getGameBySlug(slug: string): Promise<Game | null> {
  const supabase = createClient()
  const { data } = await supabase
    .from('games')
    .select('*')
    .eq('slug', slug)
    .single()
  return data
}

export async function getFeaturedGame(): Promise<Game | null> {
  const supabase = createClient()
  const { data } = await supabase
    .from('games')
    .select('*')
    .eq('status', 'live')
    .order('launched_at', { ascending: true })
    .limit(1)
    .single()
  return data
}
```

- [ ] **Step 2: Create leaderboard data helper**

Create `portal/lib/data/leaderboard.ts`:

```typescript
import { createClient } from '@/lib/supabase/server'

export interface LeaderboardEntry {
  rank: number
  username: string
  score: number
  user_id: string
}

export async function getTopScores(
  gameSlug: string,
  limit = 5
): Promise<LeaderboardEntry[]> {
  const supabase = createClient()

  const { data: game } = await supabase
    .from('games')
    .select('id')
    .eq('slug', gameSlug)
    .single()

  if (!game) return []

  const { data } = await supabase
    .from('scores')
    .select('score, user_id, users!inner(username)')
    .eq('game_id', game.id)
    .order('score', { ascending: false })
    .limit(limit)

  return (data ?? []).map((row: any, i) => ({
    rank: i + 1,
    username: row.users.username,
    score: row.score,
    user_id: row.user_id,
  }))
}
```

- [ ] **Step 3: Create seasons data helper**

Create `portal/lib/data/seasons.ts`:

```typescript
import { createClient } from '@/lib/supabase/server'

export interface Season {
  id: string
  name: string
  starts_at: string
  ends_at: string
  prize_label: string
  game_id: string
}

export async function getActiveSeason(gameSlug: string): Promise<Season | null> {
  const supabase = createClient()
  const now = new Date().toISOString()

  const { data: game } = await supabase
    .from('games')
    .select('id')
    .eq('slug', gameSlug)
    .single()

  if (!game) return null

  const { data } = await supabase
    .from('seasons')
    .select('*')
    .eq('game_id', game.id)
    .lte('starts_at', now)
    .gte('ends_at', now)
    .single()

  return data
}
```

- [ ] **Step 4: Commit**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/lib/data/
git commit -m "feat: add data helpers for games, leaderboard, and seasons"
```

---

## Task 9: Nav component + test

**Files:**
- Create: `portal/components/Nav.tsx`
- Create: `portal/components/__tests__/Nav.test.tsx`

- [ ] **Step 1: Write failing test**

Create `portal/components/__tests__/Nav.test.tsx`:

```tsx
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { Nav } from '../Nav'

describe('Nav', () => {
  it('renders arcade title', () => {
    render(<Nav />)
    expect(screen.getByText('NEXUS ARCADE')).toBeDefined()
  })

  it('title links to homepage', () => {
    render(<Nav />)
    expect(
      screen.getByText('NEXUS ARCADE').closest('a')?.getAttribute('href')
    ).toBe('/')
  })

  it('renders leaderboard link', () => {
    render(<Nav />)
    expect(
      screen.getByText('LEADERBOARD').closest('a')?.getAttribute('href')
    ).toBe('/leaderboard')
  })

  it('renders login link', () => {
    render(<Nav />)
    expect(
      screen.getByText('LOGIN').closest('a')?.getAttribute('href')
    ).toBe('/login')
  })
})
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd portal && npm test
```

Expected: FAIL — `Cannot find module '../Nav'`

- [ ] **Step 3: Implement Nav**

Create `portal/components/Nav.tsx`:

```tsx
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
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
npm test
```

Expected: `4 tests passed`

- [ ] **Step 5: Commit**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/components/Nav.tsx portal/components/__tests__/Nav.test.tsx
git commit -m "feat: Nav component with retro pixel styling"
```

---

## Task 10: SeasonBanner component + test

**Files:**
- Create: `portal/components/SeasonBanner.tsx`
- Create: `portal/components/__tests__/SeasonBanner.test.tsx`

- [ ] **Step 1: Write failing test**

Create `portal/components/__tests__/SeasonBanner.test.tsx`:

```tsx
import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import { vi } from 'vitest'
import { SeasonBanner } from '../SeasonBanner'

describe('SeasonBanner', () => {
  beforeEach(() => {
    vi.setSystemTime(new Date('2026-04-30T00:00:00Z'))
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('renders season name uppercased', () => {
    render(<SeasonBanner name="Q2 2026" endsAt="2026-06-30T00:00:00Z" />)
    expect(screen.getByText(/Q2 2026/)).toBeDefined()
  })

  it('shows correct days remaining', () => {
    render(<SeasonBanner name="Q2 2026" endsAt="2026-05-02T00:00:00Z" />)
    expect(screen.getByText(/2 DAYS LEFT/)).toBeDefined()
  })

  it('shows singular DAY when 1 day left', () => {
    render(<SeasonBanner name="Q2 2026" endsAt="2026-05-01T00:00:00Z" />)
    expect(screen.getByText(/1 DAY LEFT/)).toBeDefined()
  })

  it('shows 0 days when season ended', () => {
    render(<SeasonBanner name="Q2 2026" endsAt="2026-01-01T00:00:00Z" />)
    expect(screen.getByText(/0 DAYS LEFT/)).toBeDefined()
  })

  it('renders join event button', () => {
    render(<SeasonBanner name="Q2 2026" endsAt="2026-06-30T00:00:00Z" />)
    expect(screen.getByText('JOIN EVENT')).toBeDefined()
  })
})
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
npm test
```

Expected: FAIL — `Cannot find module '../SeasonBanner'`

- [ ] **Step 3: Implement SeasonBanner**

Create `portal/components/SeasonBanner.tsx`:

```tsx
'use client'

interface SeasonBannerProps {
  name: string
  endsAt: string
}

function daysLeft(endsAt: string): number {
  const end = new Date(endsAt)
  const now = new Date()
  return Math.max(0, Math.ceil((end.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)))
}

export function SeasonBanner({ name, endsAt }: SeasonBannerProps) {
  const days = daysLeft(endsAt)
  return (
    <div className="bg-gradient-to-r from-arcade-violet to-arcade-pink px-4 py-2 flex justify-between items-center font-mono text-xs">
      <span className="text-white font-bold tracking-wider">
        🏆 {name.toUpperCase()} — {days} DAY{days !== 1 ? 'S' : ''} LEFT
      </span>
      <button className="text-yellow-200 hover:text-white tracking-wider">
        JOIN EVENT
      </button>
    </div>
  )
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
npm test
```

Expected: `5 tests passed`

- [ ] **Step 5: Commit**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/components/SeasonBanner.tsx portal/components/__tests__/SeasonBanner.test.tsx
git commit -m "feat: SeasonBanner component with days-left countdown"
```

---

## Task 11: LeaderboardWidget component + test

**Files:**
- Create: `portal/components/LeaderboardWidget.tsx`
- Create: `portal/components/__tests__/LeaderboardWidget.test.tsx`

- [ ] **Step 1: Write failing test**

Create `portal/components/__tests__/LeaderboardWidget.test.tsx`:

```tsx
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { LeaderboardWidget } from '../LeaderboardWidget'

const mockScores = [
  { rank: 1, username: 'WeiTat', score: 2830, user_id: 'u1' },
  { rank: 2, username: 'Kira', score: 2440, user_id: 'u2' },
  { rank: 3, username: 'xXnoob', score: 1920, user_id: 'u3' },
]

describe('LeaderboardWidget', () => {
  it('renders heading', () => {
    render(<LeaderboardWidget gameSlug="ultimate-ttt" scores={mockScores} />)
    expect(screen.getByText('🏆 TOP PLAYERS')).toBeDefined()
  })

  it('renders first place player', () => {
    render(<LeaderboardWidget gameSlug="ultimate-ttt" scores={mockScores} />)
    expect(screen.getByText('#1 WeiTat')).toBeDefined()
  })

  it('renders score formatted with commas', () => {
    render(<LeaderboardWidget gameSlug="ultimate-ttt" scores={mockScores} />)
    expect(screen.getByText('2,830')).toBeDefined()
  })

  it('shows empty state when no scores', () => {
    render(<LeaderboardWidget gameSlug="ultimate-ttt" scores={[]} />)
    expect(screen.getByText('NO SCORES YET')).toBeDefined()
  })

  it('view full link goes to game leaderboard', () => {
    render(<LeaderboardWidget gameSlug="ultimate-ttt" scores={[]} />)
    expect(
      screen.getByText('VIEW FULL ►').closest('a')?.getAttribute('href')
    ).toBe('/leaderboard/ultimate-ttt')
  })
})
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
npm test
```

Expected: FAIL — `Cannot find module '../LeaderboardWidget'`

- [ ] **Step 3: Implement LeaderboardWidget**

Create `portal/components/LeaderboardWidget.tsx`:

```tsx
import Link from 'next/link'
import type { LeaderboardEntry } from '@/lib/data/leaderboard'

interface LeaderboardWidgetProps {
  gameSlug: string
  scores: LeaderboardEntry[]
}

export function LeaderboardWidget({ gameSlug, scores }: LeaderboardWidgetProps) {
  return (
    <div className="bg-arcade-panel border-2 border-arcade-gold p-4 font-mono flex flex-col gap-2">
      <div className="text-arcade-gold text-sm font-bold tracking-wider mb-1">
        🏆 TOP PLAYERS
      </div>
      {scores.length === 0 && (
        <div className="text-arcade-dim text-xs">NO SCORES YET</div>
      )}
      {scores.map((entry, i) => (
        <div
          key={entry.user_id}
          className={`text-xs border-b border-arcade-border pb-1 flex justify-between ${
            i === 0 ? 'text-arcade-green' : 'text-arcade-purple'
          }`}
        >
          <span>
            #{entry.rank} {entry.username}
          </span>
          <span className="text-arcade-gold">{entry.score.toLocaleString()}</span>
        </div>
      ))}
      <Link
        href={`/leaderboard/${gameSlug}`}
        className="text-arcade-pink text-xs text-right mt-1 hover:text-pink-300"
      >
        VIEW FULL ►
      </Link>
    </div>
  )
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
npm test
```

Expected: `5 tests passed`

- [ ] **Step 5: Commit**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/components/LeaderboardWidget.tsx portal/components/__tests__/LeaderboardWidget.test.tsx
git commit -m "feat: LeaderboardWidget component with empty state and score formatting"
```

---

## Task 12: GameCard component + test

**Files:**
- Create: `portal/components/GameCard.tsx`
- Create: `portal/components/__tests__/GameCard.test.tsx`

- [ ] **Step 1: Write failing test**

Create `portal/components/__tests__/GameCard.test.tsx`:

```tsx
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { GameCard } from '../GameCard'

describe('GameCard', () => {
  it('renders game name uppercased', () => {
    render(<GameCard slug="ultimate-ttt" name="Ultimate Ttt" />)
    expect(screen.getByText('ULTIMATE TTT')).toBeDefined()
  })

  it('play now links to game page', () => {
    render(<GameCard slug="ultimate-ttt" name="Test Game" />)
    expect(
      screen.getByText('► PLAY NOW').closest('a')?.getAttribute('href')
    ).toBe('/games/ultimate-ttt')
  })

  it('shows placeholder when no thumbnail', () => {
    render(<GameCard slug="ultimate-ttt" name="Test" />)
    expect(screen.getByText('?')).toBeDefined()
  })

  it('renders thumbnail when provided', () => {
    render(
      <GameCard slug="ultimate-ttt" name="Test" thumbnailUrl="/thumb.png" />
    )
    expect(screen.getByRole('img').getAttribute('src')).toBe('/thumb.png')
  })
})
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
npm test
```

Expected: FAIL — `Cannot find module '../GameCard'`

- [ ] **Step 3: Implement GameCard**

Create `portal/components/GameCard.tsx`:

```tsx
import Link from 'next/link'

interface GameCardProps {
  slug: string
  name: string
  thumbnailUrl?: string
}

export function GameCard({ slug, name, thumbnailUrl }: GameCardProps) {
  return (
    <div className="bg-arcade-panel border-2 border-arcade-violet p-4 flex flex-col gap-3 font-mono">
      <div className="bg-arcade-bg border border-arcade-dim flex items-center justify-center h-32">
        {thumbnailUrl ? (
          <img src={thumbnailUrl} alt={name} className="h-full object-contain" />
        ) : (
          <span className="text-arcade-dim text-4xl">?</span>
        )}
      </div>
      <div className="text-arcade-gold font-bold text-sm tracking-wider">
        {name.toUpperCase()}
      </div>
      <Link
        href={`/games/${slug}`}
        className="bg-arcade-pink text-white text-center text-xs py-1 px-3 hover:bg-pink-400 tracking-wider"
      >
        ► PLAY NOW
      </Link>
    </div>
  )
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
npm test
```

Expected: `4 tests passed`

- [ ] **Step 5: Commit**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/components/GameCard.tsx portal/components/__tests__/GameCard.test.tsx
git commit -m "feat: GameCard component with thumbnail and play button"
```

---

## Task 13: Homepage assembly

**Files:**
- Modify: `portal/app/page.tsx`

- [ ] **Step 1: Replace homepage with assembled layout**

Replace `portal/app/page.tsx`:

```tsx
import { Nav } from '@/components/Nav'
import { GameCard } from '@/components/GameCard'
import { LeaderboardWidget } from '@/components/LeaderboardWidget'
import { SeasonBanner } from '@/components/SeasonBanner'
import { getFeaturedGame } from '@/lib/data/games'
import { getTopScores } from '@/lib/data/leaderboard'
import { getActiveSeason } from '@/lib/data/seasons'

export default async function HomePage() {
  const game = await getFeaturedGame()
  const scores = game ? await getTopScores(game.slug) : []
  const season = game ? await getActiveSeason(game.slug) : null

  return (
    <div className="min-h-screen bg-arcade-bg text-white">
      <Nav />
      {season && <SeasonBanner name={season.name} endsAt={season.ends_at} />}
      <main className="max-w-4xl mx-auto px-4 py-8">
        {game ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <GameCard slug={game.slug} name={game.name} />
            <LeaderboardWidget gameSlug={game.slug} scores={scores} />
          </div>
        ) : (
          <div className="text-center font-mono text-arcade-dim text-lg mt-16">
            NO GAMES LOADED
          </div>
        )}
      </main>
      <footer className="fixed bottom-0 left-0 right-0 bg-arcade-panel border-t border-arcade-border px-4 py-2 text-center font-mono text-arcade-dim text-xs">
        NEXUS ARCADE — JOIN OUR{' '}
        <a
          href="https://discord.gg/YOUR_INVITE"
          target="_blank"
          rel="noopener noreferrer"
          className="text-arcade-violet hover:text-arcade-purple"
        >
          DISCORD
        </a>
      </footer>
    </div>
  )
}
```

- [ ] **Step 2: Run dev server and verify homepage**

```bash
cd portal && npm run dev
```

Open http://localhost:3000. Expected: Retro pixel theme homepage with game card and leaderboard widget. Season banner if active season exists. No JS errors in browser console.

- [ ] **Step 3: Commit**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/app/page.tsx
git commit -m "feat: homepage with split play/leaderboard layout and season banner"
```

---

## Task 14: Auth pages (login + OAuth callback)

**Files:**
- Create: `portal/app/login/page.tsx`
- Create: `portal/app/auth/callback/route.ts`

- [ ] **Step 1: Create login page**

Create `portal/app/login/page.tsx`:

```tsx
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
```

- [ ] **Step 2: Create auth callback route**

Create `portal/app/auth/callback/route.ts`:

```typescript
import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')

  if (code) {
    const supabase = createClient()
    await supabase.auth.exchangeCodeForSession(code)
  }

  return NextResponse.redirect(`${origin}/`)
}
```

- [ ] **Step 3: Verify login page in browser**

Open http://localhost:3000/login. Expected: "INSERT PLAYER" heading and Discord login button. Clicking it redirects to Discord OAuth (requires Discord app configured in Supabase).

- [ ] **Step 4: Commit**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/app/login/ portal/app/auth/
git commit -m "feat: Discord OAuth login page and auth callback route"
```

---

## Task 15: GameFrame client component + scores API route

**Files:**
- Create: `portal/components/GameFrame.tsx`
- Create: `portal/app/games/[slug]/page.tsx`
- Create: `portal/app/api/scores/route.ts`

- [ ] **Step 1: Create GameFrame client component**

Create `portal/components/GameFrame.tsx`:

```tsx
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
          })
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
    })

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
```

- [ ] **Step 2: Create game page**

Create `portal/app/games/[slug]/page.tsx`:

```tsx
import { notFound } from 'next/navigation'
import { getGameBySlug } from '@/lib/data/games'
import { Nav } from '@/components/Nav'
import { GameFrame } from '@/components/GameFrame'

interface Props {
  params: { slug: string }
  searchParams: { match?: string }
}

export default async function GamePage({ params, searchParams }: Props) {
  const game = await getGameBySlug(params.slug)
  if (!game || game.status !== 'live') notFound()

  return (
    <div className="min-h-screen bg-arcade-bg flex flex-col">
      <Nav />
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

- [ ] **Step 3: Create scores API route**

Create `portal/app/api/scores/route.ts`:

```typescript
import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

export async function POST(req: NextRequest) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const { slug, score, winner, mode } = await req.json()

  if (
    typeof score !== 'number' ||
    score < 0 ||
    score > 1_000_000 ||
    !['solo', 'local', 'online'].includes(mode)
  ) {
    return NextResponse.json({ error: 'Invalid score payload' }, { status: 400 })
  }

  const admin = createAdminClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )

  const { data: game } = await admin
    .from('games')
    .select('id')
    .eq('slug', slug)
    .single()

  if (!game) {
    return NextResponse.json({ error: 'Game not found' }, { status: 404 })
  }

  const { error } = await admin.from('scores').insert({
    user_id: user.id,
    game_id: game.id,
    score,
    mode,
  })

  if (error) {
    return NextResponse.json({ error: 'Failed to save score' }, { status: 500 })
  }

  return NextResponse.json({ ok: true })
}
```

- [ ] **Step 4: Commit**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/components/GameFrame.tsx portal/app/games/ portal/app/api/
git commit -m "feat: game iframe page with postMessage bridge and score submission API"
```

---

## Task 16: Stub pages

**Files:**
- Create: `portal/app/leaderboard/[slug]/page.tsx`
- Create: `portal/app/profile/[username]/page.tsx`
- Create: `portal/app/seasons/page.tsx`

- [ ] **Step 1: Create leaderboard stub**

Create `portal/app/leaderboard/[slug]/page.tsx`:

```tsx
import { Nav } from '@/components/Nav'

export default function LeaderboardPage({ params }: { params: { slug: string } }) {
  return (
    <div className="min-h-screen bg-arcade-bg">
      <Nav />
      <div className="max-w-2xl mx-auto px-4 py-8 font-mono">
        <h1 className="text-arcade-gold text-xl tracking-widest mb-4">
          🏆 LEADERBOARD — {params.slug.toUpperCase()}
        </h1>
        <p className="text-arcade-dim text-sm">Full leaderboard — coming in Plan 3.</p>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Create profile stub**

Create `portal/app/profile/[username]/page.tsx`:

```tsx
import { Nav } from '@/components/Nav'

export default function ProfilePage({ params }: { params: { username: string } }) {
  return (
    <div className="min-h-screen bg-arcade-bg">
      <Nav />
      <div className="max-w-2xl mx-auto px-4 py-8 font-mono">
        <h1 className="text-arcade-gold text-xl tracking-widest mb-4">
          PLAYER — {params.username.toUpperCase()}
        </h1>
        <p className="text-arcade-dim text-sm">Player profile — coming in Plan 3.</p>
      </div>
    </div>
  )
}
```

- [ ] **Step 3: Create seasons stub**

Create `portal/app/seasons/page.tsx`:

```tsx
import { Nav } from '@/components/Nav'

export default function SeasonsPage() {
  return (
    <div className="min-h-screen bg-arcade-bg">
      <Nav />
      <div className="max-w-2xl mx-auto px-4 py-8 font-mono">
        <h1 className="text-arcade-gold text-xl tracking-widest mb-4">SEASONS</h1>
        <p className="text-arcade-dim text-sm">Seasonal events — coming in Plan 3.</p>
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Commit**

```bash
cd C:/Projects/claude/nexus-arcade
git add portal/app/leaderboard/ portal/app/profile/ portal/app/seasons/
git commit -m "feat: add stub pages for leaderboard, profile, and seasons"
```

---

## Task 17: Railway deploy config + smoke test

**Files:**
- Modify: `portal/next.config.js`
- Create: `portal/railway.json`

- [ ] **Step 1: Enable standalone output in next.config.js**

Replace `portal/next.config.js`:

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
}

module.exports = nextConfig
```

- [ ] **Step 2: Create railway.json**

Create `portal/railway.json`:

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "node .next/standalone/server.js",
    "healthcheckPath": "/"
  }
}
```

- [ ] **Step 3: Run full test suite**

```bash
cd portal && npm test
```

Expected: All tests pass (bridge tests + all component tests).

- [ ] **Step 4: Build to verify no TypeScript errors**

```bash
npm run build
```

Expected: Build succeeds. Note any warnings but no errors.

- [ ] **Step 5: Push to GitHub**

```bash
cd C:/Projects/claude/nexus-arcade
git remote add origin https://github.com/YOUR_USERNAME/nexus-arcade.git
git push -u origin main
```

- [ ] **Step 6: Deploy to Railway**

Go to https://railway.app → New Project → Deploy from GitHub repo → select `nexus-arcade` → set root directory to `portal`.

Add environment variables in Railway dashboard:
```
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
```

Expected: Deploy succeeds. Open Railway URL — retro pixel homepage loads. Navigation works. Login page accessible.

- [ ] **Step 7: Final commit**

```bash
git add portal/next.config.js portal/railway.json
git commit -m "feat: Railway deploy config with standalone Next.js output"
git push
```

---

## Completion Checklist

After all tasks:
- [ ] All tests pass (`npm test`)
- [ ] Build succeeds (`npm run build`)
- [ ] Homepage loads with retro pixel theme
- [ ] Season banner shows Q2 2026 season
- [ ] Discord login redirects to OAuth
- [ ] `/games/ultimate-ttt` shows game page (iframe loads placeholder, no 404)
- [ ] Deployed and live on Railway

**Deferred to Plan 3:**
- Google AdSense integration (requires account approval + real game traffic; add `<Script>` to `layout.tsx` and `<ins>` elements to homepage and game page once approved)
- Full leaderboard, profile, and seasons pages (stubs only in this plan)
