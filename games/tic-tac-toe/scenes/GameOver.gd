extends Control

var _score_x: int
var _score_o: int
var _mode: GameBoard.Mode
var _board_ref: GameBoard

func setup(winner: String, score_x: int, score_o: int, mode: GameBoard.Mode,
		board: GameBoard, pts_awarded: int = 0, current_streak: int = 0) -> void:
	_score_x = score_x
	_score_o = score_o
	_mode = mode
	_board_ref = board

	match winner:
		"X":
			$VBoxContainer/LblResult.text = "X WINS!"
			$VBoxContainer/LblResult.add_theme_color_override("font_color", Color("#00d4ff"))
			$VBoxContainer/LblSub.text = "X wins the match"
		"O":
			$VBoxContainer/LblResult.text = "O WINS!"
			$VBoxContainer/LblResult.add_theme_color_override("font_color", Color("#a855f7"))
			$VBoxContainer/LblSub.text = "O wins the match"
		_:
			$VBoxContainer/LblResult.text = "DRAW"
			$VBoxContainer/LblResult.add_theme_color_override("font_color", Color("#94a3b8"))
			$VBoxContainer/LblSub.text = "No winner this time"

	if Globals.is_signed_in() and pts_awarded > 0:
		$VBoxContainer/LblPtsEarned.visible = true
		$VBoxContainer/LblPtsEarned.text = "+%d ★" % pts_awarded
		$VBoxContainer/LblPtsEarned.add_theme_color_override("font_color", Color("#00d4ff"))

	if Globals.is_signed_in() and current_streak > 0:
		$VBoxContainer/LblStreakDisplay.visible = true
		$VBoxContainer/LblStreakDisplay.text = "🔥 %d STREAK" % current_streak

	if current_streak in [10, 20, 50]:
		$VBoxContainer/MilestoneBanner.visible = true
		$VBoxContainer/MilestoneBanner/LblMilestone.text = \
			"STREAK MASTER — %d WIN STREAK!" % current_streak
		$VBoxContainer/MilestoneBanner/LblMilestone.add_theme_color_override(
			"font_color", Color("#ff2d95"))

func _ready() -> void:
	$VBoxContainer/BtnRow/BtnPlayAgain.pressed.connect(_on_play_again)
	$VBoxContainer/BtnRow/BtnMenu.pressed.connect(_on_menu)
	if $VBoxContainer/LblResult.text != "DRAW":
		_shake()

func _shake() -> void:
	var origin = position
	var tween = create_tween()
	for i in 6:
		var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		tween.tween_property(self, "position", origin + offset, 0.04)
	tween.tween_property(self, "position", origin, 0.04)

func _on_play_again() -> void:
	SFX.click()
	_board_ref._game_over_fired = false
	_board_ref._state = GameState.new()
	_board_ref._refresh_ui()
	queue_free()

func _on_menu() -> void:
	SFX.click()
	_board_ref.queue_free()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	queue_free()
