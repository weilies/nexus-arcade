# Nexus Arcade — Portal Design Spec

**Date:** 2026-04-30  
**Status:** Draft — awaiting implementation plan  
**Scope:** Game portal + backend platform + Q1 game (Ultimate Tic Tac Toe)

---

## 1. Vision

Web-first casual game portal. Each game ships to browser first, gets community feedback, then publishes to iOS/Android if traction is there. 1 game per quarter. Fast iteration — drop underperforming games, ship next idea.

**North star:** Players come back for seasonal competition. Leaderboard + quarterly champion awards drive retention. Discord handles community.

---

## 2. Architecture

**Pattern:** NextJS portal + embedded Godot games + Supabase backend.

```
[Web Browser]
  └── NextJS portal (auth, leaderboard, achievements, seasons, ads)
        └── <iframe> Godot web export (gameplay)
              └── postMessage bridge → portal → Supabase

[iOS / Android app]
  └── Godot native build
        └── Supabase SDK directly (no portal iframe)
```

**Key principle:** Portal owns all meta-game (identity, scores, seasons). Godot owns all gameplay. Bridge is the contract between them.

### postMessage Contract

Game → Portal:
```js
{ type: "game_ready" }
{ type: "match_end", score: number, winner: "player"|"opponent"|"draw", mode: "solo"|"local"|"online" }
{ type: "auth_request" }
```

Portal → Game:
```js
{ type: "auth_token", token: string }
{ type: "season_info", name: string, ends_at: string }
```

---

## 3. Tech Stack

| Layer | Technology | Hosting |
|-------|-----------|---------|
| Portal frontend | Next.js 14 + Tailwind CSS | Railway |
| Game engine | Godot 4 (GDScript) | Web export served from Railway (same deploy as portal) |
| Backend | Supabase (cloud) | Supabase cloud |
| Auth | Supabase Auth — email + Discord OAuth | — |
| Realtime (turn-based) | Supabase Realtime Channels | — |
| Realtime (action games, future) | Colyseus.js dedicated server | Railway |
| Ads | Google AdSense (web), AdMob (mobile) | — |
| Repo | GitHub (monorepo) | — |

### Realtime Strategy

- Q1–Q2 games (turn-based, puzzle): Supabase Realtime sufficient (<200ms acceptable)
- Q3+ games (action, rhythm, fighting): migrate that game's online mode to Colyseus.js
- Portal designed so realtime backend is per-game config, not global

---

## 4. Data Model

```sql
users
  id uuid PK
  username text UNIQUE
  avatar_url text
  discord_id text
  created_at timestamptz

games
  id uuid PK
  slug text UNIQUE          -- e.g. "ultimate-ttt"
  name text
  status text               -- "coming_soon" | "live" | "retired"
  launched_at date

seasons
  id uuid PK
  game_id uuid FK games
  name text                 -- e.g. "Q2 2026"
  starts_at timestamptz
  ends_at timestamptz
  prize_label text          -- e.g. "Q2 2026 Champion"

scores
  id uuid PK
  user_id uuid FK users
  game_id uuid FK games
  season_id uuid FK seasons NULLABLE
  score integer
  mode text                 -- "solo" | "local" | "online"
  created_at timestamptz

achievements
  id uuid PK
  user_id uuid FK users
  game_id uuid FK games
  type text                 -- e.g. "season_champion", "first_win"
  label text                -- e.g. "Q2 2026 Champion"
  awarded_at timestamptz

matches
  id uuid PK
  game_id uuid FK games
  player1_id uuid FK users
  player2_id uuid FK users NULLABLE   -- null for solo
  winner_id uuid FK users NULLABLE    -- null for draw / incomplete
  mode text
  created_at timestamptz
```

Score submissions validated server-side via Supabase Edge Function before insert (anti-cheat gate).

---

## 5. Portal UI

### Visual Theme: Retro Pixel
- Background: `#1a0a2e` (deep purple-black)
- Primary accent: `#fbbf24` (gold)
- Secondary accent: `#7c3aed` (violet)
- CTA / highlight: `#ec4899` (pink)
- Font: monospace for headers/labels, system sans for body text
- Border style: 2px solid, hard corners (no soft shadows)

### Homepage Layout: Split Play / Leaderboard
```
┌─────────────────────────────────────────────┐
│  NEXUS ARCADE          LEADERBOARD | LOGIN  │  ← nav
├───────────────────┬─────────────────────────┤
│                   │  🏆 TOP PLAYERS          │
│  ► PLAY           │  #1 WeiTat — 2830        │
│  [Game thumbnail] │  #2 Kira   — 2440        │
│  [PLAY NOW btn]   │  #3 xXnoob — 1920        │
│                   │  VIEW FULL ►             │
├───────────────────┴─────────────────────────┤
│  🏆 Q2 SEASON — 42 DAYS LEFT    [JOIN]      │  ← season banner
└─────────────────────────────────────────────┘
```

### Key Pages
- `/` — homepage (split play/leaderboard)
- `/games/[slug]` — full game page (Godot iframe fills screen)
- `/leaderboard/[slug]` — full leaderboard, filterable by season/mode
- `/profile/[username]` — user stats, achievements, match history
- `/seasons` — current and past seasons, champions

### Ads Placement (web)
- Banner: bottom of homepage, below game iframe
- Interstitial: between matches on game over screen (triggered via postMessage)

---

## 6. Game Pipeline (per game)

```
1. Design    GDD.md written in docs/games/<slug>/GDD.md
2. Build     Godot project in games/<slug>/
3. Export    Godot web export → games/<slug>/web-export/
4. Integrate postMessage bridge wired up
5. Test      All 3 modes working (solo, local 2P, online 2P)
6. Portal    Game entry added to `games` table, slug registered
7. Soft launch  Web only, Discord community feedback
8. Decision  Traction? → app store build. No traction? → next game
9. App store  Godot iOS/Android export, AdMob wired, submitted
```

---

## 7. Game Design Doc Workflow

**Location:** `docs/games/<slug>/GDD.md`  
**Template:** `docs/games/_template/GDD.md`

**Process:**
- Copy template → fill in for new game
- All design changes via GitHub PR (propose in Issue, merge to main)
- Git history = full version trail. No `GDD_v2.md` files.
- NotebookLM KB (`nexus-arcade-kb`) for research/inspiration queries during design
- Claude can pre-fill GDD sections from KB given a game concept

---

## 8. Repo Structure

```
nexus-arcade/
  portal/                  ← Next.js app
    app/
    components/
    lib/
      supabase.ts
      bridge.ts            ← postMessage utilities
  games/
    ultimate-ttt/          ← Godot project
      project.godot
      web-export/          ← built output (gitignored, copied to portal/public/games/<slug>/ at deploy)
    _template/             ← starter Godot project with bridge pre-wired
  docs/
    games/
      _template/GDD.md
      ultimate-ttt/GDD.md
    superpowers/specs/
  supabase/
    migrations/
    functions/             ← Edge Functions (score validation, etc.)
  assets/                  ← shared art assets
```

---

## 9. Game Modes — Online 2P Flow (turn-based)

1. Player A creates match → Supabase inserts `matches` row, returns `match_id`
2. Supabase Realtime Channel opened: `match:{match_id}`
3. Player A shares invite link (`/games/[slug]?match=[match_id]`) → Player B joins, subscribes to same channel
4. Moves broadcast via channel: `{ player: "A", move: {...} }`
5. On match end: Godot sends `match_end` via postMessage → portal calls Edge Function to validate + insert score
6. Channel closed, match row updated with winner

Turn timer: 60s per turn. Auto-forfeit on timeout.

---

## 10. Monetization

**Now:** Google AdSense (web), AdMob (mobile). Non-intrusive — banner + post-match interstitial only.

**Future (market-driven):** Premium subscription tier. Likely unlocks: no ads, exclusive seasonal cosmetics, extended match history. Supabase Auth supports custom claims for subscription status.

---

## 11. Community

Discord server with invite link in portal footer. No deep OAuth integration in v1.  
Season champions automatically awarded Discord role via bot (future — webhook from Supabase Edge Function on season end).

---

## 12. Out of Scope (v1 portal)

- In-game chat
- Friend system / social graph
- Spectator mode
- Tournament brackets
- Push notifications
- Premium subscription billing
- Colyseus integration (deferred to first action game)
