extends GutTest

func before_each() -> void:
	Globals.current_user = {}
	Globals.current_game_id = ""
	Globals.current_streak = {}
	Globals.current_game_mode = "classic"

func test_signed_out_when_user_empty() -> void:
	assert_false(Globals.is_signed_in())

func test_signed_in_when_user_populated() -> void:
	Globals.current_user = {"id": "abc", "username": "p1", "points": 0}
	assert_true(Globals.is_signed_in())

func test_streak_increments() -> void:
	Globals.current_streak["classic"] = 4
	Globals.current_streak["classic"] += 1
	assert_eq(Globals.current_streak["classic"], 5)

func test_streak_resets_on_loss() -> void:
	Globals.current_streak["classic"] = 7
	Globals.current_streak["classic"] = 0
	assert_eq(Globals.current_streak["classic"], 0)

func test_modes_independent() -> void:
	Globals.current_streak["classic"] = 5
	Globals.current_streak["ultimate"] = 3
	Globals.current_streak["classic"] = 0
	assert_eq(Globals.current_streak["classic"], 0)
	assert_eq(Globals.current_streak["ultimate"], 3)

func test_points_accumulate() -> void:
	Globals.current_user = {"id": "x", "username": "p", "points": 10}
	Globals.current_user["points"] += 5
	assert_eq(Globals.current_user["points"], 15)
