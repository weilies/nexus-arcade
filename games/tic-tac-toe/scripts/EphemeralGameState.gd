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
		var p: int = board[line[0]]
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
