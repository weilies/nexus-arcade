class_name ModeTile
extends Button

const TILE_SIZE := 160.0
const BORDER_COLOR := Color("#a855f7")
const HOVER_COLOR := Color("#00d4ff")
const LABEL_COLOR := Color("#94a3b8")

func _ready() -> void:
	custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	_apply_style()

func _apply_style() -> void:
	add_theme_constant_override("corner_radius", 0)
	add_theme_color_override("font_color", LABEL_COLOR)
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	alignment = HORIZONTAL_ALIGNMENT_LEFT

func _on_hover() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.05, 1.05), 0.12)

func _on_unhover() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.12)
