extends Control

const _COUNT = 18
const _SYMBOLS = ["X", "O", "+"]
const _FONT_PATH = "res://fonts/Orbitron.ttf"

var _particles: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font = load(_FONT_PATH) if ResourceLoader.exists(_FONT_PATH) else null
	var colors = [
		Color(0.0, 0.831, 1.0, 0.09),     # #00d4ff cyan
		Color(0.659, 0.333, 0.969, 0.08),  # #a855f7 purple
		Color(1.0, 0.176, 0.584, 0.06),    # #ff2d95 magenta
		Color(0.667, 0.667, 0.8, 0.05),    # #aaaacc muted
	]
	for i in _COUNT:
		var label = Label.new()
		label.text = _SYMBOLS[randi() % _SYMBOLS.size()]
		var col: Color = colors[randi() % colors.size()]
		label.add_theme_color_override("font_color", col)
		if font:
			label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", int(randf_range(24.0, 76.0)))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)

		var angle = randf_range(0.0, TAU)
		var speed = randf_range(12.0, 34.0)
		var p = {
			"node": label,
			"x": randf_range(-60.0, 780.0),
			"y": randf_range(-60.0, 1020.0),
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed,
			"rot": randf_range(0.0, TAU),
			"rot_speed": randf_range(-0.25, 0.25),
		}
		label.position = Vector2(p.x, p.y)
		label.rotation = p.rot
		_particles.append(p)

func _process(delta: float) -> void:
	for p in _particles:
		p.x += p.vx * delta
		p.y += p.vy * delta
		p.rot += p.rot_speed * delta
		if p.x > 830.0: p.x = -60.0
		elif p.x < -60.0: p.x = 830.0
		if p.y > 1070.0: p.y = -60.0
		elif p.y < -60.0: p.y = 1070.0
		p.node.position = Vector2(p.x, p.y)
		p.node.rotation = p.rot
