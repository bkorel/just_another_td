extends RefCounted

## Unit tests for tower placement validation rules.


static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_path_clearance_math())
	results.append(_test_gold_gate())
	return results


static func _test_path_clearance_math() -> Dictionary:
	# Mirrors level.can_place_at curve distance logic without needing a full scene tree.
	var curve := Curve2D.new()
	curve.add_point(Vector2(0, 360))
	curve.add_point(Vector2(640, 360))
	curve.add_point(Vector2(1280, 360))

	var on_path := Vector2(640, 360)
	var closest_on := curve.get_closest_point(on_path)
	var blocked: bool = on_path.distance_to(closest_on) < 36.0

	var off_path := Vector2(640, 120)
	var closest_off := curve.get_closest_point(off_path)
	var allowed: bool = off_path.distance_to(closest_off) >= 36.0

	return {
		"name": "Placement Path Clearance Math",
		"passed": blocked and allowed
	}


static func _test_gold_gate() -> Dictionary:
	GameState.reset_run()
	var start: int = GameState.gold
	var ok_spend: bool = GameState.try_spend_gold(GameState.ARCHER_COST)
	var after: int = GameState.gold
	var blocked: bool = not GameState.try_spend_gold(99999)
	return {
		"name": "Placement Gold Gate",
		"passed": ok_spend and after == start - GameState.ARCHER_COST and blocked
	}
