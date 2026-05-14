# Design Spec: Ultimate & Ephemeral Game Modes
**Date:** 2026-05-10
**Status:** Approved
**Scope:** Tic-Tac-Toe game (`games/tic-tac-toe/`) + MainMenu refactor

---

## 1. Overview

Two new game modes added to Nexus Arcade Tic-Tac-Toe. Both are Sprint 2 scope. Online multiplayer deferred for both.

| Mode | Description | Timer | AI |
|------|-------------|-------|-----|
| Ultimate | 9 mini 3×3 boards in a meta 3×3. Win mini-boards to claim meta cells. | Locked CASUAL (6s) | Yes — all 3 difficulties |
| Ephemeral | Marks expire — oldest removed when 5th placed. Max 4 marks per player. No draws. | Locked CASUAL (6s) | Yes — all 3 difficulties |

Classic mode: **zero changes to game logic.** MainMenu refactored (timer + difficulty inline controls, AIDifficultySelect removed).

---

## 2. Architecture

### Approach: Subclasses
```
scripts/
  GameState.gd              ← untouched
  UltimateGameState.gd      ← new, extends GameState
  EphemeralGameState.gd     ← new, extends GameState
  TicTacToeAI.gd            ← untouched (Classic logic)
  UltimateAI.gd             ← new, extends TicTacToeAI
  EphemeralAI.gd            ← new, extends TicTacToeAI
scenes/
  GameBoard.gd              ← modified: spawns correct state+AI, shows correct board node
  GameBoard.tscn            ← modified: UltimateGrid node added; Ephemeral reuses classic grid
  AIDifficultySelect.tscn   ← DELETED
  AIDifficultySelect.gd     ← DELETED
```

`GameBoard._ready()` reads `Globals.current_game_mode` → instantiates correct subclass → shows correct board node.

### Globals additions
```gdscript
enum AIDifficulty { EASY, HARD, UNBEATABLE }
enum TimerMode { OFF = 0, BLITZ = 3, CASUAL = 6, CHILL = 9 }

var ai_difficulty: AIDifficulty = AIDifficulty.EASY   # default
var timer_mode: TimerMode = TimerMode.OFF              # default
```

`current_game_mode` existing values extended: `"classic"` | `"ultimate"` | `"ephemeral"`

---

## 3. UltimateGameState

```gdscript
class_name UltimateGameState extends GameState

var mini_boards: Array[GameState]   # [0..8], each a fresh GameState
var meta_board: Array               # [0..8] Player.NONE/X/O
var active_board: int = -1          # -1 = free choice
```

### Rules
- `place(board_idx: int, cell: int) -> bool`
  - Fails if `active_board != -1 AND active_board != board_idx`
  - Fails if `meta_board[board_idx] != NONE` (already won)
  - Fails if `mini_boards[board_idx].board[cell] != NONE`
  - Delegates to `mini_boards[board_idx].place(cell)`
  - If mini won → set `meta_board[board_idx]` = winner → run meta win check using `WIN_LINES`
  - After placement: `active_board = cell`. If `meta_board[cell] != NONE` OR `mini_boards[cell]` full → `active_board = -1`
  - Draw: all 9 mini-boards won or full, no meta winner

### Visual state exposed to GameBoard
- `active_board` — which mini-board glows (or -1 = all open boards glow)
- `meta_board[i]` — show winner mark overlay on won mini-boards

---

## 4. EphemeralGameState

```gdscript
class_name EphemeralGameState extends GameState

var x_moves: Array[int] = []   # ordered oldest→newest, max 4
var o_moves: Array[int] = []   # ordered oldest→newest, max 4

const OPACITY_MAP = [0.25, 0.50, 0.75, 1.00]  # index 0=oldest
```

### Rules
- `place(cell: int) -> bool`
  1. Get current player's move queue (`x_moves` or `o_moves`)
  2. If queue size == 4: evict `queue[0]` → `board[queue[0]] = Player.NONE` → `queue.pop_front()`
  3. Append `cell` to queue
  4. `board[cell] = current_turn`
  5. Win check (standard `_check_result()`)
  6. If `ONGOING`: switch turn

- `get_cell_opacity(cell: int) -> float`
  - Returns 0.0 if cell empty
  - Find cell in x_moves or o_moves → return `OPACITY_MAP[index]`
  - Index 0 = oldest (0.25), index 3 = newest (1.00)

### No-draw guarantee
Max 4X + 4O = 8 marks on 9-cell board. One cell always free. Win check still runs after every placement. Game ends when any player gets 3-in-a-row.

---

## 5. MainMenu Refactor

### Removed
- `AIDifficultySelect.tscn` + `AIDifficultySelect.gd` — fully deleted, no dead references

### Added: Tap-cycle control rows (left-aligned, in carousel area)

**TIMER row** — visible in Classic only (hidden in Ultimate + Ephemeral; those lock CASUAL internally)
```
TIMER  [ OFF ▸ ]
```
Cycles: OFF → BLITZ → CASUAL → CHILL → OFF
Colors: OFF=muted `#666688`, BLITZ=magenta `#ff2d95`, CASUAL=gold `#ffd700`, CHILL=green `#00ff88`
Seconds: OFF=0, BLITZ=3, CASUAL=6, CHILL=9
Writes to: `Globals.timer_mode`

**DIFFICULTY row** — visible for Classic + Ultimate + Ephemeral in 1P only (hidden when 2P or Online selected)
```
DIFFICULTY  [ EASY ▸ ]
```
Cycles: EASY → HARD → UNBEATABLE → EASY
Colors: EASY=green, HARD=gold, UNBEATABLE=magenta
Writes to: `Globals.ai_difficulty`

**Defaults on launch:** TIMER=OFF, DIFFICULTY=EASY

**1P button** reads `Globals.ai_difficulty` directly — no intermediate screen.

---

## 6. GameBoard UI

### Ultimate — `UltimateGrid` node (new)
- `GridContainer` (3 cols) → 9 `MiniBoardPanel` children
- Each `MiniBoardPanel` = `Panel` + inner `GridContainer` → 9 `Button` cells
- Cell size: ~72px (GM-approved exception to 88px touch target floor — documented here)
- **Active board:** neon cyan border `#00d4ff` + NeonGlow shader, `glow_strength=2.0`
- **Inactive open board:** dim border `#2a2a4a`, no glow
- **Won board:** winner mark `Label` overlays full panel; underlying cells non-interactive; border = winner color
- **Free choice (-1):** all open boards dim-pulse tween (glow_strength `0.5→1.0→0.5`, 1.0s cycle)
- **Board switch transition:** outgoing border fades over 0.15s → incoming border snaps + glow burst (scale `1.0→1.15→1.0` on panel, 0.2s)

### Ephemeral — reuses classic grid
- No new scene node needed
- Each cell: `modulate.a = EphemeralGameState.get_cell_opacity(cell)` applied after every placement
- **Eviction animation:** `Tween` fades `modulate.a → 0.0` over 0.2s → clears mark → opacity resets to 0
- **New placement:** existing scale bounce tween unchanged (`0→1.1→1.0`, 0.12s+0.06s)

### Shared HUD
- `TurnTimer` reads `Globals.timer_mode.value` (seconds). 0 = disabled.
- Ultimate + Ephemeral: `Globals.timer_mode` forced to `TimerMode.CASUAL` at game start regardless of stored value

---

## 7. AI Algorithms

Full locked spec in: `docs/games/hashattack/ai-algorithms.md`

Summary:

| Mode | Easy | Hard | Unbeatable |
|------|------|------|------------|
| Classic | Random | Rule heuristic (win→block→center→corner→edge) | Full minimax α-β |
| Ephemeral | Random | Eviction-aware heuristic (win-now→block-now→eviction-safety→max-line) | Minimax over `(board, x_moves, o_moves)`, iterative deepening 1s budget |
| Ultimate | Random in active board | Meta-weighted heuristic (win mini→block mini→avoid sending to opponent's win→cell weights) | MCTS, 500 sims, UCB1, `c=√2` |

**All AIs:** clone state before simulating (never mutate live state). Return `{ "cell": int }` (Classic/Ephemeral) or `{ "board": int, "cell": int }` (Ultimate). `Difficulty` enum in `Globals`. AI thinking delay: `randf_range(1.0, 3.0)` seconds, all difficulties.

---

## 8. Visual System (Uma)

All new nodes must use `ArcadeTheme.tres` — no inline `add_theme_font_size_override()`.

| Node type | Min font size |
|-----------|--------------|
| Cell labels (X/O marks) | 28px |
| Mini-board won overlay | 48px |
| Button labels (TIMER/DIFFICULTY values) | 30px |
| HUD labels | 28px |

Touch target exception: Ultimate mini-cells ~72px — documented GM override.

Uma tasks:
1. `UltimateGrid` — style all board states (active/inactive/won/free-choice) per spec above
2. Ephemeral opacity wiring — `modulate.a` per cell, eviction tween
3. MainMenu tap-cycle rows — color-per-state, left-aligned layout
4. `ArcadeTheme.tres` — populate all font sizes per style guide section 2.2

---

## 9. QA Targets (Tessa)

### Functional
- Classic Hard: human fork strategy wins ≥50% over 20 games
- Classic Unbeatable: human never wins over 20 games
- Ephemeral: eviction fires on 5th placement, never 4th or 6th
- Ephemeral opacity: newest=1.0, 2nd=0.75, 3rd=0.50, oldest=0.25 — verified each turn
- Ephemeral Unbeatable: AI wins or draws ≥80% vs casual human over 20 games
- Ultimate: active_board constraint enforced; free-choice only on won/full destination
- Ultimate MCTS vs Hard: MCTS wins ≥70% over 20 games
- No dead references to `AIDifficultySelect` anywhere in codebase

### Visual / Mobile
- All text ≥24px on 720×960 viewport — readable on Note 10+
- Ultimate cells at ~72px: logged as known exception, no other touch target violations
- Tap-cycle rows left-aligned, not centered
- TIMER row hidden in Ultimate + Ephemeral
- DIFFICULTY row hidden when 2P or Online active

---

## 10. Out of Scope

- Online multiplayer for Ultimate or Ephemeral (deferred)
- Ephemeral draw state (structurally impossible by design)
- Ultimate draw tiebreak rules beyond "no meta winner + all boards done"

---

## Changelog

| Date | Author | Summary |
|------|--------|---------|
| 2026-05-10 | GM + Claude (Opus reeval on AI) | Initial approved spec — Ultimate + Ephemeral modes, MainMenu refactor, AI algos locked |
