extends Control

func _ready() -> void:
	var bg = load("res://scripts/BackgroundLayer.gd").new()
	add_child(bg)
	move_child(bg, 1)

	$VBoxContainer/BtnVsAI.pressed.connect(_on_vs_ai)
	$VBoxContainer/BtnLocal.pressed.connect(_on_local)
	$VBoxContainer/BtnOnline.pressed.connect(_on_online)
	$VBoxContainer/BtnSignIn.pressed.connect(_on_sign_in)
	$VBoxContainer/BtnLeaderboard.pressed.connect(_on_leaderboard)

	$VBoxContainer/ProfileRow/LblProfileIcon.text = FA6.icon("fa-user")
	$VBoxContainer/BtnLeaderboard.text = FA6.icon("fa-trophy") + "  LEADERBOARD"

	$Bridge.send_game_ready()
	$Bridge.auth_token_received.connect(func(_t): pass)  # auth via Globals.auth_ready

	if not Globals.auth_ready.is_connected(_refresh_auth_ui):
		Globals.auth_ready.connect(_refresh_auth_ui)

	_refresh_auth_ui()

func _refresh_auth_ui() -> void:
	var signed_in := Globals.is_signed_in()
	$VBoxContainer/ProfileRow.visible = signed_in
	$VBoxContainer/BtnLeaderboard.visible = signed_in
	$VBoxContainer/BtnSignIn.visible = not signed_in
	if signed_in:
		$VBoxContainer/ProfileRow/LblUsername.text = Globals.current_user.get("username", "")
		$VBoxContainer/ProfileRow/LblPoints.text = "★ %d" % Globals.current_user.get("points", 0)

func _on_sign_in() -> void:
	SFX.click()
	$Bridge.send_sign_in_request()

func _on_leaderboard() -> void:
	SFX.click()
	get_tree().change_scene_to_file("res://scenes/LeaderboardScene.tscn")

func _on_vs_ai() -> void:
	SFX.click()
	Globals.current_game_mode = "classic"
	get_tree().change_scene_to_file("res://scenes/AIDifficultySelect.tscn")

func _on_local() -> void:
	SFX.click()
	Globals.current_game_mode = "classic"
	var board = load("res://scenes/GameBoard.tscn").instantiate()
	board.setup_local()
	get_tree().root.add_child(board)
	queue_free()

func _on_online() -> void:
	SFX.click()
	Globals.current_game_mode = "classic"
	get_tree().change_scene_to_file("res://scenes/OnlineLobby.tscn")
