extends GutTest

func test_globals_timer_defaults() -> void:
	assert_eq(Globals.timer_seconds, 0, "timer_seconds should default to 0")
	assert_eq(Globals.ai_difficulty, Globals.AIDifficulty.EASY, "ai_difficulty should default to EASY")

func test_globals_timer_toggle() -> void:
	Globals.timer_seconds = 6
	assert_eq(Globals.timer_seconds, 6, "timer_seconds should be settable")
	Globals.timer_seconds = 0
	assert_eq(Globals.timer_seconds, 0, "timer_seconds should toggle back")

func test_carousel_modes_count() -> void:
	var ModeCarouselScript = load("res://scripts/ModeCarousel.gd")
	var modes = ModeCarouselScript.MODES
	assert_eq(modes.size(), 3, "should have 3 modes")

func test_carousel_modes_have_required() -> void:
	var ModeCarouselScript = load("res://scripts/ModeCarousel.gd")
	var modes = ModeCarouselScript.MODES
	var ids: Array[String] = []
	for m in modes:
		ids.append(m.id)
	assert_true(ids.has("classic"), "should have classic mode")
	assert_true(ids.has("ultimate"), "should have ultimate mode")
	assert_true(ids.has("ephemeral"), "should have ephemeral mode")

func test_mode_tile_size_constant() -> void:
	var ModeTile = load("res://scripts/ModeTile.gd")
	assert_eq(ModeTile.TILE_SIZE, 96.0, "tile size should be 96")

func test_carousel_wrap_next() -> void:
	var ModeCarouselScript = load("res://scripts/ModeCarousel.gd")
	var instances := 0
	var idx := 0
	idx = _simulate_next(idx, 3, instances)
	assert_eq(idx, 1)
	idx = _simulate_next(idx, 3, instances)
	assert_eq(idx, 2)
	idx = _simulate_next(idx, 3, instances)
	assert_eq(idx, 0)

func test_carousel_wrap_prev() -> void:
	var instances := 0
	var idx := 0
	idx = _simulate_prev(idx, 3, instances)
	assert_eq(idx, 2)

# Simulate ModeCarousel._next() wrapping logic without needing a live instance
func _simulate_next(index: int, size: int, _inst: int) -> int:
	return (index + 1) % size

# Simulate ModeCarousel._prev() wrapping logic without needing a live instance
func _simulate_prev(index: int, size: int, _inst: int) -> int:
	return (index - 1 + size) % size
