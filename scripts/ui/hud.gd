extends CanvasLayer

## Top HUD + tower feat panel + evolution picker.

@onready var gold_label: Label = $Root/TopBar/GoldLabel
@onready var lives_label: Label = $Root/TopBar/LivesLabel
@onready var wave_label: Label = $Root/TopBar/WaveLabel
@onready var hint_label: Label = $Root/TopBar/HintLabel
@onready var status_label: Label = $Root/StatusLabel
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
	GameState.gold_changed.connect(_on_gold)
	GameState.lives_changed.connect(_on_lives)
	GameState.wave_changed.connect(_on_wave)
	GameState.tower_selected.connect(_on_tower_selected)
	GameState.feat_completed.connect(_on_feat_completed)
	GameState.run_won.connect(func(): status_label.text = "YOU WIN — garden holds")
	GameState.run_lost.connect(func(): status_label.text = "DEFEATED — base fallen")
	_on_gold(GameState.gold)
	_on_lives(GameState.lives)
	_on_wave(GameState.wave_index)
	hint_label.text = "LMB place/select · Space wave · Esc cancel"


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
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_pick_evolution.bind(evo))
		evo_buttons.add_child(btn)


func _on_pick_evolution(evo: Resource) -> void:
	if _evo_tower and _evo_tower.has_method("apply_evolution"):
		_evo_tower.apply_evolution(evo)
	evolution_modal.visible = false
	_evo_tower = null
	if GameState.phase == GameState.Phase.EVOLUTION_PICK:
		# Return to build unless a wave is mid-flight (alive enemies still imply WAVE).
		var enemies := get_tree().get_nodes_in_group("enemies")
		GameState.phase = GameState.Phase.WAVE if enemies.size() > 0 else GameState.Phase.BUILD
	show_tower(GameState.selected_tower)


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
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feat_list.add_child(row)
	var pending := 0
	if "feats" in tower and tower.feats != null:
		pending = tower.feats.pending_evolution_points
		evo_points_label.text = "Evolution points: %d · Taken: %d/%d" % [
			pending, tower.feats.evolutions_taken, tower.feats.MAX_EVOLUTIONS
		]
	else:
		evo_points_label.text = ""


func _on_gold(amount: int) -> void:
	gold_label.text = "Gold: %d (tower %d)" % [amount, GameState.TOWER_COST]


func _on_lives(amount: int) -> void:
	lives_label.text = "Lives: %d" % amount


func _on_wave(index: int) -> void:
	wave_label.text = "Wave: %d" % index


func _on_tower_selected(tower: Node) -> void:
	show_tower(tower)


func _on_feat_completed(tower: Node, feat_id: StringName) -> void:
	status_label.text = "Feat unlocked: %s" % str(feat_id)
	if tower == GameState.selected_tower:
		_refresh_feats(tower)
