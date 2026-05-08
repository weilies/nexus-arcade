extends Control

func _ready() -> void:
	var bg = load("res://scripts/BackgroundLayer.gd").new()
	add_child(bg)
	move_child(bg, 1)

	$VBoxContainer/BtnBack.pressed.connect(_on_back)
	$VBoxContainer/BtnBack.text = FA6.icon("fa-arrow-left") + "  BACK"
	$VBoxContainer/LblTitle.text = "LEADERBOARD"
	_load_leaderboard()

func _load_leaderboard() -> void:
	$VBoxContainer/LblLoading.visible = true
	$VBoxContainer/LblLoading.text = "LOADING..."
	$VBoxContainer/LeaderList.visible = false

	var game_id := Globals.current_game_id
	if game_id.is_empty():
		game_id = await Globals.supabase.fetch_game_id(Globals.GAME_SLUG)

	var rows: Array = await Globals.supabase.get_leaderboard(game_id, 20)

	$VBoxContainer/LblLoading.visible = false
	$VBoxContainer/LeaderList.visible = true

	for child in $VBoxContainer/LeaderList.get_children():
		child.queue_free()

	if rows.is_empty():
		var lbl := Label.new()
		lbl.text = "No scores yet. Be first!"
		$VBoxContainer/LeaderList.add_child(lbl)
		return

	for i in rows.size():
		var pts: int = int(rows[i].get("total_points", 0))
		var uname: String = rows[i].get("users", {}).get("username", "???")

		var entry := HBoxContainer.new()
		var rank  := Label.new()
		var name  := Label.new()
		var score := Label.new()

		rank.text  = "#%d" % (i + 1)
		rank.custom_minimum_size = Vector2(56, 0)
		name.text  = uname
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		score.text = "★ %d" % pts

		if i < 3:
			var cyan := Color("#00d4ff")
			rank.add_theme_color_override("font_color", cyan)
			name.add_theme_color_override("font_color", cyan)
			score.add_theme_color_override("font_color", cyan)

		entry.add_child(rank)
		entry.add_child(name)
		entry.add_child(score)
		$VBoxContainer/LeaderList.add_child(entry)

func _on_back() -> void:
	SFX.click()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
