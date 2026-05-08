# Design: #HashAttack! Foundation — Membership, Scoring & Branding

**Date:** 2026-05-08  
**Sprint:** Foundation Weekend  
**Status:** Approved

---

## Scope

What this spec covers (this weekend):
- Rebrand "Tic Tac Toe" → `#HashAttack!`
- Agent identity rename across all agent CLAUDE.md files
- DB: membership points ledger, star-based scoring, streak multipliers, event hook
- Godot: SSO detection, sign-in/profile UI, win-point award flow, leaderboard scene
- Portal: admin tier/star config UI, profile page, postMessage sign-in handler

What is explicitly out of scope (future sprints):
- New game modes (Ultimate, Ephemeral, Hybrid, Timer) — Sprint 2
- Marketplace/store/cross-game items — Sprint 3
- Daily login streaks, weekly challenges — Sprint 3
- Status tiers (Bronze/Silver/Gold/Platinum) — Sprint 4
- Event multiplier admin UI (DB hook designed now, UI Sprint 2)

---

## 1. Agent Identity

All agent CLAUDE.md files renamed with persona handles. No functional changes to authority or rules.

| Handle | Role | File |
|--------|------|------|
| **Gladys** | Game Designer | `docs/agents/game-designer.CLAUDE.md` |
| **Dex** | Game Dev | `docs/agents/game-dev.CLAUDE.md` |
| **Uma** | UI/Artist | `docs/agents/ui-artist.CLAUDE.md` |
| **Mary** | Marketer + Advertiser | `docs/agents/marketer.CLAUDE.md` |
| **Tessa** | Tester/QA | `docs/agents/tester.CLAUDE.md` |

**Mary's expanded authority:** Social media strategy + paid/organic advertising — ad copy, campaign briefs, channel ROI estimates, influencer outreach briefs, event broadcast coordination. Still no code in `games/` or `portal/`.

**Agent interaction pattern (events example):**
1. Gladys designs event spec (timing, multiplier, game scope)
2. Mary counter-proposes: broadcast channels, optimal timing, social assets needed
3. Uma designs event banner (Godot MainMenu + portal)
4. Dex implements event multiplier in RPC + banner in MainMenu
5. Tessa verifies: multiplier math, time zone handling, banner toggle

---

## 2. Rebrand: `#HashAttack!`

### Brand rationale
The `#` symbol is a tic-tac-toe grid. It is globally read as "hashtag" (social-media-native audiences) — making `#HashAttack!` simultaneously a game name and a built-in social sharing hashtag. Spoken name: "Hash Attack." No parenthetical needed — the pun lands visually.

### What changes
| Location | Before | After |
|----------|--------|-------|
| `games.name` (DB) | `Tic Tac Toe` | `#HashAttack!` (via migration UPDATE) |
| Godot MainMenu title | `Tic Tac Toe` | `#HashAttack!` |
| Godot scene headings, UI text | "Tic Tac Toe" | "Hash Attack" (spoken form) |
| Portal game card display name | Tic Tac Toe | `#HashAttack!` |
| Portal GameFrame title bar | Tic Tac Toe | `#HashAttack!` |
| Portal page `<title>` | Tic Tac Toe | `#HashAttack!` |
| `docs/games/tic-tac-toe/` filenames | unchanged | unchanged |

### What does NOT change
- Slug: `tic-tac-toe` — Railway URL, Supabase `games` row, iframe path, export path all unchanged
- `games.id` UUID — no migration needed
- Godot project folder: `games/tic-tac-toe/` — unchanged

### Godot title visual
Godot MainMenu label: `#HashAttack!`  
`#` character: oversized (font_size 1.5× rest), neon cyan (`#00d4ff`), glow shader applied  
Rest of text: Orbitron Bold, standard neon white  
Effect: `#` reads as the game board itself — no image asset required

---

## 3. Database Schema

### New tables

```sql
-- Denormalized read-optimized points balance
-- user_id matches public.users.id (synced from auth.users on signup)
CREATE TABLE member_points (
  user_id       uuid PRIMARY KEY REFERENCES public.users ON DELETE CASCADE,
  total_points  int NOT NULL DEFAULT 0,
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Full audit log of every points award
-- game_mode: 'classic' | 'ultimate' | 'ephemeral' | 'hybrid'
CREATE TABLE point_transactions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.users ON DELETE CASCADE,
  game_id     uuid NOT NULL REFERENCES games ON DELETE CASCADE,
  game_mode   text NOT NULL DEFAULT 'classic',
  source      text NOT NULL CHECK (source IN ('ai_win', 'online_win', 'bonus')),
  amount      int NOT NULL,
  streak_at   int NOT NULL DEFAULT 1,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Per-user per-game-mode consecutive win tracking (mode-level granularity)
-- Enables per-mode streak ladders and traffic steering to specific modes
CREATE TABLE consecutive_wins (
  user_id         uuid REFERENCES public.users ON DELETE CASCADE,
  game_id         uuid REFERENCES games ON DELETE CASCADE,
  game_mode       text NOT NULL DEFAULT 'classic',
  current_streak  int NOT NULL DEFAULT 0,
  best_streak     int NOT NULL DEFAULT 0,
  last_win_at     timestamptz,
  PRIMARY KEY (user_id, game_id, game_mode)
);

-- Admin-configured streak multiplier tiers (no default seeds — must configure before launch)
-- game_id NULL + game_mode NULL = global fallback
-- game_id + game_mode = mode-specific override (highest specificity wins)
-- Tier A (confirmed): 1-4=1x · 5-20=5x · >20=20x
CREATE TABLE point_tiers (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id     uuid REFERENCES games ON DELETE CASCADE,
  game_mode   text,         -- NULL = all modes for this game
  min_streak  int NOT NULL,
  max_streak  int,          -- NULL = no upper bound
  multiplier  numeric(5,2) NOT NULL,
  UNIQUE (game_id, game_mode, min_streak)
);

-- Base stars per game mode (replaces games.base_stars — mode-level granularity)
-- Seed this weekend: (tic-tac-toe, classic, 1)
-- Sprint 2 adds: (tic-tac-toe, ultimate, 5), (tic-tac-toe, ephemeral, 3)
CREATE TABLE game_mode_stars (
  game_id     uuid REFERENCES games ON DELETE CASCADE,
  game_mode   text NOT NULL DEFAULT 'classic',
  base_stars  int NOT NULL DEFAULT 1,
  PRIMARY KEY (game_id, game_mode)
);

-- Event multiplier hook (UI deferred to Sprint 2; schema here for RPC use)
-- game_mode NULL = applies to all modes during this event
CREATE TABLE event_multipliers (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id   uuid REFERENCES seasons ON DELETE CASCADE,
  game_id     uuid,         -- NULL = all games
  game_mode   text,         -- NULL = all modes
  multiplier  numeric(5,2) NOT NULL DEFAULT 1.0,
  starts_at   timestamptz NOT NULL,
  ends_at     timestamptz NOT NULL
);
```

### RPCs

**`award_win_points(p_user_id, p_game_id, p_game_mode, p_source)`**  
Returns: `int` (points awarded, 0 if no tiers configured)

Logic:
1. Upsert `consecutive_wins(user_id, game_id, game_mode)` — increment `current_streak`, update `best_streak`
2. Read `base_stars` from `game_mode_stars` WHERE `(game_id, game_mode)` — fallback 1 if missing
3. Find tier: `point_tiers` WHERE matches `(game_id, game_mode)` or global fallback, streak in range, ORDER BY specificity DESC LIMIT 1
4. Check active `event_multipliers` WHERE `now()` BETWEEN `starts_at` AND `ends_at`, match game/mode (nullable = wildcard)
5. `pts = base_stars × tier.multiplier × event_multiplier` → round to nearest int
6. Insert `point_transactions` row (with `game_mode`)
7. Upsert `member_points` (add pts to total)
8. Return pts

If no tier → return 0 (no error). Admin sees warning in admin UI.

**`reset_win_streak(p_user_id, p_game_id, p_game_mode)`**  
On loss or draw: sets `consecutive_wins.current_streak = 0` for that specific mode. Does not affect other modes, `best_streak`, or points.

Both RPCs: `SECURITY DEFINER`, called from Godot via Supabase REST.

### RLS

| Table | Public read | Auth write | Admin |
|-------|------------|-----------|-------|
| `member_points` | own row only | — (RPC only) | all rows |
| `point_transactions` | own rows only | — (RPC only) | all rows |
| `consecutive_wins` | own rows only | — (RPC only) | all rows |
| `point_tiers` | yes | no | full CRUD |
| `game_mode_stars` | yes | no | full CRUD |
| `event_multipliers` | yes | no | full CRUD |

### Scoring scope
Points awarded for: **AI wins + online wins only**.  
Local 2P excluded — cannot verify both players' identity.

---

## 4. Godot Changes

### Auth detection (on game start)

```
GameStart
→ PortalBridge.gd receives postMessage token (already implemented)
→ SupabaseClient.validate_session(token) → returns {id, username}
→ On success: Globals.current_user = {id, username, points: 0}
→ SupabaseClient.get_member_points(user_id) → populate Globals.current_user.points
→ MainMenu.ready() reads Globals.current_user
```

### MainMenu UI changes

**Signed in:**
- Profile row (top-right): FA6 `fa-user` icon + `username` label + `★ X pts` label
- "LEADERBOARD" button added (FA6 `fa-trophy`)

**Signed out:**
- "SIGN IN" button (FA6 `fa-right-to-bracket`)
- On press: `PortalBridge.send("sign_in_request")` → portal opens `/login?return_to=/games/tic-tac-toe`

### Streak badge (GameBoard — always visible)

Top-right corner of GameBoard, persistent during play:

| Streak | Appearance |
|--------|-----------|
| 0 | Dim, small — `🔥 0` — doesn't distract |
| 1–4 | Normal brightness |
| 5–9 | Neon cyan glow pulse |
| 10–19 | Stronger glow + scale bounce on milestone hit |
| ≥ 20 | Full neon fire animation, magenta (`#ff2d95`) accent |

Badge dims on opponent's turn, brightens on player's turn.  
`Globals.current_streak[game_mode]` int — updated after each win RPC call.

### Win flow (GameBoard.gd / OnlineLobby.gd)

```
Player wins
→ Determine source: "ai_win" or "online_win"
→ game_mode = Globals.current_game_mode  (e.g. "classic")
→ SupabaseClient.call_rpc("award_win_points", {user_id, game_id, game_mode, source})
→ Receive pts_awarded (int)
→ Globals.current_user.points += pts_awarded
→ Globals.current_streak[game_mode] += 1
→ Update streak badge appearance
→ Show "+X ★" popup: tween scale 0→1.2→1.0 (0.15s), fade out (0.5s), duration 1.5s total
→ Navigate to GameOver scene (existing)
```

Loss or draw:
```
→ SupabaseClient.call_rpc("reset_win_streak", {user_id, game_id, game_mode})
→ Globals.current_streak[game_mode] = 0
→ Update streak badge to dim state
→ No points awarded, no popup
```

### GameOver scene additions

- Show current mode streak: `🔥 X STREAK` (large, above points earned)
- Show `+X ★` earned this match
- Milestone banner (streaks 10 / 20 / 50): `"STREAK MASTER — 10 WIN STREAK!"` in neon magenta — Uma designs asset, Mary uses for social screenshots

### New: LeaderboardScene

Scene: `games/tic-tac-toe/scenes/LeaderboardScene.tscn`  
Script: `games/tic-tac-toe/scenes/LeaderboardScene.gd`

Data fetch:
```
SupabaseClient.get_leaderboard(game_id, limit=20)
→ Supabase REST: member_points JOIN users, ORDER BY total_points DESC, LIMIT 20
→ Also fetch: consecutive_wins.best_streak per user
```

Display:
- Table: Rank / Display Name / ★ Total / Best Streak
- Rank 1–3: neon cyan highlight
- Back button → MainMenu

### SupabaseClient.gd additions
- `validate_session(token)` → REST GET `/auth/v1/user` with token header
- `get_member_points(user_id)` → REST GET `member_points?user_id=eq.{id}&select=total_points`
- `get_current_streak(user_id, game_id, game_mode)` → REST GET `consecutive_wins` filtered by all three keys
- `call_rpc(fn_name, params)` → REST POST `/rest/v1/rpc/{fn_name}`
- `get_leaderboard(game_id, limit)` → REST GET `member_points` JOIN `users`, order by `total_points DESC`, limit

---

## 5. Portal Changes

### Display name update
Migration UPDATE: `games.name = '#HashAttack!'` WHERE `slug = 'tic-tac-toe'`.  
Portal reads `games.name` dynamically — GameCard, GameFrame title bar, page `<title>`, and `/games/tic-tac-toe` heading all update automatically. Confirm no component hardcodes the string "Tic Tac Toe".

### Profile page (`/profile`)
New or updated page:
- Total stars: `member_points.total_points` with `★` icon
- Per-game-mode breakdown grid: rows = games, columns = modes — shows `best_streak` from `consecutive_wins`
- Transaction history (last 10): game / mode / source / amount / date

### Admin — Stars & Tiers (`/admin/scoring`)
Two sections on one page:

**Mode Stars (`game_mode_stars`):**
- Table: game / mode / base_stars / edit inline
- Add row (game + mode + stars), delete row
- This weekend seed: Hash Attack! / classic / 1★
- Sprint 2 admin adds: Hash Attack! / ultimate / 5★, Hash Attack! / ephemeral / 3★

**Streak Multiplier Tiers (`point_tiers`):**
- Table: game (all or specific) / mode (all or specific) / min streak / max streak / multiplier
- Add row / delete row / edit inline
- Warning banner if no tiers exist: `"No tiers configured — wins award 0 points."`
- Confirmed tier structure (Tier A) for admin reference:

| min | max | multiplier |
|-----|-----|-----------|
| 1 | 4 | 1× |
| 5 | 20 | 5× |
| 21 | — | 20× |

### postMessage handler (GameFrame.tsx)
```typescript
// Add to existing message listener
if (event.data?.type === 'sign_in_request') {
  router.push('/login?return_to=' + encodeURIComponent('/games/tic-tac-toe'))
}
```

---

## 6. Reward Architecture Roadmap

| Layer | Mechanic | Sprint |
|-------|---------|--------|
| Base stars × streak multiplier | Per-game value + consecutive win bonus | **This weekend** |
| Event multipliers | Time-gated 2x/5x windows | Sprint 2 |
| Daily login streak | Day 1→7 escalating bonus | Sprint 3 |
| Weekly challenges | "Win 5 matches this week → 100★" | Sprint 3 |
| Status tiers | Bronze/Silver/Gold/Platinum by lifetime ★ | Sprint 4 |
| Marketplace | Spend ★ on cross-game items | Sprint 5 |

Mary owns event calendar proposals. Gladys designs challenge mechanics. Admin configures all tier values.

---

## 7. Testing Criteria (Tessa)

- [ ] `award_win_points` returns correct pts: 1★ base × correct multiplier for streak band (Tier A: 1–4=1×, 5–20=5×, >20=20×)
- [ ] Classic and Ultimate streaks tracked independently (win in classic does not increment ultimate streak)
- [ ] Streak resets to 0 on loss for that mode only — other modes unaffected
- [ ] `best_streak` never decreases on loss
- [ ] No points awarded if no tiers configured (returns 0, no crash)
- [ ] Event multiplier stacks correctly with streak multiplier
- [ ] Signed-out user sees SIGN IN button, not profile row
- [ ] Signed-in user sees correct username and points
- [ ] Streak badge: dim at 0, brightens at 1+, pulses at 5+, bounces at 10, magenta at 20+
- [ ] Streak badge dims on opponent's turn, brightens on player's turn
- [ ] "+X ★" popup appears after AI win and online win
- [ ] GameOver shows streak + pts earned; milestone banner at 10/20/50
- [ ] Leaderboard shows top 20, sorted by total_points DESC
- [ ] Admin tier table shows warning when empty
- [ ] Admin mode stars table accepts new row for future modes
- [ ] postMessage sign_in_request redirects to login page
- [ ] Slug `tic-tac-toe` unchanged in all URLs after rebrand

---

## 8. Resolved Decisions

| Decision | Choice | Notes |
|----------|--------|-------|
| Streak granularity | **Per game mode** | Classic/Ultimate/Ephemeral each independent |
| Tier structure | **Tier A** — 1–4=1× · 5–20=5× · >20=20× | Admin enters manually, no seed |
| Base stars schema | **`game_mode_stars` table** | Replaces `games.base_stars` column |
| Streak badge | **Always visible** in GameBoard | Dims on opponent's turn |
| Leaderboard scope | Per-game (mode combined) for now | Global view → Sprint 2 portal |
| `#` color | Neon cyan `#00d4ff`, oversized | Uma may refine treatment |

## 9. Admin Launch Checklist

Before first player session:
- [ ] Insert `game_mode_stars` row: Hash Attack! / classic / 1★
- [ ] Insert `point_tiers` rows (Tier A values above) — global scope (game_id NULL)
- [ ] Verify `award_win_points` RPC deployed to Supabase
- [ ] Verify `reset_win_streak` RPC deployed to Supabase
