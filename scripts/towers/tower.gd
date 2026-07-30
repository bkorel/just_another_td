extends Node2D

## Prototype archer tower: targets, shoots, tracks feats, applies evolutions.

const ProjectileScene := preload("res://scenes/towers/projectile.tscn")

@export var tower_id: StringName = &"archer"
@export var display_name: String = "Archer"
@export var damage: float = 12.0
@export var attack_range: float = 160.0
@export var fire_interval: float = 0.7
@export var projectile_speed: float = 420.0

var feats: FeatTracker
var evolution_options: Array[EvolutionDef] = []
var applied_evolutions: Array[StringName] = []

var _cooldown: float = 0.0
var _kills: int = 0
var _shots_hit: int = 0
var _body: Polygon2D
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
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	_fire_at(target)
	_cooldown = fire_interval


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Used if Area2D child forwards; also handled via pick in level.
	pass


func try_select_at(world_pos: Vector2) -> bool:
	if global_position.distance_to(world_pos) <= 22.0:
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
	if _body:
		_body.color = evo.body_color
	_rebuild_range_visual()
	return true


func register_kill(enemy: Node) -> void:
	_kills += 1
	feats.add_progress(&"kills_10", 1.0)
	feats.add_progress(&"kills_25", 1.0)
	if enemy and enemy.get("is_elite"):
		feats.add_progress(&"elite_executions", 1.0)
	# Lane/wave share is updated by WaveManager / Level via report_wave_share.


func register_hit() -> void:
	_shots_hit += 1
	feats.add_progress(&"hits_20", 1.0)


func report_wave_kill_share(share: float) -> void:
	# share 0..1 among towers that scored kills this wave
	if share >= 0.35:
		feats.add_progress(&"wave_dominance", 1.0)


func _on_feat_unlocked(feat_id: StringName) -> void:
	GameState.notify_feat_completed(self, feat_id)


func _fire_at(target: Node2D) -> void:
	if _body:
		var tw := create_tween()
		_body.scale = Vector2(1.2, 0.8)
		tw.tween_property(_body, "scale", Vector2.ONE, 0.2)

	var proj: Node2D = ProjectileScene.instantiate()
	proj.global_position = global_position
	proj.setup(target, damage, projectile_speed, self)
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
	list.append(_feat(&"kills_10", "First Bloodbath", "Score 10 kills.", 10))
	list.append(_feat(&"kills_25", "Veteran", "Score 25 kills.", 25))
	list.append(_feat(&"hits_20", "Steady Hand", "Land 20 hits.", 20))
	list.append(_feat(&"wave_dominance", "Wave Claim", "Get ≥35% of tower kills in a wave.", 1))
	list.append(_feat(&"elite_executions", "Executioner", "Finish 2 elites/bosses.", 2))
	return list


func _default_evolutions() -> Array[EvolutionDef]:
	var a := EvolutionDef.new()
	a.id = &"marksman"
	a.title = "Marksman"
	a.description = "+40% damage, slightly less range."
	a.damage_mul = 1.4
	a.range_mul = 0.9
	a.fire_rate_mul = 1.0
	a.body_color = Color(0.55, 0.35, 0.25)
	a.projectile_color = Color(1.0, 0.75, 0.35)

	var b := EvolutionDef.new()
	b.id = &"ballista"
	b.title = "Ballista"
	b.description = "Slower shots, much higher damage."
	b.damage_mul = 2.0
	b.range_mul = 1.1
	b.fire_rate_mul = 0.65
	b.body_color = Color(0.3, 0.32, 0.45)
	b.projectile_color = Color(0.7, 0.8, 1.0)

	var c := EvolutionDef.new()
	c.id = &"scouts_eye"
	c.title = "Scout's Eye"
	c.description = "Faster attacks, wider range."
	c.damage_mul = 0.9
	c.range_mul = 1.25
	c.fire_rate_mul = 1.35
	c.body_color = Color(0.25, 0.5, 0.45)
	c.projectile_color = Color(0.55, 1.0, 0.75)

	return [a, b, c]


func _feat(id: StringName, title: String, desc: String, target: float) -> FeatDef:
	var f := FeatDef.new()
	f.id = id
	f.title = title
	f.description = desc
	f.target_value = target
	return f


func _build_visuals() -> void:
	# Unmistakable marker (Sprite2D) — Polygon2D alone was easy to miss under the ghost.
	var img := Image.create(36, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.85, 0.1, 1.0))
	for x in 36:
		img.set_pixel(x, 0, Color.BLACK)
		img.set_pixel(x, 35, Color.BLACK)
		img.set_pixel(0, x, Color.BLACK)
		img.set_pixel(35, x, Color.BLACK)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.z_index = 100
	add_child(sprite)

	_body = Polygon2D.new()
	_body.polygon = PackedVector2Array([
		Vector2(0, -22), Vector2(18, 12), Vector2(0, 6), Vector2(-18, 12)
	])
	_body.color = Color(1.0, 0.75, 0.15)
	_body.z_index = 101
	add_child(_body)

	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)
	])
	core.color = Color(1.0, 1.0, 0.5)
	core.z_index = 102
	add_child(core)

	_range_visual = Line2D.new()
	_range_visual.width = 2.0
	_range_visual.default_color = Color(1.0, 0.9, 0.3, 0.55)
	_range_visual.visible = false
	_range_visual.z_index = 99
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
