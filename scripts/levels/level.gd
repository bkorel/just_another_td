extends Node2D

## Level controller: placement, selection, waves, HUD wiring.
##
## Input rules:
## - Map LMB is handled by HUD Root `_gui_input` (full-screen Control catcher).
## - Keyboard shortcuts live in `_unhandled_input` (Space / B / 1 / 2 / Esc).
## - Never poll mouse buttons in `_process`.

const ArcherTowerScene := preload("res://scenes/towers/tower.tscn")
const FrostTowerScene := preload("res://scenes/towers/frost_tower.tscn")
const PATH_CLEARANCE := 36.0
const TOWER_SPACING := 36.0

@onready var path: Path2D = $EnemyPath
@onready var wave_manager: Node = $WaveManager
@onready var hud: CanvasLayer = $HUD
@onready var placement_ghost: Polygon2D = $PlacementGhost
@onready var towers_root: Node2D = $Towers
@onready var camera: Camera2D = $MainCamera

var _placing: bool = true
var _hide_ghost_until_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if camera:
		camera.make_current()
	placement_ghost.z_index = 1
	wave_manager.enemy_path = path
	hud.bind_level(self)
	GameState.reset_run()
	GameState.evolution_available.connect(_on_evolution_available)
	GameState.placement_type_changed.connect(_on_placement_type_changed)
	_update_ghost()
	_spawn_ambient_particles()
	call_deferred("_spawn_boot_tower")
	hud.show_status("Space=wave, B=build at cursor, LMB on map=build/select")


func _spawn_boot_tower() -> void:
	var boot_pos := Vector2(400, 90)
	if can_place_at(boot_pos) and GameState.gold >= GameState.ARCHER_COST:
		GameState.set_placement_type(&"archer")
		try_place_tower(boot_pos)
		_deselect()
		hud.show_status("Boot tower at (400,90). Press Space to start wave, or B to build.")


func _process(_delta: float) -> void:
	var can_build := _can_build_now()
	var now_ms := Time.get_ticks_msec()
	var show_ghost := _placing and can_build and now_ms >= _hide_ghost_until_ms
	if show_ghost:
		placement_ghost.visible = true
		placement_ghost.global_position = get_global_mouse_position()
		var valid := can_place_at(placement_ghost.global_position)
		if GameState.selected_placement_type == &"frost":
			placement_ghost.color = Color(0.3, 0.8, 1.2, 0.35) if valid else Color(0.9, 0.3, 0.3, 0.35)
		else:
			placement_ghost.color = Color(0.4, 0.9, 0.5, 0.35) if valid else Color(0.9, 0.3, 0.3, 0.35)
	else:
		placement_ghost.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if GameState.phase == GameState.Phase.WON or GameState.phase == GameState.Phase.LOST:
		return

	# Keyboard only here. Map LMB is handled by HUD Root `_gui_input`
	# so it never fights the Control system.
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				hud.request_start_wave()
				get_viewport().set_input_as_handled()
				return
			KEY_ESCAPE:
				if GameState.phase != GameState.Phase.EVOLUTION_PICK:
					_deselect()
				get_viewport().set_input_as_handled()
				return
			KEY_1:
				GameState.set_placement_type(&"archer")
				hud.show_status("Selected Archer. Press B or click map.")
				get_viewport().set_input_as_handled()
				return
			KEY_2:
				GameState.set_placement_type(&"frost")
				hud.show_status("Selected Frost. Press B or click map.")
				get_viewport().set_input_as_handled()
				return
			KEY_B:
				if GameState.phase != GameState.Phase.EVOLUTION_PICK:
					try_place_tower(get_global_mouse_position())
				get_viewport().set_input_as_handled()
				return


func handle_map_click(world_pos: Vector2) -> void:
	if GameState.phase == GameState.Phase.EVOLUTION_PICK or GameState.phase == GameState.Phase.WON or GameState.phase == GameState.Phase.LOST:
		hud.show_status("Cannot build: game is not active.")
		return

	if _try_select_tower(world_pos):
		return

	if not _can_build_now():
		hud.show_status("Cannot build right now (phase: %s)." % str(GameState.phase))
		return

	try_place_tower(world_pos)


func try_place_tower(pos: Vector2) -> bool:
	var cost := GameState.get_current_placement_cost()
	if GameState.gold < cost:
		hud.show_status("Need $%d (have $%d)." % [cost, GameState.gold])
		return false

	if not can_place_at(pos):
		hud.show_status("Invalid spot (%.0f, %.0f) — move off the road." % [pos.x, pos.y])
		return false

	var scene: PackedScene = FrostTowerScene if GameState.selected_placement_type == &"frost" else ArcherTowerScene
	var tower: Node2D = scene.instantiate()
	if tower == null:
		hud.show_status("ERROR: failed to instantiate tower scene.")
		return false

	if not GameState.try_spend_gold(cost):
		tower.free()
		return false

	towers_root.add_child(tower)
	tower.z_index = 50
	tower.global_position = pos
	if tower.has_signal("clicked"):
		tower.clicked.connect(_select_tower)

	placement_ghost.visible = false
	_hide_ghost_until_ms = Time.get_ticks_msec() + 400

	var tower_name: String = str(tower.get("display_name")) if "display_name" in tower else "Tower"
	var count := get_tree().get_nodes_in_group("towers").size()
	hud.show_status("Built %s! Towers: %d. Gold: %d" % [tower_name, count, GameState.gold])
	_select_tower(tower)
	return true


func can_place_at(pos: Vector2) -> bool:
	if pos.x < 24.0 or pos.x > 1256.0 or pos.y < 24.0 or pos.y > 696.0:
		return false
	if path == null or path.curve == null:
		return false

	var local_pos := path.to_local(pos)
	var closest := path.curve.get_closest_point(local_pos)
	if local_pos.distance_to(closest) < PATH_CLEARANCE:
		return false

	for tower in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower):
			continue
		if pos.distance_to((tower as Node2D).global_position) < TOWER_SPACING:
			return false
	return true


func _can_build_now() -> bool:
	return GameState.phase == GameState.Phase.BUILD or GameState.phase == GameState.Phase.WAVE


func _try_select_tower(pos: Vector2) -> bool:
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and tower.has_method("try_select_at") and tower.try_select_at(pos):
			_select_tower(tower)
			return true
	return false


func _deselect() -> void:
	GameState.select_tower(null)
	_clear_tower_selection()


func _select_tower(tower: Node) -> void:
	_clear_tower_selection()
	if tower and tower.has_method("set_selected"):
		tower.set_selected(true)
	GameState.select_tower(tower)
	hud.show_tower(tower)


func _clear_tower_selection() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and tower.has_method("set_selected"):
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
	particles.amount = 24
	particles.lifetime = 6.0
	particles.preprocess = 3.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(640, 360)
	particles.position = Vector2(640, 360)
	particles.gravity = Vector2(-5, -8)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5
	particles.color = Color(0.4, 0.8, 0.6, 0.2)
	particles.z_index = -1
	add_child(particles)
