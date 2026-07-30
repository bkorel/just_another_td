extends PathFollow2D

## Enemy walks along the level Path2D. Leaks damage the base.

signal died(enemy: Node, killer_tower: Node)
signal leaked(enemy: Node)

@export var max_hp: float = 40.0
@export var move_speed: float = 80.0
@export var gold_reward: int = 8
@export var is_elite: bool = false

var hp: float = 40.0
var last_hit_tower: Node = null

var _bar_bg: Polygon2D
var _bar_fg: Polygon2D
var _body: Polygon2D


func _ready() -> void:
	hp = max_hp
	loop = false
	rotates = false
	add_to_group("enemies")
	_build_visuals()
	_update_hp_bar()


func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.WAVE:
		return
	progress += move_speed * delta
	if progress_ratio >= 1.0:
		leaked.emit(self)
		GameState.damage_base(1 if not is_elite else 2)
		queue_free()


func apply_damage(amount: float, source_tower: Node = null) -> void:
	if hp <= 0.0:
		return
	last_hit_tower = source_tower
	hp -= amount
	_update_hp_bar()
	if source_tower and source_tower.has_method("register_hit"):
		source_tower.register_hit()
	if hp <= 0.0:
		_die()


func _die() -> void:
	GameState.add_gold(gold_reward)
	if last_hit_tower and last_hit_tower.has_method("register_kill"):
		last_hit_tower.register_kill(self)
	died.emit(self, last_hit_tower)
	queue_free()


func _build_visuals() -> void:
	_body = Polygon2D.new()
	if is_elite:
		_body.polygon = PackedVector2Array([
			Vector2(0, -16), Vector2(14, -4), Vector2(10, 14), Vector2(-10, 14), Vector2(-14, -4)
		])
		_body.color = Color(0.75, 0.25, 0.35)
	else:
		_body.polygon = PackedVector2Array([
			Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
		])
		_body.color = Color(0.7, 0.35, 0.4)
	add_child(_body)

	_bar_bg = Polygon2D.new()
	_bar_bg.polygon = PackedVector2Array([
		Vector2(-12, -20), Vector2(12, -20), Vector2(12, -16), Vector2(-12, -16)
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
	var w := 24.0 * ratio
	_bar_fg.polygon = PackedVector2Array([
		Vector2(-12, -20), Vector2(-12 + w, -20), Vector2(-12 + w, -16), Vector2(-12, -16)
	])
