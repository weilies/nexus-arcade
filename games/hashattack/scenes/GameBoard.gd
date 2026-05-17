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
var _room_code: String = ""
var _player_mark: GameState.Player = GameState.Player.X
var _supabase_ref: SupabaseClient
var _is_host: bool = false
var _online_waiting: bool = false
var _waiting_overlay: Control = null
var _concede_modal: Control = null
var _opponent_name: String = ""
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
var _ring_timer: TimerRing = null
var _lbl_timer_sec: Label = null
var _lbl_timer_ms: Label = null

# Cached refs (survive reparenting in Ultimate layout)
var _lbl_status: Label = null
var _lbl_score_x: Label = null
var _lbl_score_o: Label = null

func setup_vs_ai(_ignored_difficulty: int = 0) -> void:
	_mode = Mode.VS_AI
	# AI and difficulty read from Globals in _ready()
	if randi() % 2 == 0:
		_player_mark = GameState.Player.X   # Player = X, goes first
	else:
		_player_mark = GameState.Player.O   # Player = O, AI goes first

func setup_local() -> void:
	_mode = Mode.LOCAL

var _initial_state_dict: Dictionary = {}

func setup_online(room_id: String, player_mark: GameState.Player, sb: SupabaseClient,
		room_code: String = "", game_mode: String = "", timer_secs: int = -1,
		is_host: bool = false, state_dict: Dictionary = {}) -> void:
	_mode = Mode.ONLINE
	_room_id = room_id
	_room_code = room_code
	_player_mark = player_mark
	_supabase_ref = sb
	_is_host = is_host
	# If we have an in-progress board state (refresh-rejoin), skip waiting overlay.
	var has_state := not state_dict.is_empty() and state_dict.get("board", []) is Array \
		and not state_dict.get("board", []).is_empty() \
		and _has_any_mark(state_dict.get("board", []))
	_online_waiting = is_host and not has_state
	_initial_state_dict = state_dict
	if game_mode != "":
		Globals.current_game_mode = game_mode
	if timer_secs >= 0:
		Globals.timer_seconds = timer_secs
	if room_code != "":
		RoomManager.save_active_room(room_code)

func _has_any_mark(board: Array) -> bool:
	for c in board:
		if str(c) == "X" or str(c) == "O":
			return true
	return false

func _ready() -> void:
	var bg = load("res://scripts/BackgroundLayer.gd").new()
	add_child(bg)
	move_child(bg, 1)

	# Cache labels FIRST (before any reparenting in Ultimate setup)
	_lbl_status = $VBoxContainer/LblStatus
	_lbl_score_x = $VBoxContainer/ScoreRow/LblScoreX
	_lbl_score_o = $VBoxContainer/ScoreRow/LblScoreO
	$VBoxContainer/BtnHome.pressed.connect(_on_home)

	match Globals.current_game_mode:
		"ultimate":
			_ultimate_state = UltimateGameState.new()
			_state = _ultimate_state
			if _mode == Mode.VS_AI:
				_ai = UltimateAI.new()
			_setup_ultimate_board()
		"ephemeral":
			_ephemeral_state = EphemeralGameState.new()
			_state = _ephemeral_state
			if _mode == Mode.VS_AI:
				_ai = EphemeralAI.new()
		_:  # classic
			_state = GameState.new()
			if _mode == Mode.VS_AI:
				_ai = TicTacToeAI.new()

	# Restore in-progress online state (refresh-rejoin)
	if _mode == Mode.ONLINE and not _initial_state_dict.is_empty():
		_state.from_dict(_initial_state_dict)
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

	_connect_cells()
	# Classic grid borders - bright cyan, visible against dark bg
	for i in 9:
		var cell = $VBoxContainer/Grid.get_child(i)
		var gs := StyleBoxFlat.new()
		gs.border_width_left = 2
		gs.border_width_top = 2
		gs.border_width_right = 2
		gs.border_width_bottom = 2
		gs.border_color = Color("#00d4ff")
		gs.bg_color = Color(0.05, 0.05, 0.12, 1)
		cell.add_theme_stylebox_override("panel", gs)
	# Streak badge FA6 fire icon (Orbitron cannot render emoji)
	$VBoxContainer/StreakBadge/LblStreakIcon.add_theme_font_override("font", FA6.font())
	$VBoxContainer/StreakBadge/LblStreakIcon.text = FA6.icon("fire")
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
		if not _supabase_ref.realtime_message.is_connected(_on_online_message):
			_supabase_ref.realtime_message.connect(_on_online_message)
		if has_node("VBoxContainer/BtnHome"):
			$VBoxContainer/BtnHome.text = "CONCEDE"
		if _is_host and _online_waiting:
			_show_waiting_overlay()
			_start_waiting_poll()
		elif _state.current_turn == _player_mark and Globals.timer_seconds > 0:
			# Fresh start as guest OR refresh-rejoin: start timer if it's our turn.
			_turn_timer.set_duration(Globals.timer_seconds)
			_turn_timer.start()
		_fetch_opponent_name()
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

func _on_cell_input(event: InputEvent, cell_index: int) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _ai_thinking:
		return
	if _mode == Mode.ONLINE:
		if _online_waiting:
			return
		if _state.current_turn != _player_mark:
			return
		_do_place_online(cell_index)
		return
	_do_place(cell_index)

func _do_place(cell_index: int) -> void:
	# Ephemeral: redirect to handle eviction animation before placing
	if Globals.current_game_mode == "ephemeral" and _ephemeral_state != null:
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
	var evicted_cell := queue[0] if queue.size() == EphemeralGameState.MAX_MARKS else -1

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
		evicted_mark.modulate.a = EphemeralGameState.OPACITY_MAP[0]  # oldest opacity before vanish
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
	if Globals.current_game_mode == "ephemeral":
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
	_turn_timer.stop()  # pause timer while AI thinks (human-only timer rule)
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
	_lbl_status.text = "AI THINKING" + dots

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
		"guest_joined":
			if _is_host and _online_waiting:
				_online_waiting = false
				_hide_waiting_overlay()
				if Globals.timer_seconds > 0:
					_turn_timer.set_duration(Globals.timer_seconds)
					_turn_timer.start()
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
	SFX.lose()  # fail sfx on timeout
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
		"ephemeral":
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
	if _mode == Mode.ONLINE:
		_show_concede_confirm()
		return
	_turn_timer.stop()
	SFX.click()
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	queue_free()

func _do_concede() -> void:
	_turn_timer.stop()
	SFX.click()
	RoomManager.clear_active_room()
	if _supabase_ref:
		_supabase_ref.broadcast("room:" + _room_id, "forfeit",
			{"player": GameState.player_to_str(_player_mark)})
		# Mark finished so opponent's lobby drops it too
		if _room_id != "":
			_supabase_ref.patch_row("game_rooms", "id=eq." + _room_id,
				{"status": "finished"})
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	queue_free()

func _show_concede_confirm() -> void:
	if _concede_modal:
		return
	var orbitron := load("res://fonts/Orbitron.ttf")
	_concede_modal = Control.new()
	_concede_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_concede_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_concede_modal)
	move_child(_concede_modal, get_child_count() - 1)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	_concede_modal.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_concede_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1e1e3a")
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "CONCEDE MATCH?"
	title.add_theme_font_override("font", orbitron)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#ff2d95"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var body := Label.new()
	body.text = "You will lose this match."
	body.add_theme_font_override("font", orbitron)
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color("#e8e8f0"))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(body)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(btns)

	var btn_cancel := Button.new()
	btn_cancel.text = "CANCEL"
	btn_cancel.add_theme_font_override("font", orbitron)
	btn_cancel.add_theme_font_size_override("font_size", 16)
	btn_cancel.add_theme_color_override("font_color", Color("#94a3b8"))
	btn_cancel.custom_minimum_size = Vector2(130, 44)
	btn_cancel.pressed.connect(func():
		_concede_modal.queue_free()
		_concede_modal = null
	)
	btns.add_child(btn_cancel)

	var btn_ok := Button.new()
	btn_ok.text = "CONCEDE"
	btn_ok.add_theme_font_override("font", orbitron)
	btn_ok.add_theme_font_size_override("font_size", 16)
	btn_ok.add_theme_color_override("font_color", Color("#ff2d95"))
	btn_ok.custom_minimum_size = Vector2(130, 44)
	btn_ok.pressed.connect(func():
		_concede_modal.queue_free()
		_concede_modal = null
		_do_concede()
	)
	btns.add_child(btn_ok)

func _show_waiting_overlay() -> void:
	if _waiting_overlay:
		return
	var orbitron := load("res://fonts/Orbitron.ttf")
	_waiting_overlay = Control.new()
	_waiting_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_waiting_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_waiting_overlay)
	move_child(_waiting_overlay, get_child_count() - 1)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.55)
	_waiting_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waiting_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1e1e3a")
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "WAITING FOR OPPONENT"
	title.add_theme_font_override("font", orbitron)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#00d4ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var code := Label.new()
	code.text = "ROOM CODE:  %s" % _room_code
	code.add_theme_font_override("font", orbitron)
	code.add_theme_font_size_override("font_size", 18)
	code.add_theme_color_override("font_color", Color("#e8e8f0"))
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(code)

	var hint := Label.new()
	hint.text = "Share the code to invite a player."
	hint.add_theme_font_override("font", orbitron)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("#94a3b8"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

	var btn_share := Button.new()
	btn_share.text = "SHARE"
	btn_share.add_theme_font_override("font", orbitron)
	btn_share.add_theme_font_size_override("font_size", 16)
	btn_share.add_theme_color_override("font_color", Color("#a78bfa"))
	btn_share.custom_minimum_size = Vector2(160, 42)
	btn_share.pressed.connect(_share_room)
	vb.add_child(btn_share)

func _fetch_opponent_name() -> void:
	# Poll room until both host_id + guest_id present, then resolve username.
	while is_inside_tree() and _opponent_name == "":
		var room: Dictionary = await RoomManager.fetch_room_by_id_async(_supabase_ref, _room_id)
		if not room.is_empty():
			var opp_id := str(room.get("guest_id", "")) if _is_host else str(room.get("host_id", ""))
			if opp_id != "":
				var raw: Array = await _supabase_ref._async_get(
					"/rest/v1/users?id=eq.%s&select=username" % opp_id)
				if raw[0] == 200 and raw[1] is Array and not raw[1].is_empty():
					_opponent_name = str(raw[1][0].get("username", ""))
					return
		await get_tree().create_timer(2.0).timeout

func _hide_waiting_overlay() -> void:
	if _waiting_overlay:
		_waiting_overlay.queue_free()
		_waiting_overlay = null

func _start_waiting_poll() -> void:
	# Fallback in case broadcast missed — poll DB every 2s, dismiss when guest_id present.
	while _online_waiting and is_inside_tree():
		await get_tree().create_timer(2.0).timeout
		if not _online_waiting:
			return
		var fresh: Dictionary = await RoomManager.fetch_room_by_id_async(_supabase_ref, _room_id)
		if fresh.is_empty():
			continue
		var gid := str(fresh.get("guest_id", ""))
		var st := str(fresh.get("status", ""))
		if gid != "" or st == "active":
			if _online_waiting:
				_online_waiting = false
				_hide_waiting_overlay()
				if Globals.timer_seconds > 0:
					_turn_timer.set_duration(Globals.timer_seconds)
					_turn_timer.start()
			return

func _share_room() -> void:
	var url := RoomManager.get_share_url(_room_code)
	var text := "Join my Hash Attack room! Code: %s\n%s" % [_room_code, url]
	if OS.has_feature("web"):
		var shared: bool = JavaScriptBridge.eval("""
			(function() {
				if (navigator.share) {
					navigator.share({ title: 'Hash Attack Room', text: %s }).catch(() => {});
					return true;
				}
				return false;
			})()
		""" % JSON.stringify(text))
		if not shared:
			JavaScriptBridge.eval("navigator.clipboard.writeText(%s).catch(() => {})" % JSON.stringify(text))
	else:
		DisplayServer.clipboard_set(text)

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
		# Skip cell being eviction-animated - tween owns it until callback clears _evicting_cell
		if i == _evicting_cell:
			continue

		var cell = $VBoxContainer/Grid.get_child(i)
		var mark_label: Label = cell.get_node("Mark")
		var is_ephemeral := Globals.current_game_mode == "ephemeral" and _ephemeral_state != null
		match _state.board[i]:
			GameState.Player.X:
				mark_label.text = "X"
				var cx := Color("#00d4ff")
				if is_ephemeral:
					cx.a = _ephemeral_state.get_cell_opacity(i)
				mark_label.add_theme_color_override("font_color", cx)
			GameState.Player.O:
				mark_label.text = "O"
				var co := Color("#a855f7")
				if is_ephemeral:
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
				turn_text = "YOUR TURN - X"
			elif _mode == Mode.ONLINE:
				turn_text = "YOUR TURN - X" if _player_mark == GameState.Player.X else "OPPONENT'S TURN - X"
			else:
				turn_text = "PLAYER 1 - X"
		GameState.Player.O:
			if _mode == Mode.VS_AI and _player_mark == GameState.Player.X:
				turn_text = "AI THINKING..."
			elif _mode == Mode.VS_AI:
				turn_text = "YOUR TURN - O"
			elif _mode == Mode.LOCAL:
				turn_text = "PLAYER 2 - O"
			elif _mode == Mode.ONLINE:
				turn_text = "YOUR TURN - O" if _player_mark == GameState.Player.O else "OPPONENT'S TURN - O"
			else:
				turn_text = "OPPONENT - O"
		_:
			turn_text = ""
	_lbl_status.text = turn_text

	_lbl_score_x.text = "X: %d" % _score_x
	_lbl_score_o.text = "O: %d" % _score_o
	# Shared timer ring is always visible while game ongoing — _process() updates it

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
	# Single shared ring, neutral color, top-right corner of viewport
	var sz := Vector2(72.0, 72.0)
	var vp_size := get_viewport_rect().size
	_ring_timer = TimerRing.new()
	_ring_timer.custom_minimum_size = sz
	_ring_timer.size = sz
	_ring_timer.ring_color = Color("#e8e8f0")  # neutral primary text color
	_ring_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Plain position — no anchor preset (parent GameBoard root has no size set)
	_ring_timer.position = Vector2(vp_size.x - sz.x - 16.0, 16.0)
	add_child(_ring_timer)

	# Single centered Label "S.ms" (HBox in non-Container parent had layout issues)
	var orbitron := load("res://fonts/Orbitron.ttf")
	_lbl_timer_sec = Label.new()
	_lbl_timer_sec.add_theme_font_override("font", orbitron)
	_lbl_timer_sec.add_theme_font_size_override("font_size", 24)
	_lbl_timer_sec.add_theme_color_override("font_color", Color("#e8e8f0"))
	_lbl_timer_sec.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lbl_timer_sec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_timer_sec.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_timer_sec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_timer.add_child(_lbl_timer_sec)
	_lbl_timer_ms = null  # combined display in _lbl_timer_sec

	# Keep ring on top of any later-added overlays
	move_child(_ring_timer, get_child_count() - 1)
	_update_timer_label(Globals.timer_seconds, 0)

func _process(_delta: float) -> void:
	if _ring_timer and _turn_timer:
		var dur: float = float(Globals.timer_seconds)
		if dur > 0.0:
			if _turn_timer.is_running():
				var tl: float = _turn_timer.get_total_time_left()
				_ring_timer.set_progress(tl / dur)
				var secs := int(tl)
				var ms := int((tl - float(secs)) * 100.0)
				_update_timer_label(secs, ms)
			else:
				# Timer idle (between turns or before first move) — show full duration
				_ring_timer.set_progress(1.0)
				_update_timer_label(int(dur), 0)

func _update_timer_label(secs: int, ms: int) -> void:
	if not _lbl_timer_sec:
		return
	_lbl_timer_sec.text = "%d.%02d" % [secs, ms]

func _on_timer_tick(seconds_left: int) -> void:
	if Globals.timer_seconds <= 0:
		return
	# Tick SFX only in last 3 seconds (4→silent, 3/2/1→tick).
	if seconds_left <= 3 and seconds_left > 0:
		SFX.tick()

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
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75, 0.75))

	# Ultimate: difficulty goes in top strip after LblStatus (mirrors classic layout).
	# Classic/ephemeral: append in VBox next to LblStatus.
	if Globals.current_game_mode == "ultimate":
		var ts: Node = find_child("UltimateTopStrip", false, false)
		if ts:
			ts.add_child(lbl)
			# StreakBadge=0, LblStatus=1; place difficulty after LblStatus
			if _lbl_status and _lbl_status.get_parent() == ts:
				ts.move_child(lbl, _lbl_status.get_index() + 1)
			return
	var parent_container: Node = _lbl_status.get_parent() if _lbl_status else $VBoxContainer
	parent_container.add_child(lbl)
	if _lbl_status:
		parent_container.move_child(lbl, _lbl_status.get_index() + 1)

func _update_streak_badge() -> void:
	# StreakBadge may have been reparented to UltimateTopStrip — use find_child
	var badge: Node = find_child("StreakBadge", true, false)
	if not badge:
		return
	if not Globals.is_signed_in():
		badge.visible = false
		return
	badge.visible = true
	var streak: int = Globals.current_streak.get(Globals.current_game_mode, 0)
	var count_lbl: Label = badge.get_node("LblStreakCount") as Label
	var icon_lbl: Label = badge.get_node("LblStreakIcon") as Label
	count_lbl.text = str(streak)
	var col: Color
	if streak >= 20:
		col = Color("#ff2d95")
	elif streak >= 10:
		col = Color("#a855f7")
	elif streak >= 5:
		col = Color("#00d4ff")
	else:
		col = Color(0.55, 0.55, 0.55, 0.8)
	icon_lbl.add_theme_color_override("font_color", col)
	count_lbl.add_theme_color_override("font_color", col)

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
	lbl.text = "+%d pts" % pts
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
		_turn_timer.stop()  # AI turn next — pause human-only timer
		_ai_take_turn_ultimate.call_deferred()
	elif _mode != Mode.ONLINE and Globals.timer_seconds > 0:
		# LOCAL 2P (and VS_AI player's own next turn fallback): reset for next human
		_turn_timer.start()

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
			btn.focus_mode = Control.FOCUS_NONE
			btn.pressed.connect(_on_ultimate_cell_pressed.bind(b, c))
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

	# Reparent VBox items to top/bottom strips so they don't overlap the 660x660 grid.
	# Ultimate grid spans y=150..810 on a 720x960 viewport. Top strip y<=140, bottom y>=820.
	var vbox: VBoxContainer = $VBoxContainer

	var top_strip := VBoxContainer.new()
	top_strip.name = "UltimateTopStrip"
	top_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_strip.offset_left = 16
	top_strip.offset_right = -100  # leave room for timer ring (top-right)
	top_strip.offset_top = 16
	top_strip.offset_bottom = 140
	top_strip.add_theme_constant_override("separation", 4)
	top_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	top_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_strip)

	# Top strip: StreakBadge → LblStatus (match classic VBox order; LblGameInfo added later via deferred)
	for child_name in ["StreakBadge", "LblStatus"]:
		if vbox.has_node(child_name):
			vbox.get_node(child_name).reparent(top_strip)

	# Bottom strip VBox: ScoreRow (win tracker) + BtnHome only
	var bottom_strip := VBoxContainer.new()
	bottom_strip.name = "UltimateBottomStrip"
	bottom_strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_strip.offset_top = -110
	bottom_strip.offset_left = 16
	bottom_strip.offset_right = -16
	bottom_strip.add_theme_constant_override("separation", 6)
	bottom_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bottom_strip)

	if vbox.has_node("ScoreRow"):
		vbox.get_node("ScoreRow").reparent(bottom_strip)

	if vbox.has_node("BtnHome"):
		var home: Button = vbox.get_node("BtnHome")
		home.reparent(bottom_strip)
		home.custom_minimum_size = Vector2(180, 56)
		home.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Hide now-empty VBoxContainer (still holds invisible Grid placeholder)
	vbox.visible = false

	# TurnAnnounce overlay must render above _ultimate_board_node — push to end of tree
	if has_node("TurnAnnounce"):
		move_child($TurnAnnounce, get_child_count() - 1)

	# Keep timer ring on top after layout changes (ring stays above announce)
	if _ring_timer:
		move_child(_ring_timer, get_child_count() - 1)

	_refresh_ultimate_ui()

func _on_ultimate_cell_pressed(board_idx: int, cell_idx: int) -> void:
	if _ai_thinking:
		return
	if _mode == Mode.VS_AI and _ultimate_state.current_turn != _player_mark:
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
			# Free choice - all open boards dim-glow
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
	if _ring_timer:
		_ring_timer.visible = false
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

	# Online: mark room finished so it disappears from lobby + can't be rejoined.
	if _mode == Mode.ONLINE and _supabase_ref and _room_id != "":
		_supabase_ref.patch_row("game_rooms", "id=eq." + _room_id,
			{"status": "finished"})
		RoomManager.clear_active_room()

	var my_mark := GameState.player_to_str(_player_mark)
	var game_over = load("res://scenes/GameOver.tscn").instantiate()
	game_over.setup(winner, _score_x, _score_o, _mode, self,
		_pts_awarded, Globals.current_streak.get(Globals.current_game_mode, 0),
		my_mark, _opponent_name)
	get_tree().root.add_child(game_over)
