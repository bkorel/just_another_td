extends RefCounted

## Unit tests for FeatTracker and evolution points accumulation.


static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_feat_progress_and_unlock())
	results.append(_test_evolution_points_consumption())
	return results


static func _test_feat_progress_and_unlock() -> Dictionary:
	var tracker := FeatTracker.new()
	var def := FeatDef.new()
	def.id = &"kills_5"
	def.title = "Five Kills"
	def.target_value = 5.0
	def.grants_evolution_point = true

	var defs: Array[FeatDef] = [def]
	tracker.setup(defs)

	tracker.add_progress(&"kills_5", 3.0)
	var pass_mid := tracker.pending_evolution_points == 0

	tracker.add_progress(&"kills_5", 2.0)
	var pass_done := tracker.pending_evolution_points == 1 and tracker.has_pending_evolution()

	return { "name": "FeatTracker Progress & Unlock", "passed": pass_mid and pass_done }


static func _test_evolution_points_consumption() -> Dictionary:
	var tracker := FeatTracker.new()
	var def1 := _make_feat(&"f1", 1)
	var def2 := _make_feat(&"f2", 1)
	var def3 := _make_feat(&"f3", 1)

	var defs: Array[FeatDef] = [def1, def2, def3]
	tracker.setup(defs)

	tracker.add_progress(&"f1", 1)
	tracker.add_progress(&"f2", 1)
	var pass_two_pts := tracker.pending_evolution_points == 2

	var pass_consume1 := tracker.consume_evolution_point()
	var pass_after1 := tracker.pending_evolution_points == 1 and tracker.evolutions_taken == 1

	var pass_consume2 := tracker.consume_evolution_point()
	var pass_after2 := tracker.pending_evolution_points == 0 and tracker.evolutions_taken == 2

	# Should fail because MAX_EVOLUTIONS = 2
	tracker.add_progress(&"f3", 1)
	var pass_max_cap := tracker.pending_evolution_points == 0 and not tracker.has_pending_evolution()

	var ok := pass_two_pts and pass_consume1 and pass_after1 and pass_consume2 and pass_after2 and pass_max_cap
	return { "name": "FeatTracker Evolution Cap & Consumption", "passed": ok }


static func _make_feat(id: StringName, target: float) -> FeatDef:
	var f := FeatDef.new()
	f.id = id
	f.title = str(id)
	f.target_value = target
	f.grants_evolution_point = true
	return f
