class_name GameBoard
extends Control

class TimerRing extends Control:
	var progress: float = 1.0
	var ring_color: Color = Color("#00d4ff")
	const RING_W := 5.0

	func _draw() -> void:
		var center := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - RING_W - 1.0
		draw_arc(center, r, -PI / 2.0, -PI / 2.0 + TAU, 48,
			Color(0.15, 0.15, 0.22, 0.55), RING_W, true)
		if progress > 0.01:
			draw_arc(center, r, -PI / 2.0, -PI / 2.0 + TAU * progress, 48,
				ring_color, RING_W, true)

	func set_progress(p: float) -> void:
		progress = clampf(p, 0.0, 1.0)
		queue_redraw()

enum Mode { VS_AI, LOCAL, ONLINE }

var _state: GameState
var _ai: TicTacToeAI
var _mode: Mode
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

var _ultimate_board_node: Control = null
var _ephemeral_state: EphemeralGameState
var _ultimate_state: UltimateGameState
var _pending_ultimate_move: Dictionary = {}
var _evicting_cell: int = -1
var _ring_x: TimerRing = null
var _ring_o: TimerRing = null

func setup_vs_ai(_ignored_difficulty: int = 0) -> void:
	_mode = Mode.VS_AI
	# AI and difficulty read from Globals in _ready()
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

	match Globals.current_game_mode:
		"ultimate":
			_ultimate_state = UltimateGameState.new()
			_state = _ultimate_state
			if _mode == Mode.VS_AI:
				_ai = UltimateAI.new()
			_setup_ultimate_board()
			$VBoxContainer/Grid.visible = false
		"ephemerate":
			_ephemeral_state = EphemeralGameState.new()
			_state = _ephemeral_state
			if _mode == Mode.VS_AI:
				_ai = EphemeralAI.new()
		_:  # classic
			_state = GameState.new()
			if _mode == Mode.VS_AI:
				_ai = TicTacToeAI.new()
	_bridge = $Bridge if has_node("Bridge") else null
	if _bridge:
		_bridge.send_game_ready()

	_turn_timer = TurnTimer.new()
	if has_node("VBoxContainer/LblTimer"):
		_turn_timer.setup($VBoxContainer/LblTimer)
	add_child(_turn_timer)
	_turn_timer.timed_out.connect(_on_turn_timeout)
	_turn_timer.tick.connect(_on_timer_tick)
	if Globals.timer_seconds > 0:
		_turn_timer.set_duration(Globals.timer_seconds)
	call_deferred("_init_timer_rings")
	call_deferred("_setup_game_info_label")

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
			if Globals.timer_seconds > 0:
				_turn_timer.set_duration(Globals.timer_seconds)
				_turn_timer.start()
	elif Globals.timer_seconds > 0:
		# VS_AI and LOCAL: start timer immediately (player moves first or AI goes first)
		_turn_timer.set_duration(Globals.timer_seconds)
		if not (_mode == Mode.VS_AI and _player_mark == GameState.Player.O):
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
	# Ephemeral: redirect to handle eviction animation before placing
	if Globals.current_game_mode == "ephemerate" and _ephemeral_state != null:
		_do_place_ephemeral(cell_index)
		return

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
	elif _mode != Mode.ONLINE and Globals.timer_seconds > 0:
		_turn_timer.start()  # restart for next player's turn

func _do_place_ephemeral(cell_index: int) -> void:
	var queue := _ephemeral_state.x_moves if _ephemeral_state.current_turn == GameState.Player.X \
		else _ephemeral_state.o_moves
	var evicted_cell := queue[0] if queue.size() == 4 else -1

	# Capture evicted mark appearance BEFORE place() wipes board[evicted]
	var evicted_text := ""
	var evicted_color := Color.WHITE
	if evicted_cell >= 0:
		evicted_text = "X" if _ephemeral_state.board[evicted_cell] == GameState.Player.X else "O"
		evicted_color = Color("#00d4ff") if evicted_text == "X" else Color("#a855f7")

	if not _ephemeral_state.place(cell_index):
		return
	SFX.click()

	# Animate eviction: re-show mark briefly then tween to invisible.
	# _evicting_cell tells _refresh_ui to skip this cell while tween runs.
	if evicted_cell >= 0:
		_evicting_cell = evicted_cell
		var evicted_node = $VBoxContainer/Grid.get_child(evicted_cell)
		var evicted_mark: Label = evicted_node.get_node("Mark")
		evicted_mark.text = evicted_text
		evicted_mark.add_theme_color_override("font_color", evicted_color)
		evicted_mark.modulate.a = 0.25  # was oldest = 0.25 before vanish
		var tw := create_tween()
		tw.tween_property(evicted_mark, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func():
			evicted_mark.text = ""
			evicted_mark.modulate.a = 1.0
			_evicting_cell = -1
		)

	_animate_piece(cell_index)
	_refresh_ui()

	if _ephemeral_state.result != GameState.GameResult.ONGOING:
		_on_game_over()
		return
	if _mode == Mode.VS_AI and _ephemeral_state.current_turn != _player_mark:
		_ai_take_turn.call_deferred()
	elif _mode != Mode.ONLINE and Globals.timer_seconds > 0:
		_turn_timer.start()

func _ai_take_turn() -> void:
	_turn_timer.stop()  # pause timer during AI think
	var move_cell: int
	if Globals.current_game_mode == "ephemerate":
		var eph_ai := _ai as EphemeralAI
		move_cell = eph_ai.get_move(_ephemeral_state, Globals.ai_difficulty)
	elif Globals.current_game_mode == "ultimate":
		_ai_take_turn_ultimate()
		return
	else:
		move_cell = _ai.get_move(_state, Globals.ai_difficulty)
	_ai_move_cell = move_cell
	if _ai_move_cell < 0:
		return
	_ai_thinking = true
	_ai_dots_count = 0
	_ai_dots_timer.start()
	_ai_think_timer.start(randf_range(1.0, 3.0))

func _ai_take_turn_ultimate() -> void:
	var ultimate_ai := _ai as UltimateAI
	var move: Dictionary = ultimate_ai.get_move(_ultimate_state, Globals.ai_difficulty)
	if move.is_empty():
		return
	_ai_thinking = true
	_ai_dots_count = 0
	_ai_dots_timer.start()
	_ai_think_timer.start(randf_range(1.0, 3.0))
	# Store board+cell encoded for _ai_do_move
	_pending_ultimate_move = move

func _ai_do_move() -> void:
	_ai_dots_timer.stop()
	_ai_thinking = false
	if Globals.current_game_mode == "ultimate":
		if not _pending_ultimate_move.is_empty():
			var m: Dictionary = _pending_ultimate_move
			_pending_ultimate_move = {}
			_do_ultimate_place(m["board"], m["cell"])
	else:
		_do_place(_ai_move_cell)
	# Restart timer for player's turn after AI places
	if _mode != Mode.ONLINE and Globals.timer_seconds > 0 and _state.result == GameState.GameResult.ONGOING:
		_turn_timer.start()

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
	if _mode == Mode.ONLINE:
		var my_mark = GameState.player_to_str(_player_mark)
		_supabase_ref.broadcast("room:" + _room_id, "forfeit", {"player": my_mark})
		_state.result = GameState.GameResult.O_WINS if _player_mark == GameState.Player.X else GameState.GameResult.X_WINS
		_on_game_over()
		return

	# VS_AI and LOCAL: skip turn, no forfeit
	if _state.result != GameState.GameResult.ONGOING:
		return
	SFX.click()
	_show_times_up_banner()
	_shake_screen()
	_state.current_turn = GameState.Player.O if _state.current_turn == GameState.Player.X else GameState.Player.X
	_refresh_ui()
	if Globals.timer_seconds > 0:
		_turn_timer.start()
	if _mode == Mode.VS_AI and _state.current_turn != _player_mark:
		_ai_take_turn.call_deferred()

func _show_times_up_banner() -> void:
	var orbitron := load("res://fonts/Orbitron.ttf")
	var lbl := Label.new()
	lbl.text = "TIME'S UP!"
	lbl.add_theme_font_override("font", orbitron)
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.add_theme_color_override("font_color", Color("#ff2d95"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)
	lbl.scale = Vector2.ZERO
	await get_tree().process_frame
	lbl.position = (size - lbl.size) / 2.0
	lbl.pivot_offset = lbl.size / 2.0
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.1, 1.1), 0.15).set_trans(Tween.TRANS_BACK)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.08)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.4)
	tw.tween_callback(lbl.queue_free)

func _shake_screen() -> void:
	var origin := position
	var tw := create_tween()
	for i in 5:
		var off := Vector2(randf_range(-10.0, 10.0), randf_range(-5.0, 5.0))
		tw.tween_property(self, "position", origin + off, 0.04)
	tw.tween_property(self, "position", origin, 0.04)

func reset_for_replay() -> void:
	_game_over_fired = false

	match Globals.current_game_mode:
		"ultimate":
			_ultimate_state = UltimateGameState.new()
			_state = _ultimate_state
			_refresh_ultimate_ui()
		"ephemerate":
			_ephemeral_state = EphemeralGameState.new()
			_state = _ephemeral_state
		_:
			_state = GameState.new()

	_refresh_ui()

	if _mode != Mode.ONLINE and Globals.timer_seconds > 0:
		_turn_timer.set_duration(Globals.timer_seconds)
		if not (_mode == Mode.VS_AI and _player_mark == GameState.Player.O):
			_turn_timer.start()

	if _mode == Mode.VS_AI and _player_mark == GameState.Player.O:
		_ai_take_turn.call_deferred()

func _on_home() -> void:
	_turn_timer.stop()
	SFX.click()
	if _mode == Mode.ONLINE and _supabase_ref:
		_supabase_ref.broadcast("room:" + _room_id, "forfeit",
			{"player": GameState.player_to_str(_player_mark)})
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
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
		# Skip cell being eviction-animated â€” tween owns it until callback clears _evicting_cell
		if i == _evicting_cell:
			continue

		var cell = $VBoxContainer/Grid.get_child(i)
		var mark_label: Label = cell.get_node("Mark")
		var is_ephemerate := Globals.current_game_mode == "ephemerate" and _ephemeral_state != null
		match _state.board[i]:
			GameState.Player.X:
				mark_label.text = "X"
				var cx := Color("#00d4ff")
				if is_ephemerate:
					cx.a = _ephemeral_state.get_cell_opacity(i)
				mark_label.add_theme_color_override("font_color", cx)
			GameState.Player.O:
				mark_label.text = "O"
				var co := Color("#a855f7")
				if is_ephemerate:
					co.a = _ephemeral_state.get_cell_opacity(i)
				mark_label.add_theme_color_override("font_color", co)
			_:
				mark_label.text = ""
		mark_label.modulate.a = 1.0

	var turn_text: String
	match _state.current_turn:
		GameState.Player.X:
			if _mode == Mode.VS_AI and _player_mark == GameState.Player.O:
				turn_text = "AI THINKING..."
			elif _mode == Mode.VS_AI:
				turn_text = "YOUR TURN â€” X"
			else:
				turn_text = "PLAYER 1 â€” X"
		GameState.Player.O:
			if _mode == Mode.VS_AI and _player_mark == GameState.Player.X:
				turn_text = "AI THINKING..."
			elif _mode == Mode.VS_AI:
				turn_text = "YOUR TURN â€” O"
			elif _mode == Mode.LOCAL:
				turn_text = "PLAYER 2 â€” O"
			else:
				turn_text = "OPPONENT â€” O"
		_:
			turn_text = ""
	$VBoxContainer/LblStatus.text = turn_text

	$VBoxContainer/ScoreRow/LblScoreX.text = "X: %d" % _score_x
	$VBoxContainer/ScoreRow/LblScoreO.text = "O: %d" % _score_o
	if _ring_x and _ring_o and Globals.timer_seconds > 0:
		var x_active := _state.current_turn == GameState.Player.X
		if _ring_x.visible != x_active:
			_ring_x.visible = x_active
			_ring_x.set_progress(1.0)
		_ring_o.visible = not x_active
		if not x_active and _ring_o.progress > 0.99:
			_ring_o.set_progress(1.0)

func _highlight_win_line() -> void:
	var line = _state.get_winning_line()
	if line.is_empty():
		return
	for cell_index in line:
		var cell = $VBoxContainer/Grid.get_child(cell_index)
		var tween = create_tween().set_loops()
		tween.tween_property(cell, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.4)
		tween.tween_property(cell, "modulate", Color.WHITE, 0.4)

func _init_timer_rings() -> void:
	if Globals.timer_seconds <= 0:
		return
	var sz := Vector2(56.0, 56.0)
	var lbl_x: Label = $VBoxContainer/ScoreRow/LblScoreX
	var lbl_o: Label = $VBoxContainer/ScoreRow/LblScoreO
	_ring_x = TimerRing.new()
	_ring_x.custom_minimum_size = sz
	_ring_x.size = sz
	_ring_x.ring_color = Color("#00d4ff")
	_ring_x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cx := lbl_x.get_global_rect().get_center() - global_position
	_ring_x.position = cx - sz / 2.0
	add_child(_ring_x)
	_ring_o = TimerRing.new()
	_ring_o.custom_minimum_size = sz
	_ring_o.size = sz
	_ring_o.ring_color = Color("#a855f7")
	_ring_o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var co := lbl_o.get_global_rect().get_center() - global_position
	_ring_o.position = co - sz / 2.0
	add_child(_ring_o)
	_ring_x.visible = false
	_ring_o.visible = false

func _on_timer_tick(seconds_left: int) -> void:
	if Globals.timer_seconds <= 0:
		return
	var p := float(seconds_left) / float(Globals.timer_seconds)
	if _state.current_turn == GameState.Player.X and _ring_x:
		_ring_x.set_progress(p)
	elif _ring_o:
		_ring_o.set_progress(p)

func _setup_game_info_label() -> void:
	var parts: Array[String] = []
	if Globals.timer_seconds > 0:
		match Globals.timer_seconds:
			3: parts.append("BLITZ")
			6: parts.append("CASUAL")
			9: parts.append("CHILL")
	if _mode == Mode.VS_AI:
		match Globals.ai_difficulty:
			Globals.AIDifficulty.EASY:       parts.append("EASY")
			Globals.AIDifficulty.HARD:       parts.append("HARD")
			Globals.AIDifficulty.UNBEATABLE: parts.append("UNBEATABLE")
	if parts.is_empty():
		return
	var orbitron := load("res://fonts/Orbitron.ttf")
	var lbl := Label.new()
	lbl.name = "LblGameInfo"
	lbl.text = " | ".join(parts)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", orbitron)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75, 0.75))
	var vbox := $VBoxContainer
	vbox.add_child(lbl)
	var status_idx := $VBoxContainer/LblStatus.get_index()
	vbox.move_child(lbl, status_idx + 1)

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
	lbl.text = "+%d â˜…" % pts
	lbl.add_theme_color_override("font_color", Color("#00d4ff"))
	lbl.position = Vector2(size.x / 2.0 - 50, size.y / 2.0 - 40)
	add_child(lbl)
	lbl.scale = Vector2.ZERO
	await get_tree().process_frame
	lbl.position = (size - lbl.size) / 2.0
	lbl.pivot_offset = lbl.size / 2.0
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.06)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.tween_callback(lbl.queue_free)

func _do_ultimate_place(board_idx: int, cell_idx: int) -> void:
	if not _ultimate_state.place_on(board_idx, cell_idx):
		return
	SFX.click()
	_animate_ultimate_piece(board_idx, cell_idx)
	_refresh_ultimate_ui()
	if _ultimate_state.result != GameState.GameResult.ONGOING:
		_on_game_over()
		return
	if _mode == Mode.VS_AI and _ultimate_state.current_turn != _player_mark:
		_ai_take_turn_ultimate.call_deferred()

func _setup_ultimate_board() -> void:
	var arcade_theme := load("res://theme/ArcadeTheme.tres") as Theme
	arcade_theme.default_font = load("res://fonts/Orbitron.ttf")
	arcade_theme.set_font_size("font_size", "WonOverlay", 48)

	_ultimate_board_node = Control.new()
	_ultimate_board_node.name = "UltimateBoard"
	_ultimate_board_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ultimate_board_node.mouse_filter = Control.MOUSE_FILTER_PASS
	_ultimate_board_node.theme = arcade_theme

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.set_anchors_preset(Control.PRESET_CENTER)
	grid.custom_minimum_size = Vector2(660, 660)
	grid.offset_left = -330
	grid.offset_top = -330
	_ultimate_board_node.add_child(grid)

	for b in 9:
		var mini_panel := Panel.new()
		mini_panel.name = "Mini%d" % b
		mini_panel.custom_minimum_size = Vector2(214, 214)

		var mini_grid := GridContainer.new()
		mini_grid.name = "Grid"
		mini_grid.columns = 3
		mini_grid.add_theme_constant_override("h_separation", 3)
		mini_grid.add_theme_constant_override("v_separation", 3)
		mini_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
		mini_grid.offset_left = 4
		mini_grid.offset_top = 4
		mini_grid.offset_right = -4
		mini_grid.offset_bottom = -4
		mini_panel.add_child(mini_grid)

		for c in 9:
			var btn := Button.new()
			btn.name = "Cell%d" % c
			btn.custom_minimum_size = Vector2(66, 66)
			btn.flat = false
			btn.gui_input.connect(_on_ultimate_cell_input.bind(b, c))
			mini_grid.add_child(btn)

		var won_label := Label.new()
		won_label.name = "WonMark"
		won_label.theme_type_variation = "WonOverlay"
		won_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		won_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		won_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		won_label.visible = false
		mini_panel.add_child(won_label)

		grid.add_child(mini_panel)

	add_child(_ultimate_board_node)
	_refresh_ultimate_ui()

func _on_ultimate_cell_input(event: InputEvent, board_idx: int, cell_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _ai_thinking:
		return
	_do_ultimate_place(board_idx, cell_idx)

func _refresh_ultimate_ui() -> void:
	if _ultimate_board_node == null:
		return

	var grid_node := _ultimate_board_node.get_child(0)  # the GridContainer
	for b in 9:
		var mini_panel := grid_node.get_child(b)

		# Border style based on board state
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2

		var meta_val = _ultimate_state.meta_board[b]
		if meta_val != GameState.Player.NONE:
			# Won board
			style.bg_color = Color(0.1, 0.1, 0.2, 0.6)
			style.border_color = Color("#00d4ff") if meta_val == GameState.Player.X else Color("#a855f7")
			mini_panel.add_theme_stylebox_override("panel", style)
			var won_lbl := mini_panel.get_node("WonMark") as Label
			won_lbl.visible = true
			won_lbl.text = "X" if meta_val == GameState.Player.X else "O"
			won_lbl.add_theme_color_override("font_color",
				Color("#00d4ff") if meta_val == GameState.Player.X else Color("#a855f7"))
			# Dim the mini grid cells
			mini_panel.get_node("Grid").modulate = Color(0.3, 0.3, 0.3, 1.0)
		elif _ultimate_state.active_board == b:
			# Active board
			style.bg_color = Color("#1a1a2e")
			style.border_color = Color("#00d4ff")
			mini_panel.add_theme_stylebox_override("panel", style)
			mini_panel.get_node("Grid").modulate = Color.WHITE
		elif _ultimate_state.active_board == -1:
			# Free choice â€” all open boards dim-glow
			style.bg_color = Color("#1a1a2e")
			style.border_color = Color(0.0, 0.831, 1.0, 0.4)
			mini_panel.add_theme_stylebox_override("panel", style)
			mini_panel.get_node("Grid").modulate = Color.WHITE
		else:
			# Inactive
			style.bg_color = Color("#12122a")
			style.border_color = Color("#2a2a4a")
			mini_panel.add_theme_stylebox_override("panel", style)
			mini_panel.get_node("Grid").modulate = Color(0.5, 0.5, 0.5, 1.0)

		# Update cell labels in this mini-board
		var mini_state := _ultimate_state.mini_boards[b] as GameState
		var cell_grid := mini_panel.get_node("Grid")
		for c in 9:
			var btn := cell_grid.get_child(c) as Button
			match mini_state.board[c]:
				GameState.Player.X:
					btn.text = "X"
					btn.add_theme_color_override("font_color", Color("#00d4ff"))
				GameState.Player.O:
					btn.text = "O"
					btn.add_theme_color_override("font_color", Color("#a855f7"))
				_:
					btn.text = ""

func _animate_ultimate_piece(board_idx: int, cell_idx: int) -> void:
	var grid_node := _ultimate_board_node.get_child(0)
	var mini_panel := grid_node.get_child(board_idx)
	var cell_grid := mini_panel.get_node("Grid")
	var btn := cell_grid.get_child(cell_idx)
	btn.scale = Vector2.ZERO
	btn.pivot_offset = btn.size / 2.0
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.06)

func _on_game_over() -> void:
	if _game_over_fired:
		return
	_game_over_fired = true
	_turn_timer.stop()
	if _ring_x:
		_ring_x.visible = false
	if _ring_o:
		_ring_o.visible = false
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

	if Globals.current_game_mode != "ultimate":
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
