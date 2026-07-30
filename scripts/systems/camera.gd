extends Camera2D

## Camera with smooth screen shake support.

static var instance: Camera2D = null

var _shake_amount: float = 0.0
var _shake_decay: float = 5.0


func _ready() -> void:
	instance = self


func _process(delta: float) -> void:
	if _shake_amount > 0.0:
		_shake_amount = maxf(_shake_amount - _shake_decay * delta, 0.0)
		offset = Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount)
		)
	else:
		offset = Vector2.ZERO


static func shake(amount: float = 8.0) -> void:
	if instance != null:
		instance._shake_amount = maxf(instance._shake_amount, amount)
