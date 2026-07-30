extends PanelContainer

## In-game visual unit test runner dialog.

const TestGameState = preload("res://tests/test_game_state.gd")
const TestFeatTracker = preload("res://tests/test_feat_tracker.gd")
const TestTowerEvolution = preload("res://tests/test_tower_evolution.gd")

@onready var test_list: VBoxContainer = $Margin/VBox/Scroll/TestList
@onready var summary_label: Label = $Margin/VBox/SummaryLabel
@onready var close_btn: Button = $Margin/VBox/CloseBtn


func _ready() -> void:
	close_btn.pressed.connect(func(): queue_free())
	run_tests()


func run_tests() -> void:
	for child in test_list.get_children():
		child.queue_free()

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
			var row := Label.new()
			if test["passed"]:
				passed += 1
				row.text = "✓ [ PASS ]  %s" % test["name"]
				row.modulate = Color(0.4, 0.95, 0.5)
			else:
				failed += 1
				row.text = "✗ [ FAIL ]  %s" % test["name"]
				row.modulate = Color(1.0, 0.4, 0.4)
			test_list.add_child(row)

	summary_label.text = "TEST SUMMARY: %d/%d Passed (%d Failed)" % [passed, total, failed]
	summary_label.modulate = Color(0.4, 0.95, 0.5) if failed == 0 else Color(1.0, 0.4, 0.4)
