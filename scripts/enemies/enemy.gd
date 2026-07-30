extends PathFollow2D

## Enemy unit walking along level path with type variants, slow status, and VFX.

signal died(enemy: Node, killer_tower: Node)
signal leaked(enemy: Node)

enum Type { BASIC, RUNNER, TANK, ELITE }

@export var enemy_type: Type = Type.BASIC
@export var max_hp: float = 40.0
@export var move_speed: float = 80.0
@export var gold_reward: int = 8
@export var is_elite: bool = false

var hp: float = 40.0
var last_hit_tower: Node = null

# Status effects
var slow_factor: float = 1.0
var slow_timer: float = 0.0
var vulnerability_mul: float = 1.0

var _bar_bg: Polygon2D
var _bar_fg: Polygon2D
var _body: Polygon2D
var _glow_ring: Line2D
var _base_color: Color = Color(0.7, 0.35, 0.4)


func _ready() -> void:
	hp = max_hp
	loop = false
	rotates = false
	add_to_group("enemies")
	_apply_type_stats()
	_build_visuals()
	_update_hp_bar()


func setup_type(p_type: Type, hp_mul: float = 1.0, speed_mul: float = 1.0) -> void:
	enemy_type = p_type
	is_elite = (p_type == Type.ELITE)
	_apply_type_stats()
	max_hp *= hp_mul
	move_speed *= speed_mul
	hp = max_hp


func _apply_type_stats() -> void:
	match enemy_type:
		Type.RUNNER:
			max_hp = 22.0
			move_speed = 135.0
			gold_reward = 10
			_base_color = Color(0.9, 0.75, 0.25)
		Type.TANK:
			max_hp = 110.0
			move_speed = 50.0
			gold_reward = 18
			_base_color = Color(0.3, 0.45, 0.65)
		Type.ELITE:
			max_hp = 220.0
			move_speed = 65.0
			gold_reward = 35
			is_elite = true
			_base_color = Color(0.85, 0.25, 0.35)
		_:
			max_hp = 40.0
			move_speed = 80.0
			gold_reward = 8
			_base_color = Color(0.75, 0.35, 0.4)


func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.WAVE:
		return

	# Handle status timers
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
			if _glow_ring:
				_glow_ring.visible = false

	var current_speed := move_speed * slow_factor
	progress += current_speed * delta

	if progress_ratio >= 1.0:
		leaked.emit(self)
		var dmg := 1 if not is_elite else 3
		GameState.damage_base(dmg)
		Camera2D.shake(6.0)
		queue_free()


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = minf(slow_factor, factor)
	slow_timer = maxf(slow_timer, duration)
	if _glow_ring:
		_glow_ring.visible = true
		_glow_ring.default_color = Color(0.4, 0.8, 1.0, 0.7)


func apply_damage(amount: float, source_tower: Node = null) -> void:
	if hp <= 0.0:
		return
	last_hit_tower = source_tower

	var final_damage := amount * vulnerability_mul
	hp -= final_damage

	# Floating damage number
	var is_crit := final_damage > 25.0
	var text_color := Color(0.4, 0.8, 1.0) if slow_timer > 0.0 else (Color(1.0, 0.85, 0.3) if is_crit else Color.WHITE)
	FloatingText.spawn_damage(get_parent(), global_position, final_damage, text_color, is_crit)

	# Hit Flash effect
	_trigger_hit_flash()

	_update_hp_bar()
	if source_tower and source_tower.has_method("register_hit"):
		source_tower.register_hit()

	if hp <= 0.0:
		_die()


func _die() -> void:
	GameState.add_gold(gold_reward)

	# Impact particles on death
	ImpactVFXScene.spawn(get_parent(), global_position, _base_color, 16)

	if is_elite:
		Camera2D.shake(8.0)

	if last_hit_tower and last_hit_tower.has_method("register_kill"):
		last_hit_tower.register_kill(self)
	died.emit(self, last_hit_tower)
	queue_free()


func _trigger_hit_flash() -> void:
	if _body == null:
		return
	_body.modulate = Color(2.5, 2.5, 2.5) # Flash bright
	var tw := create_tween()
	tw.tween_property(_body, "modulate", Color.WHITE, 0.12)


func _build_visuals() -> void:
	_body = Polygon2D.new()
	match enemy_type:
		Type.RUNNER:
			_body.polygon = PackedVector2Array([
				Vector2(12, 0), Vector2(-8, -8), Vector2(-4, 0), Vector2(-8, 8)
			])
		Type.TANK:
			_body.polygon = PackedVector2Array([
				Vector2(0, -14), Vector2(14, -8), Vector2(14, 8), Vector2(0, 14), Vector2(-14, 8), Vector2(-14, -8)
			])
		Type.ELITE:
			_body.polygon = PackedVector2Array([
				Vector2(0, -18), Vector2(16, -6), Vector2(12, 14), Vector2(-12, 14), Vector2(-16, -6)
			])
		_:
			_body.polygon = PackedVector2Array([
				Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
			])
	_body.color = _base_color
	add_child(_body)

	# Slow glow ring
	_glow_ring = Line2D.new()
	_glow_ring.width = 2.0
	_glow_ring.visible = false
	var pts := PackedVector2Array()
	for i in 17:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 16.0)
	_glow_ring.points = pts
	add_child(_glow_ring)

	_bar_bg = Polygon2D.new()
	_bar_bg.polygon = PackedVector2Array([
		Vector2(-14, -22), Vector2(14, -22), Vector2(14, -18), Vector2(-14, -18)
	])
	_bar_bg.color = Color(0.1, 0.1, 0.12, 0.8)
	add_child(_bar_bg)

	_bar_fg = Polygon2D.new()
	_bar_fg.color = Color(0.45, 0.85, 0.4)
	add_child(_bar_fg)


func _update_hp_bar() -> void:
	if _bar_fg == null:
		return
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var w := 28.0 * ratio
	_bar_fg.polygon = PackedVector2Array([
		Vector2(-14, -22), Vector2(-14 + w, -22), Vector2(-14 + w, -18), Vector2(-14, -18)
	])


# Helper reference to impact VFX loader
const ImpactVFXScene = preload("res://scenes/vfx/impact_vfx.tscn")
