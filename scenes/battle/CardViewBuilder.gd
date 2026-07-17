extends RefCounted

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const ZoneState = preload("res://game_logic/battle/ZoneState.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const BattleFx = preload("res://scenes/battle/BattleFx.gd")
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")

# Fixed references — set once at setup
var _vh: float
var _fx: BattleFx
# Multiplier from the "text_scale" setting (GID-119 / TID-451).
var _text_scale: float = 1.0
# Callables back into BattleScene (avoid circular dependency at parse time)
var _bind_card_input_fn: Callable   # BattleScene._bind_card_input(panel, card, zone_id)
var _on_empty_slot_fn: Callable     # BattleScene._on_empty_slot_input(event, slot_idx)
var _make_card_view_fn: Callable    # BattleScene._make_card_view(card, zone_id) -> PanelContainer

# Set once when the GameState is built
var _state: GameState
var _enemy_data: Dictionary

# Refreshed by BattleScene before each _refresh_all() call
var _targeting_active: bool = false
var _targeting_friendly: bool = false
var _dragged_card: Dictionary = {}
var _hand_drag_card: CardInstance = null
var _slot_targeting_spell: CardInstance = null
var _slot_select_card: CardInstance = null

const SPELL_EFFECT_LABELS: Dictionary = {
	"deal_damage_single":  "Deal [power] damage to a target",
	"deal_damage_all":     "Deal [power] damage to all enemy minions",
	"deal_damage_random":  "Deal [power] damage to a random enemy",
	"debuff_attack":       "Reduce all enemy minion attack by [power]",
	"destroy_low_hp":      "Destroy all enemy minions with [power] or less HP",
	"resurrect_last":      "Resurrect the last friendly minion that died",
	"heal_single":         "Restore [power] HP to a friendly minion",
	"heal_all":            "Restore [power] HP to all friendly minions",
	"shield_minion":       "Give [power] armor to a friendly minion",
	"buff_attack":         "Give a friendly minion +[power] attack",
	"lifesteal_hit":       "Deal [power] damage; restore that much HP to your hero",
	"mana_drain":          "Remove [power] mana from the enemy hero",
	"curse_minion":        "Reduce an enemy minion's attack and HP by [power]",
	"draw_card":           "Draw [power] card(s)",
	"bless_slot":          "Bless a board slot — the next minion placed there gains +[power] ATK",
	"ward_slot":           "Ward a board slot — the next minion placed there gains Shroud",
	"deal_damage_hero":    "Deal [power] damage to the enemy hero",
	"apply_poison_single": "Poison a minion for [power] damage per turn",
	"apply_poison_all":    "Poison all enemy minions for [power] damage per turn",
	"grant_surge":         "Give a friendly minion Surge",
	"double_attack":       "A friendly minion attacks twice this turn",
	"buff_attack_all":     "Give all your minions +[power] attack",
	"heal_hero":           "Restore [power] HP to your hero",
	"armor_hero":          "Give your hero [power] armor",
	"grant_ward":          "Give a friendly minion Ward",
	"grant_shroud":        "Give a friendly minion Shroud",
	"grant_ward_all":      "Give all your minions Ward",
	"bind_minion":         "Strip all keywords from an enemy minion",
	"buff_health_all":     "Give all your minions +[power] health",
	"enemy_discard":       "Enemy discards [power] random card(s)",
	"freeze_single":       "Freeze an enemy minion for 1 turn",
	"freeze_all":          "Freeze all enemy minions for 1 turn",
	"drain_hero":          "Deal [power] to the enemy hero; restore that much HP to yours",
	"stun_single":         "Stun an enemy minion for [power] turn(s)",
	"summon_token":        "Summon [power] 1/1 Skeleton token(s)",
	"deal_damage_all_full":"Deal [power] damage to all enemy minions and their hero",
}

const EMERGENCE_LABELS: Dictionary = {
	"emergence_deal_damage":   "Emergence: Deal [power] damage to the enemy hero",
	"emergence_heal_hero":     "Emergence: Restore [power] HP to your hero",
	"emergence_draw":          "Emergence: Draw [power] card(s)",
	"emergence_buff_friendly": "Emergence: Give a friendly minion +[power] attack",
	"emergence_apply_poison":  "Emergence: Poison a random enemy minion for [power]",
}

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

func set_battle_state(state: GameState, enemy_data: Dictionary) -> void:
	_state = state
	_enemy_data = enemy_data

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
					var style := StyleBoxFlat.new()
					style.corner_radius_top_left = 4
					style.corner_radius_top_right = 4
					style.corner_radius_bottom_left = 4
					style.corner_radius_bottom_right = 4
					panel.add_theme_stylebox_override("panel", style)
					panel.set_meta("card_style", style)
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

## Single source of truth for battle card / board slot size (GID-119 / TID-449).
## ~13.5% vh wide ≈ a real thumb target on a landscape phone.
func card_size() -> Vector2:
	return Vector2(_vh * 0.135, _vh * 0.24)

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
	var lbl := Label.new()
	lbl.text = str(slot_idx + 1)
	lbl.add_theme_font_size_override("font_size", _font(0.030))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.modulate = Color(0.45, 0.45, 0.55, 0.8) if is_enemy else Color(0.5, 0.5, 0.6)
	panel.add_child(lbl)
	for conn in panel.gui_input.get_connections():
		panel.gui_input.disconnect(conn["callable"])
	if not is_enemy:
		var idx: int = slot_idx
		panel.gui_input.connect(func(ev: InputEvent) -> void: _on_empty_slot_fn.call(ev, idx))

func _apply_empty_slot_style(panel: PanelContainer, _slot_idx: int, zone_id: String, enh: Dictionary) -> void:
	var style: StyleBoxFlat = panel.get_meta("card_style", null) as StyleBoxFlat
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
	elif _hand_drag_card != null and not is_enemy and _state.players[0].can_play(_hand_drag_card):
		style.border_color = Color(0.3, 1.0, 0.5, 1.0)
		style.set_border_width_all(3)
	elif _slot_select_card != null and not is_enemy:
		style.border_color = Color(0.3, 1.0, 0.5, 1.0)
		style.set_border_width_all(3)
	else:
		style.border_color = Color(0.35, 0.35, 0.42, 0.7) if is_enemy else Color(0.4, 0.4, 0.5, 0.8)

func _apply_slot_enhancement_border(panel: Control, enh: Dictionary) -> void:
	var style: StyleBoxFlat = panel.get_meta("card_style", null) as StyleBoxFlat
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

# -------------------------------------------------------------------------
# Card view building
# -------------------------------------------------------------------------

func format_card_stats(card: CardInstance, cost: int) -> String:
	if card.card_class == "spell":
		return "(%d)" % cost
	return "%d/%d  (%d)" % [card.attack, card.health, cost]

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
	var vbox: VBoxContainer = panel.get_child(0) as VBoxContainer
	var name_lbl: Label = vbox.get_node_or_null("NameLabel") as Label if vbox else null
	var is_board_zone: bool = (zone_id == "board" or zone_id == "enemy_board")
	if not vbox or not name_lbl:
		for child in panel.get_children():
			child.queue_free()
		panel.add_child(build_card_vbox(card, is_board_zone))
	else:
		name_lbl.text = card.name
		var stats_lbl: Label = vbox.get_node_or_null("StatsLabel") as Label
		if stats_lbl:
			var eff_cost: int = _state.players[0].effective_cost(card) if zone_id == "hand" else card.cost
			stats_lbl.text = format_card_stats(card, eff_cost)
			if zone_id == "hand" and eff_cost < card.cost:
				stats_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			else:
				stats_lbl.remove_theme_color_override("font_color")
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
		var tmpl: String = str(SPELL_EFFECT_LABELS.get(card.spell_effect, card.spell_effect))
		return tmpl.replace("[power]", str(card.spell_power))
	if card.emergence_effect != "":
		var tmpl: String = str(EMERGENCE_LABELS.get(card.emergence_effect, card.emergence_effect))
		return tmpl.replace("[power]", str(card.emergence_power))
	return ""

func get_card_ability_color(card: CardInstance) -> Color:
	if card.emergence_effect != "":
		return Color(1.0, 0.85, 0.4)
	return Color(0.6, 1.0, 0.8)

func build_card_vbox(card: CardInstance, with_status_row: bool = false) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = card.name
	name_lbl.add_theme_font_size_override("font_size", _font(0.020))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tmpl_for_illus: Dictionary = CardRegistry.get_template_for_face(card.template_id, card.active_face)
	var illus: Texture2D = tmpl_for_illus.get("illustration") as Texture2D
	if illus != null:
		var art := TextureRect.new()
		art.name = "IllustrationRect"
		art.texture = illus
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(0.0, _vh * 0.07)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vbox.add_child(art)
	var stats_lbl := Label.new()
	stats_lbl.name = "StatsLabel"
	stats_lbl.text = format_card_stats(card, card.cost)
	stats_lbl.add_theme_font_size_override("font_size", _font(0.022))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	desc_lbl.add_theme_font_size_override("font_size", _font(0.017))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)
	vbox.add_child(stats_lbl)
	vbox.add_child(desc_lbl)
	var kw_row := HBoxContainer.new()
	kw_row.name = "KeywordRow"
	kw_row.alignment = BoxContainer.ALIGNMENT_CENTER
	update_keyword_badges(kw_row, card)
	vbox.add_child(kw_row)
	if with_status_row:
		var sr := HBoxContainer.new()
		sr.name = "StatusRow"
		_fx.update_status_icons_card(sr, card)
		vbox.add_child(sr)
	return vbox

func apply_card_style(panel: PanelContainer, card: CardInstance, zone_id: String) -> void:
	var style: StyleBoxFlat = panel.get_meta("card_style", null) as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override("panel", style)
		panel.set_meta("card_style", style)
	style.border_width_top = 0
	style.border_width_bottom = 0
	style.border_width_left = 0
	style.border_width_right = 0
	var tmpl: Dictionary = CardRegistry.get_template_for_face(card.template_id, card.active_face)
	style.bg_color = tmpl.get("color", Color(0.3, 0.3, 0.3)) if not tmpl.is_empty() else Color(0.3, 0.3, 0.3)
	if zone_id == "hand" and not _state.players[0].can_play(card):
		style.bg_color = style.bg_color.darkened(0.5)
	elif zone_id == "hand" and _state.players[0].effective_cost(card) < card.cost:
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
		var valid_targets: Array[CardInstance] = get_ward_valid_targets(_state.players[1].board.get_cards())
		if not valid_targets.has(card):
			style.bg_color = style.bg_color.darkened(0.45)
	elif zone_id == "board" and not _dragged_card.is_empty() and _dragged_card.get("card") == card:
		style.border_color = Color.YELLOW
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_width_left = 3
		style.border_width_right = 3
	# Non-color targeting cue (GID-119 / TID-451): colored borders alone fail
	# colorblind players, so every valid target also carries an explicit marker.
	var show_mark: bool = false
	if zone_id == "enemy_board" and _targeting_active and not _targeting_friendly:
		show_mark = true
	elif zone_id == "board" and _targeting_active and _targeting_friendly:
		show_mark = true
	elif zone_id == "enemy_board" and not _dragged_card.is_empty():
		var mark_targets: Array[CardInstance] = get_ward_valid_targets(_state.players[1].board.get_cards())
		show_mark = mark_targets.has(card)
	_target_mark(panel, _font(0.018)).visible = show_mark

## Lazily attaches a centered "◎ TARGET" overlay label to a panel. Overlay, not
## a vbox row — it must never shift the card layout when it toggles.
func _target_mark(panel: Control, font_sz: int) -> Label:
	var mark: Label = panel.get_node_or_null("TargetMark") as Label
	if mark == null:
		mark = Label.new()
		mark.name = "TargetMark"
		mark.text = "◎ TARGET"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_theme_font_size_override("font_size", font_sz)
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
	var font_sz: int = _font(0.020)
	for i in range(kw_keys.size()):
		var kw: String = kw_keys[i]
		if not card.keywords.has(kw):
			continue
		if kw == Keywords.SHROUD and not card.shroud_active:
			continue
		var lbl := Label.new()
		lbl.text = kw_labels[i]
		lbl.add_theme_font_size_override("font_size", font_sz)
		lbl.add_theme_color_override("font_color", kw_colors[i])
		hbox.add_child(lbl)

# -------------------------------------------------------------------------
# Hero view building
# -------------------------------------------------------------------------

## hand_count: opponent hand size shown on the enemy panel (GID-119 / TID-448 —
## replaces the face-down enemy hand row). -1 hides the line (player panel).
func refresh_hero(hero_node: Node, hero: HeroState, is_enemy: bool, hand_count: int = -1) -> void:
	var vbox: VBoxContainer = hero_node.get_child(0) as VBoxContainer if hero_node.get_child_count() > 0 else null
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", int(_vh * 0.004))

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
		var hero_sr := HBoxContainer.new()
		hero_sr.name = "StatusRow"
		vbox.add_child(hero_sr)
		hero_node.add_child(vbox)

	var hp_lbl: Label = vbox.get_node("HPLabel") as Label
	hp_lbl.text = "HP  %d / %d" % [hero.health, hero.max_health]
	var bar: ProgressBar = vbox.get_node("HPBar") as ProgressBar
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
	var ward_blocks_hero: bool = false
	if is_enemy and not _dragged_card.is_empty():
		for ec: CardInstance in _state.players[1].board.get_cards():
			if ec.keywords.has(Keywords.WARD):
				ward_blocks_hero = true
				break
	var is_attack_targetable: bool = is_enemy and not _dragged_card.is_empty() and not ward_blocks_hero
	var is_spell_targetable: bool = is_enemy and _targeting_active and not _targeting_friendly
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
