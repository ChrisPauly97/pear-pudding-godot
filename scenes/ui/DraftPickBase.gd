## Shared chrome for the two "pick one of N cards" overlays — the Spire floor
## draft (SpireDraftScene) and the sealed-deck PvP draft (DraftDuelPickScene).
##
## Both show the same thing: a centred panel, a title, a row of card panels that
## stack vertically on portrait screens, and a Pick button per card. Only the
## tier source and what happens on pick differ, so those are the two hooks
## subclasses override.
##
## Subclass with `extends "res://scenes/ui/DraftPickBase.gd"` — that form keeps
## the inherited statics and `_UiUtil` const resolving without a re-declaration
## (see CLAUDE.md on class_name / preload).
extends Control
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const CardRegistry = preload("res://autoloads/CardRegistry.gd")

var _vh: float = 0.0
var _vw: float = 0.0
var _ref: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_ref = minf(_vh, _vw)
	# Backdrop is created once, before any panel, so panels always draw over it.
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

## The centred draft panel plus the VBox every row goes into.
## Returns {"outer": PanelContainer, "vbox": VBoxContainer}; free "outer" to
## discard just the panel and leave the backdrop in place.
func _build_draft_panel() -> Dictionary:
	var outer := PanelContainer.new()
	var panel_w: float = minf(_vw * 0.94, _vh * 0.88)
	var panel_h: float = _vh * 0.80
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	outer.size = Vector2(panel_w, panel_h)
	outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(outer)
	var margin := _UiUtil.make_margin(int(_vw * 0.02), int(_ref * 0.02), int(_vw * 0.02), int(_ref * 0.02), outer)
	return {"outer": outer, "vbox": _UiUtil.make_vbox(int(_ref * 0.018), margin)}

## The card strip: a row on landscape, a column on portrait phones.
func _build_cards_container(parent: Control) -> BoxContainer:
	var cards_container: BoxContainer
	if _vw < _vh:
		cards_container = _UiUtil.make_vbox(int(_ref * 0.012))
	else:
		cards_container = _UiUtil.make_hbox(int(_vw * 0.015))
	cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(cards_container)
	return cards_container

## One pickable card: colour swatch, name, tier badge, stats, description and the
## Pick button. `_tier_for` and `_pick_disabled` are the subclass hooks.
func _make_card_panel(card_id: String) -> Control:
	var tmpl: Dictionary = CardRegistry.get_template(card_id)
	var cost: int = int(tmpl.get("cost", 1))
	var cls: String = str(tmpl.get("card_class", "minion"))
	var desc: String = str(tmpl.get("description", ""))

	var tier: int = _tier_for(card_id, tmpl)
	var tier_color: Color = _tier_color(tier)

	var outer_panel := PanelContainer.new()
	outer_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := _UiUtil.make_margin(int(_vw * 0.012), int(_ref * 0.012), int(_vw * 0.012), int(_ref * 0.012), outer_panel)
	var vbox := _UiUtil.make_vbox(int(_ref * 0.008), margin)

	var name_row := _UiUtil.make_hbox(int(_vw * 0.008), vbox)
	var swatch := ColorRect.new()
	swatch.color = tmpl.get("color", Color(0.3, 0.3, 0.4))
	swatch.custom_minimum_size = Vector2(_ref * 0.035, _ref * 0.035)
	name_row.add_child(swatch)
	var name_lbl := _UiUtil.make_label(str(tmpl.get("name", card_id)), int(_ref * 0.026), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, name_row)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_UiUtil.make_label(_tier_label(tier), int(_ref * 0.02), tier_color, HORIZONTAL_ALIGNMENT_LEFT, vbox)

	var stats: String
	if cls == "minion" or cls == "legendary":
		stats = "Cost %d  |  %d/%d" % [cost, int(tmpl.get("attack", 0)), int(tmpl.get("health", 0))]
	else:
		stats = "Cost %d  |  Spell" % cost
	_UiUtil.make_label(stats, int(_ref * 0.022), Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_LEFT, vbox)

	# The description doubles as the flex spacer that keeps the Pick button
	# pinned to the bottom; cards without one need a bare spacer instead.
	if desc != "":
		var desc_lbl := _UiUtil.make_label(desc, int(_ref * 0.018), Color(0.70, 0.70, 0.70), HORIZONTAL_ALIGNMENT_LEFT, vbox)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(spacer)

	var pick_btn := _UiUtil.make_button("Pick", Vector2(0.0, _ref * 0.055), int(_ref * 0.023), _on_pick.bind(card_id), vbox)
	pick_btn.modulate = tier_color
	pick_btn.disabled = _pick_disabled()
	return outer_panel

## Override: which tier badge this card gets. `tmpl` is the already-fetched
## CardRegistry template, so overrides never need a second lookup.
func _tier_for(_card_id: String, _tmpl: Dictionary) -> int:
	return 0

## Override: true greys out every Pick button (co-op draft, waiting for the
## other player's turn).
func _pick_disabled() -> bool:
	return false

## Override: the player chose `card_id`.
func _on_pick(_card_id: String) -> void:
	pass

static func _tier_color(tier: int) -> Color:
	match tier:
		0: return Color(0.80, 0.80, 0.80)
		1: return Color(0.30, 0.65, 1.00)
		2: return Color(0.75, 0.30, 1.00)
		3: return Color(1.00, 0.80, 0.10)
	return Color.WHITE

static func _tier_label(tier: int) -> String:
	match tier:
		0: return "Basic"
		1: return "Standard"
		2: return "Premium"
		3: return "Legendary"
	return ""
