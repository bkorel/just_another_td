extends RefCounted

## Unit tests for GameState autoload state management.


static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_initial_state())
	results.append(_test_spend_add_gold())
	results.append(_test_damage_base_and_lose())
	results.append(_test_placement_type_and_cost())
	return results


static func _test_initial_state() -> Dictionary:
	GameState.reset_run()
	var pass_ok := (
		GameState.gold == GameState.STARTING_GOLD and
		GameState.lives == GameState.STARTING_LIVES and
		GameState.phase == GameState.Phase.BUILD and
		GameState.wave_index == 0
	)
	return { "name": "GameState Initial State", "passed": pass_ok }


static func _test_spend_add_gold() -> Dictionary:
	GameState.reset_run()
	var start_gold := GameState.gold
	var spent := GameState.try_spend_gold(50)
	var pass_spend := spent and GameState.gold == (start_gold - 50)

	var fail_overspend := not GameState.try_spend_gold(10000)

	GameState.add_gold(100)
	var pass_add := (GameState.gold == (start_gold - 50 + 100))

	return { "name": "GameState Gold Economy", "passed": pass_spend and fail_overspend and pass_add }


static func _test_damage_base_and_lose() -> Dictionary:
	GameState.reset_run()
	GameState.damage_base(5)
	var pass_dmg := GameState.lives == (GameState.STARTING_LIVES - 5)

	GameState.damage_base(100)
	var pass_lose := (GameState.lives == 0 and GameState.phase == GameState.Phase.LOST)

	return { "name": "GameState Base Damage & Defeat Condition", "passed": pass_dmg and pass_lose }


static func _test_placement_type_and_cost() -> Dictionary:
	GameState.reset_run()
	GameState.set_placement_type(&"archer")
	var pass_archer := (GameState.get_current_placement_cost() == GameState.ARCHER_COST)

	GameState.set_placement_type(&"frost")
	var pass_frost := (GameState.get_current_placement_cost() == GameState.FROST_COST)

	return { "name": "GameState Tower Selection & Costs", "passed": pass_archer and pass_frost }
