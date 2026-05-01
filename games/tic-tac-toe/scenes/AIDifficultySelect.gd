extends Control

func _ready() -> void:
	$VBoxContainer/BtnEasy.pressed.connect(_on_easy)
	$VBoxContainer/BtnHard.pressed.connect(_on_hard)
	$VBoxContainer/BtnBack.pressed.connect(_on_back)

func _on_back() -> void:
	SFX.click()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_easy() -> void:
	SFX.click()
	_launch(TicTacToeAI.Difficulty.EASY)

func _on_hard() -> void:
	SFX.click()
	_launch(TicTacToeAI.Difficulty.HARD)

func _launch(difficulty: TicTacToeAI.Difficulty) -> void:
	var board = load("res://scenes/GameBoard.tscn").instantiate()
	board.setup_vs_ai(difficulty)
	get_tree().root.add_child(board)
	queue_free()
