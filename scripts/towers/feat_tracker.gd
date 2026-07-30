class_name FeatTracker
extends RefCounted

## Runtime progress for one tower instance.

signal feat_progressed(feat_id: StringName, current: float, target: float)
signal feat_unlocked(feat_id: StringName)

var _defs: Array[FeatDef] = []
var _progress: Dictionary = {} # StringName -> float
var _completed: Dictionary = {} # StringName -> bool
var pending_evolution_points: int = 0
var evolutions_taken: int = 0
const MAX_EVOLUTIONS := 2


func setup(defs: Array[FeatDef]) -> void:
	_defs = defs
	_progress.clear()
	_completed.clear()
	for def in _defs:
		_progress[def.id] = 0.0
		_completed[def.id] = false


func add_progress(feat_id: StringName, amount: float) -> void:
	if not _progress.has(feat_id):
		return
	if _completed.get(feat_id, false):
		return
	var def := _find_def(feat_id)
	if def == null:
		return
	_progress[feat_id] = minf(_progress[feat_id] + amount, def.target_value)
	feat_progressed.emit(feat_id, _progress[feat_id], def.target_value)
	if _progress[feat_id] >= def.target_value:
		_completed[feat_id] = true
		if def.grants_evolution_point and evolutions_taken + pending_evolution_points < MAX_EVOLUTIONS:
			pending_evolution_points += 1
		feat_unlocked.emit(feat_id)


func get_snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def in _defs:
		out.append({
			"id": def.id,
			"title": def.title,
			"description": def.description,
			"current": _progress.get(def.id, 0.0),
			"target": def.target_value,
			"done": _completed.get(def.id, false),
		})
	return out


func has_pending_evolution() -> bool:
	return pending_evolution_points > 0 and evolutions_taken < MAX_EVOLUTIONS


func consume_evolution_point() -> bool:
	if not has_pending_evolution():
		return false
	pending_evolution_points -= 1
	evolutions_taken += 1
	return true


func _find_def(feat_id: StringName) -> FeatDef:
	for def in _defs:
		if def.id == feat_id:
			return def
	return null
