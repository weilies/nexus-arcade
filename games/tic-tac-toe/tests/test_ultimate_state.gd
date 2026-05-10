extends GutTest

var state: UltimateGameState

func before_each():
	state = UltimateGameState.new()

func test_initial_active_board_is_free_choice():
	assert_eq(state.active_board, -1)

func test_initial_meta_all_none():
	for i in 9:
		assert_eq(state.meta_board[i], GameState.Player.NONE)

func test_place_on_wrong_board_fails():
	# First move: free choice. Place on board 0, cell 4.
	state.place_on(0, 4)
	# Now active_board == 4. Placing on board 3 must fail.
	assert_false(state.place_on(3, 0))

func test_place_sends_to_correct_next_board():
	state.place_on(0, 4)   # X plays board 0, cell 4 -> next active = 4
	assert_eq(state.active_board, 4)

func test_place_on_correct_board_succeeds():
	state.place_on(0, 4)   # active now 4
	assert_true(state.place_on(4, 0))

func test_won_mini_board_recorded_in_meta():
	# Win mini-board 0 for X via middle column [1,4,7]
	# Each move's cell_idx determines opponent's active board.
	# O plays cell 0 to send X back to board 0 each time.
	state.place_on(0, 1)   # X board 0 cell 1 -> active=1
	state.place_on(1, 0)   # O board 1 cell 0 -> active=0
	state.place_on(0, 4)   # X board 0 cell 4 -> active=4
	state.place_on(4, 0)   # O board 4 cell 0 -> active=0
	state.place_on(0, 7)   # X board 0 cell 7 -> X wins board 0, meta[0]=X
	assert_eq(state.meta_board[0], GameState.Player.X)

func test_sent_to_won_board_gives_free_choice():
	# Win mini-board 4 for X first
	_win_mini_board(state, 4, GameState.Player.X)
	# Now if active_board would be 4 (won), it should be -1
	assert_eq(state.active_board, -1)

func test_meta_win_ends_game():
	# Win boards 0,1,2 for X (top row of meta)
	_win_meta_row(state)
	assert_eq(state.result, GameState.GameResult.X_WINS)

func test_get_legal_moves_respects_active_board():
	state.place_on(0, 4)   # active = 4
	var moves := state.get_legal_moves()
	for m in moves:
		assert_eq(m["board"], 4)

func test_get_legal_moves_free_choice_returns_all_boards():
	# active = -1 on first move
	var moves := state.get_legal_moves()
	# Should have 9 boards x 9 cells = 81 moves (all empty)
	assert_eq(moves.size(), 81)

# Helpers
func _win_mini_board(s: UltimateGameState, board_idx: int, player: GameState.Player) -> void:
	# Force-set mini board as won. Direct manipulation for test setup.
	s.mini_boards[board_idx].board[0] = player
	s.mini_boards[board_idx].board[1] = player
	s.mini_boards[board_idx].board[2] = player
	s.mini_boards[board_idx].result = GameState.GameResult.X_WINS if player == GameState.Player.X else GameState.GameResult.O_WINS
	s.meta_board[board_idx] = player

func _win_meta_row(s: UltimateGameState) -> void:
	# Win boards 0,1,2 for X - direct manipulation
	for b in [0, 1, 2]:
		_win_mini_board(s, b, GameState.Player.X)
	# Trigger meta win check
	s._check_meta_result()
