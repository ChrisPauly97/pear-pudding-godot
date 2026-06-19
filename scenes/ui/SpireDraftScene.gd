## Draft-pick overlay shown after each Spire floor victory.
##
## Usage:
##   var draft := SpireDraftScene.instantiate()
##   add_child(draft)
##   draft.setup(floor_number)
##   draft.picked.connect(_on_draft_picked)   # receives the chosen card_id
extends Control

signal picked(card_id: String)

const SpireDraft = preload("res://game_logic/spire/SpireDraft.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

var _vh: float = 0.0
var _vw: float = 0.0
var _ref: float = 0.0
var _card_panels: HBoxContainer = null
var _floor_number: int = 1
var _draft_logic: RefCounted = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_ref = minf(_vh, _vw)

## Call after instantiation. Generates the picks and builds the UI.
func setup(floor: int) -> void:
	_floor_number = floor
	_draft_logic = SpireDraft.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(SceneManager.save_manager.get_spire_run().get("seed", 0)) + floor
	var pool_templates: Dictionary = {}
	for id: String in CardRegistry.get_all_ids():
		pool_templates[id] = CardRegistry.get_template(id)
	var picks: Array[String] = _draft_logic.generate_picks(floor, rng, pool_templates)
	_build_ui(picks)

func _build_ui(picks: Array[String]) -> void:
	# Dark backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := PanelContainer.new()
	var panel_w: float = minf(_vw * 0.94, _vh * 0.88)
	var panel_h: float = _vh * 0.80
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	outer.size = Vector2(panel_w, panel_h)
	outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(outer)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vw * 0.02))
	margin.add_theme_constant_override("margin_right",  int(_vw * 0.02))
	margin.add_theme_constant_override("margin_top",    int(_ref * 0.02))
	margin.add_theme_constant_override("margin_bottom", int(_ref * 0.02))
	outer.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", int(_ref * 0.018))
	margin.add_child(root_vbox)

	# Title
	var title := Label.new()
	title.text = "Floor %d — Choose a Card" % _floor_number
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(_ref * 0.038))
	title.modulate = Color(1.0, 0.88, 0.4)
	root_vbox.add_child(title)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Card panels row
	var is_portrait: bool = _vw < _vh
	var cards_container: BoxContainer
	if is_portrait:
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", int(_ref * 0.012))
		cards_container = vb
	else:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", int(_vw * 0.015))
		cards_container = hb
	cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(cards_container)

	for card_id: String in picks:
		var panel := _make_card_panel(card_id)
		cards_container.add_child(panel)

	# Spacer so title + cards fill the panel naturally
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(spacer)

func _make_card_panel(card_id: String) -> Control:
	var tmpl: Dictionary = CardRegistry.get_template(card_id)
	var card_name: String = str(tmpl.get("name", card_id))
	var cost: int = int(tmpl.get("cost", 1))
	var attack: int = int(tmpl.get("attack", 0))
	var health: int = int(tmpl.get("health", 0))
	var cls: String = str(tmpl.get("card_class", "minion"))
	var desc: String = str(tmpl.get("description", ""))
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.4))

	var tier: int = _draft_logic.card_tier(card_id)
	var tier_color: Color = _tier_color(tier)

	var outer_panel := PanelContainer.new()
	outer_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vw * 0.012))
	margin.add_theme_constant_override("margin_right",  int(_vw * 0.012))
	margin.add_theme_constant_override("margin_top",    int(_ref * 0.012))
	margin.add_theme_constant_override("margin_bottom", int(_ref * 0.012))
	outer_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(_ref * 0.008))
	margin.add_child(vbox)

	# Colour swatch + name row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", int(_vw * 0.008))
	vbox.add_child(name_row)

	var swatch := ColorRect.new()
	swatch.color = card_color
	swatch.custom_minimum_size = Vector2(_ref * 0.035, _ref * 0.035)
	name_row.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = card_name
	name_lbl.add_theme_font_size_override("font_size", int(_ref * 0.026))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	# Tier badge
	var tier_lbl := Label.new()
	tier_lbl.text = _tier_label(tier)
	tier_lbl.modulate = tier_color
	tier_lbl.add_theme_font_size_override("font_size", int(_ref * 0.02))
	vbox.add_child(tier_lbl)

	# Stats row
	var stats_lbl := Label.new()
	if cls == "minion" or cls == "legendary":
		stats_lbl.text = "Cost %d  |  %d/%d" % [cost, attack, health]
	else:
		stats_lbl.text = "Cost %d  |  Spell" % cost
	stats_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	stats_lbl.modulate = Color(0.85, 0.85, 0.85)
	vbox.add_child(stats_lbl)

	# Description
	if desc != "":
		var desc_lbl := Label.new()
		desc_lbl.text = desc
		desc_lbl.add_theme_font_size_override("font_size", int(_ref * 0.018))
		desc_lbl.modulate = Color(0.70, 0.70, 0.70)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(desc_lbl)
	else:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(spacer)

	# Pick button
	var pick_btn := Button.new()
	pick_btn.text = "Pick"
	pick_btn.custom_minimum_size = Vector2(0.0, _ref * 0.055)
	pick_btn.add_theme_font_size_override("font_size", int(_ref * 0.023))
	pick_btn.modulate = tier_color
	pick_btn.pressed.connect(_on_pick.bind(card_id))
	vbox.add_child(pick_btn)

	return outer_panel

func _on_pick(card_id: String) -> void:
	SceneManager.save_manager.add_drafted_card(card_id)
	GameBus.spire_card_drafted.emit(card_id)
	picked.emit(card_id)
	queue_free()

func _tier_color(tier: int) -> Color:
	match tier:
		0: return Color(0.80, 0.80, 0.80)
		1: return Color(0.30, 0.65, 1.00)
		2: return Color(0.75, 0.30, 1.00)
		3: return Color(1.00, 0.80, 0.10)
	return Color.WHITE

func _tier_label(tier: int) -> String:
	match tier:
		0: return "Basic"
		1: return "Standard"
		2: return "Premium"
		3: return "Legendary"
	return ""
