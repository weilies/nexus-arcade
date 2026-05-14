class_name ModePreview
extends Control

const GRID_COLOR := Color("#00d4ff")
const GRID_DIM_COLOR := Color(0, 0.831, 1, 0.3)
const X_COLOR := Color("#00d4ff")
const O_COLOR := Color("#a855f7")

var _mode: String = "classic"
var _tween: Tween
var _flicker: Array = []

func _ready() -> void:
	_apply_mode()

func set_mode(mode: String) -> void:
	_mode = mode
	_apply_mode()
	queue_redraw()

func _apply_mode() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	scale = Vector2.ONE
	_flicker.clear()
	match _mode:
		"classic":
			modulate.a = 0.7
			rotation_degrees = 8.0
		"ultimate":
			modulate.a = 0.7
			rotation_degrees = 0.0
		"ephemeral":
			modulate.a = 1.0
			rotation_degrees = 0.0
			_init_flicker()

func _init_flicker() -> void:
	var defs := [
		["X", 0, 0], ["O", 1, 1], ["X", 2, 0],
		["O", 0, 2], ["X", 2, 2], ["O", 1, 2],
	]
	for d in defs:
		_flicker.append({
			"mark": d[0], "col": d[1], "row": d[2],
			"alpha": randf_range(0.6, 1.0),
			"timer": randf_range(0.1, 1.5),
			"dim": false
		})

func _process(delta: float) -> void:
	if _mode != "ephemeral" or _flicker.is_empty():
		return
	var dirty := false
	for f in _flicker:
		f.timer -= delta
		if f.timer <= 0:
			if f.dim:
				f.alpha = randf_range(0.7, 1.0)
				f.timer = randf_range(0.4, 2.0)
				f.dim = false
			else:
				f.alpha = randf_range(0.0, 0.15)
				f.timer = randf_range(0.05, 0.18)
				f.dim = true
			dirty = true
	if dirty:
		queue_redraw()

func _draw() -> void:
	var sz := size
	match _mode:
		"classic": _draw_classic(sz)
		"ultimate": _draw_ultimate(sz)
		"ephemeral": _draw_ephemeral(sz)

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

func _draw_ultimate(sz: Vector2) -> void:
	var margin := 16.0
	var grid_sz := sz.x - margin * 2
	var big_cell := grid_sz / 3.0
	var small_cell := big_cell / 3.0
	var ox := margin
	var oy := (sz.y - grid_sz) / 2.0
	var x_won := [4]
	var o_won := [0]
	var active_board := 8
	for br in 3:
		for bc in 3:
			var bx := ox + big_cell * bc
			var by := oy + big_cell * br
			var idx := br * 3 + bc
			if idx in x_won:
				var pad := 6.0
				draw_line(Vector2(bx+pad, by+pad), Vector2(bx+big_cell-pad, by+big_cell-pad), Color(X_COLOR, 0.85), 5)
				draw_line(Vector2(bx+big_cell-pad, by+pad), Vector2(bx+pad, by+big_cell-pad), Color(X_COLOR, 0.85), 5)
			elif idx in o_won:
				draw_arc(Vector2(bx+big_cell/2, by+big_cell/2), big_cell/2-6, 0, TAU, 24, Color(O_COLOR, 0.85), 5)
			else:
				for si in range(1, 3):
					draw_line(Vector2(bx+small_cell*si, by), Vector2(bx+small_cell*si, by+big_cell), GRID_DIM_COLOR, 1)
					draw_line(Vector2(bx, by+small_cell*si), Vector2(bx+big_cell, by+small_cell*si), GRID_DIM_COLOR, 1)
				if idx == active_board:
					var r := small_cell * 0.28
					var cx := bx + small_cell * 0.5
					var cy := by + small_cell * 0.5
					draw_arc(Vector2(cx, cy), r, 0, TAU, 12, Color(O_COLOR, 0.6), 2)
					var cx2 := bx + small_cell * 2.5
					var cy2 := by + small_cell * 1.5
					draw_line(Vector2(cx2-r, cy2-r), Vector2(cx2+r, cy2+r), Color(X_COLOR, 0.6), 2)
					draw_line(Vector2(cx2+r, cy2-r), Vector2(cx2-r, cy2+r), Color(X_COLOR, 0.6), 2)
	var abr := active_board / 3
	var abt_bc := active_board % 3
	draw_rect(Rect2(ox+big_cell*abt_bc+1, oy+big_cell*abr+1, big_cell-2, big_cell-2), Color(GRID_COLOR, 0.35), false, 2)
	for i in range(1, 3):
		draw_line(Vector2(ox+big_cell*i, oy), Vector2(ox+big_cell*i, oy+grid_sz), GRID_COLOR, 3)
		draw_line(Vector2(ox, oy+big_cell*i), Vector2(ox+grid_sz, oy+big_cell*i), GRID_COLOR, 3)

func _draw_ephemeral(sz: Vector2) -> void:
	var margin := 40.0
	var grid_sz := sz.x - margin * 2
	var cell := grid_sz / 3.0
	var ox := margin
	var oy := (sz.y - grid_sz) / 2.0
	for i in range(1, 3):
		draw_line(Vector2(ox + cell * i, oy), Vector2(ox + cell * i, oy + grid_sz), GRID_COLOR, 2)
		draw_line(Vector2(ox, oy + cell * i), Vector2(ox + grid_sz, oy + cell * i), GRID_COLOR, 2)
	for f in _flicker:
		_draw_faded_mark(ox, oy, cell, f.col, f.row, f.mark, f.alpha)

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
