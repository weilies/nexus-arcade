extends GutTest

var state: GameState

func before_each():
	state = GameState.new()

func test_initial_board_all_none():
	for i in 9:
		assert_eq(state.board[i], GameState.Player.NONE)

func test_initial_turn_is_x():
	assert_eq(state.current_turn, GameState.Player.X)

func test_place_returns_true_on_empty_cell():
	assert_true(state.place(0))

func test_place_returns_false_on_occupied_cell():
	state.place(0)
	assert_false(state.place(0))

func test_place_returns_false_out_of_bounds():
	assert_false(state.place(9))
	assert_false(state.place(-1))

func test_turn_alternates_after_place():
	state.place(0)
	assert_eq(state.current_turn, GameState.Player.O)
	state.place(1)
	assert_eq(state.current_turn, GameState.Player.X)

func test_row_win_detection():
	state.place(0); state.place(3)
	state.place(1); state.place(4)
	state.place(2)
	assert_eq(state.result, GameState.GameResult.X_WINS)

func test_column_win_detection():
	state.place(0); state.place(1)
	state.place(3); state.place(4)
	state.place(6)
	assert_eq(state.result, GameState.GameResult.X_WINS)

func test_diagonal_win_detection():
	state.place(0); state.place(1)
	state.place(4); state.place(2)
	state.place(8)
	assert_eq(state.result, GameState.GameResult.X_WINS)

func test_draw_detection():
	# X O X / O X O / O X O
	state.place(0); state.place(1)
	state.place(3); state.place(6)
	state.place(4); state.place(2)
	state.place(7); state.place(5)
	state.place(8)
	assert_eq(state.result, GameState.GameResult.DRAW)

func test_get_empty_cells_count():
	assert_eq(state.get_empty_cells().size(), 9)
	state.place(0)
	assert_eq(state.get_empty_cells().size(), 8)

func test_get_winning_line_returns_correct_cells():
	state.place(0); state.place(3)
	state.place(1); state.place(4)
	state.place(2)
	var line = state.get_winning_line()
	assert_eq(line, [0, 1, 2])

func test_to_dict_roundtrip():
	state.place(0); state.place(4)
	var d = state.to_dict()
	var state2 = GameState.new()
	state2.from_dict(d)
	assert_eq(state2.board[0], GameState.Player.X)
	assert_eq(state2.board[4], GameState.Player.O)
	assert_eq(state2.current_turn, state.current_turn)
