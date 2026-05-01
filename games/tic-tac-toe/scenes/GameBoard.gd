class_name GameBoard
extends Control

enum Mode { VS_AI, LOCAL, ONLINE }

var _state: GameState
var _ai: TicTacToeAI
var _mode: Mode
var _ai_difficulty: TicTacToeAI.Difficulty
var _score_x: int = 0
var _score_o: int = 0

func setup_vs_ai(difficulty: TicTacToeAI.Difficulty) -> void:
	_mode = Mode.VS_AI
	_ai_difficulty = difficulty
	_ai = TicTacToeAI.new()

func setup_local() -> void:
	_mode = Mode.LOCAL

func setup_online(_room_id: String, _player_mark: GameState.Player, _supabase) -> void:
	_mode = Mode.ONLINE

func _ready() -> void:
	_state = GameState.new()
	_connect_cells()
	_refresh_ui()

func _connect_cells() -> void:
	for i in 9:
		var cell = $VBoxContainer/Grid.get_child(i)
		cell.gui_input.connect(_on_cell_input.bind(i))
		cell.mouse_entered.connect(_on_cell_hover.bind(cell, true))
		cell.mouse_exited.connect(_on_cell_hover.bind(cell, false))

func _on_cell_hover(cell: Control, entering: bool) -> void:
	var idx = $VBoxContainer/Grid.get_children().find(cell)
	if idx < 0 or _state.board[idx] != GameState.Player.NONE:
		return
	var tween = create_tween()
	var target_scale = Vector2(1.05, 1.05) if entering else Vector2.ONE
	tween.tween_property(cell, "scale", target_scale, 0.1).set_trans(Tween.TRANS_QUAD)
	cell.pivot_offset = cell.size / 2.0

func _on_cell_input(event: InputEvent, cell_index: int) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _mode == Mode.ONLINE:
		return
	_do_place(cell_index)

func _do_place(cell_index: int) -> void:
	if not _state.place(cell_index):
		return
	_animate_piece(cell_index)
	_refresh_ui()
	if _state.result != GameState.GameResult.ONGOING:
		_on_game_over()
		return
	if _mode == Mode.VS_AI and _state.current_turn == GameState.Player.O:
		_ai_take_turn.call_deferred()

func _ai_take_turn() -> void:
	var cell = _ai.get_move(_state, _ai_difficulty)
	if cell >= 0:
		_do_place(cell)

func _animate_piece(cell_index: int) -> void:
	var cell = $VBoxContainer/Grid.get_child(cell_index)
	var mark_label: Label = cell.get_node("Mark")
	mark_label.scale = Vector2.ZERO
	mark_label.pivot_offset = mark_label.size / 2.0
	var tween = create_tween()
	tween.tween_property(mark_label, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mark_label, "scale", Vector2.ONE, 0.06)

func _refresh_ui() -> void:
	for i in 9:
		var cell = $VBoxContainer/Grid.get_child(i)
		var mark_label: Label = cell.get_node("Mark")
		match _state.board[i]:
			GameState.Player.X:
				mark_label.text = "X"
				mark_label.add_theme_color_override("font_color", Color("#00d4ff"))
			GameState.Player.O:
				mark_label.text = "O"
				mark_label.add_theme_color_override("font_color", Color("#a855f7"))
			_:
				mark_label.text = ""

	var turn_text: String
	match _state.current_turn:
		GameState.Player.X:
			turn_text = "YOUR TURN — X" if _mode == Mode.VS_AI else "PLAYER 1 — X"
		GameState.Player.O:
			if _mode == Mode.VS_AI and _state.result == GameState.GameResult.ONGOING:
				turn_text = "AI THINKING..."
			elif _mode == Mode.LOCAL:
				turn_text = "PLAYER 2 — O"
			else:
				turn_text = "OPPONENT — O"
	$VBoxContainer/LblStatus.text = turn_text

	$VBoxContainer/ScoreRow/LblScoreX.text = "X: %d" % _score_x
	$VBoxContainer/ScoreRow/LblScoreO.text = "O: %d" % _score_o

func _highlight_win_line() -> void:
	var line = _state.get_winning_line()
	if line.is_empty():
		return
	for cell_index in line:
		var cell = $VBoxContainer/Grid.get_child(cell_index)
		var tween = create_tween().set_loops()
		tween.tween_property(cell, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.4)
		tween.tween_property(cell, "modulate", Color.WHITE, 0.4)

func _on_game_over() -> void:
	match _state.result:
		GameState.GameResult.X_WINS: _score_x += 1
		GameState.GameResult.O_WINS: _score_o += 1
		_: pass

	var winner: String
	match _state.result:
		GameState.GameResult.X_WINS: winner = "X"
		GameState.GameResult.O_WINS: winner = "O"
		_: winner = "draw"

	_highlight_win_line()
	var game_over = load("res://scenes/GameOver.tscn").instantiate()
	game_over.setup(winner, _score_x, _score_o, _mode, self)
	get_tree().root.add_child(game_over)
