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
