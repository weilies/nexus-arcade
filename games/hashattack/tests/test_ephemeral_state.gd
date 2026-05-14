extends GutTest

var state: EphemeralGameState

func before_each():
	state = EphemeralGameState.new()

func test_initial_queues_empty():
	assert_eq(state.x_moves.size(), 0)
	assert_eq(state.o_moves.size(), 0)

func test_place_adds_to_queue():
	state.place(4)  # X
	assert_eq(state.x_moves.size(), 1)
	assert_eq(state.x_moves[0], 4)

func test_no_eviction_before_5th_mark():
	# X places 4 marks — no eviction yet
	state.place(0); state.place(1)   # X:0, O:1
	state.place(2); state.place(3)   # X:2, O:3
	state.place(5); state.place(6)   # X:5, O:6
	state.place(7); state.place(8)   # X:7, O:8
	# X has 4 marks: 0,2,5,7. Board cells 0,2,5,7 must still be X.
	assert_eq(state.board[0], GameState.Player.X)
	assert_eq(state.board[2], GameState.Player.X)
	assert_eq(state.board[5], GameState.Player.X)
	assert_eq(state.board[7], GameState.Player.X)
	assert_eq(state.x_moves.size(), 4)

func test_eviction_fires_on_5th_mark():
	# X places 4 marks, then 5th triggers eviction of 1st
	state.place(0); state.place(1)   # X:0, O:1
	state.place(2); state.place(3)   # X:2, O:3
	state.place(5); state.place(6)   # X:5, O:6
	state.place(7); state.place(8)   # X:7, O:8
	# X's 5th mark: place on cell 4
	state.place(4)
	# Cell 0 (X's oldest) must now be cleared
	assert_eq(state.board[0], GameState.Player.NONE)
	assert_eq(state.x_moves.size(), 4)
	assert_eq(state.x_moves[0], 2)  # 2 is now oldest

func test_opacity_newest_is_1():
	state.place(4)  # X at 4, only mark → newest → opacity 1.0
	assert_almost_eq(state.get_cell_opacity(4), 1.0, 0.001)

func test_opacity_4_marks():
	# X places 4 marks — check all opacity slots
	state.place(0); state.place(1)
	state.place(2); state.place(3)
	state.place(5); state.place(6)
	state.place(7); state.place(8)
	# X queue: [0, 2, 5, 7] oldest→newest
	assert_almost_eq(state.get_cell_opacity(0), 0.25, 0.001)  # oldest
	assert_almost_eq(state.get_cell_opacity(2), 0.50, 0.001)
	assert_almost_eq(state.get_cell_opacity(5), 0.75, 0.001)
	assert_almost_eq(state.get_cell_opacity(7), 1.00, 0.001)  # newest

func test_empty_cell_opacity_is_0():
	assert_almost_eq(state.get_cell_opacity(4), 0.0, 0.001)

func test_no_draw_possible():
	# Play until board would be "full" in classic — should not draw
	# With eviction, board never saturates past 8 marks.
	# Just verify result never becomes DRAW after 20 moves.
	for i in 20:
		var empty := state.get_empty_cells()
		if empty.is_empty() or state.result != GameState.GameResult.ONGOING:
			break
		state.place(empty[0])
	assert_ne(state.result, GameState.GameResult.DRAW)

func test_win_still_detected():
	# Force X to get 3 in a row (top row: 0,1,2)
	# X: 0, O: 3, X: 1, O: 4, X: 2
	state.place(0); state.place(3)
	state.place(1); state.place(4)
	state.place(2)
	assert_eq(state.result, GameState.GameResult.X_WINS)
