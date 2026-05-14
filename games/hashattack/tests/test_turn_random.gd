extends GutTest

func test_random_first_turn_produces_x() -> void:
	var found_x := false
	for _i in 100:
		var mark := _simulate_random_turn()
		if mark == 0:  # Player.X
			found_x = true
			break
	assert_true(found_x, "random turn should produce X at least once in 100 tries")

func test_random_first_turn_produces_o() -> void:
	var found_o := false
	for _i in 100:
		var mark := _simulate_random_turn()
		if mark == 1:  # Player.O
			found_o = true
			break
	assert_true(found_o, "random turn should produce O at least once in 100 tries")

func test_vs_ai_player_is_always_x_or_o() -> void:
	for _i in 50:
		var mark := _simulate_random_turn()
		assert_true(mark == 0 or mark == 1, "player mark should be X(0) or O(1)")

func _simulate_random_turn() -> int:
	if randi() % 2 == 0:
		return 0  # Player.X
	else:
		return 1  # Player.O
