extends Control

var _current_game_mode: String = "classic"
var _timer_enabled: bool = false

@onready var _carousel: ModeCarousel = $CarouselContainer
@onready var _btn_1p: Button = $TileBar/Row1/Btn1P
@onready var _btn_2p: Button = $TileBar/Row1/Btn2P
@onready var _btn_online: Button = $TileBar/Row1/BtnOnline
@onready var _btn_leaderboard: Button = $TileBar/Row2/BtnLeaderboard
@onready var _check_timer: CheckBox = $CarouselContainer/TimerRow/CheckTimer
@onready var _lbl_clock: Label = $CarouselContainer/TimerRow/LblClock
@onready var _lbl_timer_secs: Label = $CarouselContainer/TimerRow/LblTimerSecs
@onready var _btn_left: Button = $CarouselContainer/BtnArrowLeft
@onready var _btn_right: Button = $CarouselContainer/BtnArrowRight
@onready var _preview_container: Control = $CarouselContainer/PreviewContainer

func _ready() -> void:
	var bg = load("res://scripts/BackgroundLayer.gd").new()
	add_child(bg)
	move_child(bg, 1)
	# BtnSignInIcon must render above HeaderBar (z-order fix)
	move_child($BtnSignInIcon, get_child_count() - 1)

	# Wire tile buttons
	_btn_1p.pressed.connect(_on_1p)
	_btn_2p.pressed.connect(_on_2p)
	_btn_online.pressed.connect(_on_online)
	_btn_leaderboard.pressed.connect(_on_leaderboard)
	$BtnSignInIcon.pressed.connect(_on_sign_in)

	# Wire carousel
	_carousel.mode_changed.connect(_on_mode_changed)

	# Timer toggle
	_check_timer.toggled.connect(_on_timer_toggled)
	_refresh_timer_visibility()

	# Arrow buttons — flat (no background), FA6 font
	var fa6 := FA6.font()
	_btn_left.flat = true
	_btn_left.text = FA6.icon("chevron-left")
	_btn_left.add_theme_font_override("font", fa6)
	_btn_right.flat = true
	_btn_right.text = FA6.icon("chevron-right")
	_btn_right.add_theme_font_override("font", fa6)

	# Sign-in icon
	$BtnSignInIcon.text = FA6.icon("arrow-right-to-bracket")
	$BtnSignInIcon.add_theme_font_override("font", fa6)

	# Profile icons
	$ProfileRow/LblProfileIcon.text = FA6.icon("user")
	$ProfileRow/LblProfileIcon.add_theme_font_override("font", fa6)
	_btn_leaderboard.add_theme_font_override("font", fa6)
	_btn_leaderboard.text = FA6.icon("trophy") + "  LEADERBOARD"

	# Clock icon
	_lbl_clock.text = FA6.icon("clock")
	_lbl_clock.add_theme_font_override("font", fa6)

	# Dots must not block tile button clicks below
	for dot in $CarouselContainer/DotContainer.get_children():
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Auth
	$Bridge.send_game_ready()
	$Bridge.auth_token_received.connect(func(_t): pass)
	if not Globals.auth_ready.is_connected(_refresh_auth_ui):
		Globals.auth_ready.connect(_refresh_auth_ui)
	_refresh_auth_ui()

func _on_mode_changed(index: int, mode_id: String) -> void:
	_current_game_mode = mode_id
	_refresh_timer_visibility()

func _refresh_timer_visibility() -> void:
	var show_timer := _current_game_mode != "ultimate"  # not shown for Ultimate placeholder
	$CarouselContainer/TimerRow.visible = show_timer

func _on_timer_toggled(pressed: bool) -> void:
	_timer_enabled = pressed
	_lbl_timer_secs.add_theme_color_override("font_color",
		Color("#00d4ff") if pressed else Color(0.392, 0.455, 0.573, 1))

func _on_1p() -> void:
	SFX.click()
	Globals.current_game_mode = _current_game_mode
	Globals.use_timer = _timer_enabled
	Globals.timer_seconds = 10
	get_tree().change_scene_to_file("res://scenes/AIDifficultySelect.tscn")

func _on_2p() -> void:
	SFX.click()
	Globals.current_game_mode = _current_game_mode
	Globals.use_timer = false  # timer disabled for local 2P
	Globals.timer_seconds = 10
	var board = load("res://scenes/GameBoard.tscn").instantiate()
	board.setup_local()
	get_tree().root.add_child(board)
	queue_free()

func _on_online() -> void:
	SFX.click()
	Globals.current_game_mode = _current_game_mode
	Globals.use_timer = _timer_enabled
	Globals.timer_seconds = 10
	get_tree().change_scene_to_file("res://scenes/OnlineLobby.tscn")

func _on_leaderboard() -> void:
	SFX.click()
	get_tree().change_scene_to_file("res://scenes/LeaderboardScene.tscn")

func _on_sign_in() -> void:
	SFX.click()
	$Bridge.send_sign_in_request()

func _refresh_auth_ui() -> void:
	var signed_in := Globals.is_signed_in()
	$ProfileRow.visible = signed_in
	_btn_leaderboard.visible = signed_in
	$BtnSignInIcon.visible = not signed_in
	if signed_in:
		$ProfileRow/LblUsername.text = Globals.current_user.get("username", "")
		$ProfileRow/LblPoints.text = "★ %d" % Globals.current_user.get("points", 0)
