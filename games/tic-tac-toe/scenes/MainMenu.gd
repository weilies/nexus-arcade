extends Control

var _current_game_mode: String = "classic"
var _timer_index: int = 0
# 0=Off, 1=Blitz(3s), 2=Casual(6s), 3=Chill(9s)
const TIMER_MODES: Array[Dictionary] = [
	{ "label": "OFF", "seconds": 0 },
	{ "label": "BLITZ", "seconds": 3 },
	{ "label": "CASUAL", "seconds": 6 },
	{ "label": "CHILL", "seconds": 9 },
]
var _show_sign_out: bool = false
var _help_popup: Control = null
var _difficulty_index: int = 0
const DIFFICULTY_MODES: Array[Dictionary] = [
	{ "label": "EASY",       "difficulty": 0, "color": Color("#00ff88") },
	{ "label": "HARD",       "difficulty": 1, "color": Color("#ffd700") },
	{ "label": "UNBEATABLE", "difficulty": 2, "color": Color("#ff2d95") },
]

var _btn_difficulty: Button = null

@onready var _carousel: ModeCarousel = $CarouselContainer
@onready var _btn_1p: Button = $TileBar/Row1/Btn1P
@onready var _btn_2p: Button = $TileBar/Row1/Btn2P
@onready var _btn_online: Button = $TileBar/Row1/BtnOnline
@onready var _btn_help: Button = $TileBar/Row1/BtnHelp
@onready var _btn_leaderboard: Button = $TileBar/Row2/BtnLeaderboard
@onready var _btn_left: Button = $CarouselContainer/BtnArrowLeft
@onready var _btn_right: Button = $CarouselContainer/BtnArrowRight
@onready var _btn_timer: Button = $CarouselContainer/TimerRow/BtnTimer
@onready var _lbl_timer: Label = $CarouselContainer/TimerRow/BtnTimer/HBoxTimer/LblTimer
@onready var _lbl_clock_icon: Label = $CarouselContainer/TimerRow/BtnTimer/HBoxTimer/LblClockIcon
@onready var _lbl_mode_name: Label = $CarouselContainer/LblModeName

# Row2 nodes (built programmatically)
var _auth_slot: Control = null
var _btn_sign_in: Button = null
var _btn_sign_out: Button = null
var _slot_profile: VBoxContainer = null
var _lbl_username: Label = null
var _lbl_points: Label = null

func _ready() -> void:
	var bg = load("res://scripts/BackgroundLayer.gd").new()
	add_child(bg)
	move_child(bg, 1)

	# Apply ArcadeTheme for programmatic nodes (Button=30px, Label=28px)
	var arcade_theme := load("res://theme/ArcadeTheme.tres") as Theme
	arcade_theme.default_font = load("res://fonts/Orbitron.ttf")
	theme = arcade_theme

	_btn_1p.pressed.connect(_on_1p)
	_btn_2p.pressed.connect(_on_2p)
	_btn_online.pressed.connect(_on_online)
	_btn_help.pressed.connect(_on_help)
	_btn_leaderboard.pressed.connect(_on_leaderboard)
	_btn_timer.pressed.connect(_on_timer_pressed)

	_btn_left.flat = true
	_btn_left.text = FA6.icon("chevron-left")
	_btn_left.add_theme_font_override("font", FA6.font())
	_btn_right.flat = true
	_btn_right.text = FA6.icon("chevron-right")
	_btn_right.add_theme_font_override("font", FA6.font())

	_lbl_clock_icon.text = FA6.icon("clock")
	_lbl_clock_icon.add_theme_font_override("font", FA6.font())

	_carousel.mode_changed.connect(_on_mode_changed)
	_refresh_timer_visibility()
	_refresh_timer_label()

	_build_row2()
	_build_difficulty_row()

	_slot_profile.gui_input.connect(_on_profile_clicked)

	$Bridge.send_game_ready()
	$Bridge.auth_token_received.connect(func(_t): pass)
	if not Globals.auth_ready.is_connected(_refresh_auth_ui):
		Globals.auth_ready.connect(_refresh_auth_ui)
	_refresh_auth_ui()

func _build_row2() -> void:
	var row2 := $TileBar/Row2

	# --- Auth slot (SIGN IN button / Profile + SIGN OUT toggle) ---
	_auth_slot = VBoxContainer.new()
	_auth_slot.custom_minimum_size = Vector2(96, 96)
	_auth_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	_auth_slot.mouse_filter = 1

	_btn_sign_in = Button.new()
	_btn_sign_in.custom_minimum_size = Vector2(96, 96)
	_btn_sign_in.icon = preload("res://images/icon-user.svg")
	_btn_sign_in.expand_icon = true
	_btn_sign_in.add_theme_constant_override("icon_max_width", 48)
	_btn_sign_in.add_theme_color_override("font_color", Color("#00d4ff"))
	_btn_sign_in.text = "SIGN IN"
	_btn_sign_in.pressed.connect(_on_sign_in)
	_auth_slot.add_child(_btn_sign_in)

	_slot_profile = VBoxContainer.new()
	_slot_profile.visible = false
	_slot_profile.custom_minimum_size = Vector2(96, 96)
	_slot_profile.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_profile.mouse_filter = 1

	var prof_icon := TextureRect.new()
	prof_icon.texture = preload("res://images/icon-user.svg")
	prof_icon.custom_minimum_size = Vector2(36, 36)
	prof_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	prof_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_slot_profile.add_child(prof_icon)

	_lbl_username = Label.new()
	_lbl_username.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_username.add_theme_color_override("font_color", Color("#00d4ff"))
	_slot_profile.add_child(_lbl_username)

	_lbl_points = Label.new()
	_lbl_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_points.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75, 1))
	_slot_profile.add_child(_lbl_points)

	_btn_sign_out = Button.new()
	_btn_sign_out.visible = false
	_btn_sign_out.flat = true
	_btn_sign_out.text = "SIGN OUT"
	_btn_sign_out.custom_minimum_size = Vector2(96, 32)
	_btn_sign_out.add_theme_color_override("font_color", Color("#ef4444"))
	_btn_sign_out.pressed.connect(_on_sign_out)

	_auth_slot.add_child(_slot_profile)
	_auth_slot.add_child(_btn_sign_out)
	row2.add_child(_auth_slot)
	row2.move_child(_auth_slot, 0)

func _build_difficulty_row() -> void:
	var carousel := $CarouselContainer

	var row := HBoxContainer.new()
	row.name = "DifficultyRow"
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN

	_btn_difficulty = Button.new()
	_btn_difficulty.flat = false
	_btn_difficulty.custom_minimum_size = Vector2(300, 56)
	_btn_difficulty.pressed.connect(_on_difficulty_pressed)
	row.add_child(_btn_difficulty)

	# Insert after TimerRow
	var timer_row := carousel.get_node("TimerRow")
	var insert_idx := timer_row.get_index() + 1
	carousel.add_child(row)
	carousel.move_child(row, insert_idx)

	_refresh_difficulty_label()

func _on_mode_changed(_index: int, mode_id: String) -> void:
	_current_game_mode = mode_id
	_refresh_timer_visibility()

func _refresh_timer_visibility() -> void:
	var locked := _current_game_mode in ["ultimate", "ephemerate"]
	$CarouselContainer/TimerRow.visible = not locked
	if has_node("CarouselContainer/DifficultyRow"):
		$CarouselContainer/DifficultyRow.visible = true

func _on_timer_pressed() -> void:
	_timer_index = (_timer_index + 1) % TIMER_MODES.size()
	_refresh_timer_label()

func _refresh_difficulty_label() -> void:
	var mode: Dictionary = DIFFICULTY_MODES[_difficulty_index]
	_btn_difficulty.text = mode["label"]
	var clr: Color = mode["color"]
	_btn_difficulty.add_theme_color_override("font_color", clr)
	Globals.ai_difficulty = mode["difficulty"] as Globals.AIDifficulty

func _on_difficulty_pressed() -> void:
	SFX.click()
	_difficulty_index = (_difficulty_index + 1) % DIFFICULTY_MODES.size()
	_refresh_difficulty_label()

func _refresh_timer_label() -> void:
	var mode: Dictionary = TIMER_MODES[_timer_index]
	var label: String = mode["label"]
	var secs: int = mode["seconds"]
	_lbl_timer.text = label
	var clr: Color
	match label:
		"BLITZ":  clr = Color("#ff2d95")
		"CASUAL": clr = Color("#ffd700")
		"CHILL":  clr = Color("#00ff88")
		_:        clr = Color(0.392, 0.455, 0.573, 1.0)
	_lbl_timer.add_theme_color_override("font_color", clr)
	_lbl_clock_icon.add_theme_color_override("font_color", clr)
	Globals.timer_seconds = secs

func _on_1p() -> void:
	SFX.click()
	Globals.current_game_mode = _current_game_mode
	if _current_game_mode in ["ultimate", "ephemerate"]:
		Globals.timer_seconds = 6
	else:
		Globals.timer_seconds = TIMER_MODES[_timer_index]["seconds"]
	var board = load("res://scenes/GameBoard.tscn").instantiate()
	board.setup_vs_ai(Globals.ai_difficulty)
	get_tree().root.add_child(board)
	queue_free()

func _on_2p() -> void:
	SFX.click()
	Globals.current_game_mode = _current_game_mode
	if _current_game_mode in ["ultimate", "ephemerate"]:
		Globals.timer_seconds = 6
	else:
		Globals.timer_seconds = TIMER_MODES[_timer_index]["seconds"]
	var board = load("res://scenes/GameBoard.tscn").instantiate()
	board.setup_local()
	get_tree().root.add_child(board)
	queue_free()

func _on_online() -> void:
	SFX.click()
	Globals.current_game_mode = _current_game_mode
	if _current_game_mode in ["ultimate", "ephemerate"]:
		Globals.timer_seconds = 6
	else:
		Globals.timer_seconds = TIMER_MODES[_timer_index]["seconds"]
	get_tree().change_scene_to_file("res://scenes/OnlineLobby.tscn")

func _on_leaderboard() -> void:
	SFX.click()
	get_tree().change_scene_to_file("res://scenes/LeaderboardScene.tscn")

func _on_sign_in() -> void:
	SFX.click()
	$Bridge.send_sign_in_request()

func _on_sign_out() -> void:
	SFX.click()
	$Bridge.send_sign_out_request()

func _on_help() -> void:
	SFX.click()
	if _help_popup:
		_help_popup.queue_free()
	_help_popup = _make_help_popup()
	add_child(_help_popup)

func _on_profile_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_show_sign_out = not _show_sign_out
		_refresh_auth_ui()

func _refresh_auth_ui() -> void:
	var signed_in := Globals.is_signed_in()
	if signed_in:
		_lbl_username.text = Globals.current_user.get("username", "")
		_lbl_points.text = "★ %d pts" % Globals.current_user.get("points", 0)
		_btn_sign_in.visible = false
		_slot_profile.visible = true
		_btn_sign_out.visible = _show_sign_out
	else:
		_btn_sign_in.visible = true
		_slot_profile.visible = false
		_btn_sign_out.visible = false
		_show_sign_out = false

func _make_help_popup() -> Control:
	var popup := Control.new()
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP

	# Dim background
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.8)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			SFX.click()
			popup.queue_free()
			_help_popup = null
	)
	popup.add_child(dim)

	# Panel
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -260
	panel.offset_top = -340
	panel.offset_right = 260
	panel.offset_bottom = 340
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.008, 0.008, 0.04, 0.97)
	ps.border_width_left = 2
	ps.border_color = Color("#00d4ff")
	ps.corner_radius_top_left = 12
	ps.corner_radius_top_right = 12
	ps.corner_radius_bottom_left = 12
	ps.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", ps)
	popup.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_top = 16
	vbox.offset_right = -20
	vbox.offset_bottom = -16
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 0)

	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#00d4ff"))
	hdr.add_child(title)

	var close := Button.new()
	close.flat = true
	close.text = FA6.icon("xmark")
	close.add_theme_font_override("font", FA6.font())
	close.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75, 1))
	close.custom_minimum_size = Vector2(40, 40)
	close.pressed.connect(func():
		SFX.click()
		popup.queue_free()
		_help_popup = null
	)
	hdr.add_child(close)
	vbox.add_child(hdr)

	# Scrollable content
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var content := Label.new()
	content.text = _get_help_text()
	content.add_theme_font_size_override("font_size", 24)
	content.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75, 1))
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.custom_minimum_size = Vector2(480, 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	return popup

func _get_help_text() -> String:
	var lines: Array[String] = []
	if _current_game_mode == "classic":
		lines.append_array(_help_classic())
	elif _current_game_mode == "ultimate":
		lines.append_array(_help_ultimate())
	else:
		lines.append_array(_help_ephemeral())

	lines.append("")
	lines.append("--- TIMER ---")
	lines.append("Tap TIMER to cycle: OFF > BLITZ (3s) > CASUAL (6s) > CHILL (9s).")
	lines.append("When on, place your mark before time runs out or you SKIP your turn.")

	return "\n".join(lines)

func _help_classic() -> Array[String]:
	return [
		"CLASSIC MODE",
		"",
		"The OG. The classic. The game your grandma could beat you at.",
		"",
		"Get three X's (or O's) in a row — horizontal, vertical, or diagonal. Board fills with no winner? Draw. Yes, draws happen. No, you can't argue with the grid.",
		"",
		"Pro strat: Take the center. That's it. That's the whole strategy.",
	]

func _help_ultimate() -> Array[String]:
	return [
		"ULTIMATE MODE",
		"",
		"Tic Tac Toe on steroids. A 3x3 grid OF 3x3 grids.",
		"",
		"Win a mini-board to claim that square on the mega-board. Twist: your move picks which mini-board your opponent plays next. Send them to an already-won board? They play anywhere. Evil grin optional.",
		"",
		"TIMER always on (CASUAL). Place fast.",
	]

func _help_ephemeral() -> Array[String]:
	return [
		"EPHEMERAL MODE",
		"",
		"Like classic, but your marks have commitment issues.",
		"",
		"Place your 5th mark and your oldest mark vanishes. Marks fade as they age — brightest is newest, dimmest is next to go. No draws — someone always wins.",
		"",
		"TIMER always on (CASUAL). Keep up.",
	]
