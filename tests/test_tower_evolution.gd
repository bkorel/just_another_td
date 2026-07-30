extends RefCounted

## Unit tests for Archer and Frost tower evolutions.

const ArcherScene := preload("res://scenes/towers/tower.tscn")
const FrostScene := preload("res://scenes/towers/frost_tower.tscn")


static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_archer_evolution())
	results.append(_test_frost_evolution())
	return results


static func _test_archer_evolution() -> Dictionary:
	var tower: Node2D = ArcherScene.instantiate()
	var base_dmg := tower.damage

	# Force 1 evolution point
	tower.feats.pending_evolution_points = 1

	var marksman_evo: EvolutionDef = tower.evolution_options[0] # Marksman
	var applied := tower.apply_evolution(marksman_evo)

	var pass_applied := applied
	var pass_stats := tower.damage > base_dmg and tower.applied_evolutions.has(&"marksman")

	tower.free()
	return { "name": "Archer Tower Marksman Evolution", "passed": pass_applied and pass_stats }


static func _test_frost_evolution() -> Dictionary:
	var tower: Node2D = FrostScene.instantiate()
	var base_slow := tower.slow_factor

	# Force 1 evolution point
	tower.feats.pending_evolution_points = 1

	var glacier_evo: EvolutionDef = tower.evolution_options[0] # Glacier
	var applied := tower.apply_evolution(glacier_evo)

	var pass_applied := applied
	var pass_slow := tower.slow_factor < base_slow and tower.applied_evolutions.has(&"glacier")

	tower.free()
	return { "name": "Frost Tower Glacier Evolution", "passed": pass_applied and pass_slow }
