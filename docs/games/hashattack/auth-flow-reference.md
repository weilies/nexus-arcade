# Hash Attack — Architecture & Auth Flow

## Project Tiers

```
┌─────────────────────────────────────────────────┐
│  Portal (Next.js 14)                            │
│  portal/                                        │
│  - OAuth UI (AuthCard.tsx)                       │
│  - GameFrame iframe wrapper (GameFrame.tsx)      │
│  - Auth callback handler (app/auth/callback/)    │
│  - Supabase SSR client (lib/supabase/)           │
│  - Profile + Admin pages                         │
│  - Deployed: Railway                             │
└────────────┬────────────────────────────────────┘
             │ postMessage bridge
             ▼
┌─────────────────────────────────────────────────┐
│  Godot Game (Web export)                        │
│  games/hashattack/                             │
│  - PortalBridge.gd — receives JWT               │
│  - SupabaseClient.gd — REST calls to Supabase   │
│  - Globals.gd — auth state, user, streak        │
│  - Exported to: portal/public/games/hashattack/ │
│  - Rendered in: <iframe> inside GameFrame       │
└────────────┬────────────────────────────────────┘
             │ REST / Realtime
             ▼
┌─────────────────────────────────────────────────┐
│  Supabase Cloud                                 │
│  Project: mdvmxjxhfjovbpshbbzr                  │
│  - Auth (Google OAuth)                          │
│  - PostgreSQL (games, scores, member_points...) │
│  - RLS + RPCs (award_win_points, ...)           │
│  - Realtime (online matchmaking)                │
└─────────────────────────────────────────────────┘
```

## Auth Flow (SSO — Google OAuth)

```
1. User opens /games/hashattack
2. Portal renders GameFrame → creates <iframe> with Godot web build
3. Godot PortalBridge._ready() → polls for postMessage events
4. Godot MainMenu._ready() → Bridge.send_game_ready()
5. Portal GameFrame receives "game_ready" postMessage
6. Portal calls supabase.auth.getSession()
7. IF session exists:
   a. Portal sends "auth_token" postMessage to Godot with JWT
   b. Godot PortalBridge → _populate_auth(token)
   c. Godot validates JWT via Supabase REST /auth/v1/user
   d. Godot fetches member_points + streak from Supabase REST
   e. Godot emits auth_ready → MainMenu shows profile row
8. IF no session:
   a. Godot MainMenu shows "SIGN IN" button
   b. User clicks → Bridge.send_sign_in_request()
   c. Portal receives "sign_in_request" postMessage
   d. Portal router.push('/login?return_to=/games/hashattack')
   e. AuthCard.tsx renders Google OAuth button
   f. redirectTo = `${origin}/auth/callback?return_to=/games/hashattack`
   g. Supabase initiates Google OAuth flow
   h. Google redirects to Supabase Auth callback
   i. Supabase redirects to /auth/callback?code=...&return_to=...
   j. Auth callback exchanges code for session
   k. Redirects to /games/hashattack
   l. GameFrame onAuthStateChange fires → sends fresh JWT to Godot
   m. Go to step 7c
```

## The Site URL Problem

Supabase Auth has ONE **Site URL** setting (Dashboard → Authentication → URL Configuration).

Google OAuth enforces strict redirect URI matching:
- `redirectTo` in `signInWithOAuth()` MUST be on the allowed redirect list
- Supabase auto-derives redirect URIs from Site URL

**Two environments, one Supabase project, one Site URL:**

| Environment | Origin | Needs Site URL |
|-------------|--------|---------------|
| Local dev | `http://localhost:3000` | `http://localhost:3000` |
| Railway (prod) | `https://nexus-arcade.railway.app` (or custom domain) | Prod URL |

**When Site URL = production URL:**
- Localhost OAuth redirects to production URL → broken (wrong origin)
- Or Google rejects the non-matching redirect URI

**When Site URL = localhost:**
- Production OAuth redirects to localhost → broken
- Google may reject non-HTTPS redirect URIs

### Where the origin is used

| File | Usage |
|------|-------|
| `AuthCard.tsx:43` | `redirectTo = ${window.location.origin}/auth/callback?...` |
| `app/auth/callback/route.ts:8` | `NEXT_PUBLIC_SITE_URL || new URL(request.url).origin` |
| `GameFrame.tsx:50` | `router.push('/login?return_to=...')` (relative, safe) |
| `GameFrame.tsx:25` | `sendToGame(iframeRef.current, 'auth_token', { token }, window.location.origin)` — origin check in bridge |

### Current .env.local

```
NEXT_PUBLIC_SUPABASE_URL=https://mdvmxjxhfjovbpshbbzr.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
```

No `NEXT_PUBLIC_SITE_URL` set — falls back to `new URL(request.url).origin` in callback.

## Solutions

### A. Two Supabase Projects (free, recommended)

- Production: keep `mdvmxjxhfjovbpshbbzr`
- UAT/staging: create new project, copy migrations
- Each has its own Site URL, OAuth config, Google Cloud OAuth credentials
- `.env.local` → UAT project; Railway env vars → production project
- Extra setup: second Google OAuth app in GCP, or add UAT redirect to existing one

### B. Supabase Branching (Pro plan, $25/mo)

- Single project, isolated DB branches
- Each branch = separate URL + keys + Auth config
- https://supabase.com/docs/guides/platform/branching

### C. Single Project Workaround (fragile)

- Add both `http://localhost:3000` and prod URL to Redirect URLs allowlist
- Set Site URL to production
- Use `redirectTo` dynamically (already implemented)
- Caveats: Site URL mismatch can break cookie policies; Google may reject non-HTTPS origins

## Key Files Reference

### Portal (auth)
- `portal/components/AuthCard.tsx` — Google/Discord OAuth buttons, `redirectTo` construction
- `portal/app/auth/callback/route.ts` — OAuth code exchange, `NEXT_PUBLIC_SITE_URL` fallback
- `portal/app/auth/signout/route.ts` — Signout redirect
- `portal/components/GameFrame.tsx` — postMessage bridge, auth token handoff, `onAuthStateChange`
- `portal/lib/supabase/server.ts` — SSR Supabase client (cookies)
- `portal/lib/supabase/browser.ts` — Browser Supabase client

### Godot (auth)
- `games/hashattack/scripts/PortalBridge.gd` — postMessage listener, JWT validation, `sign_in_request` sender
- `games/hashattack/scripts/Globals.gd` — Auth state: `current_user`, `jwt`, `is_signed_in()`, `auth_ready` signal
- `games/hashattack/scripts/SupabaseClient.gd` — REST API client: `validate_session()`, `call_rpc()`, `get_member_points()`
- `games/hashattack/scenes/MainMenu.gd` — Auth-aware UI: profile row / SIGN IN / leaderboard

### Supabase
- `supabase/migrations/001_initial_schema.sql` — Base schema (users, games, scores, matches)
- `supabase/migrations/003_game_rooms.sql` — Online matchmaking rooms
- `supabase/migrations/007_membership_scoring.sql` — Membership points, streak system, RPCs

### Specs & Plans
- `docs/superpowers/specs/2026-05-08-hash-attack-foundation-design.md` — Full feature spec
- `docs/superpowers/plans/2026-05-08-hash-attack-foundation.md` — Implementation plan (18 tasks)
- `docs/superpowers/specs/2026-05-08-hash-attack-main-menu-overhaul-design.md` — MainMenu spec
- `docs/superpowers/plans/2026-05-08-hash-attack-main-menu-overhaul.md` — MainMenu plan
- `docs/games/hashattack/GDD.md` — Game design document
