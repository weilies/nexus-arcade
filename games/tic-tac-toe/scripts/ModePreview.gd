class_name ModePreview
extends Control

const GRID_COLOR := Color("#00d4ff")
const GRID_DIM_COLOR := Color(0, 0.831, 1, 0.3)
const X_COLOR := Color("#00d4ff")
const O_COLOR := Color("#a855f7")

var _mode: String = "classic"
var _tween: Tween

func _ready() -> void:
	_start_spin()

func set_mode(mode: String) -> void:
	_mode = mode
	_start_spin()
	queue_redraw()

func _start_spin() -> void:
	if _tween:
		_tween.kill()
	match _mode:
		"classic":
			modulate.a = 0.7
			var tw := create_tween().set_loops()
			tw.tween_property(self, "rotation_degrees", 12.0, 1.5).set_trans(Tween.TRANS_SINE)
			tw.tween_property(self, "rotation_degrees", -12.0, 1.5).set_trans(Tween.TRANS_SINE)
			_tween = tw
		"ultimate":
			modulate.a = 0.7
			var tw := create_tween().set_loops()
			tw.tween_property(self, "scale:x", 0.92, 1.0).set_trans(Tween.TRANS_SINE)
			tw.tween_property(self, "scale:x", 1.08, 1.0).set_trans(Tween.TRANS_SINE)
			_tween = tw
		"ephemerate":
			var tw := create_tween().set_loops()
			tw.tween_property(self, "modulate:a", 0.4, 1.2).set_trans(Tween.TRANS_SINE)
			tw.tween_property(self, "modulate:a", 0.7, 1.2).set_trans(Tween.TRANS_SINE)
			_tween = tw

func _draw() -> void:
	var sz := size
	match _mode:
		"classic":
			_draw_classic(sz)
		"ultimate":
			_draw_ultimate(sz)
		"ephemerate":
			_draw_ephemerate(sz)

func _draw_classic(sz: Vector2) -> void:
	var margin := 40.0
	var grid_sz := sz.x - margin * 2
	var cell := grid_sz / 3.0
	var ox := margin
	var oy := (sz.y - grid_sz) / 2.0
	for i in range(1, 3):
		draw_line(Vector2(ox + cell * i, oy), Vector2(ox + cell * i, oy + grid_sz), GRID_COLOR, 2)
		draw_line(Vector2(ox, oy + cell * i), Vector2(ox + grid_sz, oy + cell * i), GRID_COLOR, 2)
	_place_mark(ox, oy, cell, 0, 0, "X")
	_place_mark(ox, oy, cell, 1, 1, "O")
	_place_mark(ox, oy, cell, 2, 0, "X")
	_place_mark(ox, oy, cell, 1, 2, "O")

func _place_mark(ox: float, oy: float, cell: float, col: int, row: int, mark: String) -> void:
	var cx := ox + cell * col + cell / 2.0
	var cy := oy + cell * row + cell / 2.0
	var r := cell * 0.3
	var clr: Color = X_COLOR if mark == "X" else O_COLOR
	if mark == "X":
		draw_line(Vector2(cx - r, cy - r), Vector2(cx + r, cy + r), clr, 4)
		draw_line(Vector2(cx + r, cy - r), Vector2(cx - r, cy + r), clr, 4)
	else:
		draw_arc(Vector2(cx, cy), r, 0, TAU, 32, clr, 4)

func _draw_ultimate(sz: Vector2) -> void:
	var margin := 20.0
	var grid_sz := sz.x - margin * 2
	var big_cell := grid_sz / 3.0
	var small_cell := big_cell / 3.0
	var ox := margin
	var oy := (sz.y - grid_sz) / 2.0
	for i in range(1, 3):
		draw_line(Vector2(ox + big_cell * i, oy), Vector2(ox + big_cell * i, oy + grid_sz), GRID_COLOR, 3)
		draw_line(Vector2(ox, oy + big_cell * i), Vector2(ox + grid_sz, oy + big_cell * i), GRID_COLOR, 3)
	for br in 3:
		for bc in 3:
			var bx := ox + big_cell * bc
			var by := oy + big_cell * br
			for si in range(1, 3):
				draw_line(Vector2(bx + small_cell * si, by), Vector2(bx + small_cell * si, by + big_cell), GRID_DIM_COLOR, 1)
				draw_line(Vector2(bx, by + small_cell * si), Vector2(bx + big_cell, by + small_cell * si), GRID_DIM_COLOR, 1)

func _draw_ephemerate(sz: Vector2) -> void:
	var margin := 40.0
	var grid_sz := sz.x - margin * 2
	var cell := grid_sz / 3.0
	var ox := margin
	var oy := (sz.y - grid_sz) / 2.0
	for i in range(1, 3):
		draw_line(Vector2(ox + cell * i, oy), Vector2(ox + cell * i, oy + grid_sz), GRID_COLOR, 2)
		draw_line(Vector2(ox, oy + cell * i), Vector2(ox + grid_sz, oy + cell * i), GRID_COLOR, 2)
	_draw_faded_mark(ox, oy, cell, 0, 0, "X", 1.0)
	_draw_faded_mark(ox, oy, cell, 1, 1, "O", 0.75)
	_draw_faded_mark(ox, oy, cell, 2, 0, "X", 0.5)
	_draw_faded_mark(ox, oy, cell, 1, 2, "O", 0.25)

func _draw_faded_mark(ox: float, oy: float, cell: float, col: int, row: int, mark: String, alpha: float) -> void:
	var cx := ox + cell * col + cell / 2.0
	var cy := oy + cell * row + cell / 2.0
	var r := cell * 0.3
	var clr: Color = (X_COLOR if mark == "X" else O_COLOR)
	clr.a = alpha
	if mark == "X":
		draw_line(Vector2(cx - r, cy - r), Vector2(cx + r, cy + r), clr, 3)
		draw_line(Vector2(cx + r, cy - r), Vector2(cx - r, cy + r), clr, 3)
	else:
		draw_arc(Vector2(cx, cy), r, 0, TAU, 32, clr, 3)
