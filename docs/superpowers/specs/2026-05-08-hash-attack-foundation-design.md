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
CREATE TABLE point_transactions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.users ON DELETE CASCADE,
  game_id     uuid NOT NULL REFERENCES games ON DELETE CASCADE,
  source      text NOT NULL CHECK (source IN ('ai_win', 'online_win', 'bonus')),
  amount      int NOT NULL,
  streak_at   int NOT NULL DEFAULT 1,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Per-user per-game consecutive win tracking
CREATE TABLE consecutive_wins (
  user_id         uuid REFERENCES public.users ON DELETE CASCADE,
  game_id         uuid REFERENCES games ON DELETE CASCADE,
  current_streak  int NOT NULL DEFAULT 0,
  best_streak     int NOT NULL DEFAULT 0,
  last_win_at     timestamptz,
  PRIMARY KEY (user_id, game_id)
);

-- Admin-configured streak multiplier tiers (no default seeds)
-- game_id NULL = applies to all games; specific game_id overrides global
CREATE TABLE point_tiers (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id     uuid REFERENCES games ON DELETE CASCADE,
  min_streak  int NOT NULL,
  max_streak  int,          -- NULL = no upper bound
  multiplier  numeric(5,2) NOT NULL,
  UNIQUE (game_id, min_streak)
);

-- Event multiplier hook (UI deferred to Sprint 2)
CREATE TABLE event_multipliers (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id   uuid REFERENCES seasons ON DELETE CASCADE,
  game_id     uuid,         -- NULL = all games
  multiplier  numeric(5,2) NOT NULL DEFAULT 1.0,
  starts_at   timestamptz NOT NULL,
  ends_at     timestamptz NOT NULL
);
```

### Modify existing table

```sql
ALTER TABLE games ADD COLUMN base_stars int NOT NULL DEFAULT 1;
-- Seed: tic-tac-toe classic = 1 star
UPDATE games SET base_stars = 1 WHERE slug = 'tic-tac-toe';
```

### RPCs

**`award_win_points(p_user_id, p_game_id, p_source)`**  
Returns: `int` (points awarded)

Logic:
1. Increment `consecutive_wins.current_streak`, update `best_streak`
2. Find tier: `point_tiers` WHERE `game_id = p_game_id OR game_id IS NULL`, streak in range, ORDER BY `game_id NULLS LAST, min_streak DESC LIMIT 1`
3. Check active `event_multipliers` for current timestamp
4. `pts = games.base_stars × tier.multiplier × event_multiplier (default 1.0)`
5. Round to nearest int
6. Insert `point_transactions` row
7. Upsert `member_points` (add pts)
8. Return pts

If no tier configured → return 0, log warning. Admin must configure tiers before scoring activates.

**`reset_win_streak(p_user_id, p_game_id)`**  
On loss or draw: sets `consecutive_wins.current_streak = 0`. Does not affect `best_streak` or points.

Both RPCs: `SECURITY DEFINER`, called from Godot via Supabase REST.

### RLS

| Table | Public read | Auth write | Admin |
|-------|------------|-----------|-------|
| `member_points` | own row only | — (RPC only) | all rows |
| `point_transactions` | own rows only | — (RPC only) | all rows |
| `consecutive_wins` | own rows only | — (RPC only) | all rows |
| `point_tiers` | yes | no | full CRUD |
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

### Win flow (GameBoard.gd / OnlineLobby.gd)

```
Player wins
→ Determine source: "ai_win" or "online_win"
→ SupabaseClient.call_rpc("award_win_points", {user_id, game_id, source})
→ Receive pts_awarded (int)
→ Globals.current_user.points += pts_awarded
→ Show "+X ★" popup: tween scale 0→1.2→1.0 (0.15s), fade out (0.5s), duration 1.5s total
→ Navigate to GameOver scene (existing)
```

Loss or draw:
```
→ SupabaseClient.call_rpc("reset_win_streak", {user_id, game_id})
→ No points awarded, no popup
```

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
- `call_rpc(fn_name, params)` → REST POST `/rest/v1/rpc/{fn_name}`
- `get_leaderboard(game_id, limit)` → REST GET with join query

---

## 5. Portal Changes

### Display name update
Migration UPDATE: `games.name = '#HashAttack!'` WHERE `slug = 'tic-tac-toe'`.  
Portal reads `games.name` dynamically — GameCard, GameFrame title bar, page `<title>`, and `/games/tic-tac-toe` heading all update automatically. Confirm no component hardcodes the string "Tic Tac Toe".

### Profile page (`/profile`)
New or updated page:
- Total stars: `member_points.total_points` with `★` icon
- Per-game breakdown: best streak from `consecutive_wins`
- Transaction history (last 10): game / source / amount / date

### Admin — Stars & Tiers (`/admin/scoring`)
Two sections on one page:

**Game Stars:**
- Table: game name / base_stars / edit inline
- Save → UPDATE `games.base_stars`

**Streak Multiplier Tiers:**
- Table: game (all or specific) / min streak / max streak / multiplier
- Add row / delete row / edit inline
- Warning banner if no tiers exist: `"No tiers configured — wins award 0 points."`

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

- [ ] `award_win_points` returns correct pts for each tier boundary (1★ base, multipliers 1x/5x/20x)
- [ ] Streak resets to 0 on loss, best_streak unchanged
- [ ] No points awarded if no tiers configured (returns 0)
- [ ] Event multiplier stacks correctly with streak multiplier
- [ ] Signed-out user sees SIGN IN button, not profile row
- [ ] Signed-in user sees correct username and points
- [ ] "+X ★" popup appears after AI win and online win
- [ ] Leaderboard shows top 20, sorted by total_points DESC
- [ ] Admin tier table shows warning when empty
- [ ] postMessage sign_in_request redirects to login page
- [ ] Slug `tic-tac-toe` unchanged in all URLs after rebrand

---

## 8. Open Questions / Decisions for Admin

1. **Tier values** — No defaults. Admin must configure before launch. Gladys will provide recommended tiers as a design doc under `docs/mechanics/`.
2. **`#` color in Godot title** — Neon cyan `#00d4ff`. Can adjust if Uma wants different treatment.
3. **Leaderboard scope** — Global (all games combined) vs per-game. Design assumes per-game for now; global view is Sprint 2 portal page.
