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
