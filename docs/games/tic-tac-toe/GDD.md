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
- **Thinking delay:** AI waits 1–3 seconds (random) before placing its mark, with animated "AI THINKING...." dots to simulate human deliberation. Player input is blocked during this window.

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

- `MainMenu` — Mode select + HUD panel. See layout below.
- `AIDifficultySelect` — Easy / Hard picker (entered from MainMenu → 1P).
- `OnlineLobby` — Create room or paste/join room link.
- `GameBoard` — Active gameplay. Shows current turn, board grid, scores.
- `GameOver` — Win / Lose / Draw result with Play Again and Menu buttons.
- `LeaderboardScene` — Top 20 players by total stars.

### MainMenu Layout

```
┌──────────────────────────────────────┐
│  #HashAttack!                    [>] │  ← [>] = expand button (top-right)
│                                      │
│  ◄  ● GAME MODE: CLASSIC  ●  ►      │  ← ◄/► = mode carousel
│       [ TIMER: [✓] 10s  ]           │  ← timer row (hidden in Ultimate)
│                                      │
│  ┌──────────────────────────────┐    │
│  │    1P        2P      ONLINE  │    │  ← Row1: game mode buttons
│  └──────────────────────────────┘    │
│  ┌──────────────────────────────┐    │
│  │  SIGN IN  LEADERBOARD  MKT   │    │  ← Row2: auth + nav (signed out)
│  │  ─────────────────────────── │    │
│  │  username  LEADERBOARD  MKT  │    │  ← Row2: profile + nav (signed in)
│  │  ★ 123 pts                  │    │
│  └──────────────────────────────┘    │
│                                      │
└──────────────────────────────────────┘
```

Row2 left slot:
- **Signed out:** "SIGN IN" button → triggers Google OAuth via portal
- **Signed in:** Username + points display

Expand panel slides in from right (reserved for future use):

┌──────────────────────────────┐
│  [<]                         │  ← [<] = collapse
│                              │
│  (future slots)              │
└──────────────────────────────┘
```

### Game Modes (via carousel ◄ ►)

| Mode | Description | Timer | Status |
|------|-------------|-------|--------|
| **Classic** | Standard 3×3 Tic Tac Toe | Optional (checkbox) | Live |
| **Ultimate** | 3×3 grid of 3×3 mini-boards. Win a mini-board to claim that cell in the meta-board. | Always on (30s) | Sprint 2 |
| **Ephemeral** | Moves expire after 6 turns (oldest mark vanishes). No draws — always a winner. | Always on (30s) | Sprint 2 |

Each mode shows the same 3 action buttons: **1P (VS AI)** / **2P (LOCAL)** / **ONLINE**.

### HUD Expand Panel

Accessible from all game scenes via top-right `[>]` button. Slides in/out from right edge.

**Signed out state:**
- `>  SIGN IN` button → triggers Google OAuth via portal

**Signed in state:**
- Profile slot: FA6 user icon + username + `★ points`
- `>  LEADERBOARD` button → opens LeaderboardScene
- `MARKETPLACE` button → greyed out (Sprint 5)

### Screen Flow

```
MainMenu
  ├─ 1P → AIDifficultySelect → GameBoard → GameOver → MainMenu
  ├─ 2P → GameBoard (local) → GameOver → MainMenu
  └─ Online → OnlineLobby → GameBoard (online) → GameOver → MainMenu

[>] Expand Panel (overlay, any screen)
  ├─ SIGN IN → portal login → back to game
  └─ LEADERBOARD → LeaderboardScene → MainMenu
```

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
- Turn timer: each player runs a local 30s `Timer` node. At 5 seconds remaining, the countdown label color shifts to red and a looping `Tween` pulses its scale (1.0 → 1.15 → 1.0, ~0.5s cycle) to create urgency. Both clients reset their local timer whenever they receive a valid move broadcast from the channel — this keeps them in sync without a shared clock. If your own timer hits 0 and you haven't moved, your Godot client broadcasts a `{ type: "forfeit", player: "X"|"O" }` message, ending the match.

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

### Online Move Sync Flow

Supabase Realtime uses persistent WebSocket connections routed through Supabase's globally distributed edge nodes (Fly.io). Both players connect to the same named channel and messages fan out to all subscribers regardless of region. Typical round-trip: 50–200ms globally.

**Step-by-step — X places a mark:**

```
X's client                  Supabase Realtime            O's client
(e.g. Malaysia)             (nearest edge node)          (e.g. USA)

1. X taps cell 4
2. Update local board immediately (optimistic)
3. Broadcast ──────────────────────────────────►
   { type:"move", cell:4, player:"X" }
                            4. Fan out to all
                               channel subscribers ──────►
                                                         5. Receive broadcast
                                                         6. Validate: correct
                                                            player + empty cell
                                                         7. Update board
                                                         8. Switch turn to O
9. Also: PATCH game_rooms.state via REST
   { board:[..], turn:"O", winner:null }
   (persisted for reconnect recovery)
```

**Reconnect recovery:** If O disconnects mid-game and rejoins, Godot fetches `game_rooms` row via REST to rebuild board state — no need to replay broadcast history.

**Conflict prevention:** Only the current turn's player can broadcast a move. The receiving client ignores any move broadcast from the wrong player (e.g. O sending a move on X's turn). No server-side move validation in v1 — acceptable for POC, add RLS/edge function validation post-POC.

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
| 2026-05-02 | @weilies | Added AI thinking delay (1–3s random) with animated dots |
| 2026-05-01 | @weilies | Initial draft — POC spec |
