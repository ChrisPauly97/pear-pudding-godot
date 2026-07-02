## Draft Duel pick overlay (GID-104 / TID-385) — sealed-deck PvP drafting.
##
## Both duelists instantiate this locally with the SAME shared seed; the round
## sequence is fully deterministic (DraftDuelGen.generate_rounds), so no network
## traffic happens per pick. When the final pick is made, `draft_finished(deck)`
## fires with the assembled transient deck (Array of instance dicts) and the
## overlay switches itself into a "Waiting for opponent…" state — the owner
## (WorldScene) frees it when both decks are ready and the battle starts, or on
## abort (peer disconnect / session end).
##
## Drafted cards are TRANSIENT: they exist only in this overlay and the one
## GameState of the resulting duel. They are never written to owned_cards,
## SaveManager, or SessionState.
##
## Mobile/desktop parity: every pick is a Button (touch + mouse); no keybinds.
extends Control

signal draft_finished(deck: Array)

const DraftDuelGen = preload("res://game_logic/net/DraftDuelGen.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

var _vh: float = 0.0
var _vw: float = 0.0
var _ref: float = 0.0
var _rounds: Array = []            # Array of Array[String] — the shared pick script
var _round_idx: int = 0
var _owner_token: String = ""
var _deck: Array = []              # transient instance dicts picked so far
var _content_root: Control = null  # rebuilt per round

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_ref = minf(_vh, _vw)
	# Dark backdrop — created once; per-round content lives in _content_root.
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

## Call after add_child. Derives the deterministic rounds from the shared seed
## and shows round 1. `owner_token` namespaces the transient instance uids.
func setup(seed_val: int, owner_token: String) -> void:
	_owner_token = owner_token
	var pool_templates: Dictionary = {}
	for id: String in CardRegistry.get_all_ids():
		pool_templates[id] = CardRegistry.get_template(id)
	_rounds = DraftDuelGen.generate_rounds(seed_val, pool_templates)
	if _rounds.is_empty():
		# Headless/no-cards edge: finish immediately with an empty deck; the
		# receiving battle path falls back to its default deck.
		_finish()
		return
	_round_idx = 0
	_build_round_ui()

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _clear_content() -> void:
	if _content_root != null and is_instance_valid(_content_root):
		_content_root.queue_free()
	_content_root = null

func _build_round_ui() -> void:
	_clear_content()
	var outer := PanelContainer.new()
	var panel_w: float = minf(_vw * 0.94, _vh * 0.88)
	var panel_h: float = _vh * 0.80
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	outer.size = Vector2(panel_w, panel_h)
	outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(outer)
	_content_root = outer

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vw * 0.02))
	margin.add_theme_constant_override("margin_right",  int(_vw * 0.02))
	margin.add_theme_constant_override("margin_top",    int(_ref * 0.02))
	margin.add_theme_constant_override("margin_bottom", int(_ref * 0.02))
	outer.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", int(_ref * 0.018))
	margin.add_child(root_vbox)

	var title := Label.new()
	title.text = "Draft Duel — Pick %d of %d" % [_round_idx + 1, _rounds.size()]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(_ref * 0.038))
	title.modulate = Color(1.0, 0.88, 0.4)
	root_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Both players draft from the same sealed pool. Drafted cards last for this duel only."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", int(_ref * 0.018))
	subtitle.modulate = Color(0.75, 0.75, 0.75)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(subtitle)

	root_vbox.add_child(HSeparator.new())

	# Card option row/column (portrait stacks vertically, like SpireDraftScene).
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

	var options: Array = _rounds[_round_idx]
	for cid in options:
		cards_container.add_child(_make_card_panel(str(cid)))

	# Drafted-so-far strip.
	var drafted := Label.new()
	var names: Array[String] = []
	for inst in _deck:
		var d: Dictionary = inst
		var tmpl: Dictionary = CardRegistry.get_template(str(d.get("template_id", "")))
		names.append(str(tmpl.get("name", d.get("template_id", "?"))))
	drafted.text = "Drafted: %s" % (", ".join(names) if not names.is_empty() else "—")
	drafted.add_theme_font_size_override("font_size", int(_ref * 0.018))
	drafted.modulate = Color(0.65, 0.85, 0.65)
	drafted.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(drafted)

func _make_card_panel(card_id: String) -> Control:
	var tmpl: Dictionary = CardRegistry.get_template(card_id)
	var card_name: String = str(tmpl.get("name", card_id))
	var cost: int = int(tmpl.get("cost", 1))
	var attack: int = int(tmpl.get("attack", 0))
	var health: int = int(tmpl.get("health", 0))
	var cls: String = str(tmpl.get("card_class", "minion"))
	var desc: String = str(tmpl.get("description", ""))
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.4))

	var tier: int = DraftDuelGen.tier_for_template(tmpl)
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

	var tier_lbl := Label.new()
	tier_lbl.text = _tier_label(tier)
	tier_lbl.modulate = tier_color
	tier_lbl.add_theme_font_size_override("font_size", int(_ref * 0.02))
	vbox.add_child(tier_lbl)

	var stats_lbl := Label.new()
	if cls == "minion" or cls == "legendary":
		stats_lbl.text = "Cost %d  |  %d/%d" % [cost, attack, health]
	else:
		stats_lbl.text = "Cost %d  |  Spell" % cost
	stats_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	stats_lbl.modulate = Color(0.85, 0.85, 0.85)
	vbox.add_child(stats_lbl)

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

	var pick_btn := Button.new()
	pick_btn.text = "Pick"
	pick_btn.custom_minimum_size = Vector2(0.0, _ref * 0.055)
	pick_btn.add_theme_font_size_override("font_size", int(_ref * 0.023))
	pick_btn.modulate = tier_color
	pick_btn.pressed.connect(_on_pick.bind(card_id))
	vbox.add_child(pick_btn)

	return outer_panel

# ---------------------------------------------------------------------------
# Pick flow
# ---------------------------------------------------------------------------

func _on_pick(card_id: String) -> void:
	var tmpl: Dictionary = CardRegistry.get_template(card_id)
	var tier: int = DraftDuelGen.tier_for_template(tmpl)
	_deck.append(DraftDuelGen.make_drafted_instance(card_id, tier, _round_idx, _owner_token, tmpl))
	_round_idx += 1
	if _round_idx >= _rounds.size():
		_finish()
	else:
		_build_round_ui()

func _finish() -> void:
	_show_waiting()
	draft_finished.emit(_deck)

## Post-draft holding state: the duel starts once the opponent's deck arrives;
## WorldScene frees this overlay at that point (or on abort).
func _show_waiting() -> void:
	_clear_content()
	var panel := PanelContainer.new()
	var panel_w: float = _vw * 0.6
	var panel_h: float = _vh * 0.2
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(panel)
	_content_root = panel
	var lbl := Label.new()
	lbl.text = "Deck drafted! Waiting for your opponent to finish…"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", int(_ref * 0.026))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(lbl)

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
