class_name EphemeralAI
extends TicTacToeAI

func get_move(state: GameState, difficulty: Globals.AIDifficulty) -> int:
	var eph := state as EphemeralGameState
	match difficulty:
		Globals.AIDifficulty.EASY:
			return _random_move(eph)
		Globals.AIDifficulty.HARD:
			return _ephemeral_heuristic(eph)
		Globals.AIDifficulty.UNBEATABLE:
			return _ephemeral_minimax_move(eph)
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
	if queue.size() == EphemeralGameState.MAX_MARKS:
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
		var ai_count: int = line.filter(func(c): return state.board[c] == ai_player).size()
		var opp_count: int = line.filter(func(c): return state.board[c] == opp).size()
		if opp_count == 0:
			score += pow(10, ai_count)
		if ai_count == 0:
			score -= pow(10, opp_count)
	return score
