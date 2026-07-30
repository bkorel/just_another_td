extends SceneTree

## Main test runner script.
## Can be executed headless via command line: godot --headless -s tests/test_runner.gd

const TestGameState = preload("res://tests/test_game_state.gd")
const TestFeatTracker = preload("res://tests/test_feat_tracker.gd")
const TestTowerEvolution = preload("res://tests/test_tower_evolution.gd")


func _init() -> void:
	print("\n==========================================")
	print("🧪 RUNNING JUST ANOTHER TD UNIT TESTS")
	print("==========================================\n")

	var total := 0
	var passed := 0
	var failed := 0

	var suites := [
		TestGameState.run_all(),
		TestFeatTracker.run_all(),
		TestTowerEvolution.run_all()
	]

	for suite in suites:
		for test in suite:
			total += 1
			if test["passed"]:
				passed += 1
				print("  [ PASS ]  %s" % test["name"])
			else:
				failed += 1
				print("  [ FAIL ]  %s" % test["name"])

	print("\n------------------------------------------")
	print("RESULT: %d/%d PASSED (%d Failed)" % [passed, total, failed])
	print("==========================================\n")

	quit(0 if failed == 0 else 1)
