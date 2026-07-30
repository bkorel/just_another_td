extends Node

## Spawns composition-based waves along Path2D and tracks per-tower feat statistics.

signal wave_started(index: int)
signal wave_cleared(index: int)
signal all_waves_cleared

const EnemyScene := preload("res://scenes/enemies/enemy.tscn")

@export var enemy_path: Path2D
@export var max_waves: int = 8

var _spawning: bool = false
var _alive: int = 0
var _wave_kills: Dictionary = {} # tower instance_id -> count


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
	var count := 6 + index * 2
	var hp_scale := 1.0 + (index - 1) * 0.28
	var speed_scale := 1.0 + (index - 1) * 0.05

	for i in count:
		await get_tree().create_timer(0.42).timeout
		if GameState.phase == GameState.Phase.LOST:
			_spawning = false
			return

		var e_type := _select_type_for_wave(index, i, count)
		_spawn_enemy_type(e_type, hp_scale, speed_scale)

	_spawning = false
	_check_wave_end()


func _select_type_for_wave(wave_idx: int, enemy_idx: int, total_count: int) -> int:
	# Enemy.Type enum: 0=BASIC, 1=RUNNER, 2=TANK, 3=ELITE
	if enemy_idx == total_count - 1 and (wave_idx % 2 == 0 or wave_idx == max_waves):
		return 3 # ELITE at wave end

	if wave_idx <= 2:
		return 0 # BASIC
	elif wave_idx <= 4:
		return 1 if enemy_idx % 2 == 1 else 0 # BASIC + RUNNER
	elif wave_idx <= 6:
		if enemy_idx % 3 == 0:
			return 2 # TANK
		elif enemy_idx % 3 == 1:
			return 1 # RUNNER
		return 0 # BASIC
	else:
		# Late waves: mixed heavy
		return enemy_idx % 3


func _spawn_enemy_type(type_id: int, hp_scale: float, speed_scale: float) -> void:
	if enemy_path == null:
		return
	var enemy: PathFollow2D = EnemyScene.instantiate()
	enemy_path.add_child(enemy)
	enemy.setup_type(type_id, hp_scale, speed_scale)
	_alive += 1
	enemy.died.connect(func(e, killer): notify_enemy_died(e, killer))
	enemy.leaked.connect(func(e): notify_enemy_leaked(e))
