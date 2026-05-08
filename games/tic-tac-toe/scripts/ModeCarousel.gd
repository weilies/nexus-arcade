class_name ModeCarousel
extends Control

signal mode_changed(index: int, mode_name: String)

const MODES: Array[Dictionary] = [
	{ "name": "Classic", "id": "classic" },
	{ "name": "Ultimate", "id": "ultimate" },
	{ "name": "Ephemerate", "id": "ephemerate" },
]

var _current_index: int = 0
var _drag_start: Vector2
var _dragging: bool = false

@onready var _preview: ModePreview = $PreviewContainer/ModePreview
@onready var _lbl_mode: Label = $LblModeName
@onready var _btn_left: Button = $BtnArrowLeft
@onready var _btn_right: Button = $BtnArrowRight
@onready var _dots: Array[Label] = [
	$DotContainer/Dot0,
	$DotContainer/Dot1,
	$DotContainer/Dot2,
]

func _ready() -> void:
	_btn_left.pressed.connect(func(): _prev())
	_btn_right.pressed.connect(func(): _next())
	_refresh()

func _next() -> void:
	_current_index = (_current_index + 1) % MODES.size()
	_refresh()
	SFX.click()

func _prev() -> void:
	_current_index = (_current_index - 1 + MODES.size()) % MODES.size()
	_refresh()
	SFX.click()

func _refresh() -> void:
	var m := MODES[_current_index]
	_lbl_mode.text = m.name.to_upper()
	_preview.set_mode(m.id)
	for i in _dots.size():
		_dots[i].add_theme_color_override("font_color",
			Color("#00d4ff") if i == _current_index else Color("#334466"))
	mode_changed.emit(_current_index, m.id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start = event.position
				_dragging = true
			elif _dragging:
				var dx := event.position.x - _drag_start.x
				if abs(dx) > 50:
					if dx > 0: _prev()
					else: _next()
				_dragging = false
