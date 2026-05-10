class_name UltimateGameState
extends RefCounted

# 9 mini-boards, each a classic 3x3 GameState
var mini_boards: Array = []       # Array[GameState], size 9
var meta_board: Array = []        # Array of GameState.Player, size 9
var active_board: int = -1        # -1 = free choice (first move or sent to won/full)
var current_turn: int = GameState.Player.X
var result: int = GameState.GameResult.ONGOING

func _init() -> void:
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

func _check_meta_result() -> void:
	for line in GameState.WIN_LINES:
		var p = meta_board[line[0]]
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
