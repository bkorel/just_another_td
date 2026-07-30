extends Node2D

## Level controller: placement, selection, wires wave manager + HUD.

const ArcherTowerScene := preload("res://scenes/towers/tower.tscn")
const FrostTowerScene := preload("res://scenes/towers/frost_tower.tscn")

@onready var path: Path2D = $EnemyPath
@onready var wave_manager: Node = $WaveManager
@onready var hud: CanvasLayer = $HUD
@onready var placement_ghost: Polygon2D = $PlacementGhost
@onready var ground: Polygon2D = $Ground

var _placing: bool = true


func _ready() -> void:
	wave_manager.enemy_path = path
	hud.bind_level(self)
	GameState.reset_run()
	GameState.evolution_available.connect(_on_evolution_available)
	GameState.placement_type_changed.connect(_on_placement_type_changed)
	_update_ghost()
	_spawn_ambient_particles()


func _process(_delta: float) -> void:
	var can_build := (GameState.phase == GameState.Phase.BUILD or GameState.phase == GameState.Phase.WAVE)
	if _placing and can_build:
		placement_ghost.visible = true
		placement_ghost.global_position = get_global_mouse_position()
		var valid := _can_place_at(placement_ghost.global_position)
		if GameState.selected_placement_type == &"frost":
			placement_ghost.color = Color(0.3, 0.8, 1.2, 0.45) if valid else Color(0.9, 0.3, 0.3, 0.35)
		else:
			placement_ghost.color = Color(0.4, 0.8, 0.5, 0.45) if valid else Color(0.9, 0.3, 0.3, 0.35)
	else:
		placement_ghost.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if GameState.phase == GameState.Phase.EVOLUTION_PICK or GameState.phase == GameState.Phase.WON or GameState.phase == GameState.Phase.LOST:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			wave_manager.start_next_wave()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			GameState.select_tower(null)
			_clear_tower_selection()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_1:
			GameState.set_placement_type(&"archer")
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_2:
			GameState.set_placement_type(&"frost")
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_global_mouse_position()
		if _try_select_tower(pos):
			get_viewport().set_input_as_handled()
			return

		var can_build := (GameState.phase == GameState.Phase.BUILD or GameState.phase == GameState.Phase.WAVE)
		if can_build and _try_place_tower(pos):
			get_viewport().set_input_as_handled()


func _try_place_tower(pos: Vector2) -> bool:
	if not _can_place_at(pos):
		return false
	var cost := GameState.get_current_placement_cost()
	if not GameState.try_spend_gold(cost):
		return false

	var scene := FrostTowerScene if GameState.selected_placement_type == &"frost" else ArcherTowerScene
	var tower: Node2D = scene.instantiate()
	tower.global_position = pos
	$Towers.add_child(tower)
	tower.clicked.connect(func(t): _select_tower(t))
	return true


func _can_place_at(pos: Vector2) -> bool:
	if path == null or path.curve == null:
		return false

	# Keep off path
	var baked := path.curve.get_baked_points()
	var step_size := 3
	for i in range(0, baked.size(), step_size):
		if pos.distance_to(path.to_global(baked[i])) < 38.0:
			return false

	# Keep away from existing towers
	for tower in get_tree().get_nodes_in_group("towers"):
		if pos.distance_to(tower.global_position) < 36.0:
			return false

	# Field boundaries
	if pos.x < 30 or pos.x > 1250 or pos.y < 30 or pos.y > 690:
		return false

	return true


func _try_select_tower(pos: Vector2) -> bool:
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower.has_method("try_select_at") and tower.try_select_at(pos):
			_select_tower(tower)
			return true
	GameState.select_tower(null)
	_clear_tower_selection()
	return false


func _select_tower(tower: Node) -> void:
	_clear_tower_selection()
	if tower and tower.has_method("set_selected"):
		tower.set_selected(true)
	GameState.select_tower(tower)
	hud.show_tower(tower)


func _clear_tower_selection() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower.has_method("set_selected"):
			tower.set_selected(false)
	hud.show_tower(null)


func _on_evolution_available(tower: Node) -> void:
	_select_tower(tower)
	hud.open_evolution_modal(tower)


func _on_placement_type_changed(_type_id: StringName) -> void:
	_update_ghost()


func _update_ghost() -> void:
	if GameState.selected_placement_type == &"frost":
		placement_ghost.polygon = PackedVector2Array([
			Vector2(0, -16), Vector2(10, 0), Vector2(0, 12), Vector2(-10, 0)
		])
	else:
		placement_ghost.polygon = PackedVector2Array([
			Vector2(0, -18), Vector2(16, 10), Vector2(0, 6), Vector2(-16, 10)
		])


func _spawn_ambient_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.amount = 32
	particles.lifetime = 6.0
	particles.preprocess = 6.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(640, 360)
	particles.position = Vector2(640, 360)
	particles.gravity = Vector2(-5, -8)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5
	particles.color = Color(0.4, 0.8, 0.6, 0.25)
	add_child(particles)
