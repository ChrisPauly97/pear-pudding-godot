## Draft-pick overlay shown after each Spire floor victory.
##
## Usage (single-player):
##   var draft := SpireDraftScene.instantiate()
##   add_child(draft)
##   draft.setup(floor_number)
##   draft.picked.connect(_on_draft_picked)   # receives the chosen card_id
##
## Usage (co-op alternating draft, GID-106 / TID-390):
##   draft.setup_coop(floor_number, broadcast_options, is_my_turn, active_picker_name)
##   if is_my_turn: draft.picked.connect(_submit_coop_spire_draft_choice)
extends Control
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

signal picked(card_id: String)

const SpireDraft = preload("res://game_logic/spire/SpireDraft.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

var _vh: float = 0.0
var _vw: float = 0.0
var _ref: float = 0.0
var _floor_number: int = 1
var _draft_logic: RefCounted = null

# Co-op alternating draft (GID-106 / TID-390). _is_coop gates the single-player
# persistence side effects in _on_pick (the co-op grant path is
# SceneManager.add_coop_drafted_card, driven by WorldScene, not
# SaveManager.add_drafted_card / GameBus.spire_card_drafted).
var _is_coop: bool = false
var _coop_is_my_turn: bool = false
var _coop_picker_name: String = ""

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

## Co-op entry point (WorldScene._on_spire_draft_start_received): unlike setup(),
## `options` are pre-broadcast by the authority — never regenerated locally, so
## every peer renders identical cards. `is_my_turn` gates interactivity: only the
## active picker's buttons are enabled; everyone else sees a disabled "waiting" banner.
func setup_coop(floor: int, options: Array[String], is_my_turn: bool, picker_name: String) -> void:
	_floor_number = floor
	_draft_logic = SpireDraft.new()  # still needed for card_tier() lookups in _make_card_panel
	_is_coop = true
	_coop_is_my_turn = is_my_turn
	_coop_picker_name = picker_name
	_build_ui(options)

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

	var margin := _UiUtil.make_margin(int(_vw * 0.02), int(_ref * 0.02), int(_vw * 0.02), int(_ref * 0.02), outer)

	var root_vbox := _UiUtil.make_vbox(int(_ref * 0.018), margin)

	# Title
	var title := _UiUtil.make_label("Floor %d — Choose a Card" % _floor_number, int(_ref * 0.038), Color(1.0, 0.88, 0.4), HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	# Co-op turn banner: "Your turn!" or "Waiting for <name>…" — every peer sees the
	# same 3 cards, but only the active picker's buttons are interactive.
	if _is_coop:
		var turn_banner := _UiUtil.make_label("Your turn!" if _coop_is_my_turn else "Waiting for %s…" % _coop_picker_name, int(_ref * 0.026), Color(0.6, 1.0, 0.6) if _coop_is_my_turn else Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Card panels row
	var is_portrait: bool = _vw < _vh
	var cards_container: BoxContainer
	if is_portrait:
		var vb := _UiUtil.make_vbox(int(_ref * 0.012))
		cards_container = vb
	else:
		var hb := _UiUtil.make_hbox(int(_vw * 0.015))
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

	var margin := _UiUtil.make_margin(int(_vw * 0.012), int(_ref * 0.012), int(_vw * 0.012), int(_ref * 0.012), outer_panel)

	var vbox := _UiUtil.make_vbox(int(_ref * 0.008), margin)

	# Colour swatch + name row
	var name_row := _UiUtil.make_hbox(int(_vw * 0.008), vbox)

	var swatch := ColorRect.new()
	swatch.color = card_color
	swatch.custom_minimum_size = Vector2(_ref * 0.035, _ref * 0.035)
	name_row.add_child(swatch)

	var name_lbl := _UiUtil.make_label(card_name, int(_ref * 0.026), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, name_row)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Tier badge
	var tier_lbl := _UiUtil.make_label(_tier_label(tier), int(_ref * 0.02), tier_color, HORIZONTAL_ALIGNMENT_LEFT, vbox)

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
		var desc_lbl := _UiUtil.make_label(desc, int(_ref * 0.018), Color(0.70, 0.70, 0.70), HORIZONTAL_ALIGNMENT_LEFT, vbox)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(spacer)

	# Pick button — disabled for every peer except the active picker during a co-op round.
	var pick_btn := _UiUtil.make_button("Pick", Vector2(0.0, _ref * 0.055), int(_ref * 0.023), _on_pick.bind(card_id), vbox)
	pick_btn.modulate = tier_color
	pick_btn.disabled = _is_coop and not _coop_is_my_turn

	return outer_panel

func _on_pick(card_id: String) -> void:
	if _is_coop:
		# Defensive: the button is already disabled for a non-active picker, but
		# never emit/free on a stray signal. Co-op persistence (SceneManager.
		# add_coop_drafted_card) is driven by WorldScene after the authority
		# resolves the pick — this scene never touches SaveManager/GameBus in co-op.
		if not _coop_is_my_turn:
			return
		picked.emit(card_id)
		queue_free()
		return
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
