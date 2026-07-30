extends Node2D

## Homing-ish projectile that damages a locked enemy.

var target: Node2D
var damage: float = 10.0
var speed: float = 400.0
var source_tower: Node = null
var _color: Color = Color(0.95, 0.9, 0.45)


func setup(p_target: Node2D, p_damage: float, p_speed: float, p_source: Node) -> void:
	target = p_target
	damage = p_damage
	speed = p_speed
	source_tower = p_source
	if source_tower and "applied_evolutions" in source_tower and source_tower.applied_evolutions.size() > 0:
		# Tint by last evolution if available via options colors — keep simple yellow otherwise.
		_color = Color(1.0, 0.7, 0.35)


func _ready() -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0, -4), Vector2(8, 0), Vector2(0, 4), Vector2(-4, 0)
	])
	poly.color = _color
	add_child(poly)


func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		queue_free()
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var step := speed * delta
	if dist <= step or dist < 6.0:
		if target.has_method("apply_damage"):
			target.apply_damage(damage, source_tower)
		queue_free()
		return
	global_position += to_target.normalized() * step
	rotation = to_target.angle()
