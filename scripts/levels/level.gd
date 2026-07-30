extends Node2D

## Level controller: placement, selection, wires wave manager + HUD.

const TowerScene := preload("res://scenes/towers/tower.tscn")

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
	_update_ghost()


func _process(_delta: float) -> void:
	if _placing and GameState.phase == GameState.Phase.BUILD:
		placement_ghost.visible = true
		placement_ghost.global_position = get_global_mouse_position()
		placement_ghost.color = Color(0.4, 0.8, 0.5, 0.35) if _can_place_at(placement_ghost.global_position) else Color(0.9, 0.3, 0.3, 0.35)
	else:
		placement_ghost.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if GameState.phase == GameState.Phase.EVOLUTION_PICK:
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_global_mouse_position()
		if _try_select_tower(pos):
			get_viewport().set_input_as_handled()
			return
		if GameState.phase == GameState.Phase.BUILD and _try_place_tower(pos):
			get_viewport().set_input_as_handled()


func _try_place_tower(pos: Vector2) -> bool:
	if not _can_place_at(pos):
		return false
	if not GameState.try_spend_gold(GameState.TOWER_COST):
		return false
	var tower: Node2D = TowerScene.instantiate()
	tower.global_position = pos
	$Towers.add_child(tower)
	tower.clicked.connect(func(t): _select_tower(t))
	return true


func _can_place_at(pos: Vector2) -> bool:
	# Keep off the path corridor and away from other towers.
	if path == null or path.curve == null:
		return false
	var baked := path.curve.get_baked_points()
	for p in baked:
		if pos.distance_to(path.to_global(p)) < 42.0:
			return false
	for tower in get_tree().get_nodes_in_group("towers"):
		if pos.distance_to(tower.global_position) < 40.0:
			return false
	# Playable field margins
	if pos.x < 40 or pos.x > 1240 or pos.y < 40 or pos.y > 680:
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


func _update_ghost() -> void:
	placement_ghost.polygon = PackedVector2Array([
		Vector2(0, -18), Vector2(16, 10), Vector2(0, 6), Vector2(-16, 10)
	])
