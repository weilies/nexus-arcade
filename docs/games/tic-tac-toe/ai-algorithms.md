# Tic-Tac-Toe — AI Algorithms (LOCKED SPEC)

> **Purpose:** Authoritative algorithm spec for all AI difficulties across all 3 game modes.
> **Status:** LOCKED — implementation must match exactly. Do NOT introduce alternative algorithms.
> **Date:** 2026-05-10
> **Authority:** GM-approved during brainstorming session

---

## Common Rules

- **Difficulty levels (all modes):** EASY → HARD → UNBEATABLE
- **AI thinking delay:** All difficulties wait `randf_range(1.0, 3.0)` seconds before placing — preserves "AI THINKING..." animated-dots feel. Covers MCTS compute time. Player input blocked during delay.
- **Player color rule:** AI mark is whichever the player did not pick. Trigger AI move via `_state.current_turn != _player_mark`, NOT `current_turn == Player.O`.
- **Difficulty selected on MainMenu** via tap-cycle row. No AIDifficultySelect scene.

---

## 1. Classic AI (`TicTacToeAI.gd` — refactored)

### EASY
```
Pick uniformly at random from get_empty_cells()
```

### HARD (rule-based heuristic — beatable by fork setups)
Priority order — first matching rule wins, evaluate top-down on each AI turn:

1. **Win:** if any empty cell completes a line of own marks → play it
2. **Block:** if any empty cell would complete an opponent line of 2 → play it
3. **Center:** if cell 4 empty → play 4
4. **Corner:** if any of cells [0,2,6,8] empty → play random one
5. **Edge:** play random of remaining empty cells [1,3,5,7]

**Why beatable:** Skips fork detection. Player can set up two simultaneous winning threats — heuristic blocks only one.

### UNBEATABLE (full minimax, no depth limit)
Standard minimax with α-β pruning. Score: +10/-10 for terminal win/loss (offset by depth to prefer faster wins / slower losses), 0 for draw.

```
function minimax(state, depth, isMaximizing):
  if state terminal:
    return score
  if isMaximizing:
    best = -inf
    for each empty cell:
      simulate AI move
      val = minimax(state', depth+1, false)
      best = max(best, val)
    return best
  else:
    best = +inf
    for each empty cell:
      simulate opponent move
      val = minimax(state', depth+1, true)
      best = min(best, val)
    return best
```

Pick the cell with the highest minimax score on root call. 3×3 is solved → result is always draw or win for AI.

---

## 2. Ephemeral AI (`EphemeralAI.gd`)

### State representation
```
EphemeralState {
  board: [9] of Player.NONE/X/O
  x_moves: ordered queue of cells, max 4
  o_moves: ordered queue of cells, max 4
}
```

`place(cell)`:
1. If `current.moves.size() == 4` → evict `moves[0]`, clear `board[moves[0]]`
2. Append `cell` to `current.moves`
3. Set `board[cell] = current_player`
4. Win check
5. Switch turn (if not won)

### EASY
```
Pick uniformly at random from get_empty_cells()
```

### HARD (heuristic with eviction awareness)
Priority order:

1. **Win-now:** play cell that completes own line *after eviction simulation* (must account for own oldest disappearing)
2. **Block-now:** play cell that blocks opponent line *after their potential eviction*
3. **Self-eviction safety:** if any candidate cell would, on AI's NEXT turn, force AI's about-to-evict mark to break a forming 2-in-a-row → deprioritize
4. **Max-line cell:** rank empty cells by lines they participate in (center=4, corners=3, edges=2) — pick highest
5. **Tie-break:** random among tied

**Why beatable:** Doesn't lookahead on opponent's eviction sequence. Player can win by exploiting AI's blindness to opponent-side eviction timing.

### UNBEATABLE (minimax over full ephemeral state)
- State node = `(board, x_moves, o_moves, turn)`
- Children = state after each legal placement (including eviction effects)
- Score: +1000 win for AI / -1000 loss / 0 ongoing-leaf at depth cap
- **Depth control:** iterative deepening, 1.0s wall-clock budget per move. Typical depth 6–8.
- **Terminal:** win-by-line OR depth cap (return heuristic eval = own_potential_lines − opponent_potential_lines).

No-draw guarantee preserves search — game can technically loop. Time budget bounds search.

---

## 3. Ultimate AI (`UltimateAI.gd`)

### State representation
```
UltimateState {
  mini_boards: [9] of GameState (each a 3×3 board)
  meta_board: [9] of Player.NONE/X/O (winners of mini-boards)
  active_board: int (-1 = free choice)
  current_turn: Player.X / Player.O
}
```

`place(board_idx, cell)`:
1. Validate `active_board == -1 OR active_board == board_idx`
2. Validate `mini_boards[board_idx]` not won/full
3. Place on mini board, run mini win-check
4. If mini won → set `meta_board[board_idx] = winner`, run meta win-check
5. `active_board = cell` (the cell index just played) — unless `meta_board[cell]` won/full → then `active_board = -1`
6. Switch turn (if meta not won)

### EASY
```
Determine valid_boards (active_board if set, else all unwon/unfull)
Pick random valid_board
Pick random empty cell within it
```

### HARD (Ultimate heuristic — strategic but blind to multi-ply meta)
For each candidate (board_idx, cell) in legal moves, score:

1. **+1000:** wins active mini-board (if not already)
2. **+500:** mini win that also wins meta-board
3. **+200:** blocks opponent winning active mini-board next turn
4. **−400:** sends opponent to a mini they can win immediately (counts opponent's win-now cells in destination)
5. **+100:** sends opponent to an already-won or full mini (free choice for them but no immediate gain)
6. **Cell-weight modifier:** within active mini: center=+8, corner=+5, edge=+2
7. **Meta-position weight:** if cell wins mini, multiply that win value by meta-position weight (meta corners/center=1.5x, edges=1.0x)

Pick max score. Tie-break random.

**Why beatable:** No 2-ply meta lookahead. Player can craft sequences forcing AI into losing meta forks.

### UNBEATABLE (MCTS)
- **Iterations:** 500 per move (tunable constant — single source of truth: `MCTS_ITERATIONS` const)
- **Selection:** UCB1, exploration constant `c = sqrt(2)` (standard)
- **Expansion:** add one new child per iteration when reaching unexpanded node
- **Rollout (simulation):** random valid moves until terminal (meta win or full draw)
- **Backpropagation:** propagate win=+1, draw=0, loss=−1 up to root, incrementing visit counts
- **Move selection:** child of root with highest visit count (NOT highest avg value — visit count is more robust)
- **Wall-clock cap:** 1.0s safety cap. Stop iterating if exceeded.

Why this beats minimax for Ultimate: branching factor up to 81 at start, full search infeasible. MCTS's selective deepening on promising branches scales. Industry standard for Ultimate TTT bots.

---

## Implementation Notes

- All three AIs return `Dictionary` from `pick_move(state)`:
  - Classic / Ephemeral: `{ "cell": int }`
  - Ultimate: `{ "board": int, "cell": int }`
- AI classes do NOT mutate the live game state — they receive a clone and return the chosen move
- Cloning: `GameState.duplicate()` deep-copies arrays; subclasses override to copy mode-specific fields
- `Difficulty` enum lives in `Globals` so all UI/AI references the same source: `Globals.AIDifficulty.{EASY, HARD, UNBEATABLE}`

---

## Testing Targets (for Tessa)

- **Classic Hard:** human player following fork strategy wins ≥50% over 20 games
- **Classic Unbeatable:** human player never wins; AI draws or wins 100% over 20 games
- **Ephemeral Hard:** human exploiting eviction timing wins ≥40% over 20 games
- **Ephemeral Unbeatable:** AI wins or draws ≥80% vs casual human over 20 games (no perfect-play benchmark — game's complexity makes this empirical)
- **Ultimate Hard:** human with meta-fork strategy wins ≥40% over 20 games
- **Ultimate Unbeatable (MCTS 500 sims):** AI wins ≥70% vs Hard AI over 20 games (sanity check); vs casual human ≥50%

---

## Changelog

| Date | Author | Summary |
|------|--------|---------|
| 2026-05-10 | GM brainstorm + Opus 4.7 reeval | Locked algos: Classic (rule-heuristic Hard, full minimax Unbeatable), Ephemeral (eviction-aware heuristic, full ephemeral minimax with iterative deepening), Ultimate (heuristic with meta weights, MCTS 500 sims Unbeatable) |
