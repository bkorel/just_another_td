extends Camera2D

## Camera with smooth screen shake support.

var _shake_amount: float = 0.0
var _shake_decay: float = 5.0


func _ready() -> void:
	GameState.main_camera = self


func add_shake(amount: float = 8.0) -> void:
	_shake_amount = maxf(_shake_amount, amount)


func _process(delta: float) -> void:
	if _shake_amount > 0.0:
		_shake_amount = maxf(_shake_amount - _shake_decay * delta, 0.0)
		offset = Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount)
		)
	else:
		offset = Vector2.ZERO
