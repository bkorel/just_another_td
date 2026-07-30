extends Node

## Global run state: lives, gold, phase, tower placement selection.

signal gold_changed(amount: int)
signal lives_changed(amount: int)
signal wave_changed(index: int)
signal tower_selected(tower: Node)
signal feat_completed(tower: Node, feat_id: StringName)
signal evolution_available(tower: Node)
signal placement_type_changed(type_id: StringName)
signal run_won
signal run_lost

enum Phase { BUILD, WAVE, EVOLUTION_PICK, WON, LOST }

var phase: Phase = Phase.BUILD
var gold: int = 140
var lives: int = 20
var wave_index: int = 0
var selected_tower: Node = null
var selected_placement_type: StringName = &"archer"

const ARCHER_COST := 50
const FROST_COST := 60
const STARTING_GOLD := 140
const STARTING_LIVES := 20


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	phase = Phase.BUILD
	gold = STARTING_GOLD
	lives = STARTING_LIVES
	wave_index = 0
	selected_tower = null
	selected_placement_type = &"archer"
	gold_changed.emit(gold)
	lives_changed.emit(lives)
	wave_changed.emit(wave_index)
	tower_selected.emit(null)
	placement_type_changed.emit(selected_placement_type)


func set_placement_type(type_id: StringName) -> void:
	selected_placement_type = type_id
	placement_type_changed.emit(selected_placement_type)


func get_current_placement_cost() -> int:
	return FROST_COST if selected_placement_type == &"frost" else ARCHER_COST


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func try_spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func damage_base(amount: int = 1) -> void:
	if phase == Phase.LOST or phase == Phase.WON:
		return
	lives = maxi(lives - amount, 0)
	lives_changed.emit(lives)
	if lives <= 0:
		phase = Phase.LOST
		run_lost.emit()


func select_tower(tower: Node) -> void:
	selected_tower = tower
	tower_selected.emit(tower)


func notify_feat_completed(tower: Node, feat_id: StringName) -> void:
	feat_completed.emit(tower, feat_id)
	if tower != null and tower.has_method("has_pending_evolution") and tower.has_pending_evolution():
		evolution_available.emit(tower)


func set_wave(index: int) -> void:
	wave_index = index
	wave_changed.emit(wave_index)


func win_run() -> void:
	phase = Phase.WON
	run_won.emit()
