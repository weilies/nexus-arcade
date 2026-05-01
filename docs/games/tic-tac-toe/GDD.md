# Tic Tac Toe — Game Design Document

> **Status:** `in-development`
> **Engine:** Godot 4
> **Target quarter:** Q2 2026
> **Slug:** `tic-tac-toe`

---

## 1. Concept

**One-liner:** Classic 3×3 grid game with neon dark theme, local/online multiplayer, and AI opponent.

**Elevator pitch:** Everyone knows Tic Tac Toe. Nexus Arcade's version adds slick neon aesthetics, a beatable Easy AI and an unbeatable Hard AI, instant online rooms via share link, and Google sign-in through Supabase Auth. Fast match length makes it a perfect arcade warmup or casual break.

**Inspiration:** Classic pen-and-paper Tic Tac Toe. Aesthetic inspired by neon arcade cabinets and synthwave visuals.

**Genre tags:** `strategy`, `casual`, `multiplayer`, `2-player`, `board-game`

---

## 2. Core Mechanics

**Primary mechanic:** Players take turns placing their mark (X or O) on a 3×3 grid.

**Win condition:** First player to align 3 of their marks horizontally, vertically, or diagonally wins.

**Lose condition:** Opponent aligns 3 marks before you do.

**Draw condition:** All 9 cells filled with no winner.

**Match length:** 30–90 seconds per match.

**Skill ceiling:** Low — pure strategy on a solved board. Separating factor is speed and reading opponent patterns (especially in online play with turn timer).

---

## 3. Game Modes

### Solo (vs AI)
- **Easy:** AI picks a random valid cell each turn. Beatable by anyone.
- **Hard:** AI runs full minimax (no depth limit — 3×3 is trivially fast). Unbeatable; best outcome is draw.
- AI plays as O; player always plays as X.

### Local 2P (same screen)
- Alternating turns on same device.
- Player 1 = X, Player 2 = O.
- No turn timer.

### Online 2P
- Host creates room → Supabase inserts `game_rooms` row with `game_slug = "tic-tac-toe"` → `room_code` is a 6-char random alphanumeric string → shareable URL format: `https://<portal>/games/tic-tac-toe?room=XXXXXX`.
- Guest opens URL → Godot reads `room` query param → joins room → both connect to Supabase Realtime channel `room:{id}`.
- Moves broadcast as Realtime channel messages; game state stored in `game_rooms.state` (jsonb).
- **Turn timer:** 30 seconds per turn. Timeout = auto-forfeit.
- **Disconnect behavior:** 10-second grace period. If no reconnect, opponent wins.
- **Auth required:** Google sign-in (via Supabase Auth) gated at Online mode entry. VS AI and 2P Local are guest-friendly.

---

## 4. UI / Screens

Godot scenes inside the game (not the portal):

- `MainMenu` — Mode select: vs AI, 2P Local, 2P Online. No auth prompt here.
- `AIDifficultySelect` — Easy / Hard picker (entered from MainMenu → vs AI).
- `OnlineLobby` — Create room or paste/join room link. Auth gate triggers here if not signed in.
- `GameBoard` — Active gameplay. Shows current turn, board grid, scores.
- `GameOver` — Win / Lose / Draw result with Play Again and Menu buttons.

---

## 5. Portal Bridge (postMessage API)

Events Godot sends to the Next.js portal:

```js
// Game ready
{ type: "game_ready" }

// Match ended
{ type: "match_end", winner: "player" | "opponent" | "draw", mode: "solo" | "local" | "online" }

// Request auth token (online mode entry)
{ type: "auth_request" }
```

Events the portal sends to Godot:

```js
// Auth token after sign-in
{ type: "auth_token", token: "supabase_jwt_string" }

// Season info (future use)
{ type: "season_info", name: "Q2 2026", ends_at: "2026-06-30" }
```

Auth flow: Godot sends `auth_request` → portal checks Supabase session → if logged in returns JWT immediately, else triggers Google OAuth (Supabase Auth, auto-link by verified email) → returns JWT → Godot uses JWT for Realtime channel auth.

---

## 6. Art Direction

**Visual style:** Dark synthwave / neon arcade. Flat shapes, glows, minimal UI chrome.

**Color palette:**

| Role | Hex |
|------|-----|
| Background | `#0f0f1a` |
| Cell background | `#1a1a2e` |
| Panel / card | `#1e1e3a` |
| X mark (neon cyan) | `#00d4ff` |
| O mark (neon purple) | `#a855f7` |
| Accent / buttons | `#a78bfa` |
| Muted text | `#94a3b8` |

**Key assets needed:**
- [x] Game board (3×3 grid, rounded cells, dark bg)
- [x] X and O marks with neon glow shader
- [x] Win line highlight (glowing stroke over winning 3 cells)
- [ ] UI elements (buttons, panels — built in Godot Control nodes)
- [ ] Sound effects: cell place, win fanfare, draw tone, tick (turn timer warning)
- [ ] Background music: lo-fi synthwave loop (optional for POC)

**Animation / Juice:**
- Cell hover: scale pulse (1.0 → 1.05 → 1.0)
- Piece placement: drop-in tween (scale 0 → 1.1 → 1.0)
- Win line: glow stroke draw animation
- GameOver: screen shake + particle burst on win
- Turn timer: last 5 seconds = pulsing red countdown

---

## 7. Supabase Schema

```sql
create table game_rooms (
  id          uuid primary key default gen_random_uuid(),
  game_slug   text not null,              -- 'tic-tac-toe'
  room_code   text unique not null,       -- short shareable code
  host_id     uuid references auth.users,
  guest_id    uuid references auth.users,
  status      text default 'waiting',    -- 'waiting' | 'active' | 'finished'
  state       jsonb default '{}',         -- { board: [null|"X"|"O" x9], turn: "X"|"O", winner: null|"X"|"O"|"draw" }
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- Index for lobby listing per game
create index game_rooms_slug_status on game_rooms(game_slug, status);
```

Realtime channel per room: `room:{id}`. Moves broadcast as messages; `state` column updated on each move for reconnect recovery.

---

## 8. Auth & Identity

- **Provider:** Supabase Auth with Google OAuth (v1). Discord and Twitch planned for future.
- **Identity linking:** Auto-link by verified email (`link_identity` enabled). Same email across providers = one `auth.users` row, multiple `auth.identities` rows. No duplicate accounts.
- **Guest play:** VS AI and 2P Local require no auth. Online mode requires sign-in.
- **JWT handoff:** Portal passes Supabase JWT to Godot via postMessage `auth_token` event. Godot attaches JWT to Realtime channel connection.

---

## 9. Seasonal Events

**Season tie-in:** Placeholder — no season system in v1.

**Seasonal challenge examples (future):** "Win 5 games on Hard AI", "Win 3 online matches in a row"

**Season reward (future):** "Q2 2026 Arcade Starter" badge

---

## 10. Monetization

**Ads (future):** Interstitial between matches (online mode only).

**Premium (future):** No ads, custom X/O skins, extra board themes.

---

## 11. Leaderboard & Scoring

Not in scope for v1. See Out of Scope.

---

## 12. Out of Scope (v1)

- [ ] Leaderboard / ranked scoring
- [ ] Seasonal events and challenges
- [ ] Monetization / ads
- [ ] Spectator mode
- [ ] Discord / Twitch OAuth (schema ready, not wired)
- [ ] Mobile app (web export covers mobile browser)
- [ ] Custom board themes / skins
- [ ] Tournament brackets
- [ ] Random matchmaking queue (invite-link only for v1)

---

## Changelog

| Date | Author | Summary |
|------|--------|---------|
| 2026-05-01 | @weilies | Initial draft — POC spec |
