class_name FeatDef
extends Resource

## Static definition of a combat feat a tower can earn.

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var target_value: float = 1.0
@export var grants_evolution_point: bool = true
