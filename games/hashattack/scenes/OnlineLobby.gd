extends Control

const ORBITRON_PATH := "res://fonts/Orbitron.ttf"
const CYAN  := Color("#00d4ff")
const PURPLE := Color("#a855f7")
const ACCENT := Color("#a78bfa")
const MUTED := Color("#94a3b8")
const TEXT  := Color("#e8e8f0")
const PANEL := Color("#1e1e3a")
const CELL  := Color("#1a1a2e")

var _orbitron: FontFile
var _portal_bridge: PortalBridge

var _player_mark: GameState.Player = GameState.Player.X
var _room_id: String = ""
var _room_code: String = ""

# UI refs
var _lbl_status: Label
var _vbox_rooms: VBoxContainer
var _scroll: ScrollContainer
var _btn_refresh: Button
var _btn_create: Button
var _modal: Control
var _modal_body: VBoxContainer

func _ready() -> void:
	_orbitron = load(ORBITRON_PATH)
	_portal_bridge = PortalBridge.new()
	add_child(_portal_bridge)
	_portal_bridge.auth_token_received.connect(_on_auth_token)

	_build_ui()

	# URL-based deep link: ?room=CODE → auto-join (after auth).
	var url_code := RoomManager.get_room_code_from_url()
	if url_code != "":
		_set_status("Room code in URL. Sign in to join %s..." % url_code)

	if Globals.is_signed_in():
		_on_auth_token(Globals.jwt)
	else:
		_portal_bridge.request_auth()
		_set_status("Waiting for sign-in...")

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_top = 20
	root.offset_right = -20
	root.offset_bottom = -20
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# Title
	var title := _mk_label("ONLINE PLAY", 29, CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	# Action row
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(actions)

	_btn_create = _mk_button("+ CREATE ROOM", 20, ACCENT)
	_btn_create.custom_minimum_size = Vector2(200, 44)
	_btn_create.pressed.connect(_open_create_dialog)
	actions.add_child(_btn_create)

	_btn_refresh = _mk_button("REFRESH", 20, MUTED)
	_btn_refresh.custom_minimum_size = Vector2(120, 44)
	_btn_refresh.pressed.connect(_refresh_rooms)
	actions.add_child(_btn_refresh)

	# Section label
	var section := _mk_label("AVAILABLE ROOMS", 16, MUTED)
	section.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(section)

	# Scrollable room list
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)

	_vbox_rooms = VBoxContainer.new()
	_vbox_rooms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox_rooms.add_theme_constant_override("separation", 6)
	_scroll.add_child(_vbox_rooms)

	# Join by code row
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 6)
	code_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(code_row)

	var code_input := _mk_line_edit("Room code (6 chars)")
	code_input.max_length = 6
	code_input.custom_minimum_size = Vector2(180, 40)
	code_row.add_child(code_input)

	var btn_code_join := _mk_button("JOIN", 18, ACCENT)
	btn_code_join.custom_minimum_size = Vector2(80, 40)
	btn_code_join.pressed.connect(func():
		var code := code_input.text.strip_edges().to_upper()
		if code.length() != 6:
			_set_status("Enter a valid 6-character code.")
			return
		_auto_join_by_code(code)
	)
	code_row.add_child(btn_code_join)

	# Status line
	_lbl_status = _mk_label("", 16, MUTED)
	_lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(_lbl_status)

	# Back
	var back := _mk_button("BACK", 22, MUTED)
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	root.add_child(back)

func _on_auth_token(token: String) -> void:
	Globals.jwt = token
	if token.is_empty():
		_set_status("Sign-in failed. Tap BACK and try again.")
		return
	Globals.supabase.set_jwt(token)
	_set_status("Signed in.")
	# Auto-join from URL if present.
	var url_code := RoomManager.get_room_code_from_url()
	if url_code != "":
		_auto_join_by_code(url_code)
	else:
		_refresh_rooms()

# ── Room list ─────────────────────────────────────────────────────────────────

func _refresh_rooms() -> void:
	_set_status("Loading rooms...")
	for c in _vbox_rooms.get_children():
		c.queue_free()
	var rooms: Array = await RoomManager.list_waiting_rooms_async(Globals.supabase)
	var my_id := _get_user_id_from_jwt(Globals.jwt)
	var shown := 0
	for r in rooms:
		var host_id := str(r.get("host_id", ""))
		# Skip rooms with no host (data anomaly) but show own rooms (for "rejoin").
		if host_id.is_empty():
			continue
		_add_room_row(r, host_id == my_id)
		shown += 1
	if shown == 0:
		var empty := _mk_label("No rooms waiting. Create one!", 16, MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vbox_rooms.add_child(empty)
		_set_status("")
	else:
		_set_status("%d room(s)" % shown)

func _add_room_row(room: Dictionary, is_mine: bool) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	_vbox_rooms.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_line := HBoxContainer.new()
	name_line.add_theme_constant_override("separation", 6)
	info.add_child(name_line)

	var name_lbl := _mk_label(str(room.get("room_name", "Room")), 18, TEXT)
	name_line.add_child(name_lbl)

	var is_private: bool = bool(room.get("is_private", false))
	var tag_lbl := _mk_label("[PRIVATE]" if is_private else "[PUBLIC]", 13,
		PURPLE if is_private else CYAN)
	name_line.add_child(tag_lbl)

	var game_mode_raw := str(room.get("game_mode", "classic"))
	var timer_lbl := str(room.get("timer_label", "OFF"))
	var mode_display := game_mode_raw.to_upper()
	var sub := _mk_label("%s | %s | %s" % [mode_display, timer_lbl, str(room.get("room_code", "?"))], 12, MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.add_child(sub)

	var room_id := str(room.get("id", ""))
	var room_code := str(room.get("room_code", ""))

	# SHARE button — copy code / native share
	var btn_share := _mk_button("SHARE", 14, MUTED)
	btn_share.custom_minimum_size = Vector2(72, 40)
	btn_share.pressed.connect(func(): _share_room_code(room_code))
	row.add_child(btn_share)

	# Action button
	var btn_text := "REJOIN" if is_mine else ("UNLOCK" if is_private else "JOIN")
	var btn := _mk_button(btn_text, 16, ACCENT if not is_mine else CYAN)
	btn.custom_minimum_size = Vector2(88, 40)
	if is_mine:
		btn.pressed.connect(func(): _enter_as_host(room_id, room_code))
	elif is_private:
		btn.pressed.connect(func(): _open_password_dialog(room_id, room_code, room))
	else:
		btn.pressed.connect(func(): _do_join(room_id, room_code))
	row.add_child(btn)

# ── Create flow ───────────────────────────────────────────────────────────────

func _open_create_dialog() -> void:
	if not Globals.is_signed_in():
		_portal_bridge.request_auth()
		_set_status("Waiting for sign-in...")
		return
	_open_modal("Create Room")

	var name_input := _mk_line_edit("Room name (e.g. Friday Night)")
	name_input.max_length = 24
	_modal_body.add_child(name_input)

	# Public/Private toggle row
	var toggle_row := HBoxContainer.new()
	toggle_row.add_theme_constant_override("separation", 8)
	toggle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_modal_body.add_child(toggle_row)

	var btn_pub := _mk_button("PUBLIC", 16, CYAN)
	var btn_priv := _mk_button("PRIVATE", 16, MUTED)
	btn_pub.custom_minimum_size = Vector2(110, 38)
	btn_priv.custom_minimum_size = Vector2(110, 38)
	toggle_row.add_child(btn_pub)
	toggle_row.add_child(btn_priv)

	var pwd_input := _mk_line_edit("Password (min 4 chars)")
	pwd_input.secret = true
	pwd_input.max_length = 32
	pwd_input.visible = false
	_modal_body.add_child(pwd_input)

	var is_private_ref := [false]
	btn_pub.pressed.connect(func():
		is_private_ref[0] = false
		btn_pub.add_theme_color_override("font_color", CYAN)
		btn_priv.add_theme_color_override("font_color", MUTED)
		pwd_input.visible = false
	)
	btn_priv.pressed.connect(func():
		is_private_ref[0] = true
		btn_pub.add_theme_color_override("font_color", MUTED)
		btn_priv.add_theme_color_override("font_color", PURPLE)
		pwd_input.visible = true
	)

	var err_lbl := _mk_label("", 13, Color("#ef4444"))
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_body.add_child(err_lbl)

	# Buttons
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	_modal_body.add_child(btns)

	var btn_cancel := _mk_button("CANCEL", 16, MUTED)
	btn_cancel.custom_minimum_size = Vector2(120, 42)
	btn_cancel.pressed.connect(_close_modal)
	btns.add_child(btn_cancel)

	var btn_go := _mk_button("CREATE", 16, ACCENT)
	btn_go.custom_minimum_size = Vector2(120, 42)
	btn_go.pressed.connect(func():
		var rn := name_input.text.strip_edges()
		if rn.is_empty():
			err_lbl.text = "Room name required."
			return
		var priv := bool(is_private_ref[0])
		var pwd := pwd_input.text
		if priv and pwd.length() < RoomManager.MIN_PASSWORD_LEN:
			err_lbl.text = "Password must be %d+ chars." % RoomManager.MIN_PASSWORD_LEN
			return
		btn_go.disabled = true
		err_lbl.text = ""
		await _do_create(rn, priv, pwd)
		btn_go.disabled = false
	)
	btns.add_child(btn_go)

func _do_create(room_name: String, is_private: bool, password: String) -> void:
	_set_status("Creating room...")
	var user_id := _get_user_id_from_jwt(Globals.jwt)
	var game_mode := Globals.current_game_mode if Globals.current_game_mode != "" else "classic"
	var timer_lbl := RoomManager.timer_label_from_seconds(Globals.timer_seconds)
	var row: Dictionary = await RoomManager.create_room_async(
		Globals.supabase, user_id, room_name, is_private, password, game_mode, timer_lbl)
	if row.is_empty():
		var err := RoomManager.last_error if RoomManager.last_error != "" else "unknown"
		_set_status("Create failed: " + err)
		return
	_close_modal()
	var rid := str(row.get("id", ""))
	var rcode := str(row.get("room_code", ""))
	_enter_as_host(rid, rcode)
	await _refresh_rooms()

func _enter_as_host(room_id: String, room_code: String) -> void:
	_room_id = room_id
	_room_code = room_code
	_player_mark = GameState.Player.X
	_set_status("Room ready (%s). Waiting for opponent..." % room_code)
	Globals.supabase.connect_realtime("room:" + _room_id)
	if not Globals.supabase.realtime_message.is_connected(_on_realtime):
		Globals.supabase.realtime_message.connect(_on_realtime)

# ── Join flow ─────────────────────────────────────────────────────────────────

func _open_password_dialog(room_id: String, room_code: String, room: Dictionary) -> void:
	_open_modal("Enter Password")
	_modal_body.add_child(_mk_label(str(room.get("room_name", "Room")), 16, TEXT))

	var pwd_input := _mk_line_edit("Password")
	pwd_input.secret = true
	pwd_input.max_length = 32
	_modal_body.add_child(pwd_input)

	var err_lbl := _mk_label("", 13, Color("#ef4444"))
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_body.add_child(err_lbl)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	_modal_body.add_child(btns)

	var btn_cancel := _mk_button("CANCEL", 16, MUTED)
	btn_cancel.custom_minimum_size = Vector2(120, 42)
	btn_cancel.pressed.connect(_close_modal)
	btns.add_child(btn_cancel)

	var btn_go := _mk_button("JOIN", 16, ACCENT)
	btn_go.custom_minimum_size = Vector2(120, 42)
	btn_go.pressed.connect(func():
		btn_go.disabled = true
		err_lbl.text = ""
		# Re-fetch to get current password + status (avoid race with stale list).
		var fresh: Dictionary = await RoomManager.fetch_room_by_id_async(Globals.supabase, room_id)
		if fresh.is_empty() or fresh.get("status") != "waiting":
			err_lbl.text = "Room no longer available."
			btn_go.disabled = false
			return
		if str(fresh.get("password", "")) != pwd_input.text:
			err_lbl.text = "Wrong password."
			btn_go.disabled = false
			return
		_close_modal()
		_do_join(room_id, room_code)
	)
	btns.add_child(btn_go)

func _do_join(room_id: String, room_code: String) -> void:
	_set_status("Joining...")
	_room_id = room_id
	_room_code = room_code
	_player_mark = GameState.Player.O
	var user_id := _get_user_id_from_jwt(Globals.jwt)
	var ok: bool = await RoomManager.join_room_async(Globals.supabase, _room_id, user_id)
	if not ok:
		_set_status("Join failed (room may already be full).")
		return
	Globals.supabase.connect_realtime("room:" + _room_id)
	await get_tree().create_timer(0.6).timeout
	Globals.supabase.broadcast("room:" + _room_id, "guest_joined", {})
	_launch_game()

func _auto_join_by_code(code: String) -> void:
	var room: Dictionary = await RoomManager.fetch_room_by_code_async(Globals.supabase, code.to_upper())
	if room.is_empty():
		_set_status("Room not found.")
		_refresh_rooms()
		return
	if room.get("status") != "waiting":
		_set_status("Room already full or finished.")
		_refresh_rooms()
		return
	var my_id := _get_user_id_from_jwt(Globals.jwt)
	if str(room.get("host_id", "")) == my_id:
		_enter_as_host(str(room.get("id", "")), str(room.get("room_code", "")))
		return
	if bool(room.get("is_private", false)):
		_open_password_dialog(str(room.get("id", "")), str(room.get("room_code", "")), room)
	else:
		_do_join(str(room.get("id", "")), str(room.get("room_code", "")))

# ── Realtime ──────────────────────────────────────────────────────────────────

func _on_realtime(_channel: String, event: String, _payload: Dictionary) -> void:
	if event == "guest_joined":
		_launch_game()

func _launch_game() -> void:
	if Globals.supabase.realtime_message.is_connected(_on_realtime):
		Globals.supabase.realtime_message.disconnect(_on_realtime)
	var board = load("res://scenes/GameBoard.tscn").instantiate()
	board.setup_online(_room_id, _player_mark, Globals.supabase)
	get_tree().root.add_child(board)
	get_tree().current_scene = board
	queue_free()

# ── Modal ─────────────────────────────────────────────────────────────────────

func _open_modal(title_text: String) -> void:
	_close_modal()
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	_modal.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	_modal_body = VBoxContainer.new()
	_modal_body.add_theme_constant_override("separation", 12)
	panel.add_child(_modal_body)

	var title := _mk_label(title_text, 20, CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_body.add_child(title)

func _close_modal() -> void:
	if _modal:
		_modal.queue_free()
		_modal = null
		_modal_body = null

# ── Helpers ───────────────────────────────────────────────────────────────────

func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _orbitron)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _mk_button(text: String, size: int, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _orbitron)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", color)
	return b

func _mk_line_edit(placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.add_theme_font_override("font", _orbitron)
	le.add_theme_font_size_override("font_size", 14)
	return le

func _share_room_code(room_code: String) -> void:
	var share_url := RoomManager.get_share_url(room_code)
	var text := "Join my Hash Attack room! Code: %s\n%s" % [room_code, share_url]
	if OS.has_feature("web"):
		# Try native share (mobile), fall back to clipboard.
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
	_set_status("Room code %s copied!" % room_code)

func _set_status(text: String) -> void:
	if _lbl_status:
		_lbl_status.text = text

func _get_user_id_from_jwt(jwt: String) -> String:
	var parts = jwt.split(".")
	if parts.size() < 2:
		return ""
	var padded = parts[1]
	while padded.length() % 4 != 0:
		padded += "="
	var decoded = Marshalls.base64_to_utf8(padded.replace("-", "+").replace("_", "/"))
	var payload = JSON.parse_string(decoded)
	return payload.get("sub", "") if payload else ""

func _exit_tree() -> void:
	if Globals.supabase.realtime_message.is_connected(_on_realtime):
		Globals.supabase.realtime_message.disconnect(_on_realtime)
