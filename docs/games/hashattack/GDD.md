# Hash Attack — Game Design Document

> **Status:** `in-development`
> **Engine:** Godot 4
> **Target quarter:** Q2 2026
> **Slug:** `hashattack`

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
- **Hard:** Rule-based heuristic (win → block → center → corner → edge). Beatable via fork setups (two simultaneous threats).
- **Unbeatable:** Full minimax (Classic) / iterative deepening minimax (Ephemeral) / MCTS 500 sims (Ultimate). Best outcome for player: draw (Classic) or rare exploit (Ephemeral/Ultimate).
- **Player color:** Player picks X or O at game start; AI plays the other mark. Code uses `state.current_turn != player_mark` to detect AI turn — NOT `current_turn == Player.O`.
- **Difficulty selected on MainMenu** via tap-cycle row (no separate AIDifficultySelect scene).
- **Thinking delay:** AI waits `randf_range(1.0, 3.0)` seconds before placing, with animated "AI THINKING...." dots. Player input blocked during delay. Covers MCTS compute time.
- **Full algorithm spec:** `docs/games/hashattack/ai-algorithms.md` (LOCKED).

### Local 2P (same screen)
- Alternating turns on same device.
- Player 1 = X, Player 2 = O.
- Turn timer applies per turn (both seats are human — see Turn Timer subsection).

### Online 2P
- Host creates room via `OnlineLobby` → enters room name, picks **PUBLIC** or **PRIVATE** (private requires 4+ char password) → `game_rooms` row inserted (`game_slug = "hashattack"`, `room_code` 6-char random, `room_name`, `is_private`, `password` (plaintext, null if public)).
- Guests see all waiting public/private rooms listed in `OnlineLobby` (manual REFRESH button + initial load). Tap **JOIN** on public; tap **UNLOCK** on private → password dialog → server re-fetch + plaintext compare → join on match.
- Legacy deep link still supported: opening `?room=XXXXXX` auto-fetches that room and presents JOIN / UNLOCK as appropriate.
- Both players connect to Supabase Realtime channel `room:{id}`.
- Moves broadcast as Realtime channel messages; game state stored in `game_rooms.state` (jsonb).
- Turn timer applies only on your own turn; timeout = auto-forfeit (broadcast to opponent).
- **Disconnect behavior:** 10-second grace period. If no reconnect, opponent wins.
- **Auth required:** Google sign-in (via Supabase Auth) gated at Online mode entry. VS AI and 2P Local are guest-friendly.

### Turn Timer (common to all modes + game variants)

Configurable via `Globals.timer_seconds`, set on MainMenu (cycle button):

| Option | Seconds |
|--------|---------|
| OFF    | 0 (no time limit) |
| BLITZ  | 3 |
| CASUAL | 6 |
| CHILL  | 9 |

**Rules:**
- Timer applies to **human turns only**. AI turns never count down (AI has its own 1–3 s think delay).
- Timer **starts** when a human player's turn begins (game start if human goes first, or right after the previous turn ends).
- Timer **resets to the full chosen duration** every time control passes to a human player. Per-game duration does not change mid-match.
- Tick SFX plays only in the **last 3 seconds** (4 → silent, 3/2/1 → tick).
- Timeout:
  - VS_AI / LOCAL → skip turn, fail SFX + screen shake, pass to next player.
  - ONLINE → auto-forfeit, opponent wins.
- Timer selector shown for all game-mode carousel options (Classic / Ultimate / Ephemeral).

---

## 4. UI / Screens

Godot scenes inside the game (not the portal):

- `MainMenu` — Mode select + difficulty cycle + HUD panel. See layout below.
- `OnlineLobby` — Create room or paste/join room link.
- `GameBoard` — Active gameplay. Shows current turn, board grid, scores.
- `GameOver` — Win / Lose / Draw result with Play Again and Menu buttons.
- `LeaderboardScene` — Top 20 players by total stars.

### MainMenu Layout

```
┌──────────────────────────────────────┐
│  #HashAttack!                        │
│                                      │
│  ◄  ● GAME MODE: CLASSIC  ●  ►      │  ← ◄/► = mode carousel
│       [ TIMER: CASUAL  ]            │  ← timer row (always shown)
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
- **Signed in:** Username + points display (tap to toggle sign-out)

### Game Modes (via carousel ◄ ►)

| Mode | Description | Timer | Status |
|------|-------------|-------|--------|
| **Classic** | Standard 3×3 Tic Tac Toe | Optional (0/3/6/9s) | Live |
| **Ultimate** | 3×3 grid of 3×3 mini-boards. Win mini-board to claim that cell in meta-board. | Optional (0/3/6/9s) | Live |
| **Ephemeral** | Each player keeps last 3 marks; 4th placement evicts their oldest. Oldest renders sharply faded (alpha 0.2) for tension. No draws — always a winner. | Optional (0/3/6/9s) | Live |

Each mode shows the same 3 action buttons: **1P (VS AI)** / **2P (LOCAL)** / **ONLINE**.

### Screen Flow

```
MainMenu (mode + difficulty preset inline)
  ├─ 1P → GameBoard → GameOver → MainMenu
  ├─ 2P → GameBoard (local) → GameOver → MainMenu
  └─ Online → OnlineLobby → GameBoard (online) → GameOver → MainMenu

Row2 in-flow actions (no overlay):
  ├─ SIGN IN → portal login → back to MainMenu
  └─ LEADERBOARD → LeaderboardScene → MainMenu
```

---

## 5. Portal Bridge (postMessage API)

Events Godot sends to the Next.js portal:

```js
// Game ready (Godot scene initialized)
{ type: "game_ready" }

// Match ended (score: win=100, draw=50, loss=0)
{ type: "match_end", score: 100 | 50 | 0, winner: "player" | "opponent" | "draw", mode: "solo" | "local" | "online" }

// Request auth token (online mode entry, or re-request if first send raced JS listener)
{ type: "auth_request" }

// Trigger portal Google OAuth flow
{ type: "sign_in_request" }

// Sign out current Supabase session
{ type: "sign_out_request" }
```

Events the portal sends to Godot:

```js
// Auth token after sign-in (or on initial session restore)
{ type: "auth_token", token: "supabase_jwt_string" }
```

Source of truth: `portal/lib/bridge.ts` (TypeScript) and `games/hashattack/scripts/PortalBridge.gd` (GDScript).

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
  game_slug   text not null,              -- 'hashattack'
  room_code   text unique not null,       -- short shareable code
  room_name   text not null default 'Room',
  is_private  boolean not null default false,
  password    text,                       -- plaintext, null iff is_private=false, 4+ chars otherwise
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
| 2026-05-17 | User feature + Opus 4.7 | Online lobby redesign: list waiting rooms in `OnlineLobby` (PUBLIC/PRIVATE tag, JOIN/UNLOCK button), create dialog with room name + public/private + password (4+ chars). Schema adds `room_name`, `is_private`, `password` (migration 011). Plaintext password (POC). Removed 6-char-code text input. Legacy `?room=` deep link preserved. |
| 2026-05-13 | Claude (doc alignment review) | Rebrand title to Hash Attack; §3 AI: 3 difficulty levels + player-color rule; remove AIDifficultySelect; §3 timer 0/3/6/9s; §4 carousel: Ephemeral eviction rule fixed, Ultimate/Ephemeral status Live; §5 bridge: add `score` to match_end, add `sign_in_request`/`sign_out_request`, drop dead `season_info` |
| 2026-05-02 | @weilies | Added AI thinking delay (1–3s random) with animated dots |
| 2026-05-01 | @weilies | Initial draft — POC spec |
