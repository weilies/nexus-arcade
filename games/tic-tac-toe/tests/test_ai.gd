extends GutTest

var ai: TicTacToeAI

func before_each():
	ai = TicTacToeAI.new()

func test_easy_returns_valid_cell():
	var state = GameState.new()
	var cell = ai.get_move(state, TicTacToeAI.Difficulty.EASY)
	assert_true(cell >= 0 and cell <= 8)
	assert_eq(state.board[cell], GameState.Player.NONE)

func test_easy_returns_neg1_on_full_board():
	var state = GameState.new()
	state.place(0); state.place(1)
	state.place(3); state.place(6)
	state.place(4); state.place(2)
	state.place(7); state.place(5)
	state.place(8)
	var cell = ai.get_move(state, TicTacToeAI.Difficulty.EASY)
	assert_eq(cell, -1)

func test_hard_blocks_winning_move():
	# X at 0,1 — if not blocked at 2, X wins. AI is O, plays next.
	var state = GameState.new()
	state.place(0)  # X
	state.place(4)  # O (first AI move, manual)
	state.place(1)  # X  — now X threatens 2
	# AI (O) must play at 2 to block
	var cell = ai.get_move(state, TicTacToeAI.Difficulty.HARD)
	assert_eq(cell, 2)

func test_hard_takes_winning_move():
	# O at 3,4 — AI should take 5 to win
	var state = GameState.new()
	state.board[3] = GameState.Player.O
	state.board[4] = GameState.Player.O
	state.board[0] = GameState.Player.X
	state.board[1] = GameState.Player.X
	state.current_turn = GameState.Player.O
	var cell = ai.get_move(state, TicTacToeAI.Difficulty.HARD)
	assert_eq(cell, 5)

func test_hard_never_loses():
	# Exhaustive: hard AI as O should never lose when X plays randomly
	var ai_easy = TicTacToeAI.new()
	for _trial in 100:
		var state = GameState.new()
		while state.result == GameState.GameResult.ONGOING:
			var cell: int
			if state.current_turn == GameState.Player.X:
				cell = ai_easy.get_move(state, TicTacToeAI.Difficulty.EASY)
			else:
				cell = ai.get_move(state, TicTacToeAI.Difficulty.HARD)
			state.place(cell)
		assert_ne(state.result, GameState.GameResult.X_WINS,
			"Hard AI (O) lost to random (X)")
