extends Control

func _ready() -> void:
	$VBoxContainer/BtnVsAI.pressed.connect(_on_vs_ai)
	$VBoxContainer/BtnLocal.pressed.connect(_on_local)
	$VBoxContainer/BtnOnline.pressed.connect(_on_online)

func _on_vs_ai() -> void:
	get_tree().change_scene_to_file("res://scenes/AIDifficultySelect.tscn")

func _on_local() -> void:
	var board = load("res://scenes/GameBoard.tscn").instantiate()
	board.setup_local()
	get_tree().root.add_child(board)
	queue_free()

func _on_online() -> void:
	get_tree().change_scene_to_file("res://scenes/OnlineLobby.tscn")
