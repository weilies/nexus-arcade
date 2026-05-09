class_name GameBoard
extends Control

enum Mode { VS_AI, LOCAL, ONLINE }

var _state: GameState
var _ai: TicTacToeAI
var _mode: Mode
var _ai_difficulty: TicTacToeAI.Difficulty
var _score_x: int = 0
var _score_o: int = 0
var _room_id: String = ""
var _player_mark: GameState.Player = GameState.Player.X
var _supabase_ref: SupabaseClient
var _turn_timer: TurnTimer
var _bridge: PortalBridge
var _game_over_fired: bool = false
var _ai_thinking: bool = false
var _ai_move_cell: int = -1
var _ai_think_timer: Timer
var _ai_dots_timer: Timer
var _ai_dots_count: int = 0
var _pts_awarded: int = 0

func setup_vs_ai(difficulty: TicTacToeAI.Difficulty) -> void:
	_mode = Mode.VS_AI
	_ai_difficulty = difficulty
	_ai = TicTacToeAI.new()
	# Randomize who goes first
	if randi() % 2 == 0:
		_player_mark = GameState.Player.X   # Player = X, goes first
	else:
		_player_mark = GameState.Player.O   # Player = O, AI goes first

func setup_local() -> void:
	_mode = Mode.LOCAL

func setup_online(room_id: String, player_mark: GameState.Player, sb: SupabaseClient) -> void:
	_mode = Mode.ONLINE
	_room_id = room_id
	_player_mark = player_mark
	_supabase_ref = sb

func _ready() -> void:
	var bg = load("res://scripts/BackgroundLayer.gd").new()
	add_child(bg)
	move_child(bg, 1)

	_state = GameState.new()
	_bridge = $Bridge if has_node("Bridge") else null
	if _bridge:
		_bridge.send_game_ready()

	_turn_timer = TurnTimer.new()
	if has_node("VBoxContainer/LblTimer"):
		_turn_timer.setup($VBoxContainer/LblTimer)
	add_child(_turn_timer)
	_turn_timer.timed_out.connect(_on_turn_timeout)
	if Globals.use_timer:
		_turn_timer.set_duration(Globals.timer_seconds)

	_ai_think_timer = Timer.new()
	_ai_think_timer.one_shot = true
	_ai_think_timer.timeout.connect(_ai_do_move)
	add_child(_ai_think_timer)

	_ai_dots_timer = Timer.new()
	_ai_dots_timer.wait_time = 0.5
	_ai_dots_timer.timeout.connect(_ai_update_dots)
	add_child(_ai_dots_timer)

	$VBoxContainer/BtnHome.pressed.connect(_on_home)
	_connect_cells()
	_refresh_ui()
	_update_streak_badge()

	# Turn announcement
	if _mode == Mode.VS_AI:
		var announce = $TurnAnnounce if has_node("TurnAnnounce") else null
		if announce:
			if _player_mark == GameState.Player.X:
				announce.text = "YOU GO FIRST"
			else:
				announce.text = "OPPONENT GOES FIRST"
			announce.visible = true
			announce.modulate = Color.WHITE
			var tw := create_tween()
			tw.tween_property(announce, "modulate:a", 0.0, 2.5).set_delay(0.5)
			tw.tween_callback(func(): announce.visible = false)

	if _mode == Mode.ONLINE:
		_supabase_ref.realtime_message.connect(_on_online_message)
		if _player_mark == GameState.Player.X:
			if Globals.use_timer:
				_turn_timer.set_duration(Globals.timer_seconds)
				_turn_timer.start()

	# AI first move if player is O
	if _mode == Mode.VS_AI and _player_mark == GameState.Player.O:
		_ai_take_turn.call_deferred()

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
	if _ai_thinking:
		return
	if _mode == Mode.ONLINE:
		if _state.current_turn != _player_mark:
			return
		_do_place_online(cell_index)
		return
	_do_place(cell_index)

func _do_place(cell_index: int) -> void:
	if not _state.place(cell_index):
		return
	SFX.click()
	_animate_piece(cell_index)
	_refresh_ui()
	if _state.result != GameState.GameResult.ONGOING:
		_on_game_over()
		return
	if _mode == Mode.VS_AI and _state.current_turn != _player_mark:
		_ai_take_turn.call_deferred()

func _ai_take_turn() -> void:
	_ai_move_cell = _ai.get_move(_state, _ai_difficulty)
	if _ai_move_cell < 0:
		return
	_ai_thinking = true
	_ai_dots_count = 0
	_ai_dots_timer.start()
	_ai_think_timer.start(randf_range(1.0, 3.0))

func _ai_do_move() -> void:
	_ai_dots_timer.stop()
	_ai_thinking = false
	_do_place(_ai_move_cell)

func _ai_update_dots() -> void:
	_ai_dots_count = (_ai_dots_count + 1) % 5
	var dots = ".".repeat(_ai_dots_count)
	$VBoxContainer/LblStatus.text = "AI THINKING" + dots

func _do_place_online(cell_index: int) -> void:
	if not _state.place(cell_index):
		return
	SFX.click()
	_turn_timer.stop()
	_animate_piece(cell_index)
	_supabase_ref.broadcast("room:" + _room_id, "move",
		{"cell": cell_index, "player": GameState.player_to_str(_player_mark)})
	_supabase_ref.patch_row("game_rooms", "id=eq." + _room_id,
		{"state": _state.to_dict()})
	_refresh_ui()
	if _state.result != GameState.GameResult.ONGOING:
		_on_game_over()

func _on_online_message(channel: String, event: String, payload: Dictionary) -> void:
	if channel != "room:" + _room_id:
		return
	match event:
		"move":
			var cell: int = payload.get("cell", -1)
			if cell < 0:
				return
			_turn_timer.stop()
			_state.place(cell)
			_animate_piece(cell)
			_refresh_ui()
			if _state.result != GameState.GameResult.ONGOING:
				_on_game_over()
			else:
				_turn_timer.start()
		"forfeit":
			_turn_timer.stop()
			var forfeiter = payload.get("player", "")
			_state.result = GameState.GameResult.O_WINS if forfeiter == "X" else GameState.GameResult.X_WINS
			_on_game_over()

func _on_turn_timeout() -> void:
	var my_mark = GameState.player_to_str(_player_mark)
	_supabase_ref.broadcast("room:" + _room_id, "forfeit", {"player": my_mark})
	_state.result = GameState.GameResult.O_WINS if _player_mark == GameState.Player.X else GameState.GameResult.X_WINS
	_on_game_over()

func _on_home() -> void:
	SFX.click()
	if _mode == Mode.ONLINE and _supabase_ref:
		_supabase_ref.broadcast("room:" + _room_id, "forfeit",
			{"player": GameState.player_to_str(_player_mark)})
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	queue_free()

func _exit_tree() -> void:
	if _supabase_ref and _supabase_ref.realtime_message.is_connected(_on_online_message):
		_supabase_ref.realtime_message.disconnect(_on_online_message)

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
			if _mode == Mode.VS_AI and _player_mark == GameState.Player.O:
				turn_text = "AI THINKING..."
			elif _mode == Mode.VS_AI:
				turn_text = "YOUR TURN — X"
			else:
				turn_text = "PLAYER 1 — X"
		GameState.Player.O:
			if _mode == Mode.VS_AI and _player_mark == GameState.Player.X:
				turn_text = "AI THINKING..."
			elif _mode == Mode.VS_AI:
				turn_text = "YOUR TURN — O"
			elif _mode == Mode.LOCAL:
				turn_text = "PLAYER 2 — O"
			else:
				turn_text = "OPPONENT — O"
		_:
			turn_text = ""
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

func _update_streak_badge() -> void:
	if not has_node("VBoxContainer/StreakBadge"):
		return
	if not Globals.is_signed_in():
		$VBoxContainer/StreakBadge.visible = false
		return
	$VBoxContainer/StreakBadge.visible = true
	var streak: int = Globals.current_streak.get(Globals.current_game_mode, 0)
	$VBoxContainer/StreakBadge/LblStreakCount.text = str(streak)
	var col: Color
	if streak >= 20:
		col = Color("#ff2d95")
	elif streak >= 10:
		col = Color("#a855f7")
	elif streak >= 5:
		col = Color("#00d4ff")
	else:
		col = Color(0.55, 0.55, 0.55, 0.8)
	$VBoxContainer/StreakBadge/LblStreakIcon.add_theme_color_override("font_color", col)
	$VBoxContainer/StreakBadge/LblStreakCount.add_theme_color_override("font_color", col)

func _award_points_if_signed_in(source: String) -> void:
	if not Globals.is_signed_in() or Globals.current_game_id.is_empty():
		return
	var result: Variant = await Globals.supabase.call_rpc("award_win_points", {
		"p_user_id":   Globals.current_user["id"],
		"p_game_id":   Globals.current_game_id,
		"p_game_mode": Globals.current_game_mode,
		"p_source":    source
	})
	_pts_awarded = int(result) if result != null else 0
	Globals.current_user["points"] = Globals.current_user.get("points", 0) + _pts_awarded
	Globals.current_streak[Globals.current_game_mode] = \
		Globals.current_streak.get(Globals.current_game_mode, 0) + 1
	_update_streak_badge()
	if _pts_awarded > 0:
		_show_pts_popup(_pts_awarded)

func _show_pts_popup(pts: int) -> void:
	var lbl := Label.new()
	lbl.text = "+%d ★" % pts
	lbl.add_theme_color_override("font_color", Color("#00d4ff"))
	lbl.position = Vector2(size.x / 2.0 - 50, size.y / 2.0 - 40)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.06)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.tween_callback(lbl.queue_free)

func _on_game_over() -> void:
	if _game_over_fired:
		return
	_game_over_fired = true
	match _state.result:
		GameState.GameResult.X_WINS: _score_x += 1
		GameState.GameResult.O_WINS: _score_o += 1
		_: pass

	var winner: String
	match _state.result:
		GameState.GameResult.X_WINS: winner = "X"
		GameState.GameResult.O_WINS: winner = "O"
		_: winner = "draw"

	# SFX: win/lose based on mode and player perspective
	match _state.result:
		GameState.GameResult.X_WINS:
			if _mode == Mode.LOCAL:
				SFX.win()
			elif _mode == Mode.VS_AI and _player_mark == GameState.Player.X:
				SFX.win()
			elif _mode == Mode.VS_AI:
				SFX.lose()
			elif _player_mark == GameState.Player.X:
				SFX.win()
			else:
				SFX.lose()
		GameState.GameResult.O_WINS:
			if _mode == Mode.LOCAL:
				SFX.win()
			elif _mode == Mode.VS_AI and _player_mark == GameState.Player.O:
				SFX.win()
			elif _mode == Mode.VS_AI:
				SFX.lose()
			elif _player_mark == GameState.Player.O:
				SFX.win()
			else:
				SFX.lose()

	var score: int
	if _state.result == GameState.GameResult.DRAW:
		score = 50
	elif (winner == "X" and _player_mark == GameState.Player.X) or (winner == "O" and _player_mark == GameState.Player.O):
		score = 100
	else:
		score = 0

	var mode_str: String
	match _mode:
		Mode.VS_AI: mode_str = "solo"
		Mode.LOCAL: mode_str = "local"
		Mode.ONLINE: mode_str = "online"
		_: mode_str = "solo"

	if _bridge:
		_bridge.send_match_end(winner, mode_str, score)

	_highlight_win_line()

	var local_won := false
	var rpc_source := "ai_win"
	match _mode:
		Mode.VS_AI:
			local_won = (
				(_player_mark == GameState.Player.X and _state.result == GameState.GameResult.X_WINS) or
				(_player_mark == GameState.Player.O and _state.result == GameState.GameResult.O_WINS))
			rpc_source = "ai_win"
		Mode.ONLINE:
			local_won = (
				(_player_mark == GameState.Player.X and _state.result == GameState.GameResult.X_WINS) or
				(_player_mark == GameState.Player.O and _state.result == GameState.GameResult.O_WINS))
			rpc_source = "online_win"
		Mode.LOCAL:
			local_won = false  # local 2P excluded from scoring

	_pts_awarded = 0
	if local_won:
		await _award_points_if_signed_in(rpc_source)
	elif _state.result != GameState.GameResult.DRAW and _mode != Mode.LOCAL:
		if Globals.is_signed_in() and not Globals.current_game_id.is_empty():
			Globals.current_streak[Globals.current_game_mode] = 0
			_update_streak_badge()
			Globals.supabase.call_rpc("reset_win_streak", {
				"p_user_id":   Globals.current_user["id"],
				"p_game_id":   Globals.current_game_id,
				"p_game_mode": Globals.current_game_mode
			})

	var game_over = load("res://scenes/GameOver.tscn").instantiate()
	game_over.setup(winner, _score_x, _score_o, _mode, self,
		_pts_awarded, Globals.current_streak.get(Globals.current_game_mode, 0))
	get_tree().root.add_child(game_over)
