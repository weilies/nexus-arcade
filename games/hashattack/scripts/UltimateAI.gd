class_name UltimateAI
extends TicTacToeAI

const MCTS_ITERATIONS := 500
const UCB1_C := 1.4142135  # sqrt(2)

# Returns { "board": int, "cell": int }
func get_move(state: GameState, difficulty: Globals.AIDifficulty):
	var ultimate_state := state as UltimateGameState
	match difficulty:
		Globals.AIDifficulty.EASY:
			return _random_ultimate_move(ultimate_state)
		Globals.AIDifficulty.HARD:
			return _heuristic_ultimate_move(ultimate_state)
		Globals.AIDifficulty.UNBEATABLE:
			return _mcts_move(ultimate_state)
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
		# Meta-position weight (corners=0,2,6,8 center=4 -> 1.5x)
		if b in [0, 2, 4, 6, 8]:
			score += 500  # approx 1.5x applied as flat bonus

	# Block opponent winning active mini-board
	var opp_can_win_mini := _opponent_can_win_mini(state, b, opp)
	if opp_can_win_mini and not wins_mini:
		score += 200

	# Destination board analysis (where opponent lands)
	var dest := c
	if state.meta_board[dest] != GameState.Player.NONE or state.mini_boards[dest].get_empty_cells().is_empty():
		score += 100  # free choice for opponent - no immediate harm
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
		var opp_marks: Array = line.filter(func(cc): return mini.board[cc] == opp)
		var empties: Array = line.filter(func(cc): return mini.board[cc] == GameState.Player.NONE)
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
			next_state.place_on(m["board"], m["cell"])
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
			rollout_state.place_on(rm["board"], rm["cell"])
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
