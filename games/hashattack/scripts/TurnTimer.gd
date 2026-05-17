class_name TurnTimer
extends Node

signal timed_out
signal tick(seconds_left: int)

var _duration: float = 9.0  # overridden by set_duration() before start()
const PULSE_THRESHOLD = 3

var _timer: Timer
var _label: Label
var _seconds_left: int
var _pulse_tween: Tween

func _ready() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.wait_time = 1.0
		_timer.autostart = false
		_timer.timeout.connect(_on_tick)
		add_child(_timer)

func setup(label_node: Label) -> void:
	_label = label_node

func start() -> void:
	_seconds_left = int(_duration)
	_update_label()
	_timer.start()

func stop() -> void:
	_timer.stop()
	if _pulse_tween:
		_pulse_tween.kill()
	if _label:
		_label.add_theme_color_override("font_color", Color("#94a3b8"))
		_label.scale = Vector2.ONE

func set_duration(seconds: float) -> void:
	_duration = seconds

func get_duration() -> float:
	return _duration

func get_time_left() -> float:
	return _timer.time_left if _timer and not _timer.is_stopped() else 0.0

# Total remaining seconds including the current sub-second interval
func get_total_time_left() -> float:
	if not is_running():
		return 0.0
	return float(_seconds_left - 1) + _timer.time_left

func is_running() -> bool:
	return _timer != null and not _timer.is_stopped()

func reset_and_start() -> void:
	stop()
	start()

func _on_tick() -> void:
	_seconds_left -= 1
	tick.emit(_seconds_left)
	_update_label()
	if _seconds_left <= 0:
		timed_out.emit()
		stop()

func _update_label() -> void:
	if not _label:
		return
	_label.text = "%ds" % _seconds_left
	if _seconds_left <= PULSE_THRESHOLD:
		_label.add_theme_color_override("font_color", Color("#ef4444"))
		if not _pulse_tween or not _pulse_tween.is_running():
			_pulse_tween = create_tween().set_loops()
			_pulse_tween.tween_property(_label, "scale", Vector2(1.15, 1.15), 0.25)
			_pulse_tween.tween_property(_label, "scale", Vector2.ONE, 0.25)
			_label.pivot_offset = _label.size / 2.0
	else:
		_label.add_theme_color_override("font_color", Color("#94a3b8"))
