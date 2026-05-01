class_name TicTacToeAI
extends RefCounted

enum Difficulty { EASY, HARD }

func get_move(state: GameState, difficulty: Difficulty) -> int:
	match difficulty:
		Difficulty.EASY:
			return _random_move(state)
		Difficulty.HARD:
			return _minimax_move(state)
	return -1

func _random_move(state: GameState) -> int:
	var empty = state.get_empty_cells()
	if empty.is_empty():
		return -1
	return empty[randi() % empty.size()]

func _minimax_move(state: GameState) -> int:
	var ai_player = state.current_turn
	var best_score = -100
	var best_cell = -1
	for cell in state.get_empty_cells():
		var clone = _clone(state)
		clone.place(cell)
		var score = _minimax(clone, false, ai_player)
		if score > best_score:
			best_score = score
			best_cell = cell
	return best_cell

func _minimax(state: GameState, is_maximizing: bool, ai_player: GameState.Player) -> int:
	var r = state.result
	if r != GameState.GameResult.ONGOING:
		if r == GameState.GameResult.DRAW:
			return 0
		var winner = GameState.Player.X if r == GameState.GameResult.X_WINS else GameState.Player.O
		return 10 if winner == ai_player else -10

	var scores: Array = []
	for cell in state.get_empty_cells():
		var clone = _clone(state)
		clone.place(cell)
		scores.append(_minimax(clone, not is_maximizing, ai_player))
	return scores.max() if is_maximizing else scores.min()

func _clone(state: GameState) -> GameState:
	var c = GameState.new()
	c.board = state.board.duplicate()
	c.current_turn = state.current_turn
	c.result = state.result
	return c
