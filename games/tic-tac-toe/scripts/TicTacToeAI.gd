class_name TicTacToeAI
extends RefCounted

# Returns the cell index AI wants to play (-1 if no move available).
# Override get_move in subclasses for different state types.
func get_move(state: GameState, difficulty: Globals.AIDifficulty):
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

# Rule-based heuristic: win -> block -> center -> corner -> edge
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
		var marks: Array = line.filter(func(c): return state.board[c] == player)
		var empties: Array = line.filter(func(c): return state.board[c] == GameState.Player.NONE)
		if marks.size() == 2 and empties.size() == 1:
			return empties[0]
	return -1

func _minimax_move(state: GameState) -> int:
	var ai_player := state.current_turn
	# Prefer immediate winning moves over equally-scored delayed wins
	for cell in state.get_empty_cells():
		var clone := _clone(state)
		clone.place(cell)
		if clone.result != GameState.GameResult.ONGOING and clone.result != GameState.GameResult.DRAW:
			var winner := GameState.Player.X if clone.result == GameState.GameResult.X_WINS else GameState.Player.O
			if winner == ai_player:
				return cell
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
