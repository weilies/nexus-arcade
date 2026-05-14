extends GutTest

var ai

func before_each():
	ai = UltimateAI.new()

func test_easy_returns_valid_move():
	var state := UltimateGameState.new()
	var move = ai.get_move(state, Globals.AIDifficulty.EASY)
	assert_true(move.has("board") and move.has("cell"))
	assert_between(move["board"], 0, 8)
	assert_between(move["cell"], 0, 8)

func test_easy_respects_active_board():
	var state := UltimateGameState.new()
	state.place_on(0, 4)   # active = 4
	var move = ai.get_move(state, Globals.AIDifficulty.EASY)
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
	var move = ai.get_move(state, Globals.AIDifficulty.HARD)
	# O must play cell 5 to win row [3,4,5]
	assert_eq(move["board"], 0)
	assert_eq(move["cell"], 5)

func test_unbeatable_returns_valid_move():
	var state := UltimateGameState.new()
	var move = ai.get_move(state, Globals.AIDifficulty.UNBEATABLE)
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
