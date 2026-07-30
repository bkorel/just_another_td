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
	var base_dmg: float = tower.get("damage")

	# Force 1 evolution point
	if tower.get("feats") != null:
		tower.get("feats").pending_evolution_points = 1

	var options: Array = tower.get("evolution_options")
	var marksman_evo: EvolutionDef = options[0] # Marksman
	var applied: bool = tower.apply_evolution(marksman_evo)

	var pass_applied: bool = applied
	var new_dmg: float = tower.get("damage")
	var applied_evos: Array = tower.get("applied_evolutions")
	var pass_stats: bool = new_dmg > base_dmg and applied_evos.has(&"marksman")

	tower.free()
	return { "name": "Archer Tower Marksman Evolution", "passed": pass_applied and pass_stats }


static func _test_frost_evolution() -> Dictionary:
	var tower: Node2D = FrostScene.instantiate()
	var base_slow: float = tower.get("slow_factor")

	# Force 1 evolution point
	if tower.get("feats") != null:
		tower.get("feats").pending_evolution_points = 1

	var options: Array = tower.get("evolution_options")
	var glacier_evo: EvolutionDef = options[0] # Glacier
	var applied: bool = tower.apply_evolution(glacier_evo)

	var pass_applied: bool = applied
	var new_slow: float = tower.get("slow_factor")
	var applied_evos: Array = tower.get("applied_evolutions")
	var pass_slow: bool = new_slow < base_slow and applied_evos.has(&"glacier")

	tower.free()
	return { "name": "Frost Tower Glacier Evolution", "passed": pass_applied and pass_slow }
