class_name EvolutionDef
extends Resource

## One evolution branch option unlocked by spending an evolution point.

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var damage_mul: float = 1.0
@export var range_mul: float = 1.0
@export var fire_rate_mul: float = 1.0
@export var projectile_color: Color = Color(0.9, 0.85, 0.4)
@export var body_color: Color = Color(0.35, 0.55, 0.4)
