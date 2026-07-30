extends Node2D

## Homing-ish projectile with trailing visual effects, impact particles, and status application.

const ImpactVFXScene = preload("res://scenes/vfx/impact_vfx.tscn")

var target: Node2D
var damage: float = 10.0
var speed: float = 400.0
var source_tower: Node = null
var is_frost: bool = false
var slow_factor: float = 0.5
var slow_duration: float = 2.5
var _color: Color = Color(1.2, 0.95, 0.45) # HDR brightness for glow!

var _trail: Line2D
var _max_trail_points: int = 8


func setup(p_target: Node2D, p_damage: float, p_speed: float, p_source: Node, p_is_frost: bool = false) -> void:
	target = p_target
	damage = p_damage
	speed = p_speed
	source_tower = p_source
	is_frost = p_is_frost

	if is_frost:
		_color = Color(0.4, 0.9, 1.5) # Cyan glow
	elif source_tower and "applied_evolutions" in source_tower and source_tower.applied_evolutions.size() > 0:
		if "ballista" in source_tower.applied_evolutions:
			_color = Color(1.8, 0.6, 0.2) # Intense orange/red
		elif "marksman" in source_tower.applied_evolutions:
			_color = Color(1.5, 1.2, 0.3) # Bright yellow/gold
		elif "scouts_eye" in source_tower.applied_evolutions:
			_color = Color(0.4, 1.4, 0.8) # Emerald glow


func _ready() -> void:
	_build_visuals()


func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		_explode_and_free()
		return

	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var step := speed * delta

	_update_trail()

	if dist <= step or dist < 8.0:
		_hit_target()
		return

	global_position += to_target.normalized() * step
	rotation = to_target.angle()


func _hit_target() -> void:
	if is_instance_valid(target):
		if is_frost and target.has_method("apply_slow"):
			target.apply_slow(slow_factor, slow_duration)

		if target.has_method("apply_damage"):
			target.apply_damage(damage, source_tower)

		ImpactVFXScene.spawn(get_parent(), global_position, _color, 12)

		if damage > 25.0:
			Camera2D.shake(3.0)

	queue_free()


func _explode_and_free() -> void:
	ImpactVFXScene.spawn(get_parent(), global_position, _color * 0.7, 6)
	queue_free()


func _update_trail() -> void:
	if _trail == null:
		return
	_trail.add_point(global_position)
	if _trail.get_point_count() > _max_trail_points:
		_trail.remove_point(0)


func _build_visuals() -> void:
	# Top level trail in world space
	_trail = Line2D.new()
	_trail.width = 3.5
	_trail.default_color = _color
	_trail.top_level = true
	add_child(_trail)

	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0, -4), Vector2(10, 0), Vector2(0, 4), Vector2(-4, 0)
	])
	poly.color = _color
	add_child(poly)
