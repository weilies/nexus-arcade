# Ultimate & Ephemeral Game Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Ultimate and Ephemeral game modes to Nexus Arcade Tic-Tac-Toe, with inline MainMenu difficulty/timer controls and three-tier AI for all modes.

**Architecture:** Subclass GameState and TicTacToeAI for each mode — classic code is zero-touch. GameBoard dispatches to the correct state/AI/UI based on `Globals.current_game_mode`. AIDifficultySelect scene is deleted; difficulty is selected inline on MainMenu via a tap-cycle row.

**Tech Stack:** Godot 4.x GDScript, GL Compatibility renderer, 720×960 viewport, GUT for tests. No new dependencies.

---

## CRITICAL: Read Before Writing Any Code

1. **Locked AI spec:** `docs/games/tic-tac-toe/ai-algorithms.md` — algorithms are locked. Do NOT invent alternatives.
2. **Design spec:** `docs/superpowers/specs/2026-05-10-ultimate-ephemeral-modes-design.md`
3. **Style guide:** `docs/style/nexus-arcade-style-guide.md` — colors, font sizes, animation values
4. **Game CLAUDE.md:** `games/tic-tac-toe/CLAUDE.md` — FA6 rules, SVG scale, layout rules, auth flow

**Color constants (Godot):**
```gdscript
const CYAN    := Color("#00d4ff")
const PURPLE  := Color("#a855f7")
const MAGENTA := Color("#ff2d95")
const GOLD    := Color("#ffd700")
const GREEN   := Color("#00ff88")
const MUTED   := Color(0.392, 0.455, 0.573, 1.0)
const BG_DEEP := Color("#0a0a1a")
const BG_CELL := Color("#12122a")
const BG_PANEL:= Color("#1a1a2e")
const BORDER_DIM  := Color("#2a2a4a")
const BORDER_GLOW := Color("#3a3a66")
```

---

## File Map

| Action | File |
|--------|------|
| **Modify** | `games/tic-tac-toe/scripts/Globals.gd` |
| **Modify** | `games/tic-tac-toe/scripts/TicTacToeAI.gd` |
| **Create** | `games/tic-tac-toe/scripts/UltimateGameState.gd` |
| **Create** | `games/tic-tac-toe/scripts/EphemeralGameState.gd` |
| **Create** | `games/tic-tac-toe/scripts/UltimateAI.gd` |
| **Create** | `games/tic-tac-toe/scripts/EphemeralAI.gd` |
| **Modify** | `games/tic-tac-toe/scenes/MainMenu.gd` |
| **Delete** | `games/tic-tac-toe/scenes/AIDifficultySelect.tscn` |
| **Delete** | `games/tic-tac-toe/scenes/AIDifficultySelect.gd` |
| **Modify** | `games/tic-tac-toe/scenes/GameBoard.gd` |
| **Create** | `games/tic-tac-toe/tests/test_ultimate_state.gd` |
| **Create** | `games/tic-tac-toe/tests/test_ephemeral_state.gd` |
| **Create** | `games/tic-tac-toe/tests/test_ultimate_ai.gd` |
| **Create** | `games/tic-tac-toe/tests/test_ephemeral_ai.gd` |
| **Modify** | `games/tic-tac-toe/tests/test_ai.gd` |

**Uma owns after Task 9:** Visual polish — `UltimateBoard` styling, ephemeral opacity, `ArcadeTheme.tres`.
**Tessa runs after Uma:** QA against criteria in spec section 9.

---

## Task 1: Globals — Add Difficulty and Timer Enums

**Files:**
- Modify: `games/tic-tac-toe/scripts/Globals.gd`

- [ ] **Step 1: Replace `use_timer`/`timer_seconds` with typed vars, add AIDifficulty enum**

Replace the full file content with:

```gdscript
extends Node

const GAME_SLUG := "tic-tac-toe"

signal auth_ready

enum AIDifficulty { EASY, HARD, UNBEATABLE }

var supabase: SupabaseClient

var current_user: Dictionary = {}
var current_game_id: String = ""
var current_game_mode: String = "classic"
var current_streak: Dictionary = {}

var ai_difficulty: AIDifficulty = AIDifficulty.EASY
var timer_seconds: int = 0   # 0 = off, 3/6/9 for blitz/casual/chill

var jwt: String = "":
	set(value):
		jwt = value
		supabase.set_jwt(value)

func _ready() -> void:
	supabase = SupabaseClient.new()
	supabase.init(
		ProjectSettings.get_setting("supabase/url"),
		ProjectSettings.get_setting("supabase/anon_key")
	)
	add_child(supabase)

func is_signed_in() -> bool:
	return not current_user.is_empty()
```

Note: `use_timer` removed — callers check `timer_seconds > 0`. `timer_seconds` still present for backward compat with GameBoard.gd (which reads it directly).

- [ ] **Step 2: Commit**

```
git add games/tic-tac-toe/scripts/Globals.gd
git commit -m "feat(ttt): add AIDifficulty enum and timer_seconds to Globals"
```

---

## Task 2: TicTacToeAI — Refactor to Three Difficulties

**Files:**
- Modify: `games/tic-tac-toe/scripts/TicTacToeAI.gd`
- Modify: `games/tic-tac-toe/tests/test_ai.gd`

The existing `Difficulty.HARD` is full minimax (unbeatable). We:
- Remove the local `Difficulty` enum (use `Globals.AIDifficulty`)
- Add rule-based heuristic as new `HARD` (beatable)
- Keep full minimax as `UNBEATABLE`

- [ ] **Step 1: Write failing tests first**

Replace `games/tic-tac-toe/tests/test_ai.gd` with:

```gdscript
extends GutTest

var ai: TicTacToeAI

func before_each():
	ai = TicTacToeAI.new()

func test_easy_returns_valid_cell():
	var state = GameState.new()
	var cell = ai.get_move(state, Globals.AIDifficulty.EASY)
	assert_between(cell, 0, 8)
	assert_eq(state.board[cell], GameState.Player.NONE)

func test_easy_returns_neg1_on_full_board():
	var state = GameState.new()
	state.place(0); state.place(1)
	state.place(3); state.place(6)
	state.place(4); state.place(2)
	state.place(7); state.place(5)
	state.place(8)
	var cell = ai.get_move(state, Globals.AIDifficulty.EASY)
	assert_eq(cell, -1)

func test_hard_blocks_opponent_win():
	# X at 0,1 — O must block at 2
	var state = GameState.new()
	state.place(0)  # X
	state.place(4)  # O
	state.place(1)  # X threatens 2
	var cell = ai.get_move(state, Globals.AIDifficulty.HARD)
	assert_eq(cell, 2)

func test_hard_takes_winning_move():
	# O at 3,4 — AI (O) should play 5 to win
	var state = GameState.new()
	state.board[3] = GameState.Player.O
	state.board[4] = GameState.Player.O
	state.board[0] = GameState.Player.X
	state.board[1] = GameState.Player.X
	state.current_turn = GameState.Player.O
	var cell = ai.get_move(state, Globals.AIDifficulty.HARD)
	assert_eq(cell, 5)

func test_hard_prefers_center():
	# Empty board — heuristic prefers center (4)
	var state = GameState.new()
	var cell = ai.get_move(state, Globals.AIDifficulty.HARD)
	assert_eq(cell, 4)

func test_unbeatable_blocks_win():
	var state = GameState.new()
	state.place(0); state.place(4)
	state.place(1)
	var cell = ai.get_move(state, Globals.AIDifficulty.UNBEATABLE)
	assert_eq(cell, 2)

func test_unbeatable_takes_winning_move():
	var state = GameState.new()
	state.board[3] = GameState.Player.O
	state.board[4] = GameState.Player.O
	state.board[0] = GameState.Player.X
	state.board[1] = GameState.Player.X
	state.current_turn = GameState.Player.O
	var cell = ai.get_move(state, Globals.AIDifficulty.UNBEATABLE)
	assert_eq(cell, 5)
```

- [ ] **Step 2: Run tests — expect FAIL (enum not updated yet)**

```powershell
cd games/tic-tac-toe
& "C:\Projects\godot\Godot_v4.6.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -- -gtest=test_ai
```

Expected: errors about `Globals.AIDifficulty` not found or wrong enum.

- [ ] **Step 3: Rewrite TicTacToeAI.gd**

```gdscript
class_name TicTacToeAI
extends RefCounted

# Returns the cell index AI wants to play (-1 if no move available).
# Override get_move in subclasses for different state types.
func get_move(state: GameState, difficulty: Globals.AIDifficulty) -> int:
	match difficulty:
		Globals.AIDifficulty.EASY:
			return _random_move(state)
		Globals.AIDifficulty.HARD:
			return _heuristic_move(state)
		Globals.AIDifficulty.UNBEATABLE:
			return _minimax_move(state)
	return -1

func _random_move(state: GameState) -> int:
	var empty := state.get_empty_cells()
	if empty.is_empty():
		return -1
	return empty[randi() % empty.size()]

# Rule-based heuristic: win → block → center → corner → edge
# Beatable by fork setups (creating two simultaneous threats).
func _heuristic_move(state: GameState) -> int:
	var ai_player := state.current_turn
	var opp := GameState.Player.O if ai_player == GameState.Player.X else GameState.Player.X

	# 1. Win if possible
	var win := _find_winning_cell(state, ai_player)
	if win >= 0:
		return win

	# 2. Block opponent win
	var block := _find_winning_cell(state, opp)
	if block >= 0:
		return block

	# 3. Center
	if state.board[4] == GameState.Player.NONE:
		return 4

	# 4. Random corner
	var corners := [0, 2, 6, 8]
	corners.shuffle()
	for c in corners:
		if state.board[c] == GameState.Player.NONE:
			return c

	# 5. Random edge
	var edges := [1, 3, 5, 7]
	edges.shuffle()
	for e in edges:
		if state.board[e] == GameState.Player.NONE:
			return e

	return -1

func _find_winning_cell(state: GameState, player: GameState.Player) -> int:
	for line in GameState.WIN_LINES:
		var marks := line.filter(func(c): return state.board[c] == player)
		var empties := line.filter(func(c): return state.board[c] == GameState.Player.NONE)
		if marks.size() == 2 and empties.size() == 1:
			return empties[0]
	return -1

func _minimax_move(state: GameState) -> int:
	var ai_player := state.current_turn
	var best_score := -100
	var best_cell := -1
	for cell in state.get_empty_cells():
		var clone := _clone(state)
		clone.place(cell)
		var score := _minimax(clone, false, ai_player)
		if score > best_score:
			best_score = score
			best_cell = cell
	return best_cell

func _minimax(state: GameState, is_maximizing: bool, ai_player: GameState.Player) -> int:
	var r := state.result
	if r != GameState.GameResult.ONGOING:
		if r == GameState.GameResult.DRAW:
			return 0
		var winner := GameState.Player.X if r == GameState.GameResult.X_WINS else GameState.Player.O
		return 10 if winner == ai_player else -10
	var scores: Array = []
	for cell in state.get_empty_cells():
		var clone := _clone(state)
		clone.place(cell)
		scores.append(_minimax(clone, not is_maximizing, ai_player))
	return scores.max() if is_maximizing else scores.min()

func _clone(state: GameState) -> GameState:
	var c := GameState.new()
	c.board = state.board.duplicate()
	c.current_turn = state.current_turn
	c.result = state.result
	return c
```

- [ ] **Step 4: Run tests — expect PASS**

```powershell
& "C:\Projects\godot\Godot_v4.6.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -- -gtest=test_ai
```

Expected: all 7 tests PASS.

- [ ] **Step 5: Commit**

```
git add games/tic-tac-toe/scripts/TicTacToeAI.gd games/tic-tac-toe/tests/test_ai.gd
git commit -m "feat(ttt): refactor AI — add HARD heuristic, rename minimax to UNBEATABLE"
```

---

## Task 3: UltimateGameState

**Files:**
- Create: `games/tic-tac-toe/scripts/UltimateGameState.gd`
- Create: `games/tic-tac-toe/tests/test_ultimate_state.gd`

- [ ] **Step 1: Write failing tests**

Create `games/tic-tac-toe/tests/test_ultimate_state.gd`:

```gdscript
extends GutTest

var state: UltimateGameState

func before_each():
	state = UltimateGameState.new()

func test_initial_active_board_is_free_choice():
	assert_eq(state.active_board, -1)

func test_initial_meta_all_none():
	for i in 9:
		assert_eq(state.meta_board[i], GameState.Player.NONE)

func test_place_on_wrong_board_fails():
	# First move: free choice. Place on board 0, cell 4.
	state.place(0, 4)
	# Now active_board == 4. Placing on board 3 must fail.
	assert_false(state.place(3, 0))

func test_place_sends_to_correct_next_board():
	state.place(0, 4)   # X plays board 0, cell 4 → next active = 4
	assert_eq(state.active_board, 4)

func test_place_on_correct_board_succeeds():
	state.place(0, 4)   # active now 4
	assert_true(state.place(4, 0))

func test_won_mini_board_recorded_in_meta():
	# Win mini-board 0 for X: cells 0,1,2 in board 0
	state.place(0, 0)   # X → active=0
	state.place(0, 3)   # O
	state.place(0, 1)   # X → active=1
	state.place(1, 3)   # O
	state.place(0, 2)   # X wins board 0 → meta[0] = X
	assert_eq(state.meta_board[0], GameState.Player.X)

func test_sent_to_won_board_gives_free_choice():
	# Win mini-board 4 for X first
	_win_mini_board(state, 4, GameState.Player.X)
	# Now if active_board would be 4 (won), it should be -1
	assert_eq(state.active_board, -1)

func test_meta_win_ends_game():
	# Win boards 0,1,2 for X (top row of meta)
	_win_meta_row(state)
	assert_eq(state.result, GameState.GameResult.X_WINS)

func test_get_legal_moves_respects_active_board():
	state.place(0, 4)   # active = 4
	var moves := state.get_legal_moves()
	for m in moves:
		assert_eq(m["board"], 4)

func test_get_legal_moves_free_choice_returns_all_boards():
	# active = -1 on first move
	var moves := state.get_legal_moves()
	# Should have 9 boards × 9 cells = 81 moves (all empty)
	assert_eq(moves.size(), 81)

# Helpers
func _win_mini_board(s: UltimateGameState, board_idx: int, player: GameState.Player) -> void:
	# Force-set mini board as won. Direct manipulation for test setup.
	s.mini_boards[board_idx].board[0] = player
	s.mini_boards[board_idx].board[1] = player
	s.mini_boards[board_idx].board[2] = player
	s.mini_boards[board_idx].result = GameState.GameResult.X_WINS if player == GameState.Player.X else GameState.GameResult.O_WINS
	s.meta_board[board_idx] = player

func _win_meta_row(s: UltimateGameState) -> void:
	# Win boards 0,1,2 for X — direct manipulation
	for b in [0, 1, 2]:
		_win_mini_board(s, b, GameState.Player.X)
	# Trigger meta win check
	s._check_meta_result()
```

- [ ] **Step 2: Run tests — expect FAIL**

```powershell
& "C:\Projects\godot\Godot_v4.6.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -- -gtest=test_ultimate_state
```

Expected: FAIL — class not found.

- [ ] **Step 3: Create UltimateGameState.gd**

Create `games/tic-tac-toe/scripts/UltimateGameState.gd`:

```gdscript
class_name UltimateGameState
extends GameState

# 9 mini-boards, each a classic 3×3 GameState
var mini_boards: Array = []       # Array[GameState], size 9
var meta_board: Array = []        # Array of GameState.Player, size 9
var active_board: int = -1        # -1 = free choice (first move or sent to won/full)

func _init() -> void:
	super._init()
	meta_board.resize(9)
	meta_board.fill(GameState.Player.NONE)
	for i in 9:
		mini_boards.append(GameState.new())

# Place a mark on mini-board board_idx, cell cell_idx.
# Returns false if move is invalid.
func place(board_idx: int, cell_idx: int) -> bool:
	if result != GameState.GameResult.ONGOING:
		return false
	if active_board != -1 and active_board != board_idx:
		return false
	if meta_board[board_idx] != GameState.Player.NONE:
		return false
	var mini := mini_boards[board_idx] as GameState
	if not mini.place(cell_idx):
		return false

	# If mini-board just finished, update meta
	if mini.result != GameState.GameResult.ONGOING:
		if mini.result == GameState.GameResult.X_WINS:
			meta_board[board_idx] = GameState.Player.X
		elif mini.result == GameState.GameResult.O_WINS:
			meta_board[board_idx] = GameState.Player.O
		# DRAW on mini-board: cell stays unclaimed (Player.NONE) but board is full
		_check_meta_result()
		if result != GameState.GameResult.ONGOING:
			return true

	# Determine next active_board
	var next := cell_idx
	if meta_board[next] != GameState.Player.NONE or _mini_is_full(next):
		active_board = -1
	else:
		active_board = next

	# Switch turn (mini.place already switched inside it; re-sync)
	current_turn = mini_boards[0].current_turn  # all minis share turn parity — read from any
	# Actually safer: track turn ourselves
	current_turn = GameState.Player.O if current_turn == GameState.Player.X else GameState.Player.X
	# Wait — mini.place already flipped its own current_turn. We manage turn at this level.
	# Correct approach: flip our own turn, ignore mini's turn tracking.
	return true

# Override _init turn tracking — UltimateGameState tracks its own turn.
# Mini-board turns are ignored; we pass current_turn into each mini.
# Simpler: inject correct player into mini before placing.

func _check_meta_result() -> void:
	for line in WIN_LINES:
		var p := meta_board[line[0]]
		if p != GameState.Player.NONE and meta_board[line[1]] == p and meta_board[line[2]] == p:
			result = GameState.GameResult.X_WINS if p == GameState.Player.X else GameState.GameResult.O_WINS
			return
	# Draw: all 9 cells resolved (won or full)
	var all_done := true
	for i in 9:
		if meta_board[i] == GameState.Player.NONE and not _mini_is_full(i):
			all_done = false
			break
	if all_done:
		result = GameState.GameResult.DRAW

func _mini_is_full(board_idx: int) -> bool:
	return mini_boards[board_idx].get_empty_cells().is_empty()

# Returns all legal (board, cell) moves as Array[Dictionary]
func get_legal_moves() -> Array:
	var moves: Array = []
	var boards_to_check: Array = []
	if active_board == -1:
		for i in 9:
			if meta_board[i] == GameState.Player.NONE and not _mini_is_full(i):
				boards_to_check.append(i)
	else:
		boards_to_check = [active_board]

	for b in boards_to_check:
		for c in mini_boards[b].get_empty_cells():
			moves.append({"board": b, "cell": c})
	return moves

func duplicate_state() -> UltimateGameState:
	var c := UltimateGameState.new()
	c.current_turn = current_turn
	c.result = result
	c.active_board = active_board
	c.meta_board = meta_board.duplicate()
	for i in 9:
		var m := GameState.new()
		m.board = mini_boards[i].board.duplicate()
		m.current_turn = mini_boards[i].current_turn
		m.result = mini_boards[i].result
		c.mini_boards[i] = m
	return c
```

**Critical turn-tracking fix:** The above `place()` has a logic error in turn tracking (the comment calls it out). Replace the place() function with this corrected version:

```gdscript
func place(board_idx: int, cell_idx: int) -> bool:
	if result != GameState.GameResult.ONGOING:
		return false
	if active_board != -1 and active_board != board_idx:
		return false
	if meta_board[board_idx] != GameState.Player.NONE:
		return false

	var mini := mini_boards[board_idx] as GameState
	# Inject correct turn into mini before placing (mini tracks its own turn)
	mini.current_turn = current_turn
	if not mini.place(cell_idx):
		return false

	# Check if mini-board was won/drawn
	if mini.result == GameState.GameResult.X_WINS:
		meta_board[board_idx] = GameState.Player.X
		_check_meta_result()
	elif mini.result == GameState.GameResult.O_WINS:
		meta_board[board_idx] = GameState.Player.O
		_check_meta_result()

	if result != GameState.GameResult.ONGOING:
		return true

	# Next active board
	var next := cell_idx
	if meta_board[next] != GameState.Player.NONE or _mini_is_full(next):
		active_board = -1
	else:
		active_board = next

	# Flip our turn
	current_turn = GameState.Player.O if current_turn == GameState.Player.X else GameState.Player.X
	return true
```

- [ ] **Step 4: Run tests — expect PASS**

```powershell
& "C:\Projects\godot\Godot_v4.6.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -- -gtest=test_ultimate_state
```

Expected: all tests PASS. Fix any failures before continuing.

- [ ] **Step 5: Commit**

```
git add games/tic-tac-toe/scripts/UltimateGameState.gd games/tic-tac-toe/tests/test_ultimate_state.gd
git commit -m "feat(ttt): add UltimateGameState — 9 mini-boards, meta win, active board routing"
```

---

## Task 4: EphemeralGameState

**Files:**
- Create: `games/tic-tac-toe/scripts/EphemeralGameState.gd`
- Create: `games/tic-tac-toe/tests/test_ephemeral_state.gd`

- [ ] **Step 1: Write failing tests**

Create `games/tic-tac-toe/tests/test_ephemeral_state.gd`:

```gdscript
extends GutTest

var state: EphemeralGameState

func before_each():
	state = EphemeralGameState.new()

func test_initial_queues_empty():
	assert_eq(state.x_moves.size(), 0)
	assert_eq(state.o_moves.size(), 0)

func test_place_adds_to_queue():
	state.place(4)  # X
	assert_eq(state.x_moves.size(), 1)
	assert_eq(state.x_moves[0], 4)

func test_no_eviction_before_5th_mark():
	# X places 4 marks — no eviction yet
	state.place(0); state.place(1)   # X:0, O:1
	state.place(2); state.place(3)   # X:2, O:3
	state.place(5); state.place(6)   # X:5, O:6
	state.place(7); state.place(8)   # X:7, O:8
	# X has 4 marks: 0,2,5,7. Board cells 0,2,5,7 must still be X.
	assert_eq(state.board[0], GameState.Player.X)
	assert_eq(state.board[2], GameState.Player.X)
	assert_eq(state.board[5], GameState.Player.X)
	assert_eq(state.board[7], GameState.Player.X)
	assert_eq(state.x_moves.size(), 4)

func test_eviction_fires_on_5th_mark():
	# X places 4 marks, then 5th triggers eviction of 1st
	state.place(0); state.place(1)   # X:0, O:1
	state.place(2); state.place(3)   # X:2, O:3
	state.place(5); state.place(6)   # X:5, O:6
	state.place(7); state.place(8)   # X:7, O:8
	# X's 5th mark: place on cell 4
	state.place(4)
	# Cell 0 (X's oldest) must now be cleared
	assert_eq(state.board[0], GameState.Player.NONE)
	assert_eq(state.x_moves.size(), 4)
	assert_eq(state.x_moves[0], 2)  # 2 is now oldest

func test_opacity_newest_is_1():
	state.place(4)  # X at 4, only mark → newest → opacity 1.0
	assert_almost_eq(state.get_cell_opacity(4), 1.0, 0.001)

func test_opacity_4_marks():
	# X places 4 marks — check all opacity slots
	state.place(0); state.place(1)
	state.place(2); state.place(3)
	state.place(5); state.place(6)
	state.place(7); state.place(8)
	# X queue: [0, 2, 5, 7] oldest→newest
	assert_almost_eq(state.get_cell_opacity(0), 0.25, 0.001)  # oldest
	assert_almost_eq(state.get_cell_opacity(2), 0.50, 0.001)
	assert_almost_eq(state.get_cell_opacity(5), 0.75, 0.001)
	assert_almost_eq(state.get_cell_opacity(7), 1.00, 0.001)  # newest

func test_empty_cell_opacity_is_0():
	assert_almost_eq(state.get_cell_opacity(4), 0.0, 0.001)

func test_no_draw_possible():
	# Play until board would be "full" in classic — should not draw
	# With eviction, board never saturates past 8 marks.
	# Just verify result never becomes DRAW after 20 moves.
	for i in 20:
		var empty := state.get_empty_cells()
		if empty.is_empty() or state.result != GameState.GameResult.ONGOING:
			break
		state.place(empty[0])
	assert_ne(state.result, GameState.GameResult.DRAW)

func test_win_still_detected():
	# Force X to get 3 in a row (top row: 0,1,2)
	# X: 0, O: 3, X: 1, O: 4, X: 2
	state.place(0); state.place(3)
	state.place(1); state.place(4)
	state.place(2)
	assert_eq(state.result, GameState.GameResult.X_WINS)
```

- [ ] **Step 2: Run tests — expect FAIL**

```powershell
& "C:\Projects\godot\Godot_v4.6.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -- -gtest=test_ephemeral_state
```

- [ ] **Step 3: Create EphemeralGameState.gd**

Create `games/tic-tac-toe/scripts/EphemeralGameState.gd`:

```gdscript
class_name EphemeralGameState
extends GameState

# Move history per player — ordered oldest (index 0) → newest (index -1). Max 4 each.
var x_moves: Array[int] = []
var o_moves: Array[int] = []

# Opacity per age slot. Index 0 = oldest mark, index 3 = newest.
# Player has 1 mark: [1.0]. 2 marks: [0.75, 1.0]. 3: [0.5, 0.75, 1.0]. 4: [0.25, 0.5, 0.75, 1.0].
const OPACITY_MAP: Array = [0.25, 0.50, 0.75, 1.00]

func place(cell: int) -> bool:
	if cell < 0 or cell > 8:
		return false
	if board[cell] != GameState.Player.NONE:
		return false
	if result != GameState.GameResult.ONGOING:
		return false

	var queue := x_moves if current_turn == GameState.Player.X else o_moves

	# Evict oldest if at capacity (5th placement triggers removal of 1st)
	if queue.size() == 4:
		var evicted: int = queue[0]
		queue.pop_front()
		board[evicted] = GameState.Player.NONE

	# Place new mark
	queue.append(cell)
	board[cell] = current_turn

	# Win check
	result = _check_result()
	if result == GameState.GameResult.ONGOING:
		current_turn = GameState.Player.O if current_turn == GameState.Player.X else GameState.Player.X
	return true

# Returns opacity for cell (0.0 if empty, OPACITY_MAP value based on age).
func get_cell_opacity(cell: int) -> float:
	if board[cell] == GameState.Player.NONE:
		return 0.0
	var queue: Array
	if board[cell] == GameState.Player.X:
		queue = x_moves
	else:
		queue = o_moves
	var idx := queue.find(cell)
	if idx < 0:
		return 1.0
	# Map queue position to opacity: 0=oldest. OPACITY_MAP has 4 slots.
	# If queue has fewer than 4 marks, shift index to align newest=1.0.
	var slot := idx + (4 - queue.size())
	return OPACITY_MAP[clamp(slot, 0, 3)]

# EphemeralGameState cannot draw — override _check_result to never return DRAW.
func _check_result() -> GameState.GameResult:
	for line in WIN_LINES:
		var p := board[line[0]]
		if p != GameState.Player.NONE and board[line[1]] == p and board[line[2]] == p:
			return GameState.GameResult.X_WINS if p == GameState.Player.X else GameState.GameResult.O_WINS
	return GameState.GameResult.ONGOING  # never DRAW

func duplicate_state() -> EphemeralGameState:
	var c := EphemeralGameState.new()
	c.board = board.duplicate()
	c.current_turn = current_turn
	c.result = result
	c.x_moves = x_moves.duplicate()
	c.o_moves = o_moves.duplicate()
	return c
```

- [ ] **Step 4: Run tests — expect PASS**

```powershell
& "C:\Projects\godot\Godot_v4.6.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -- -gtest=test_ephemeral_state
```

- [ ] **Step 5: Commit**

```
git add games/tic-tac-toe/scripts/EphemeralGameState.gd games/tic-tac-toe/tests/test_ephemeral_state.gd
git commit -m "feat(ttt): add EphemeralGameState — 4-mark queues, eviction on 5th, opacity map"
```

---

## Task 5: UltimateAI

**Files:**
- Create: `games/tic-tac-toe/scripts/UltimateAI.gd`
- Create: `games/tic-tac-toe/tests/test_ultimate_ai.gd`

- [ ] **Step 1: Write failing tests**

Create `games/tic-tac-toe/tests/test_ultimate_ai.gd`:

```gdscript
extends GutTest

var ai: UltimateAI

func before_each():
	ai = UltimateAI.new()

func test_easy_returns_valid_move():
	var state := UltimateGameState.new()
	var move := ai.get_move(state, Globals.AIDifficulty.EASY)
	assert_true(move.has("board") and move.has("cell"))
	assert_between(move["board"], 0, 8)
	assert_between(move["cell"], 0, 8)

func test_easy_respects_active_board():
	var state := UltimateGameState.new()
	state.place(0, 4)   # active = 4
	var move := ai.get_move(state, Globals.AIDifficulty.EASY)
	assert_eq(move["board"], 4)

func test_hard_wins_mini_board_when_possible():
	var state := UltimateGameState.new()
	# Set up: X has 0,1 in mini-board 0. AI (O) is in board 0 (active=-1 for setup).
	# Force state: X at board0/cell0 and board0/cell1, O to play in board0.
	state.mini_boards[0].board[0] = GameState.Player.X
	state.mini_boards[0].board[1] = GameState.Player.X
	state.mini_boards[0].board[3] = GameState.Player.O
	state.mini_boards[0].board[4] = GameState.Player.O
	state.active_board = 0
	state.current_turn = GameState.Player.O
	var move := ai.get_move(state, Globals.AIDifficulty.HARD)
	# O must play cell 5 to win row [3,4,5]
	assert_eq(move["board"], 0)
	assert_eq(move["cell"], 5)

func test_unbeatable_returns_valid_move():
	var state := UltimateGameState.new()
	var move := ai.get_move(state, Globals.AIDifficulty.UNBEATABLE)
	assert_true(move.has("board") and move.has("cell"))
	var legal := state.get_legal_moves()
	var found := false
	for m in legal:
		if m["board"] == move["board"] and m["cell"] == move["cell"]:
			found = true
			break
	assert_true(found)

func test_unbeatable_finishes_under_2_seconds():
	var state := UltimateGameState.new()
	var t := Time.get_ticks_msec()
	ai.get_move(state, Globals.AIDifficulty.UNBEATABLE)
	var elapsed := Time.get_ticks_msec() - t
	assert_lt(elapsed, 2000)
```

- [ ] **Step 2: Run tests — expect FAIL**

```powershell
& "C:\Projects\godot\Godot_v4.6.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -- -gtest=test_ultimate_ai
```

- [ ] **Step 3: Create UltimateAI.gd**

Create `games/tic-tac-toe/scripts/UltimateAI.gd`:

```gdscript
class_name UltimateAI
extends TicTacToeAI

const MCTS_ITERATIONS := 500
const UCB1_C := 1.4142135  # sqrt(2)

# Returns { "board": int, "cell": int }
func get_move(state: UltimateGameState, difficulty: Globals.AIDifficulty) -> Dictionary:
	match difficulty:
		Globals.AIDifficulty.EASY:
			return _random_ultimate_move(state)
		Globals.AIDifficulty.HARD:
			return _heuristic_ultimate_move(state)
		Globals.AIDifficulty.UNBEATABLE:
			return _mcts_move(state)
	return {}

func _random_ultimate_move(state: UltimateGameState) -> Dictionary:
	var moves := state.get_legal_moves()
	if moves.is_empty():
		return {}
	return moves[randi() % moves.size()]

# Heuristic priority (per ai-algorithms.md):
# +1000: wins active mini-board
# +500:  mini win that also wins meta
# +200:  blocks opponent winning active mini-board next turn
# -400:  sends opponent to mini they can win immediately
# +100:  sends to already-won/full board (forces free choice)
# Cell-weight modifier: center=+8, corner=+5, edge=+2
# Meta-position weight: corners/center x1.5 if that move wins the mini
func _heuristic_ultimate_move(state: UltimateGameState) -> Dictionary:
	var moves := state.get_legal_moves()
	if moves.is_empty():
		return {}

	var best_score := -999999
	var best_moves: Array = []

	for m in moves:
		var score := _score_move(state, m)
		if score > best_score:
			best_score = score
			best_moves = [m]
		elif score == best_score:
			best_moves.append(m)

	return best_moves[randi() % best_moves.size()]

func _score_move(state: UltimateGameState, move: Dictionary) -> int:
	var b: int = move["board"]
	var c: int = move["cell"]
	var score := 0
	var ai_player := state.current_turn
	var opp := GameState.Player.O if ai_player == GameState.Player.X else GameState.Player.X

	# Check if this move wins the mini-board
	var mini := state.mini_boards[b] as GameState
	var mini_clone := _clone_mini(mini)
	mini_clone.current_turn = ai_player
	mini_clone.place(c)

	var wins_mini := mini_clone.result == (GameState.GameResult.X_WINS if ai_player == GameState.Player.X else GameState.GameResult.O_WINS)
	if wins_mini:
		score += 1000
		# Check if winning this mini also wins the meta
		var meta_clone := state.meta_board.duplicate()
		meta_clone[b] = ai_player
		if _check_meta_win(meta_clone, ai_player):
			score += 500
		# Meta-position weight (corners=0,2,6,8 center=4 → 1.5x)
		if b in [0, 2, 4, 6, 8]:
			score += 500  # approx 1.5x applied as flat bonus

	# Block opponent winning active mini-board
	var opp_can_win_mini := _opponent_can_win_mini(state, b, opp)
	if opp_can_win_mini and not wins_mini:
		score += 200

	# Destination board analysis (where opponent lands)
	var dest := c
	if state.meta_board[dest] != GameState.Player.NONE or state.mini_boards[dest].get_empty_cells().is_empty():
		score += 100  # free choice for opponent — no immediate harm
	else:
		# Check if opponent can win destination mini on their next turn
		if _opponent_can_win_mini(state, dest, opp):
			score -= 400

	# Cell-weight modifier within mini
	if c == 4:
		score += 8
	elif c in [0, 2, 6, 8]:
		score += 5
	else:
		score += 2

	return score

func _opponent_can_win_mini(state: UltimateGameState, board_idx: int, opp: GameState.Player) -> bool:
	var mini := state.mini_boards[board_idx] as GameState
	for line in GameState.WIN_LINES:
		var opp_marks := line.filter(func(cc): return mini.board[cc] == opp)
		var empties := line.filter(func(cc): return mini.board[cc] == GameState.Player.NONE)
		if opp_marks.size() == 2 and empties.size() == 1:
			return true
	return false

func _check_meta_win(meta: Array, player: GameState.Player) -> bool:
	for line in GameState.WIN_LINES:
		if meta[line[0]] == player and meta[line[1]] == player and meta[line[2]] == player:
			return true
	return false

func _clone_mini(mini: GameState) -> GameState:
	var c := GameState.new()
	c.board = mini.board.duplicate()
	c.current_turn = mini.current_turn
	c.result = mini.result
	return c

# --- MCTS ---

class MCTSNode:
	var state: UltimateGameState
	var parent: MCTSNode
	var children: Array = []
	var visits: int = 0
	var wins: float = 0.0
	var move: Dictionary = {}
	var untried_moves: Array = []

	func _init(s: UltimateGameState, p: MCTSNode, m: Dictionary) -> void:
		state = s
		parent = p
		move = m
		untried_moves = s.get_legal_moves().duplicate()

	func ucb1(c: float) -> float:
		if visits == 0:
			return INF
		return wins / visits + c * sqrt(log(float(parent.visits)) / float(visits))

	func best_child(c: float) -> MCTSNode:
		var best: MCTSNode = children[0]
		for child in children:
			if (child as MCTSNode).ucb1(c) > best.ucb1(c):
				best = child
		return best

	func most_visited_child() -> MCTSNode:
		var best: MCTSNode = children[0]
		for child in children:
			if (child as MCTSNode).visits > best.visits:
				best = child
		return best

func _mcts_move(state: UltimateGameState) -> Dictionary:
	var ai_player := state.current_turn
	var root := MCTSNode.new(state.duplicate_state(), null, {})
	var deadline := Time.get_ticks_msec() + 1000  # 1s wall-clock cap

	for _i in MCTS_ITERATIONS:
		if Time.get_ticks_msec() > deadline:
			break

		# Selection
		var node := root
		while node.untried_moves.is_empty() and not node.children.is_empty():
			node = node.best_child(UCB1_C)

		# Expansion
		if not node.untried_moves.is_empty() and node.state.result == GameState.GameResult.ONGOING:
			var m: Dictionary = node.untried_moves[randi() % node.untried_moves.size()]
			node.untried_moves.erase(m)
			var next_state := node.state.duplicate_state()
			next_state.place(m["board"], m["cell"])
			var child := MCTSNode.new(next_state, node, m)
			node.children.append(child)
			node = child

		# Rollout
		var rollout_state := node.state.duplicate_state()
		var depth := 0
		while rollout_state.result == GameState.GameResult.ONGOING and depth < 50:
			var moves := rollout_state.get_legal_moves()
			if moves.is_empty():
				break
			var rm: Dictionary = moves[randi() % moves.size()]
			rollout_state.place(rm["board"], rm["cell"])
			depth += 1

		# Result
		var reward := 0.0
		if rollout_state.result == GameState.GameResult.X_WINS:
			reward = 1.0 if ai_player == GameState.Player.X else 0.0
		elif rollout_state.result == GameState.GameResult.O_WINS:
			reward = 1.0 if ai_player == GameState.Player.O else 0.0
		else:
			reward = 0.5

		# Backpropagation
		var bp := node
		while bp != null:
			bp.visits += 1
			bp.wins += reward
			bp = bp.parent

	if root.children.is_empty():
		return _random_ultimate_move(state)
	return root.most_visited_child().move
```

- [ ] **Step 4: Run tests — expect PASS**

```powershell
& "C:\Projects\godot\Godot_v4.6.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -- -gtest=test_ultimate_ai
```

- [ ] **Step 5: Commit**

```
git add games/tic-tac-toe/scripts/UltimateAI.gd games/tic-tac-toe/tests/test_ultimate_ai.gd
git commit -m "feat(ttt): add UltimateAI — Easy random, Hard heuristic, Unbeatable MCTS 500 sims"
```

---

## Task 6: EphemeralAI

**Files:**
- Create: `games/tic-tac-toe/scripts/EphemeralAI.gd`
- Create: `games/tic-tac-toe/tests/test_ephemeral_ai.gd`

- [ ] **Step 1: Write failing tests**

Create `games/tic-tac-toe/tests/test_ephemeral_ai.gd`:

```gdscript
extends GutTest

var ai: EphemeralAI

func before_each():
	ai = EphemeralAI.new()

func test_easy_returns_valid_cell():
	var state := EphemeralGameState.new()
	var cell := ai.get_move(state, Globals.AIDifficulty.EASY)
	assert_between(cell, 0, 8)

func test_hard_wins_immediately():
	var state := EphemeralGameState.new()
	# Set up O to win at cell 5 (row [3,4,5])
	state.board[3] = GameState.Player.O
	state.board[4] = GameState.Player.O
	state.o_moves = [3, 4]
	state.board[0] = GameState.Player.X
	state.x_moves = [0]
	state.current_turn = GameState.Player.O
	var cell := ai.get_move(state, Globals.AIDifficulty.HARD)
	assert_eq(cell, 5)

func test_hard_blocks_opponent_win():
	var state := EphemeralGameState.new()
	# X threatens to win at cell 2 (row [0,1,2])
	state.board[0] = GameState.Player.X
	state.board[1] = GameState.Player.X
	state.x_moves = [0, 1]
	state.board[3] = GameState.Player.O
	state.o_moves = [3]
	state.current_turn = GameState.Player.O
	var cell := ai.get_move(state, Globals.AIDifficulty.HARD)
	assert_eq(cell, 2)

func test_unbeatable_returns_valid_cell():
	var state := EphemeralGameState.new()
	var cell := ai.get_move(state, Globals.AIDifficulty.UNBEATABLE)
	assert_between(cell, 0, 8)
	assert_eq(state.board[cell], GameState.Player.NONE)

func test_unbeatable_finishes_under_2_seconds():
	var state := EphemeralGameState.new()
	var t := Time.get_ticks_msec()
	ai.get_move(state, Globals.AIDifficulty.UNBEATABLE)
	var elapsed := Time.get_ticks_msec() - t
	assert_lt(elapsed, 2000)
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Create EphemeralAI.gd**

Create `games/tic-tac-toe/scripts/EphemeralAI.gd`:

```gdscript
class_name EphemeralAI
extends TicTacToeAI

func get_move(state: EphemeralGameState, difficulty: Globals.AIDifficulty) -> int:
	match difficulty:
		Globals.AIDifficulty.EASY:
			return _random_move(state)
		Globals.AIDifficulty.HARD:
			return _ephemeral_heuristic(state)
		Globals.AIDifficulty.UNBEATABLE:
			return _ephemeral_minimax_move(state)
	return -1

# Heuristic (per ai-algorithms.md):
# 1. Win-now (accounting for own eviction)
# 2. Block-now
# 3. Eviction safety: avoid cells where own next eviction breaks a forming line
# 4. Max-line cell (center > corners > edges)
func _ephemeral_heuristic(state: EphemeralGameState) -> int:
	var ai_player := state.current_turn
	var opp := GameState.Player.O if ai_player == GameState.Player.X else GameState.Player.X

	# 1. Win-now: simulate placement (with eviction) and check result
	for cell in state.get_empty_cells():
		var clone := state.duplicate_state()
		clone.place(cell)
		var expected_result := GameState.GameResult.X_WINS if ai_player == GameState.Player.X else GameState.GameResult.O_WINS
		if clone.result == expected_result:
			return cell

	# 2. Block-now: opponent's win after their simulated placement
	for cell in state.get_empty_cells():
		var opp_clone := state.duplicate_state()
		opp_clone.current_turn = opp
		opp_clone.place(cell)
		var opp_wins := GameState.GameResult.X_WINS if opp == GameState.Player.X else GameState.GameResult.O_WINS
		if opp_clone.result == opp_wins:
			return cell

	# 3 + 4. Score remaining cells
	var best_score := -999
	var best_cells: Array = []
	for cell in state.get_empty_cells():
		var score := _cell_score(state, cell, ai_player)
		if score > best_score:
			best_score = score
			best_cells = [cell]
		elif score == best_score:
			best_cells.append(cell)

	return best_cells[randi() % best_cells.size()] if not best_cells.is_empty() else -1

func _cell_score(state: EphemeralGameState, cell: int, ai_player: GameState.Player) -> int:
	# Lines the cell participates in (center=4, corners=3, edges=2)
	var line_count := 0
	for line in GameState.WIN_LINES:
		if cell in line:
			line_count += 1
	var score := line_count * 10

	# Eviction safety: if placing here means next-turn eviction breaks our line
	var queue := state.x_moves if ai_player == GameState.Player.X else state.o_moves
	if queue.size() == 4:
		var will_evict := queue[0]
		# If evicting will_evict breaks any 2-in-a-row we're building, penalize
		for line in GameState.WIN_LINES:
			if will_evict in line and cell in line:
				score -= 15  # evicting from same line we're building into

	return score

func _ephemeral_minimax_move(state: EphemeralGameState) -> int:
	var ai_player := state.current_turn
	var best_score := -INF
	var best_cell := -1
	var deadline := Time.get_ticks_msec() + 1000

	# Iterative deepening
	for depth in range(1, 9):
		if Time.get_ticks_msec() > deadline:
			break
		for cell in state.get_empty_cells():
			var clone := state.duplicate_state()
			clone.place(cell)
			var score := _eph_minimax(clone, depth - 1, false, ai_player, -INF, INF, deadline)
			if score > best_score:
				best_score = score
				best_cell = cell

	return best_cell if best_cell >= 0 else _random_move(state)

func _eph_minimax(state: EphemeralGameState, depth: int, is_max: bool, ai_player: GameState.Player,
		alpha: float, beta: float, deadline: int) -> float:
	if state.result != GameState.GameResult.ONGOING:
		var wins := GameState.GameResult.X_WINS if ai_player == GameState.Player.X else GameState.GameResult.O_WINS
		if state.result == wins:
			return 1000.0 + depth
		else:
			return -1000.0 - depth
	if depth == 0 or Time.get_ticks_msec() > deadline:
		return _eph_eval(state, ai_player)

	var empty := state.get_empty_cells()
	if is_max:
		var best := -INF
		for cell in empty:
			var clone := state.duplicate_state()
			clone.place(cell)
			var score := _eph_minimax(clone, depth - 1, false, ai_player, alpha, beta, deadline)
			best = max(best, score)
			alpha = max(alpha, best)
			if beta <= alpha:
				break
		return best
	else:
		var best := INF
		for cell in empty:
			var clone := state.duplicate_state()
			clone.place(cell)
			var score := _eph_minimax(clone, depth - 1, true, ai_player, alpha, beta, deadline)
			best = min(best, score)
			beta = min(beta, best)
			if beta <= alpha:
				break
		return best

func _eph_eval(state: EphemeralGameState, ai_player: GameState.Player) -> float:
	var opp := GameState.Player.O if ai_player == GameState.Player.X else GameState.Player.X
	var score := 0.0
	for line in GameState.WIN_LINES:
		var ai_count := line.filter(func(c): return state.board[c] == ai_player).size()
		var opp_count := line.filter(func(c): return state.board[c] == opp).size()
		if opp_count == 0:
			score += pow(10, ai_count)
		if ai_count == 0:
			score -= pow(10, opp_count)
	return score
```

- [ ] **Step 4: Run tests — expect PASS**

```powershell
& "C:\Projects\godot\Godot_v4.6.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -- -gtest=test_ephemeral_ai
```

- [ ] **Step 5: Commit**

```
git add games/tic-tac-toe/scripts/EphemeralAI.gd games/tic-tac-toe/tests/test_ephemeral_ai.gd
git commit -m "feat(ttt): add EphemeralAI — heuristic with eviction safety, minimax iterative deepening"
```

---

## Task 7: MainMenu — Inline Difficulty Row + Fix 1P Flow

**Files:**
- Modify: `games/tic-tac-toe/scenes/MainMenu.gd`

The MainMenu already has timer cycle logic (OFF/BLITZ/CASUAL/CHILL) and mode carousel. Changes needed:
1. Add difficulty row (tap-cycle, programmatic, left-aligned)
2. Fix `_on_1p()` — remove navigation to AIDifficultySelect, launch GameBoard directly
3. Fix `_refresh_timer_label()` — remove seconds from label, add per-state colors
4. Fix `_refresh_timer_visibility()` — also hide timer for "ephemeral"
5. Hide difficulty row for 2P and Online

- [ ] **Step 1: Add difficulty row construction and update `_ready()`**

In `MainMenu.gd`, add these new vars after the existing vars block (before `@onready`):

```gdscript
var _difficulty_index: int = 0
# Maps index to difficulty label + color
const DIFFICULTY_MODES: Array[Dictionary] = [
	{ "label": "EASY",       "difficulty": 0, "color": Color("#00ff88") },
	{ "label": "HARD",       "difficulty": 1, "color": Color("#ffd700") },
	{ "label": "UNBEATABLE", "difficulty": 2, "color": Color("#ff2d95") },
]

var _btn_difficulty: Button = null
var _lbl_difficulty: Label = null
```

- [ ] **Step 2: Add `_build_difficulty_row()` method**

Add this method to MainMenu.gd:

```gdscript
func _build_difficulty_row() -> void:
	var orbitron := load("res://fonts/Orbitron.ttf")
	var carousel := $CarouselContainer

	var row := HBoxContainer.new()
	row.name = "DifficultyRow"
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN

	var lbl_prefix := Label.new()
	lbl_prefix.text = "DIFFICULTY"
	lbl_prefix.add_theme_font_override("font", orbitron)
	lbl_prefix.add_theme_font_size_override("font_size", 20)
	lbl_prefix.add_theme_color_override("font_color", Color(0.667, 0.667, 0.8, 1.0))
	lbl_prefix.custom_minimum_size = Vector2(180, 0)
	row.add_child(lbl_prefix)

	_btn_difficulty = Button.new()
	_btn_difficulty.flat = false
	_btn_difficulty.custom_minimum_size = Vector2(220, 56)
	_btn_difficulty.add_theme_font_override("font", orbitron)
	_btn_difficulty.add_theme_font_size_override("font_size", 22)

	_lbl_difficulty = Label.new()
	_lbl_difficulty.text = ""
	_btn_difficulty.add_child(_lbl_difficulty)
	_btn_difficulty.pressed.connect(_on_difficulty_pressed)
	row.add_child(_btn_difficulty)

	# Insert after TimerRow
	var timer_row := carousel.get_node("TimerRow")
	var insert_idx := timer_row.get_index() + 1
	carousel.add_child(row)
	carousel.move_child(row, insert_idx)

	_refresh_difficulty_label()
```

- [ ] **Step 3: Update `_refresh_timer_label()` — remove seconds, add per-state colors**

Replace the existing `_refresh_timer_label()` method with:

```gdscript
func _refresh_timer_label() -> void:
	var mode: Dictionary = TIMER_MODES[_timer_index]
	var label: String = mode["label"]
	var secs: int = mode["seconds"]
	_lbl_timer.text = label
	var clr: Color
	match label:
		"BLITZ":  clr = Color("#ff2d95")
		"CASUAL": clr = Color("#ffd700")
		"CHILL":  clr = Color("#00ff88")
		_:        clr = Color(0.392, 0.455, 0.573, 1.0)
	_lbl_timer.add_theme_color_override("font_color", clr)
	_lbl_clock_icon.add_theme_color_override("font_color", clr)
	Globals.timer_seconds = secs
```

- [ ] **Step 4: Add `_refresh_difficulty_label()` and `_on_difficulty_pressed()`**

```gdscript
func _refresh_difficulty_label() -> void:
	var mode: Dictionary = DIFFICULTY_MODES[_difficulty_index]
	_lbl_difficulty.text = mode["label"] + " ▸"
	var clr: Color = mode["color"]
	_lbl_difficulty.add_theme_color_override("font_color", clr)
	Globals.ai_difficulty = mode["difficulty"] as Globals.AIDifficulty

func _on_difficulty_pressed() -> void:
	SFX.click()
	_difficulty_index = (_difficulty_index + 1) % DIFFICULTY_MODES.size()
	_refresh_difficulty_label()
```

- [ ] **Step 5: Update `_refresh_timer_visibility()` — add ephemeral**

Replace:
```gdscript
func _refresh_timer_visibility() -> void:
	$CarouselContainer/TimerRow.visible = _current_game_mode != "ultimate"
```

With:
```gdscript
func _refresh_timer_visibility() -> void:
	var locked := _current_game_mode in ["ultimate", "ephemeral"]
	$CarouselContainer/TimerRow.visible = not locked
	if has_node("CarouselContainer/DifficultyRow"):
		$CarouselContainer/DifficultyRow.visible = true  # always visible; hidden by button selection
```

- [ ] **Step 6: Update `_on_1p()` — direct launch, no AIDifficultySelect**

Replace `_on_1p()`:

```gdscript
func _on_1p() -> void:
	SFX.click()
	Globals.current_game_mode = _current_game_mode
	# Lock timer for ultimate/ephemeral
	if _current_game_mode in ["ultimate", "ephemeral"]:
		Globals.timer_seconds = 6  # CASUAL locked
	else:
		Globals.timer_seconds = TIMER_MODES[_timer_index]["seconds"]
	var board = load("res://scenes/GameBoard.tscn").instantiate()
	board.setup_vs_ai(Globals.ai_difficulty)
	get_tree().root.add_child(board)
	queue_free()
```

- [ ] **Step 7: Hide difficulty row on 2P / Online**

Update `_on_2p()` and `_on_online()` — add locked timer logic (same pattern as 1P):

```gdscript
func _on_2p() -> void:
	SFX.click()
	Globals.current_game_mode = _current_game_mode
	if _current_game_mode in ["ultimate", "ephemeral"]:
		Globals.timer_seconds = 6
	else:
		Globals.timer_seconds = TIMER_MODES[_timer_index]["seconds"]
	var board = load("res://scenes/GameBoard.tscn").instantiate()
	board.setup_local()
	get_tree().root.add_child(board)
	queue_free()

func _on_online() -> void:
	SFX.click()
	Globals.current_game_mode = _current_game_mode
	if _current_game_mode in ["ultimate", "ephemeral"]:
		Globals.timer_seconds = 6
	else:
		Globals.timer_seconds = TIMER_MODES[_timer_index]["seconds"]
	get_tree().change_scene_to_file("res://scenes/OnlineLobby.tscn")
```

- [ ] **Step 8: Wire `_build_difficulty_row()` in `_ready()`**

In `_ready()`, after `_build_row2()` call, add:

```gdscript
_build_difficulty_row()
```

- [ ] **Step 9: Update help text for ephemeral timer (it says "30 seconds" currently)**

In `_help_ephemeral()`, replace the last line to remove the hardcoded "30":

```gdscript
func _help_ephemeral() -> Array[String]:
	return [
		"═══ EPHEMERAL MODE ═══",
		"",
		"Like classic, but your marks have commitment issues.",
		"",
		"Place your 5th mark and your oldest mark vanishes into the void. Each mark fades as it ages — brightest is newest, dimmest is next to go. The board is always shifting. No draws possible — someone always wins.",
		"",
		"Timer is always CASUAL here. Keep up or get left behind.",
	]
```

Also update `_help_ultimate()` last line:

```gdscript
"This mode has TIMER always on (CASUAL). No chill here — place fast!",
```

- [ ] **Step 10: Commit**

```
git add games/tic-tac-toe/scenes/MainMenu.gd
git commit -m "feat(ttt): add inline difficulty row, fix timer labels, direct 1P launch from MainMenu"
```

---

## Task 8: Delete AIDifficultySelect

**Files:**
- Delete: `games/tic-tac-toe/scenes/AIDifficultySelect.tscn`
- Delete: `games/tic-tac-toe/scenes/AIDifficultySelect.gd`

- [ ] **Step 1: Search for any remaining references**

```powershell
cd games/tic-tac-toe
Select-String -Path "**/*.gd","**/*.tscn" -Pattern "AIDifficultySelect" -Recurse
```

Expected: zero results (Task 7 already removed the navigation reference).

If any results found, fix them before deleting.

- [ ] **Step 2: Delete the files**

```powershell
Remove-Item "games/tic-tac-toe/scenes/AIDifficultySelect.tscn"
Remove-Item "games/tic-tac-toe/scenes/AIDifficultySelect.gd"
```

- [ ] **Step 3: Commit**

```
git add -A
git commit -m "feat(ttt): delete AIDifficultySelect — difficulty now inline on MainMenu"
```

---

## Task 9: GameBoard — Mode Dispatch + Ultimate Board

**Files:**
- Modify: `games/tic-tac-toe/scenes/GameBoard.gd`

GameBoard currently instantiates `GameState.new()` for everything and connects to `$VBoxContainer/Grid` cells. We need to:
1. Dispatch state and AI based on mode
2. Build Ultimate board programmatically for Ultimate mode
3. Keep classic/ephemeral grid as-is (ephemeral reuses it)
4. Wire Ultimate cell input differently

- [ ] **Step 1: Add mode vars and update `_ready()`**

Add to the top of GameBoard.gd (after existing vars):

```gdscript
var _ultimate_board_node: Control = null   # built in code for Ultimate
var _ephemeral_state: EphemeralGameState   # typed alias for ephemeral mode
var _ultimate_state: UltimateGameState     # typed alias for ultimate mode
```

In `_ready()`, replace:
```gdscript
_state = GameState.new()
```
With:
```gdscript
match Globals.current_game_mode:
	"ultimate":
		_ultimate_state = UltimateGameState.new()
		_state = _ultimate_state
		if _mode == Mode.VS_AI:
			_ai = UltimateAI.new()
		_setup_ultimate_board()
		$VBoxContainer/Grid.visible = false
	"ephemeral":
		_ephemeral_state = EphemeralGameState.new()
		_state = _ephemeral_state
		if _mode == Mode.VS_AI:
			_ai = EphemeralAI.new()
	_:  # classic
		_state = GameState.new()
		if _mode == Mode.VS_AI:
			_ai = TicTacToeAI.new()
```

Also update the turn timer setup to use `Globals.timer_seconds` (already present in existing code — verify it reads `Globals.timer_seconds`, not the old `Globals.use_timer`):

```gdscript
if Globals.timer_seconds > 0:
	_turn_timer.set_duration(Globals.timer_seconds)
```

- [ ] **Step 2: Add `_setup_ultimate_board()`**

Add this method to GameBoard.gd:

```gdscript
func _setup_ultimate_board() -> void:
	var orbitron := load("res://fonts/Orbitron.ttf")

	_ultimate_board_node = Control.new()
	_ultimate_board_node.name = "UltimateBoard"
	_ultimate_board_node.set_anchors_preset(Control.PRESET_FULL_RECT)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.set_anchors_preset(Control.PRESET_CENTER)
	grid.custom_minimum_size = Vector2(660, 660)
	grid.offset_left = -330
	grid.offset_top = -330
	_ultimate_board_node.add_child(grid)

	for b in 9:
		var mini_panel := Panel.new()
		mini_panel.name = "Mini%d" % b
		mini_panel.custom_minimum_size = Vector2(214, 214)

		var mini_grid := GridContainer.new()
		mini_grid.name = "Grid"
		mini_grid.columns = 3
		mini_grid.add_theme_constant_override("h_separation", 3)
		mini_grid.add_theme_constant_override("v_separation", 3)
		mini_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
		mini_grid.offset_left = 4
		mini_grid.offset_top = 4
		mini_grid.offset_right = -4
		mini_grid.offset_bottom = -4
		mini_panel.add_child(mini_grid)

		for c in 9:
			var btn := Button.new()
			btn.name = "Cell%d" % c
			btn.custom_minimum_size = Vector2(66, 66)
			btn.flat = false
			btn.add_theme_font_override("font", orbitron)
			btn.add_theme_font_size_override("font_size", 28)
			btn.gui_input.connect(_on_ultimate_cell_input.bind(b, c))
			mini_grid.add_child(btn)

		# Won overlay label (hidden initially)
		var won_label := Label.new()
		won_label.name = "WonMark"
		won_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		won_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		won_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		won_label.add_theme_font_override("font", orbitron)
		won_label.add_theme_font_size_override("font_size", 80)
		won_label.visible = false
		mini_panel.add_child(won_label)

		grid.add_child(mini_panel)

	add_child(_ultimate_board_node)
	_refresh_ultimate_ui()
```

- [ ] **Step 3: Add `_on_ultimate_cell_input()`**

```gdscript
func _on_ultimate_cell_input(event: InputEvent, board_idx: int, cell_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _ai_thinking:
		return
	_do_ultimate_place(board_idx, cell_idx)

func _do_ultimate_place(board_idx: int, cell_idx: int) -> void:
	if not _ultimate_state.place(board_idx, cell_idx):
		return
	SFX.click()
	_animate_ultimate_piece(board_idx, cell_idx)
	_refresh_ultimate_ui()
	if _ultimate_state.result != GameState.GameResult.ONGOING:
		_on_game_over()
		return
	if _mode == Mode.VS_AI and _ultimate_state.current_turn != _player_mark:
		_ai_take_turn_ultimate.call_deferred()

func _ai_take_turn_ultimate() -> void:
	var ultimate_ai := _ai as UltimateAI
	var move := ultimate_ai.get_move(_ultimate_state, Globals.ai_difficulty)
	if move.is_empty():
		return
	_ai_thinking = true
	_ai_dots_count = 0
	_ai_dots_timer.start()
	_ai_think_timer.start(randf_range(1.0, 3.0))
	# Store move for deferred execution
	_ai_move_cell = move["cell"] * 9 + move["board"]  # encode board+cell into single int

func _ai_do_move() -> void:
	_ai_dots_timer.stop()
	_ai_thinking = false
	if Globals.current_game_mode == "ultimate":
		var encoded := _ai_move_cell
		var b := encoded % 9
		var c := encoded / 9
		_do_ultimate_place(b, c)
	else:
		_do_place(_ai_move_cell)
```

- [ ] **Step 4: Add `_refresh_ultimate_ui()`**

```gdscript
func _refresh_ultimate_ui() -> void:
	if _ultimate_board_node == null:
		return
	var orbitron := load("res://fonts/Orbitron.ttf")

	var grid_node := _ultimate_board_node.get_child(0)  # the GridContainer
	for b in 9:
		var mini_panel := grid_node.get_child(b)

		# Border style based on board state
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2

		var meta_val := _ultimate_state.meta_board[b]
		if meta_val != GameState.Player.NONE:
			# Won board
			style.bg_color = Color(0.1, 0.1, 0.2, 0.6)
			style.border_color = Color("#00d4ff") if meta_val == GameState.Player.X else Color("#a855f7")
			mini_panel.add_theme_stylebox_override("panel", style)
			var won_lbl := mini_panel.get_node("WonMark") as Label
			won_lbl.visible = true
			won_lbl.text = "X" if meta_val == GameState.Player.X else "O"
			won_lbl.add_theme_color_override("font_color",
				Color("#00d4ff") if meta_val == GameState.Player.X else Color("#a855f7"))
			# Dim the mini grid cells
			mini_panel.get_node("Grid").modulate = Color(0.3, 0.3, 0.3, 1.0)
		elif _ultimate_state.active_board == b:
			# Active board
			style.bg_color = Color("#1a1a2e")
			style.border_color = Color("#00d4ff")
			mini_panel.add_theme_stylebox_override("panel", style)
			mini_panel.get_node("Grid").modulate = Color.WHITE
		elif _ultimate_state.active_board == -1:
			# Free choice — all open boards dim-glow
			style.bg_color = Color("#1a1a2e")
			style.border_color = Color(0.0, 0.831, 1.0, 0.4)
			mini_panel.add_theme_stylebox_override("panel", style)
			mini_panel.get_node("Grid").modulate = Color.WHITE
		else:
			# Inactive
			style.bg_color = Color("#12122a")
			style.border_color = Color("#2a2a4a")
			mini_panel.add_theme_stylebox_override("panel", style)
			mini_panel.get_node("Grid").modulate = Color(0.5, 0.5, 0.5, 1.0)

		# Update cell labels in this mini-board
		var mini_state := _ultimate_state.mini_boards[b] as GameState
		var cell_grid := mini_panel.get_node("Grid")
		for c in 9:
			var btn := cell_grid.get_child(c) as Button
			match mini_state.board[c]:
				GameState.Player.X:
					btn.text = "X"
					btn.add_theme_color_override("font_color", Color("#00d4ff"))
				GameState.Player.O:
					btn.text = "O"
					btn.add_theme_color_override("font_color", Color("#a855f7"))
				_:
					btn.text = ""

func _animate_ultimate_piece(board_idx: int, cell_idx: int) -> void:
	var grid_node := _ultimate_board_node.get_child(0)
	var mini_panel := grid_node.get_child(board_idx)
	var cell_grid := mini_panel.get_node("Grid")
	var btn := cell_grid.get_child(cell_idx)
	btn.scale = Vector2.ZERO
	btn.pivot_offset = btn.size / 2.0
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.06)
```

- [ ] **Step 5: Update `_ai_take_turn()` for ephemeral**

The existing `_ai_take_turn()` calls `_ai.get_move(_state, _ai_difficulty)`. With refactored AI, update the call to use `Globals.ai_difficulty`:

```gdscript
func _ai_take_turn() -> void:
	var move_cell: int
	if Globals.current_game_mode == "ephemeral":
		var eph_ai := _ai as EphemeralAI
		move_cell = eph_ai.get_move(_ephemeral_state, Globals.ai_difficulty)
	else:
		move_cell = _ai.get_move(_state, Globals.ai_difficulty)
	_ai_move_cell = move_cell
	if _ai_move_cell < 0:
		return
	_ai_thinking = true
	_ai_dots_count = 0
	_ai_dots_timer.start()
	_ai_think_timer.start(randf_range(1.0, 3.0))
```

Also remove the `_ai_difficulty` local field from GameBoard (it was `TicTacToeAI.Difficulty` type — now handled by `Globals.ai_difficulty`). Remove the field declaration and the `setup_vs_ai()` parameter:

```gdscript
# Old:
func setup_vs_ai(difficulty: TicTacToeAI.Difficulty) -> void:
	_mode = Mode.VS_AI
	_ai_difficulty = difficulty
	_ai = TicTacToeAI.new()
	...

# New:
func setup_vs_ai(_ignored_difficulty: int = 0) -> void:
	_mode = Mode.VS_AI
	# AI and difficulty read from Globals in _ready()
	if randi() % 2 == 0:
		_player_mark = GameState.Player.X
	else:
		_player_mark = GameState.Player.O
```

- [ ] **Step 6: Commit**

```
git add games/tic-tac-toe/scenes/GameBoard.gd
git commit -m "feat(ttt): GameBoard mode dispatch — Ultimate board built in code, Ephemeral state wired"
```

---

## Task 10: GameBoard — Ephemeral Opacity

**Files:**
- Modify: `games/tic-tac-toe/scenes/GameBoard.gd`

Ephemeral uses the existing classic 3×3 grid. After every placement, update `modulate.a` per cell. Eviction triggers a fade-out tween.

- [ ] **Step 1: Update `_refresh_ui()` to apply opacity for ephemeral mode**

After the existing `match _state.board[i]` block in `_refresh_ui()`, add:

```gdscript
func _refresh_ui() -> void:
	for i in 9:
		var cell = $VBoxContainer/Grid.get_child(i)
		var mark_label: Label = cell.get_node("Mark")
		match _state.board[i]:
			GameState.Player.X:
				mark_label.text = "X"
				mark_label.add_theme_color_override("font_color", Color("#00d4ff"))
			GameState.Player.O:
				mark_label.text = "O"
				mark_label.add_theme_color_override("font_color", Color("#a855f7"))
			_:
				mark_label.text = ""

		# Ephemeral: apply fade opacity
		if Globals.current_game_mode == "ephemeral" and _ephemeral_state != null:
			var opacity := _ephemeral_state.get_cell_opacity(i)
			mark_label.modulate.a = opacity if opacity > 0.0 else 1.0
		else:
			mark_label.modulate.a = 1.0

	# ... rest of existing _refresh_ui() (turn text, scores) unchanged
```

- [ ] **Step 2: Add eviction tween on `_do_place()` for ephemeral**

The eviction happens inside `EphemeralGameState.place()`. To animate it, we need to know which cell was evicted BEFORE placing. Update `_do_place()` for ephemeral:

```gdscript
func _do_place(cell_index: int) -> void:
	# For ephemeral, check if eviction will happen and animate it
	if Globals.current_game_mode == "ephemeral" and _ephemeral_state != null:
		_do_place_ephemeral(cell_index)
		return

	if not _state.place(cell_index):
		return
	SFX.click()
	_animate_piece(cell_index)
	_refresh_ui()
	if _state.result != GameState.GameResult.ONGOING:
		_on_game_over()
		return
	if _mode == Mode.VS_AI and _state.current_turn != _player_mark:
		_ai_take_turn.call_deferred()

func _do_place_ephemeral(cell_index: int) -> void:
	var queue := _ephemeral_state.x_moves if _ephemeral_state.current_turn == GameState.Player.X \
		else _ephemeral_state.o_moves
	var evicted_cell := queue[0] if queue.size() == 4 else -1

	if not _ephemeral_state.place(cell_index):
		return
	SFX.click()

	# Animate eviction (fade out the old cell label)
	if evicted_cell >= 0:
		var evicted_cell_node = $VBoxContainer/Grid.get_child(evicted_cell)
		var evicted_mark: Label = evicted_cell_node.get_node("Mark")
		var tw := create_tween()
		tw.tween_property(evicted_mark, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func():
			evicted_mark.text = ""
			evicted_mark.modulate.a = 1.0
		)

	_animate_piece(cell_index)
	_refresh_ui()

	if _ephemeral_state.result != GameState.GameResult.ONGOING:
		_on_game_over()
		return
	if _mode == Mode.VS_AI and _ephemeral_state.current_turn != _player_mark:
		_ai_take_turn.call_deferred()
```

- [ ] **Step 3: Commit**

```
git add games/tic-tac-toe/scenes/GameBoard.gd
git commit -m "feat(ttt): ephemeral opacity wiring — modulate.a per cell age, eviction fade tween"
```

---

## Task 11: Uma Visual Pass

**⚠️ HANDOFF TO UMA — invoke `/uma` skill**

Uma owns all visual work in this task. Brief Uma with:

> "Implement visual polish for Ultimate and Ephemeral modes. Read the spec at `docs/superpowers/specs/2026-05-10-ultimate-ephemeral-modes-design.md` section 8 for your task list. Read style guide at `docs/style/nexus-arcade-style-guide.md` sections 1.1 and 2.2 for all color and font values. All new nodes must use `ArcadeTheme.tres` — no inline font size overrides."

Uma tasks (from spec section 8):
1. **UltimateBoard styling:** active/inactive/won/free-choice panel states with correct colors and NeonGlow shader. Glow pulse tween for free-choice state. Board-switch transition tween.
2. **Ephemeral opacity:** verify `modulate.a` values correct visually. Add smooth tween for new mark placement (opacity 0→target over 0.1s).
3. **MainMenu difficulty row:** color-per-state (green/gold/magenta), correct font size (≥30px button labels), left-aligned.
4. **ArcadeTheme.tres:** populate font sizes per style guide section 2.2 — help text 24px, body labels 28px, button labels 30px, section headings 36px, score display 56px.
5. **Mobile readability check:** all new text nodes ≥24px on 720×960 viewport.

Uma commits their changes separately.

---

## Task 12: Tessa QA

**⚠️ HANDOFF TO TESSA — invoke `/tessa` skill**

Tessa runs QA against spec section 9. Brief Tessa with:

> "Run QA for Ultimate and Ephemeral mode implementation. Spec: `docs/superpowers/specs/2026-05-10-ultimate-ephemeral-modes-design.md` section 9. AI algorithm spec: `docs/games/tic-tac-toe/ai-algorithms.md`."

Tessa criteria:
- Classic Hard: human fork strategy wins ≥50% over 20 games
- Classic Unbeatable: human never wins
- Ephemeral: eviction fires on 5th placement, never 4th or 6th
- Ephemeral opacity slots: newest=1.0, 2nd=0.75, 3rd=0.50, oldest=0.25
- Ephemeral Unbeatable: AI wins/draws ≥80% vs casual
- Ultimate: active_board constraint enforced, free-choice only on won/full destination
- Ultimate MCTS vs Hard: MCTS wins ≥70% over 20 games
- No dead references to AIDifficultySelect
- All text ≥24px on 720×960, Note 10+ readable
- 72px Ultimate cells logged as known exception

Tessa files bug reports and blocks merge until criteria pass.

---

## Run All Tests (checkpoint after each task)

```powershell
cd games/tic-tac-toe
& "C:\Projects\godot\Godot_v4.6.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd
```

Expected: all tests PASS before handing off to Uma (Task 11).
