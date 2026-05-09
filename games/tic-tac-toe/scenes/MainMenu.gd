extends Control

var _current_game_mode: String = "classic"
var _timer_enabled: bool = false
var _panel_open := false

@onready var _carousel: ModeCarousel = $CarouselContainer
@onready var _btn_1p: Button = $TileBar/Row1/Btn1P
@onready var _btn_2p: Button = $TileBar/Row1/Btn2P
@onready var _btn_online: Button = $TileBar/Row1/BtnOnline
@onready var _check_timer: CheckBox = $CarouselContainer/TimerRow/CheckTimer
@onready var _lbl_clock: Label = $CarouselContainer/TimerRow/LblClock
@onready var _lbl_timer_secs: Label = $CarouselContainer/TimerRow/LblTimerSecs
@onready var _btn_left: Button = $CarouselContainer/BtnArrowLeft
@onready var _btn_right: Button = $CarouselContainer/BtnArrowRight
@onready var _btn_expand: Button = $BtnExpand
@onready var _hud_panel: Control = $HUDPanel

func _ready() -> void:
	var bg = load("res://scripts/BackgroundLayer.gd").new()
	add_child(bg)
	move_child(bg, 1)
	move_child($BtnExpand, get_child_count() - 1)

	_btn_1p.pressed.connect(_on_1p)
	_btn_2p.pressed.connect(_on_2p)
	_btn_online.pressed.connect(_on_online)
	_btn_expand.pressed.connect(_toggle_panel)
	$HUDPanel/Slots/BtnSignIn.pressed.connect(_on_sign_in)
	$HUDPanel/Slots/BtnLeaderboard.pressed.connect(_on_leaderboard)

	_carousel.mode_changed.connect(_on_mode_changed)
	_check_timer.toggled.connect(_on_timer_toggled)
	_refresh_timer_visibility()

	var fa6 := FA6.font()
	_btn_left.flat = true
	_btn_left.text = FA6.icon("chevron-left")
	_btn_left.add_theme_font_override("font", fa6)
	_btn_right.flat = true
	_btn_right.text = FA6.icon("chevron-right")
	_btn_right.add_theme_font_override("font", fa6)

	_btn_expand.text = ">"

	_lbl_clock.text = FA6.icon("clock")
	_lbl_clock.add_theme_font_override("font", fa6)

	$HUDPanel/Slots/SlotProfile/LblProfileIcon.add_theme_font_override("font", fa6)
	$HUDPanel/Slots/SlotProfile/LblProfileIcon.text = FA6.icon("user")
	$HUDPanel/Slots/BtnSignIn.add_theme_font_override("font", fa6)
	$HUDPanel/Slots/BtnSignIn.text = FA6.icon("arrow-right-to-bracket") + "  SIGN IN"
	$HUDPanel/Slots/BtnLeaderboard.add_theme_font_override("font", fa6)
	$HUDPanel/Slots/BtnLeaderboard.text = FA6.icon("trophy") + "  LEADERBOARD"
	$HUDPanel/Slots/BtnMarketplace.add_theme_font_override("font", fa6)
	$HUDPanel/Slots/BtnMarketplace.text = FA6.icon("lock") + "  MARKETPLACE"

	$Bridge.send_game_ready()
	$Bridge.auth_token_received.connect(func(_t): pass)
	if not Globals.auth_ready.is_connected(_refresh_auth_ui):
		Globals.auth_ready.connect(_refresh_auth_ui)
	_refresh_auth_ui()

func _toggle_panel() -> void:
	_panel_open = not _panel_open
	_hud_panel.visible = true
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _panel_open:
		tw.tween_property(_hud_panel, "offset_left", -240.0, 0.18)
		_btn_expand.text = "<"
	else:
		tw.tween_property(_hud_panel, "offset_left", 0.0, 0.15)
		tw.tween_callback(func(): _hud_panel.visible = false)
		_btn_expand.text = ">"

func _on_mode_changed(_index: int, mode_id: String) -> void:
	_current_game_mode = mode_id
	_refresh_timer_visibility()

func _refresh_timer_visibility() -> void:
	$CarouselContainer/TimerRow.visible = _current_game_mode != "ultimate"

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
	Globals.use_timer = false
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
	$HUDPanel/Slots/SlotProfile.visible = signed_in
	$HUDPanel/Slots/BtnSignIn.visible = not signed_in
	if signed_in:
		$HUDPanel/Slots/SlotProfile/VBoxProfileInfo/LblUsername.text = Globals.current_user.get("username", "")
		$HUDPanel/Slots/SlotProfile/VBoxProfileInfo/LblPoints.text = "★ %d" % Globals.current_user.get("points", 0)
