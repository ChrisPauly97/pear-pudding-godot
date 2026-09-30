# gdlint: disable=max-file-lines
# BID-053 lint debt: oversized script. Shrink it by extraction; don't add to it.
extends RefCounted

const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const SpellEffectLabels = preload("res://game_logic/battle/SpellEffectLabels.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const ZoneState = preload("res://game_logic/battle/ZoneState.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const BattleFx = preload("res://scenes/battle/BattleFx.gd")
const CardArt = preload("res://scenes/battle/CardArt.gd")
const CardFace = preload("res://scenes/ui/CardFace.gd")
const CardMotion = preload("res://scenes/battle/CardMotion.gd")
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const COST_COLOR := Color.WHITE  # on the blue mana gem
const HP_DAMAGED_COLOR := Color(1.0, 0.6, 0.55)
## Rim fill over the frame when a card is unaffordable / not a valid target.
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.5)
## Minimum share of the card height for the illustration; it grows into any
## height the text leaves over, so the stats row always sits at the bottom.
const ART_FRAC := 0.1
const COST_DISCOUNT_COLOR := Color(0.3, 1.0, 0.5)
const COST_UNAFFORDABLE_COLOR := Color(1.0, 0.45, 0.45)

# Fixed references — set once at setup
var _vh: float
var _fx: BattleFx
# Multiplier from the "text_scale" setting (GID-119 / TID-451).
var _text_scale: float = 1.0
# Callables back into BattleScene (avoid circular dependency at parse time)
var _bind_card_input_fn: Callable   # BattleScene.card_input._bind_card_input(panel, card, zone_id)
var _on_empty_slot_fn: Callable     # BattleScene.card_input._on_empty_slot_input(event, slot_idx)
var _make_card_view_fn: Callable    # BattleScene._make_card_view(card, zone_id) -> PanelContainer

# Set once when the GameState is built
var _state: GameState
var _seat_idx_fn: Callable = Callable()
var _enemy_data: Dictionary

# Refreshed by BattleScene before each _refresh_all() call
var _targeting_active: bool = false
var _targeting_friendly: bool = false
var _dragged_card: Dictionary = {}
var _hand_drag_card: CardInstance = null
var _slot_targeting_spell: CardInstance = null
var _slot_select_card: CardInstance = null

## Single source of truth for battle card / board slot size (GID-119 / TID-449).
## ~13.5% vh wide ≈ a real thumb target on a landscape phone. Co-op/team modes
## set a <1 scale because their top status bar eats a row of vertical space.
var _card_scale: float = 1.0

func setup(
	vh: float,
	fx: BattleFx,
	bind_card_input_fn: Callable,
	on_empty_slot_fn: Callable,
	make_card_view_fn: Callable,
	text_scale: float = 1.0
) -> void:
	_vh = vh
	_fx = fx
	_bind_card_input_fn = bind_card_input_fn
	_on_empty_slot_fn = on_empty_slot_fn
	_make_card_view_fn = make_card_view_fn
	_text_scale = text_scale

func _font(pct: float) -> int:
	return int(_vh * pct * _text_scale)

## `seat_idx_fn` maps seat 0 (local) / 1 (shown opponent) to a `state.players`
## index. See BattleFx.set_game_state.
func set_battle_state(state: GameState, enemy_data: Dictionary, seat_idx_fn: Callable = Callable()) -> void:
	_state = state
	_enemy_data = enemy_data
	_seat_idx_fn = seat_idx_fn

func _seat_player(seat: int) -> PlayerState:
	var idx: int = int(_seat_idx_fn.call(seat)) if _seat_idx_fn.is_valid() else seat
	return _state.players[idx]

func _is_local_turn() -> bool:
	var idx: int = int(_seat_idx_fn.call(0)) if _seat_idx_fn.is_valid() else 0
	return _state != null and _state.current_player_idx == idx

func update_context(
	targeting_active: bool,
	targeting_friendly: bool,
	dragged_card: Dictionary,
	hand_drag_card: CardInstance,
	slot_targeting_spell: CardInstance,
	slot_select_card: CardInstance
) -> void:
	_targeting_active = targeting_active
	_targeting_friendly = targeting_friendly
	_dragged_card = dragged_card
	_hand_drag_card = hand_drag_card
	_slot_targeting_spell = slot_targeting_spell
	_slot_select_card = slot_select_card

# -------------------------------------------------------------------------
# Zone refresh
# -------------------------------------------------------------------------

func refresh_zone(zone_node: Node, cards: Array[CardInstance], zone_id: String) -> void:
	var existing: Array[Node] = []
	for child in zone_node.get_children():
		if not child.is_queued_for_deletion():
			existing.append(child)
	var needed: int = cards.size()
	for i in range(needed):
		if i < existing.size():
			update_card_view(existing[i] as PanelContainer, cards[i], zone_id)
		else:
			var card_view: PanelContainer = _make_card_view_fn.call(cards[i], zone_id)
			zone_node.add_child(card_view)
	for i in range(needed, existing.size()):
		existing[i].queue_free()
	if zone_id == "hand" and zone_node is HBoxContainer:
		_apply_hand_separation(zone_node as HBoxContainer, needed)

## Fans the hand when card_count × card_width exceeds the row width: negative
## HBox separation overlaps cards (later children draw on top, Hearthstone-style)
## instead of letting them overflow off-screen (GID-119 / TID-449).
func _apply_hand_separation(hand_box: HBoxContainer, count: int) -> void:
	var sep: int = 4
	if count > 1:
		var avail: float = hand_box.size.x
		if avail <= 0.0:
			avail = _vh * 1.5  # first refresh runs before layout; ≈ content-column width at 16:9
		var card_w: float = card_size().x
		var total: float = card_w * float(count) + 4.0 * float(count - 1)
		if total > avail:
			var overlap: float = (card_w * float(count) - avail) / float(count - 1)
			var max_overlap: float = card_w * 0.55
			sep = -int(ceil(minf(overlap, max_overlap)))
	hand_box.add_theme_constant_override("separation", sep)

func refresh_board_zone(zone_node: Node, zone_state: ZoneState, zone_id: String) -> void:
	var existing: Array[Node] = []
	for child in zone_node.get_children():
		if not child.is_queued_for_deletion() and child.has_meta("slot_idx"):
			existing.append(child)
	while existing.size() < ZoneState.SLOT_COUNT:
		var panel: PanelContainer = _make_empty_slot_panel(existing.size(), zone_id)
		zone_node.add_child(panel)
		existing.append(panel)
	while existing.size() > ZoneState.SLOT_COUNT:
		(existing.back() as Node).queue_free()
		existing.resize(existing.size() - 1)
	for i in range(ZoneState.SLOT_COUNT):
		var panel: Control = existing[i] as Control
		if panel == null:
			continue
		var card: CardInstance = zone_state.slots[i]
		var enh: Dictionary = zone_state.get_slot_enhancement(i)
		panel.set_meta("slot_idx", i)
		if card != null:
			if bool(panel.get_meta("is_empty_slot", false)):
				for ch in panel.get_children():
					ch.queue_free()
				panel.remove_meta("is_empty_slot")
				if not bool(panel.get_meta("is_card_back", false)):
					var is_board_zone: bool = true
					panel.add_child(build_card_vbox(card, is_board_zone))
					attach_card_style(panel)
				panel.custom_minimum_size = card_size()
			update_card_view(panel as PanelContainer, card, zone_id)
			_apply_slot_enhancement_border(panel, enh)
		else:
			if not bool(panel.get_meta("is_empty_slot", false)):
				for ch in panel.get_children():
					ch.queue_free()
				if panel.has_meta("card_style"):
					panel.remove_meta("card_style")
				_setup_empty_slot_panel(panel as PanelContainer, i, zone_id)
			else:
				_apply_empty_slot_style(panel as PanelContainer, i, zone_id, enh)

func set_card_scale(s: float) -> void:
	_card_scale = s

func card_size() -> Vector2:
	return Vector2(_vh * 0.135, _vh * 0.24) * _card_scale

func _slot_size() -> Vector2:
	return card_size()

func _make_empty_slot_panel(slot_idx: int, zone_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	# MOUSE_FILTER_PASS lets drag events propagate to the parent board view
	# (which has the drop handler) while still receiving click events for
	# slot-select play mode. Enemy slots also use PASS so attack drags reach
	# their per-panel forwarding before bubbling further up.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.set_meta("slot_idx", slot_idx)
	panel.set_meta("is_empty_slot", true)
	panel.custom_minimum_size = _slot_size()
	_setup_empty_slot_panel(panel, slot_idx, zone_id)
	return panel

func _setup_empty_slot_panel(panel: PanelContainer, slot_idx: int, zone_id: String) -> void:
	panel.set_meta("is_empty_slot", true)
	panel.custom_minimum_size = _slot_size()
	# Same reuse-safety reset as update_card_view() — a board slot panel is a
	# stable identity that toggles between "card" and "empty" indefinitely, so
	# any transient modulate/scale from an in-flight animation must not leak
	# into the empty state (TID-429).
	panel.visible = true
	panel.modulate = Color.WHITE
	panel.scale = Vector2.ONE
	for ch in panel.get_children():
		if not ch is LongPressDetector:
			ch.queue_free()
	var style := StyleBoxFlat.new()
	var is_enemy: bool = (zone_id == "enemy_board")
	style.bg_color = Color(0.12, 0.12, 0.16, 0.4) if is_enemy else Color(0.15, 0.15, 0.2, 0.6)
	style.border_color = Color(0.35, 0.35, 0.42, 0.7) if is_enemy else Color(0.4, 0.4, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_meta("card_style", style)
	var lbl := _UiUtil.make_label(str(slot_idx + 1), int(_font(0.030)),
			Color(0.45, 0.45, 0.55, 0.8) if is_enemy else Color(0.5, 0.5, 0.6), HORIZONTAL_ALIGNMENT_CENTER, panel)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for conn in panel.gui_input.get_connections():
		panel.gui_input.disconnect(conn["callable"])
	if not is_enemy:
		var idx: int = slot_idx
		panel.gui_input.connect(func(ev: InputEvent) -> void: _on_empty_slot_fn.call(ev, idx))

func _apply_empty_slot_style(panel: PanelContainer, _slot_idx: int, zone_id: String, enh: Dictionary) -> void:
	var style: StyleBoxFlat = (panel.get_meta("card_style") if panel.has_meta("card_style") else null) as StyleBoxFlat
	if style == null:
		return
	var is_enemy: bool = (zone_id == "enemy_board")
	style.bg_color = Color(0.12, 0.12, 0.16, 0.4) if is_enemy else Color(0.15, 0.15, 0.2, 0.6)
	style.set_border_width_all(2)
	var enh_type: String = str(enh.get("type", ""))
	if enh_type == "atk_bonus":
		style.border_color = Color(1.0, 0.65, 0.1)
	elif enh_type == "shroud":
		style.border_color = Color(0.6, 0.6, 1.0)
	elif _slot_targeting_spell != null and not is_enemy:
		style.border_color = Color.CYAN
		style.set_border_width_all(4)
	elif _hand_drag_card != null and not is_enemy and _seat_player(0).can_play(_hand_drag_card):
		style.border_color = Color(0.3, 1.0, 0.5, 1.0)
		style.set_border_width_all(3)
	elif _slot_select_card != null and not is_enemy:
		style.border_color = Color(0.3, 1.0, 0.5, 1.0)
		style.set_border_width_all(3)
	else:
		style.border_color = Color(0.35, 0.35, 0.42, 0.7) if is_enemy else Color(0.4, 0.4, 0.5, 0.8)

func _apply_slot_enhancement_border(panel: Control, enh: Dictionary) -> void:
	var style: StyleBoxFlat = (panel.get_meta("card_style") if panel.has_meta("card_style") else null) as StyleBoxFlat
	if style == null:
		return
	if style.border_width_top > 0:
		return
	var enh_type: String = str(enh.get("type", ""))
	if enh_type == "atk_bonus":
		style.border_color = Color(1.0, 0.65, 0.1)
		style.set_border_width_all(3)
	elif enh_type == "shroud":
		style.border_color = Color(0.6, 0.6, 1.0)
		style.set_border_width_all(3)
	panel.queue_redraw()

# -------------------------------------------------------------------------
# Card view building
# -------------------------------------------------------------------------

## Mana cost as shown on the card's gem: points in real time (×100), units otherwise.
static func format_cost(points: int) -> String:
	return "%d" % points

## Bottom row: cost gem on the left, attack / health badges on the right
## (hidden for spells). Rebuilt in place on recycled panels.
func _build_stats_row(card: CardInstance) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "StatsRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	var d: float = card_size().x * 0.24
	var fs: int = _font(0.017)
	var cost := CardFace.make_badge("cost", "", d, fs)
	cost.name = "CostLabel"
	row.add_child(cost)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var atk := CardFace.make_badge("atk", "", d, fs)
	atk.name = "AtkLabel"
	row.add_child(atk)
	var hp := CardFace.make_badge("hp", "", d, fs)
	hp.name = "HpLabel"
	row.add_child(hp)
	_refresh_stat_badges(row, card)
	return row

func _refresh_stat_badges(row: HBoxContainer, card: CardInstance) -> void:
	# Spell-like legendaries (Time Warp, Soul Harvest) carry a spell_effect and no body.
	var is_unit: bool = card.card_class != "spell" and not (card.card_class == "legendary" and card.spell_effect != "")
	var atk: Label = row.get_node_or_null("AtkLabel") as Label
	var hp: Label = row.get_node_or_null("HpLabel") as Label
	if atk:
		atk.visible = is_unit
		CardFace.set_badge_text(atk, str(card.attack))
	if hp:
		hp.visible = is_unit
		CardFace.set_badge_text(hp, str(card.health))
		hp.add_theme_color_override("font_color",
				HP_DAMAGED_COLOR if card.health < card.max_health else Color.WHITE)

## Cost in mana points for `zone_id` — hand cards include battlefield discounts.
func _cost_points(card: CardInstance, zone_id: String) -> int:
	if _state == null:
		return card.cost
	var p: PlayerState = _seat_player(0)
	return p.effective_cost(card) if zone_id == "hand" else p.base_cost(card)

## Text + colour of a card's CostLabel: blue, green when discounted, red when
## a hand card is not affordable yet (so real-time players see what to wait for).
func _refresh_cost_label(lbl: Label, card: CardInstance, zone_id: String) -> void:
	var pts: int = _cost_points(card, zone_id)
	CardFace.set_badge_text(lbl, format_cost(pts))
	var col: Color = COST_COLOR
	if zone_id == "hand" and _state != null:
		var p: PlayerState = _seat_player(0)
		if pts < p.base_cost(card):
			col = COST_DISCOUNT_COLOR
		elif p.hero.mana < pts:
			col = COST_UNAFFORDABLE_COLOR
	lbl.add_theme_color_override("font_color", col)

func update_card_view(panel: PanelContainer, card: CardInstance, zone_id: String) -> void:
	if bool(panel.get_meta("is_card_back", false)):
		return
	# A reused panel can carry transient per-instance visual state from its
	# previous card — drag-lift dimming (TID-429), a hidden hand panel mid
	# card-travel (TID-426), or an in-flight lunge scale — none of which
	# `update_card_view` otherwise touches. Reset before it might get
	# reassigned to a completely different card.
	panel.visible = true
	panel.modulate = Color.WHITE
	panel.scale = Vector2.ONE
	panel.rotation = 0.0
	panel.self_modulate = Color.WHITE
	panel.z_index = 0
	var vbox: VBoxContainer = panel.get_child(0) as VBoxContainer
	var name_lbl: Label = vbox.get_node_or_null("NameLabel") as Label if vbox else null
	var is_board_zone: bool = (zone_id == "board" or zone_id == "enemy_board")
	if not vbox or not name_lbl:
		for child in panel.get_children():
			child.queue_free()
		panel.add_child(build_card_vbox(card, is_board_zone))
	else:
		name_lbl.text = card.name
		CardArt.apply(vbox, card, card_size().y * ART_FRAC, card_size().y)
		var stats_row: HBoxContainer = vbox.get_node_or_null("StatsRow") as HBoxContainer
		if stats_row:
			_refresh_stat_badges(stats_row, card)
			var cost_lbl: Label = stats_row.get_node_or_null("CostLabel") as Label
			if cost_lbl:
				_refresh_cost_label(cost_lbl, card, zone_id)
		var desc_lbl: Label = vbox.get_node_or_null("DescLabel") as Label
		if desc_lbl:
			var ability_text: String = get_card_ability_text(card)
			desc_lbl.visible = ability_text != ""
			if ability_text != "":
				desc_lbl.text = ability_text
				desc_lbl.add_theme_color_override("font_color", get_card_ability_color(card))
			else:
				desc_lbl.text = ""
				desc_lbl.remove_theme_color_override("font_color")
		var kw_row: HBoxContainer = vbox.get_node_or_null("KeywordRow") as HBoxContainer
		if kw_row:
			update_keyword_badges(kw_row, card)
		if is_board_zone:
			var sr: HBoxContainer = vbox.get_node_or_null("StatusRow") as HBoxContainer
			if sr:
				_fx.update_status_icons_card(sr, card)
			else:
				var new_sr := HBoxContainer.new()
				new_sr.name = "StatusRow"
				_fx.update_status_icons_card(new_sr, card)
				vbox.add_child(new_sr)
	apply_card_style(panel, card, zone_id)
	_bind_card_input_fn.call(panel, card, zone_id)

func get_card_ability_text(card: CardInstance) -> String:
	if card.card_class == "spell" and card.spell_effect != "":
		return SpellEffectLabels.spell(card.spell_effect, card.spell_power)
	if card.emergence_effect != "":
		return SpellEffectLabels.emergence(card.emergence_effect, card.emergence_power)
	return ""

func get_card_ability_color(card: CardInstance) -> Color:
	if card.emergence_effect != "":
		return Color(1.0, 0.85, 0.4)
	return Color(0.6, 1.0, 0.8)

func build_card_vbox(card: CardInstance, with_status_row: bool = false) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(_vh * 0.003))
	var name_lbl := _UiUtil.make_label(card.name, int(_font(0.017)), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.name = "NameLabel"
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_color_override("font_outline_color", CardFace.BADGE_OUTLINE)
	name_lbl.add_theme_constant_override("outline_size", maxi(2, int(_font(0.017) * 0.2)))
	CardArt.apply(vbox, card, card_size().y * ART_FRAC, card_size().y)
	var stats_row: HBoxContainer = _build_stats_row(card)
	_refresh_cost_label(stats_row.get_node("CostLabel") as Label, card, "")
	var desc_lbl := Label.new()
	desc_lbl.name = "DescLabel"
	# Card faces only carry gameplay text (spell/emergence abilities). Minion
	# flavor text is unreadable at card size and lives in the long-press inspect
	# overlay instead (GID-119 / TID-449).
	var ability_text: String = get_card_ability_text(card)
	if ability_text != "":
		desc_lbl.text = ability_text
		desc_lbl.add_theme_color_override("font_color", get_card_ability_color(card))
	else:
		desc_lbl.text = ""
		desc_lbl.visible = false
	desc_lbl.add_theme_font_size_override("font_size", _font(0.015))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.max_lines_visible = 3  # full text lives in the inspect overlay
	desc_lbl.add_theme_stylebox_override("normal", CardFace.plate_style(card_size().y))
	vbox.add_child(name_lbl)
	vbox.add_child(desc_lbl)
	var kw_row := HBoxContainer.new()
	kw_row.name = "KeywordRow"
	kw_row.alignment = BoxContainer.ALIGNMENT_CENTER
	update_keyword_badges(kw_row, card)
	vbox.add_child(kw_row)
	vbox.add_child(stats_row)
	if with_status_row:
		var sr := HBoxContainer.new()
		sr.name = "StatusRow"
		_fx.update_status_icons_card(sr, card)
		vbox.add_child(sr)
	return vbox

## Attaches (or reuses) the rounded StyleBoxFlat that carries a card panel's
## border. Kept in the panel's "card_style" meta so recolouring a card mutates
## the live box instead of allocating a new one every refresh.
## Since GID-151 the panel's own stylebox is the pixel-art frame; this rim is
## drawn over it (under the card's contents) from the panel's draw signal, so
## highlight borders and the dimming fill still show on the framed card.
static func attach_card_style(panel: PanelContainer) -> StyleBoxFlat:
	var style: StyleBoxFlat = (panel.get_meta("card_style") if panel.has_meta("card_style") else null) as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.bg_color = Color.TRANSPARENT
		panel.set_meta("card_style", style)
	if not panel.has_meta("card_rim_hooked"):
		panel.set_meta("card_rim_hooked", true)
		panel.draw.connect(_draw_rim.bind(panel))
	return style

## Empty board slots own their stylebox outright; only framed cards get a rim.
static func _draw_rim(panel: PanelContainer) -> void:
	if bool(panel.get_meta("is_empty_slot", false)) or not panel.has_meta("card_style"):
		return
	var style: StyleBoxFlat = panel.get_meta("card_style") as StyleBoxFlat
	if style != null:
		panel.draw_style_box(style, Rect2(Vector2.ZERO, panel.size))
	CardMotion.draw_glow(panel)

func apply_card_style(panel: PanelContainer, card: CardInstance, zone_id: String) -> void:
	var style: StyleBoxFlat = attach_card_style(panel)
	style.border_width_top = 0
	style.border_width_bottom = 0
	style.border_width_left = 0
	style.border_width_right = 0
	var tmpl: Dictionary = CardRegistry.get_template_for_face(card.template_id, card.active_face)
	var magic_type: String = str(tmpl.get("magic_type", card.magic_type))
	panel.set_meta("card_branch", str(tmpl.get("magic_branch", card.magic_branch)))
	panel.add_theme_stylebox_override("panel", CardFace.frame_style(magic_type, card_size().y))
	style.bg_color = Color.TRANSPARENT
	CardMotion.set_playable_glow(panel, zone_id == "hand" and _is_local_turn() and _seat_player(0).can_play(card))
	if zone_id == "hand" and not _seat_player(0).can_play(card):
		style.bg_color = DIM_COLOR
	elif zone_id == "hand" and _seat_player(0).effective_cost(card) < _seat_player(0).base_cost(card):
		style.border_color = Color(0.3, 1.0, 0.5, 0.8)
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_width_left = 2
		style.border_width_right = 2
	elif zone_id == "enemy_board" and _targeting_active and not _targeting_friendly:
		style.border_color = Color.CYAN
		style.border_width_top = 4
		style.border_width_bottom = 4
		style.border_width_left = 4
		style.border_width_right = 4
	elif zone_id == "board" and _targeting_active and _targeting_friendly:
		style.border_color = Color.CYAN
		style.border_width_top = 4
		style.border_width_bottom = 4
		style.border_width_left = 4
		style.border_width_right = 4
	elif zone_id == "enemy_board" and not _dragged_card.is_empty():
		var valid_targets: Array[CardInstance] = get_ward_valid_targets(_seat_player(1).board.get_cards())
		if not valid_targets.has(card):
			style.bg_color = DIM_COLOR
	elif zone_id == "board" and not _dragged_card.is_empty() and _dragged_card.get("card") == card:
		panel.pivot_offset = panel.custom_minimum_size * 0.5
		panel.scale = Vector2(1.06, 1.06)
		style.border_color = Color.YELLOW
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_width_left = 3
		style.border_width_right = 3
	elif zone_id == "board" and _dragged_card.is_empty() and _is_local_turn() and card.can_attack():
		# Ready-to-attack cue: a soft green rim on every minion that can act.
		style.border_color = Color(0.35, 1.0, 0.45, 0.9)
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_width_left = 2
		style.border_width_right = 2
	# Non-color targeting cue (GID-119 / TID-451): colored borders alone fail
	# colorblind players, so every valid target also carries an explicit marker.
	var show_mark: bool = false
	if zone_id == "enemy_board" and _targeting_active and not _targeting_friendly:
		show_mark = true
	elif zone_id == "board" and _targeting_active and _targeting_friendly:
		show_mark = true
	elif zone_id == "enemy_board" and not _dragged_card.is_empty():
		var mark_targets: Array[CardInstance] = get_ward_valid_targets(_seat_player(1).board.get_cards())
		show_mark = mark_targets.has(card)
	_target_mark(panel, _font(0.018)).visible = show_mark
	panel.queue_redraw()

## Lazily attaches a centered "◎ TARGET" overlay label to a panel. Overlay, not
## a vbox row — it must never shift the card layout when it toggles.
func _target_mark(panel: Control, font_sz: int) -> Label:
	var mark: Label = panel.get_node_or_null("TargetMark") as Label
	if mark == null:
		mark = _UiUtil.make_label("◎ TARGET", int(font_sz), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		mark.name = "TargetMark"
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_theme_color_override("font_color", Color.WHITE)
		mark.add_theme_color_override("font_outline_color", Color.BLACK)
		mark.add_theme_constant_override("outline_size", maxi(2, int(_vh * 0.005)))
		mark.visible = false
		panel.add_child(mark)
	return mark

func update_keyword_badges(hbox: HBoxContainer, card: CardInstance) -> void:
	for child in hbox.get_children():
		child.queue_free()
	var kw_keys: Array[String]  = [Keywords.WARD, Keywords.SURGE, Keywords.SHROUD]
	var kw_labels: Array[String] = ["Ward",        "Surge",        "Shroud"]
	var kw_colors: Array[Color]  = [
		Color(0.35, 0.5, 1.0),
		Color(1.0,  0.6, 0.15),
		Color(0.8,  0.8, 0.88),
	]
	var font_sz: int = _font(0.016)
	for i in range(kw_keys.size()):
		var kw: String = kw_keys[i]
		if not card.keywords.has(kw):
			continue
		if kw == Keywords.SHROUD and not card.shroud_active:
			continue
		var lbl := _UiUtil.make_label(kw_labels[i], int(font_sz))
		lbl.add_theme_color_override("font_color", kw_colors[i])
		hbox.add_child(lbl)

# -------------------------------------------------------------------------
# Hero view building
# -------------------------------------------------------------------------

## hand_count: opponent hand size shown on the enemy panel (GID-119 / TID-448 —
## replaces the face-down enemy hand row). -1 hides the line (player panel).
func refresh_hero(hero_node: PanelContainer, hero: HeroState, is_enemy: bool, hand_count: int = -1) -> void:
	var vbox: VBoxContainer = hero_node.get_child(0) as VBoxContainer if hero_node.get_child_count() > 0 else null
	if not vbox:
		vbox = _UiUtil.make_vbox(int(_vh * 0.004))

		var name_lbl := Label.new()
		name_lbl.name = "NameLabel"
		if is_enemy:
			if bool(_enemy_data.get("is_boss", false)):
				name_lbl.text = EnemyRegistry.get_display_name(str(_enemy_data.get("enemy_type", "")))
			else:
				name_lbl.text = "ENEMY"
		else:
			name_lbl.text = "YOU"
		name_lbl.add_theme_font_size_override("font_size", _font(0.022))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.modulate = Color(1.0, 0.55, 0.55) if is_enemy else Color(0.55, 1.0, 0.75)

		var hp_lbl := Label.new()
		hp_lbl.name = "HPLabel"
		hp_lbl.add_theme_font_size_override("font_size", _font(0.025))
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var bar := ProgressBar.new()
		bar.name = "HPBar"
		bar.custom_minimum_size = Vector2(0, int(_vh * 0.020))
		bar.show_percentage = false

		vbox.add_child(name_lbl)
		vbox.add_child(hp_lbl)
		vbox.add_child(bar)
		if is_enemy:
			var hand_lbl := Label.new()
			hand_lbl.name = "HandLabel"
			hand_lbl.add_theme_font_size_override("font_size", _font(0.020))
			hand_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hand_lbl.modulate = Color(0.85, 0.82, 0.95)
			hand_lbl.visible = false
			vbox.add_child(hand_lbl)
		else:
			var mana_lbl := Label.new()
			mana_lbl.name = "ManaLabel"
			mana_lbl.add_theme_font_size_override("font_size", _font(0.022))
			mana_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(mana_lbl)
		var hero_sr := _UiUtil.make_hbox(0, vbox)
		hero_sr.name = "StatusRow"
		hero_node.add_child(vbox)

	var hp_lbl: Label = vbox.get_node("HPLabel") as Label
	hp_lbl.text = "HP  %d / %d" % [hero.health, hero.max_health]
	var bar: ProgressBar = vbox.get_node("HPBar") as ProgressBar
	bar.visible = not hero.leaderless
	if hero.leaderless:  # BID-077: no leader — the pack itself is the fight
		(vbox.get_node("NameLabel") as Label).text = "PACK"
		hp_lbl.text = "Clear the board"
	bar.max_value = hero.max_health
	bar.value = hero.health
	var mana_lbl: Label = vbox.get_node_or_null("ManaLabel") as Label
	if mana_lbl:
		mana_lbl.text = "Mana  %d / %d" % [hero.mana, hero.max_mana]
	var hand_lbl_u: Label = vbox.get_node_or_null("HandLabel") as Label
	if hand_lbl_u:
		hand_lbl_u.visible = hand_count >= 0
		if hand_count >= 0:
			hand_lbl_u.text = "Cards in hand: %d" % hand_count
	var hero_status_row: HBoxContainer = vbox.get_node_or_null("StatusRow") as HBoxContainer
	if hero_status_row:
		_fx.update_status_icons_hero(hero_status_row, hero)

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left    = 6
	style.corner_radius_top_right   = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	var ward_blocks_hero: bool = is_enemy and not _dragged_card.is_empty() and _seat_player(1).hero_unreachable()
	var is_attack_targetable: bool = is_enemy and not _dragged_card.is_empty() and not ward_blocks_hero
	var is_spell_targetable: bool = (is_enemy and _targeting_active and not _targeting_friendly
			and not hero.leaderless)
	if hero_node is Control:
		_target_mark(hero_node as Control, _font(0.022)).visible = \
			is_attack_targetable or is_spell_targetable
	if is_enemy:
		if is_spell_targetable:
			style.bg_color = Color(0.1, 0.35, 0.45)
			style.border_color = Color.CYAN
			style.border_width_top    = 4
			style.border_width_bottom = 4
			style.border_width_left   = 4
			style.border_width_right  = 4
		elif is_attack_targetable:
			style.bg_color = Color(0.55, 0.15, 0.1)
			style.border_color = Color(1.0, 0.35, 0.2)
			style.border_width_top    = 3
			style.border_width_bottom = 3
			style.border_width_left   = 3
			style.border_width_right  = 3
		else:
			style.bg_color = Color(0.45, 0.1, 0.1)
	else:
		style.bg_color = Color(0.1, 0.2, 0.4)
	hero_node.add_theme_stylebox_override("panel", style)

# -------------------------------------------------------------------------
# Ward targeting helper
# -------------------------------------------------------------------------

func get_ward_valid_targets(cards: Array[CardInstance]) -> Array[CardInstance]:
	var ward: Array[CardInstance] = []
	for c: CardInstance in cards:
		if c.keywords.has(Keywords.WARD):
			ward.append(c)
	return ward if not ward.is_empty() else cards
