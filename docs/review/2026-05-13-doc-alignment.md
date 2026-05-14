# Doc Alignment Review — 2026-05-13

> **Reviewer:** Claude Sonnet 4.6 (1M context)
> **Scope:** GDD ↔ ai-algorithms ↔ auth-flow-reference ↔ code
> **Mode:** Review only, no code changes
> **Subject game:** Hash Attack (formerly tic-tac-toe)

---

## Summary

11 drifts found across 3 docs vs current code. None are runtime bugs — all are doc-stale. Severity ranked.

| # | Severity | Doc | Issue | Fix location |
|---|----------|-----|-------|--------------|
| 1 | **HIGH** | `Globals.gd` | `GAME_SLUG = "tic-tac-toe"` but folder renamed | Verify Supabase `games.slug` value, then update either code or DB |
| 2 | **HIGH** | `auth-flow-reference.md` | Still references `/games/tic-tac-toe/` URL path | Replace with `/games/hashattack/` everywhere |
| 3 | **MED** | `GDD.md §3` | "AI plays as O; player always X" — locked spec says player picks color | Rewrite paragraph |
| 4 | **MED** | `GDD.md §3` | Only describes Easy + Hard (2 levels), no Unbeatable | Add UNBEATABLE level |
| 5 | **MED** | `GDD.md §4` | Lists `AIDifficultySelect` scene — deprecated (selected on MainMenu now) | Remove scene from list |
| 6 | **MED** | `GDD.md §4 carousel` | "Moves expire after 6 turns" — wrong; queue is 4/player | Update Ephemeral description |
| 7 | **MED** | `GDD.md §3` | "Turn timer: 30s" but code defaults 0, options 3/6/9 | Update timer spec |
| 8 | **MED** | `GDD.md §5` | `match_end` event missing `score` field | Add `score: number` to event schema |
| 9 | **LOW** | `GDD.md §5` | Missing `sign_in_request`, `sign_out_request` events | Add to portal-bridge event list |
| 10 | **LOW** | `bridge.ts` | `season_info` type declared, never emitted | Delete dead type |
| 11 | **LOW** | `GDD.md §4` | Mode status "Sprint 2" for Ultimate/Ephemeral — both shipped | Update status to Live |

---

## Detailed Findings

### 1. HIGH — `GAME_SLUG` mismatch [games/hashattack/scripts/Globals.gd:3](../../games/hashattack/scripts/Globals.gd#L3)

**Code:**
```gdscript
const GAME_SLUG := "tic-tac-toe"
```

**Problem:** Folder renamed `tic-tac-toe → hashattack`, URL path now `/games/hashattack/`, but slug used to query Supabase `games` table still `"tic-tac-toe"`.

**Impact:** `fetch_game_id(GAME_SLUG)` looks up `games WHERE slug='tic-tac-toe'` in Supabase. Works IF seed data still uses old slug. Breaks if anyone re-seeds with new slug.

**Decision needed:** Two valid options —
- **A.** Keep `GAME_SLUG = "tic-tac-toe"` (Supabase slug is internal, "Hash Attack" is display name). Add comment to Globals.gd explaining intentional split.
- **B.** Rename slug everywhere: code + Supabase `games` table + URL path + folder. Single source of truth.

Recommend **B** for clean alignment. Migration: add new `games` row with slug `hashattack`, migrate score data, then drop `tic-tac-toe` row.

---

### 2. HIGH — auth-flow-reference.md stale URLs [docs/games/hashattack/auth-flow-reference.md:42-66](../games/hashattack/auth-flow-reference.md#L42)

**Doc:** Multiple references to `/games/tic-tac-toe` URL path.

**Impact:** Future agent reading auth-flow-reference will use wrong URL in OAuth `return_to` examples.

**Fix:** Global replace `tic-tac-toe → hashattack` in URL paths only (NOT in code identifier references like `class_name TicTacToeAI`).

Lines needing update: 22, 24, 42, 58, 60, 62, 65, 67, 146, 147, 148, 149.

---

### 3. MED — GDD player color rule [docs/games/hashattack/GDD.md:43](../games/hashattack/GDD.md#L43)

**GDD says:**
> AI plays as O; player always plays as X.

**Locked spec (ai-algorithms.md L14) says:**
> AI mark is whichever the player did not pick.

**Code [scripts/TicTacToeAI.gd:25](../../games/hashattack/scripts/TicTacToeAI.gd#L25):** Uses `state.current_turn` (player-color-agnostic) — matches locked spec ✓.

**GDD is wrong.** Rewrite to: "Player picks X or O at game start; AI plays the other color."

---

### 4. MED — GDD missing UNBEATABLE level [docs/games/hashattack/GDD.md:41-42](../games/hashattack/GDD.md#L41)

**GDD lists:** Easy (random), Hard (full minimax, unbeatable)

**ai-algorithms.md:** 3 levels — EASY (random), HARD (rule-heuristic, beatable), UNBEATABLE (full minimax)

**Code:** Implements all 3 [TicTacToeAI.gd:6-14](../../games/hashattack/scripts/TicTacToeAI.gd#L6)

**Drift cause:** GDD predates the brainstorm session that split "Hard" into HARD + UNBEATABLE. GDD treats HARD as the unbeatable tier — locked spec demotes HARD to beatable heuristic.

**Fix:** Replace GDD §3 Solo bullet list with all 3 difficulties + behavior.

---

### 5. MED — Deprecated scene in GDD [docs/games/hashattack/GDD.md:67](../games/hashattack/GDD.md#L67)

**GDD lists scene:** `AIDifficultySelect — Easy / Hard picker`

**Reality:**
- ai-algorithms.md: "Difficulty selected on MainMenu via tap-cycle row. No AIDifficultySelect scene."
- Filesystem: only `AIDifficultySelect.gd.uid` orphan remains, no `.gd`/`.tscn` files

**Fix:** Remove scene from GDD §4 scene list. Remove orphan `.uid` file from disk.

Also screen flow diagram (§4) needs update:
```
GDD says:  1P → AIDifficultySelect → GameBoard
Should be: 1P → GameBoard (difficulty preset on MainMenu)
```

---

### 6. MED — Ephemeral eviction wrong in GDD [docs/games/hashattack/GDD.md:113](../games/hashattack/GDD.md#L113)

**GDD carousel table says:**
> Moves expire after 6 turns (oldest mark vanishes)

**Code [EphemeralGameState.gd:23](../../games/hashattack/scripts/EphemeralGameState.gd#L23):**
```gdscript
if queue.size() == 4:  # evict on 5th placement
```

Each player has independent queue of 4. So 8 total marks on board max. Eviction triggers per-player on their 5th move — not "6 turns".

**Fix:** Update GDD: "Each player keeps last 4 marks; 5th placement evicts their oldest."

---

### 7. MED — Turn timer drift [docs/games/hashattack/GDD.md:55](../games/hashattack/GDD.md#L55)

**GDD says (Online):** "Turn timer: 30 seconds per turn"

**Code:**
- [Globals.gd:17](../../games/hashattack/scripts/Globals.gd#L17): `timer_seconds: int = 0   # 0 = off, 3/6/9 for blitz/casual/chill`
- [games/hashattack/CLAUDE.md] says "10s per-turn (configurable via Globals), off by default"

**Three sources disagree:** GDD=30s, game CLAUDE.md=10s default, Globals.gd default=0 (off) with 3/6/9 options.

**Fix:** Reconcile to one truth. Suggest: timer values are 3/6/9 (per Globals comment), default off. Update GDD §3 and game CLAUDE.md.

---

### 8. MED — match_end missing score in GDD [docs/games/hashattack/GDD.md:153](../games/hashattack/GDD.md#L153)

**GDD:**
```js
{ type: "match_end", winner: "...", mode: "..." }
```

**bridge.ts:**
```ts
interface MatchEndMessage {
  type: 'match_end'
  score: number
  winner: 'player' | 'opponent' | 'draw'
  mode: 'solo' | 'local' | 'online'
}
```

**PortalBridge.gd:65** — sends `score` ✓.

**Fix:** Add `score: 100|50|0` field to GDD event schema (win=100, draw=50, loss=0 per existing plan doc).

---

### 9. LOW — Missing events in GDD §5 [docs/games/hashattack/GDD.md:144-157](../games/hashattack/GDD.md#L144)

GDD lists: `game_ready`, `match_end`, `auth_request` only.

Code also sends: `sign_in_request`, `sign_out_request` ([PortalBridge.gd:70-74](../../games/hashattack/scripts/PortalBridge.gd#L70)).

**Fix:** Add both events to GDD §5 "Events Godot sends to portal" list.

---

### 10. LOW — Dead type `season_info` [portal/lib/bridge.ts:1](../../portal/lib/bridge.ts#L1)

```ts
export type PortalMessageType = 'auth_token' | 'season_info'
```

No code emits `season_info`. GDD §5 mentions it as "future use" but no implementation exists.

**Fix:** Drop from PortalMessageType type union until actually emitted. Re-add when season system ships.

---

### 11. LOW — Mode status stale in GDD [docs/games/hashattack/GDD.md:111-113](../games/hashattack/GDD.md#L111)

**GDD says:**
| Mode | Status |
| Classic | Live |
| Ultimate | Sprint 2 |
| Ephemeral | Sprint 2 |

**Reality:** Both Ultimate (`UltimateGameState.gd`, `UltimateAI.gd` w/ MCTS) and Ephemeral (`EphemeralGameState.gd`, `EphemeralAI.gd` w/ iterative deepening) are implemented and tested.

**Fix:** All three → Live.

---

## What's Aligned (positive findings)

- **AI algorithms match locked spec.** TicTacToeAI/EphemeralAI/UltimateAI implementations match ai-algorithms.md priorities, weights, MCTS iterations (500), UCB1 constant, wall-clock cap (1s).
- **GameState logic matches GDD §2 win/draw conditions.**
- **EphemeralGameState `_check_result` correctly never returns DRAW** (matches "no-draw guarantee" in algo spec).
- **UltimateGameState `place_on` validates active_board + meta state** correctly per algo spec.
- **PortalBridge re-request after 2s** is a defensive measure not in GDD but documented in game CLAUDE.md auth flow notes — implementation matches.
- **Globals autoload structure** matches CLAUDE.md description.

---

## Recommended Fix Sequence

Run as 4 separate commits, in order:

1. **Slug decision + Globals.gd update** (Issue #1) — biggest blast radius, decide first
2. **GDD overhaul** (Issues #3-9, #11) — single edit pass on GDD.md
3. **auth-flow-reference URL updates** (Issue #2) — find-replace
4. **Drop dead types** (Issue #10) — small cleanup in bridge.ts

Total: ~4 commits, ~50 lines changed across 3 doc files + 1 code file.

---

## Next Session

Recommend session #1 (Godot scene tree audit) after fixes from this report land.
