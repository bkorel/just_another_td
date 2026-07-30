extends CanvasLayer

## Top HUD + Build Palette + tower feat panel + evolution picker + banners.

const TestRunnerScene := preload("res://scenes/tests/test_runner_scene.tscn")

@onready var gold_label: Label = $Root/TopBar/GoldLabel
@onready var lives_label: Label = $Root/TopBar/LivesLabel
@onready var wave_label: Label = $Root/TopBar/WaveLabel
@onready var hint_label: Label = $Root/TopBar/HintLabel
@onready var status_label: Label = $Root/StatusLabel

@onready var archer_btn: Button = $Root/BuildPalette/ArcherBtn
@onready var frost_btn: Button = $Root/BuildPalette/FrostBtn
@onready var next_wave_btn: Button = $Root/BuildPalette/NextWaveBtn
@onready var test_btn: Button = $Root/BuildPalette/TestBtn

@onready var banner: PanelContainer = $Root/Banner
@onready var banner_text: Label = $Root/Banner/BannerText

@onready var tower_panel: PanelContainer = $Root/TowerPanel
@onready var tower_title: Label = $Root/TowerPanel/Margin/VBox/TowerTitle
@onready var feat_list: VBoxContainer = $Root/TowerPanel/Margin/VBox/FeatList
@onready var evo_points_label: Label = $Root/TowerPanel/Margin/VBox/EvoPoints

@onready var evolution_modal: PanelContainer = $Root/EvolutionModal
@onready var evo_buttons: VBoxContainer = $Root/EvolutionModal/Margin/VBox/Buttons

var _level: Node = null
var _evo_tower: Node = null


func _ready() -> void:
	tower_panel.visible = false
	evolution_modal.visible = false
	banner.visible = false

	archer_btn.pressed.connect(func(): GameState.set_placement_type(&"archer"))
	frost_btn.pressed.connect(func(): GameState.set_placement_type(&"frost"))
	next_wave_btn.pressed.connect(_on_next_wave_pressed)
	test_btn.pressed.connect(_on_test_pressed)

	GameState.gold_changed.connect(_on_gold)
	GameState.lives_changed.connect(_on_lives)
	GameState.wave_changed.connect(_on_wave)
	GameState.tower_selected.connect(_on_tower_selected)
	GameState.feat_completed.connect(_on_feat_completed)
	GameState.placement_type_changed.connect(_on_placement_type_changed)

	GameState.run_won.connect(func(): status_label.text = "YOU WIN — Garden Sanctuary Saved!")
	GameState.run_lost.connect(func(): status_label.text = "DEFEATED — Sanctuary Base Fallen")

	_on_gold(GameState.gold)
	_on_lives(GameState.lives)
	_on_wave(GameState.wave_index)
	_on_placement_type_changed(GameState.selected_placement_type)

	hint_label.text = "[1] Archer · [2] Frost · [Space] Wave · [Esc] Deselect"


func bind_level(level: Node) -> void:
	_level = level


func show_tower(tower: Node) -> void:
	if tower == null:
		tower_panel.visible = false
		return
	tower_panel.visible = true
	tower_title.text = tower.get("display_name") if "display_name" in tower else "Tower"
	_refresh_feats(tower)


func open_evolution_modal(tower: Node) -> void:
	if tower == null or not tower.has_pending_evolution():
		return
	_evo_tower = tower
	GameState.phase = GameState.Phase.EVOLUTION_PICK
	evolution_modal.visible = true
	for child in evo_buttons.get_children():
		child.queue_free()

	var options: Array = tower.evolution_options if "evolution_options" in tower else []
	for evo in options:
		var btn := Button.new()
		btn.text = "%s — %s" % [evo.title, evo.description]
		btn.custom_minimum_size = Vector2(0, 42)
		btn.pressed.connect(_on_pick_evolution.bind(evo))
		evo_buttons.add_child(btn)


func _on_test_pressed() -> void:
	var existing = $Root.get_node_or_null("TestRunnerUI")
	if existing:
		existing.queue_free()
		return
	var test_ui = TestRunnerScene.instantiate()
	$Root.add_child(test_ui)


func _on_next_wave_pressed() -> void:
	if _level and _level.has_node("WaveManager"):
		var wm = _level.get_node("WaveManager")
		if wm.can_start_wave():
			if GameState.phase == GameState.Phase.BUILD and GameState.wave_index > 0:
				GameState.add_gold(15) # Early call bonus gold!
				status_label.text = "Early Wave Call! +15 Gold Bonus!"
			wm.start_next_wave()


func _on_pick_evolution(evo: Resource) -> void:
	if _evo_tower and _evo_tower.has_method("apply_evolution"):
		_evo_tower.apply_evolution(evo)
		show_banner("⚡ EVOLUTION UNLOCKED: %s!" % evo.title)
	evolution_modal.visible = false
	_evo_tower = null

	if GameState.phase == GameState.Phase.EVOLUTION_PICK:
		var enemies := get_tree().get_nodes_in_group("enemies")
		GameState.phase = GameState.Phase.WAVE if enemies.size() > 0 else GameState.Phase.BUILD

	show_tower(GameState.selected_tower)


func show_banner(msg: String) -> void:
	banner_text.text = msg
	banner.visible = true
	banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 0.0, 2.5).set_delay(1.5)
	tw.tween_callback(func(): banner.visible = false)


func _refresh_feats(tower: Node) -> void:
	for child in feat_list.get_children():
		child.queue_free()
	if tower == null or not tower.has_method("get_feat_snapshot"):
		return

	var snapshot: Array = tower.get_feat_snapshot()
	for item in snapshot:
		var row := Label.new()
		var cur := int(item["current"])
		var tgt := int(item["target"])
		var mark := "✓" if item["done"] else "%d/%d" % [cur, tgt]
		row.text = "%s  %s — %s" % [mark, item["title"], item["description"]]
		if item["done"]:
			row.modulate = Color(0.5, 1.0, 0.6)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feat_list.add_child(row)

	var pending := 0
	if "feats" in tower and tower.feats != null:
		pending = tower.feats.pending_evolution_points
		evo_points_label.text = "Evolution Points: %d · Branch: %d/2" % [
			pending, tower.feats.evolutions_taken
		]
	else:
		evo_points_label.text = ""


func _on_placement_type_changed(type_id: StringName) -> void:
	archer_btn.modulate = Color(1.3, 1.3, 1.0) if type_id == &"archer" else Color(0.7, 0.7, 0.7)
	frost_btn.modulate = Color(1.3, 1.3, 1.0) if type_id == &"frost" else Color(0.7, 0.7, 0.7)


func _on_gold(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount


func _on_lives(amount: int) -> void:
	lives_label.text = "Sanctuary HP: %d" % amount


func _on_wave(index: int) -> void:
	wave_label.text = "Wave: %d/8" % index


func _on_tower_selected(tower: Node) -> void:
	show_tower(tower)


func _on_feat_completed(tower: Node, feat_id: StringName) -> void:
	var title: String = str(feat_id)
	status_label.text = "✨ FEAT COMPLETED: %s!" % title
	show_banner("✨ FEAT UNLOCKED: %s!" % title)

	if tower == GameState.selected_tower:
		_refresh_feats(tower)
