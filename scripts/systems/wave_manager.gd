extends Node

## Spawns waves along a Path2D and tracks per-tower kill shares for feats.

signal wave_started(index: int)
signal wave_cleared(index: int)
signal all_waves_cleared

const EnemyScene := preload("res://scenes/enemies/enemy.tscn")

@export var enemy_path: Path2D
@export var max_waves: int = 8

var _spawning: bool = false
var _alive: int = 0
var _wave_kills: Dictionary = {} # tower instance_id -> count
var _pending_start: bool = false


func _ready() -> void:
	pass


func can_start_wave() -> bool:
	return not _spawning and _alive == 0 and GameState.phase == GameState.Phase.BUILD and GameState.wave_index < max_waves


func start_next_wave() -> void:
	if not can_start_wave():
		return
	GameState.phase = GameState.Phase.WAVE
	GameState.set_wave(GameState.wave_index + 1)
	_wave_kills.clear()
	wave_started.emit(GameState.wave_index)
	_spawn_wave(GameState.wave_index)


func notify_enemy_died(enemy: Node, killer_tower: Node) -> void:
	_alive = maxi(_alive - 1, 0)
	if killer_tower != null:
		var id := killer_tower.get_instance_id()
		_wave_kills[id] = int(_wave_kills.get(id, 0)) + 1
	_check_wave_end()


func notify_enemy_leaked(enemy: Node) -> void:
	_alive = maxi(_alive - 1, 0)
	_check_wave_end()


func _check_wave_end() -> void:
	if _spawning or _alive > 0:
		return
	_award_wave_dominance()
	wave_cleared.emit(GameState.wave_index)
	if GameState.wave_index >= max_waves:
		GameState.win_run()
		all_waves_cleared.emit()
	else:
		GameState.phase = GameState.Phase.BUILD


func _award_wave_dominance() -> void:
	var total := 0
	for v in _wave_kills.values():
		total += int(v)
	if total <= 0:
		return
	for tower in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower):
			continue
		var kills := int(_wave_kills.get(tower.get_instance_id(), 0))
		var share := float(kills) / float(total)
		if tower.has_method("report_wave_kill_share"):
			tower.report_wave_kill_share(share)


func _spawn_wave(index: int) -> void:
	_spawning = true
	var count := 5 + index * 2
	var hp := 35.0 + index * 12.0
	var speed := 70.0 + index * 4.0
	for i in count:
		await get_tree().create_timer(0.45).timeout
		if GameState.phase == GameState.Phase.LOST:
			_spawning = false
			return
		var is_elite := (i == count - 1 and index % 3 == 0)
		_spawn_enemy(hp * (2.2 if is_elite else 1.0), speed * (0.85 if is_elite else 1.0), is_elite, 10 + index if not is_elite else 25 + index * 2)
	_spawning = false
	_check_wave_end()


func _spawn_enemy(hp: float, speed: float, elite: bool, gold: int) -> void:
	if enemy_path == null:
		return
	var enemy: PathFollow2D = EnemyScene.instantiate()
	enemy.max_hp = hp
	enemy.move_speed = speed
	enemy.is_elite = elite
	enemy.gold_reward = gold
	enemy_path.add_child(enemy)
	_alive += 1
	enemy.died.connect(func(e, killer): notify_enemy_died(e, killer))
	enemy.leaked.connect(func(e): notify_enemy_leaked(e))
