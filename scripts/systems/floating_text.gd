extends Node2D

## Floating text for damage numbers and notifications.

@onready var label: Label = $Label


static func spawn_damage(parent: Node, pos: Vector2, amount: float, color: Color = Color.WHITE, is_crit: bool = false) -> void:
	var scene := preload("res://scenes/vfx/floating_text.tscn")
	var node: Node2D = scene.instantiate()
	node.global_position = pos + Vector2(randf_range(-8, 8), randf_range(-8, 0))
	parent.add_child(node)
	node.setup_damage(amount, color, is_crit)


static func spawn_notice(parent: Node, pos: Vector2, text: String, color: Color = Color(1.0, 0.85, 0.3)) -> void:
	var scene := preload("res://scenes/vfx/floating_text.tscn")
	var node: Node2D = scene.instantiate()
	node.global_position = pos
	parent.add_child(node)
	node.setup_notice(text, color)


func setup_damage(amount: float, color: Color, is_crit: bool) -> void:
	if label == null:
		await ready
	label.text = str(roundi(amount))
	label.modulate = color
	if is_crit:
		label.text += "!"
		label.scale = Vector2(1.4, 1.4)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 35.0, 0.65).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, 0.65).set_delay(0.2)
	tween.chain().tween_callback(queue_free)


func setup_notice(text: String, color: Color) -> void:
	if label == null:
		await ready
	label.text = text
	label.modulate = color
	label.scale = Vector2(1.2, 1.2)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 45.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tween.chain().tween_callback(queue_free)
