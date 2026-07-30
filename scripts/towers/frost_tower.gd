extends Node2D

## Frost Tower: shoots ice crystals that slow enemies and boost support synergy.

const ProjectileScene := preload("res://scenes/towers/projectile.tscn")

@export var tower_id: StringName = &"frost"
@export var display_name: String = "Frost Tower"
@export var damage: float = 8.0
@export var attack_range: float = 145.0
@export var fire_interval: float = 0.9
@export var projectile_speed: float = 380.0
@export var slow_factor: float = 0.5 # 50% speed
@export var slow_duration: float = 2.5

var feats: FeatTracker
var evolution_options: Array[EvolutionDef] = []
var applied_evolutions: Array[StringName] = []

var _cooldown: float = 0.0
var _kills: int = 0
var _shots_hit: int = 0
var _slows_applied: int = 0
var _body: Polygon2D
var _crystal: Polygon2D
var _range_visual: Line2D
var _selected: bool = false

signal clicked(tower: Node2D)


func _ready() -> void:
	_build_visuals()
	feats = FeatTracker.new()
	feats.setup(_default_feats())
	evolution_options = _default_evolutions()
	feats.feat_unlocked.connect(_on_feat_unlocked)
	add_to_group("towers")


func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.WAVE and GameState.phase != GameState.Phase.BUILD:
		return

	# Idle crystal rotation for juice
	if _crystal:
		_crystal.rotation += delta * 1.5

	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0:
		return

	var target := _find_target()
	if target == null:
		return

	_fire_at(target)
	_cooldown = fire_interval


func try_select_at(world_pos: Vector2) -> bool:
	if global_position.distance_to(world_pos) <= 24.0:
		set_selected(true)
		clicked.emit(self)
		return true
	return false


func set_selected(value: bool) -> void:
	_selected = value
	if _range_visual:
		_range_visual.visible = value


func has_pending_evolution() -> bool:
	return feats != null and feats.has_pending_evolution()


func get_feat_snapshot() -> Array[Dictionary]:
	return feats.get_snapshot() if feats else []


func apply_evolution(evo: EvolutionDef) -> bool:
	if evo == null or not feats.consume_evolution_point():
		return false

	damage *= evo.damage_mul
	attack_range *= evo.range_mul
	fire_interval = maxf(0.15, fire_interval / evo.fire_rate_mul)
	applied_evolutions.append(evo.id)

	if evo.id == &"glacier":
		slow_factor = 0.3 # 70% slow!
		slow_duration = 3.5
	elif evo.id == &"frostbite":
		damage *= 1.25

	if _crystal:
		_crystal.color = evo.body_color

	_rebuild_range_visual()
	return true


func register_kill(enemy: Node) -> void:
	_kills += 1
	feats.add_progress(&"kills_10", 1.0)
	if enemy and enemy.get("slow_timer") > 0.0:
		feats.add_progress(&"shatter_kills", 1.0)


func register_hit() -> void:
	_shots_hit += 1
	_slows_applied += 1
	feats.add_progress(&"slows_15", 1.0)
	feats.add_progress(&"slows_35", 1.0)


func report_wave_kill_share(share: float) -> void:
	if share >= 0.30:
		feats.add_progress(&"wave_dominance", 1.0)


func _on_feat_unlocked(feat_id: StringName) -> void:
	GameState.notify_feat_completed(self, feat_id)


func _fire_at(target: Node2D) -> void:
	# Recoil animation
	if _crystal:
		var tw := create_tween()
		_crystal.scale = Vector2(1.3, 0.7)
		tw.tween_property(_crystal, "scale", Vector2.ONE, 0.25)

	var proj: Node2D = ProjectileScene.instantiate()
	proj.global_position = global_position
	proj.slow_factor = slow_factor
	proj.slow_duration = slow_duration
	proj.setup(target, damage, projectile_speed, self, true) # true = is_frost
	get_tree().current_scene.add_child(proj)


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_progress := -1.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if global_position.distance_to(enemy.global_position) > attack_range:
			continue
		var prog: float = 0.0
		if enemy is PathFollow2D:
			prog = (enemy as PathFollow2D).progress
		if prog > best_progress:
			best_progress = prog
			best = enemy
	return best


func _default_feats() -> Array[FeatDef]:
	var list: Array[FeatDef] = []
	list.append(_feat(&"slows_15", "Frostbite Touch", "Slow 15 enemies.", 15))
	list.append(_feat(&"slows_35", "Deep Freeze", "Slow 35 enemies.", 35))
	list.append(_feat(&"shatter_kills", "Shatter Execution", "Kill 8 chilled targets.", 8))
	list.append(_feat(&"wave_dominance", "Frost Dominance", "Score ≥30% kills in a wave.", 1))
	return list


func _default_evolutions() -> Array[EvolutionDef]:
	var a := EvolutionDef.new()
	a.id = &"glacier"
	a.title = "Glacier"
	a.description = "70% heavy slow + 3.5s freeze duration."
	a.damage_mul = 1.2
	a.range_mul = 1.1
	a.fire_rate_mul = 0.9
	a.body_color = Color(0.2, 0.8, 1.2) # Cyan glow

	var b := EvolutionDef.new()
	b.id = &"frostbite"
	b.title = "Frostbite"
	b.description = "High ice shard damage & faster fire rate."
	b.damage_mul = 1.75
	b.range_mul = 1.0
	b.fire_rate_mul = 1.3
	b.body_color = Color(0.6, 0.4, 1.2) # Deep purple ice

	var c := EvolutionDef.new()
	c.id = &"blizzard"
	c.title = "Blizzard"
	c.description = "Wider attack range & faster projectile speed."
	c.damage_mul = 1.1
	c.range_mul = 1.35
	c.fire_rate_mul = 1.4
	c.body_color = Color(0.8, 1.0, 1.5) # Bright white/cyan

	return [a, b, c]


func _feat(id: StringName, title: String, desc: String, target: float) -> FeatDef:
	var f := FeatDef.new()
	f.id = id
	f.title = title
	f.description = desc
	f.target_value = target
	return f


func _build_visuals() -> void:
	_body = Polygon2D.new()
	_body.polygon = PackedVector2Array([
		Vector2(-16, 16), Vector2(16, 16), Vector2(12, -10), Vector2(-12, -10)
	])
	_body.color = Color(0.25, 0.45, 0.75)
	_body.z_index = 5
	add_child(_body)

	var outline := Line2D.new()
	outline.width = 2.5
	outline.default_color = Color(0.05, 0.05, 0.05, 1)
	outline.points = PackedVector2Array([
		Vector2(-16, 16), Vector2(16, 16), Vector2(12, -10), Vector2(-12, -10), Vector2(-16, 16)
	])
	outline.z_index = 6
	add_child(outline)

	_crystal = Polygon2D.new()
	_crystal.polygon = PackedVector2Array([
		Vector2(0, -18), Vector2(10, -2), Vector2(0, 10), Vector2(-10, -2)
	])
	_crystal.color = Color(0.55, 1.2, 1.5)
	_crystal.z_index = 7
	add_child(_crystal)

	_range_visual = Line2D.new()
	_range_visual.width = 2.0
	_range_visual.default_color = Color(0.4, 0.9, 1.2, 0.55)
	_range_visual.visible = false
	_range_visual.z_index = 4
	add_child(_range_visual)
	_rebuild_range_visual()


func _rebuild_range_visual() -> void:
	if _range_visual == null:
		return
	var pts := PackedVector2Array()
	var steps := 48
	for i in steps + 1:
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * attack_range)
	_range_visual.points = pts
