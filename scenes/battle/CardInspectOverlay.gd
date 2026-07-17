extends "res://scenes/ui/BaseOverlay.gd"

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")

# Mirrors CardViewBuilder.SPELL_EFFECT_LABELS and EMERGENCE_LABELS (TID-140, TID-142). Keep both in sync.
const _SPELL_EFFECT_LABELS: Dictionary = {
	"deal_damage_single":  "Deal [power] damage to one target",
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

const _EMERGENCE_LABELS: Dictionary = {
	"emergence_deal_damage":   "Emergence: Deal [power] damage to the enemy hero",
	"emergence_heal_hero":     "Emergence: Restore [power] HP to your hero",
	"emergence_draw":          "Emergence: Draw [power] card(s)",
	"emergence_buff_friendly": "Emergence: Give a friendly minion +[power] attack",
	"emergence_apply_poison":  "Emergence: Poison a random enemy minion for [power]",
}

var _card: CardInstance = null
# Multiplier from the "text_scale" accessibility setting (GID-119 / TID-451).
var _ts: float = 1.0

func _ready() -> void:
	super._ready()

func _font(pct: float) -> int:
	return int(_vh * pct * _ts)

func show_card(card: CardInstance) -> void:
	_card = card
	_ts = clampf(float(SceneManager.save_manager.get_setting("text_scale", 1.0)), 0.5, 2.0)
	_build_ui()

func _build_ui() -> void:
	_build_backdrop(0.72, true)

	var is_dual: bool = _card != null and _card.dual_card_id != ""

	if is_dual:
		_build_dual_face_ui()
	else:
		_build_single_face_ui()

# Single-face layout (existing cards and non-dual side of display)
func _build_single_face_ui() -> void:
	var panel_w: float = _vw * 0.6
	var panel_h: float = _vh * 0.62
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var inner := _build_margin_vbox(panel, 0.025, 0.016)
	_build_face_body(inner, CardRegistry.get_template(_card.template_id if _card != null else ""), _card, true)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.055)
	close_btn.add_theme_font_size_override("font_size", _font(0.025))
	close_btn.pressed.connect(_close)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(close_btn)
	inner.add_child(btn_row)

# Dual-face layout: Light and Dark faces side by side.
func _build_dual_face_ui() -> void:
	var total_w: float = minf(_vw * 0.92, _vh * 1.2)
	var panel_h: float = _vh * 0.78
	var panel := _build_centered_panel(total_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", int(_vh * 0.012))
	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left",   int(_vh * 0.018))
	outer_margin.add_theme_constant_override("margin_right",  int(_vh * 0.018))
	outer_margin.add_theme_constant_override("margin_top",    int(_vh * 0.018))
	outer_margin.add_theme_constant_override("margin_bottom", int(_vh * 0.018))
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(outer_margin)
	outer_margin.add_child(outer_vbox)

	# Header
	var header_lbl := Label.new()
	header_lbl.text = "Dual-Faced Card"
	header_lbl.add_theme_font_size_override("font_size", _font(0.028))
	header_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(header_lbl)

	# Two face panels side by side
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(_vh * 0.012))
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(hbox)

	var light_tmpl: Dictionary = CardRegistry.get_template_for_face(_card.dual_card_id, "light")
	var dark_tmpl: Dictionary = CardRegistry.get_template_for_face(_card.dual_card_id, "dark")
	var active: String = _card.active_face if _card.active_face != "" else "light"

	_build_face_panel(hbox, light_tmpl, _card, active == "light", "Light")
	_build_face_panel(hbox, dark_tmpl, _card, active == "dark", "Dark")

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.055)
	close_btn.add_theme_font_size_override("font_size", _font(0.025))
	close_btn.pressed.connect(_close)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(close_btn)
	outer_vbox.add_child(btn_row)

func _build_face_panel(parent: HBoxContainer, tmpl: Dictionary, card: CardInstance, is_active: bool, face_label: String) -> void:
	var face_panel := PanelContainer.new()
	face_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	face_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.08, 0.08, 0.18, 0.9)
	fs.corner_radius_top_left = 6
	fs.corner_radius_top_right = 6
	fs.corner_radius_bottom_left = 6
	fs.corner_radius_bottom_right = 6
	if is_active:
		fs.border_color = Color(0.4, 1.0, 0.6)
		fs.set_border_width_all(3)
	face_panel.add_theme_stylebox_override("panel", fs)
	parent.add_child(face_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vh * 0.012))
	margin.add_theme_constant_override("margin_right",  int(_vh * 0.012))
	margin.add_theme_constant_override("margin_top",    int(_vh * 0.012))
	margin.add_theme_constant_override("margin_bottom", int(_vh * 0.012))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	face_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(_vh * 0.006))
	margin.add_child(vbox)

	# Face tag
	var tag_lbl := Label.new()
	tag_lbl.text = face_label + (" (Active)" if is_active else "")
	tag_lbl.add_theme_font_size_override("font_size", _font(0.019))
	tag_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6) if is_active else Color(0.65, 0.65, 0.75))
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tag_lbl)

	_build_face_body(vbox, tmpl, card if is_active else null, false)

func _build_face_body(container: VBoxContainer, tmpl: Dictionary, card: CardInstance, show_status: bool) -> void:
	# Color bar
	var color_bar := ColorRect.new()
	color_bar.custom_minimum_size = Vector2(0, _vh * 0.006)
	color_bar.color = tmpl.get("color", Color(0.4, 0.4, 0.4)) if not tmpl.is_empty() else Color(0.4, 0.4, 0.4)
	container.add_child(color_bar)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = str(tmpl.get("name", "?")) if not tmpl.is_empty() else (card.name if card != null else "?")
	name_lbl.add_theme_font_size_override("font_size", _font(0.030))
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_lbl)

	# Class / type row
	var cc: String = str(tmpl.get("card_class", "")) if not tmpl.is_empty() else (card.card_class if card != null else "")
	var mt: String = str(tmpl.get("magic_type", "")) if not tmpl.is_empty() else ""
	var mb_val: String = str(tmpl.get("magic_branch", "")) if not tmpl.is_empty() else ""
	var class_text: String = cc.capitalize()
	if cc == "spell":
		if mt != "":
			class_text += "  ·  " + mt.capitalize()
		if mb_val != "":
			class_text += " / " + mb_val.capitalize()
	var class_lbl := Label.new()
	class_lbl.text = class_text
	class_lbl.add_theme_font_size_override("font_size", _font(0.018))
	class_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(class_lbl)

	# Stats
	var cost_v: int = int(tmpl.get("cost", 0)) if not tmpl.is_empty() else (card.cost if card != null else 0)
	var atk_v: int = int(tmpl.get("attack", 0)) if not tmpl.is_empty() else (card.attack if card != null else 0)
	var hp_v: int = int(tmpl.get("health", 0)) if not tmpl.is_empty() else (card.health if card != null else 0)
	var stats_lbl := Label.new()
	if cc == "minion":
		stats_lbl.text = "Cost %d   ·   %d / %d" % [cost_v, atk_v, hp_v]
	else:
		stats_lbl.text = "Cost %d" % cost_v
	stats_lbl.add_theme_font_size_override("font_size", _font(0.022))
	stats_lbl.add_theme_color_override("font_color", Color.WHITE)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(stats_lbl)

	var sep := HSeparator.new()
	container.add_child(sep)

	# Description
	var desc: String = str(tmpl.get("description", "")) if not tmpl.is_empty() else (card.description if card != null else "")
	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", _font(0.019))
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(desc_lbl)

	# Spell effect
	var se: String = str(tmpl.get("spell_effect", "")) if not tmpl.is_empty() else (card.spell_effect if card != null else "")
	var sp: int = int(tmpl.get("spell_power", 0)) if not tmpl.is_empty() else (card.spell_power if card != null else 0)
	if cc == "spell" and se != "":
		var effect_lbl := Label.new()
		var template_str: String = _SPELL_EFFECT_LABELS.get(se, se)
		effect_lbl.text = template_str.replace("[power]", str(sp))
		effect_lbl.add_theme_font_size_override("font_size", _font(0.018))
		effect_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
		effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(effect_lbl)

	# Keywords
	var kws_raw = tmpl.get("keywords", []) if not tmpl.is_empty() else (card.keywords if card != null else [])
	var kws: Array[String] = []
	kws.assign(kws_raw)
	if not kws.is_empty():
		var kw_sep := HSeparator.new()
		container.add_child(kw_sep)
		var kw_descs: Dictionary = {
			Keywords.WARD:   "Enemy attacks must target this minion first.",
			Keywords.SURGE:  "Can attack the turn it is summoned.",
			Keywords.SHROUD: "Absorbs the first hit.",
		}
		for kw: String in kws:
			var base_desc: String = str(kw_descs.get(kw, kw))
			if kw == Keywords.SHROUD and card != null and show_status:
				base_desc += " (" + ("Active" if card.shroud_active else "Consumed") + ")"
			var kw_lbl := Label.new()
			kw_lbl.text = kw.capitalize() + " — " + base_desc
			kw_lbl.add_theme_font_size_override("font_size", _font(0.017))
			kw_lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
			kw_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			kw_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			container.add_child(kw_lbl)

	# Emergence
	var ee: String = str(tmpl.get("emergence_effect", "")) if not tmpl.is_empty() else (card.emergence_effect if card != null else "")
	var ep: int = int(tmpl.get("emergence_power", 0)) if not tmpl.is_empty() else (card.emergence_power if card != null else 0)
	if ee != "":
		var em_sep := HSeparator.new()
		container.add_child(em_sep)
		var em_lbl := Label.new()
		var em_tmpl: String = str(_EMERGENCE_LABELS.get(ee, ee))
		em_lbl.text = em_tmpl.replace("[power]", str(ep))
		em_lbl.add_theme_font_size_override("font_size", _font(0.018))
		em_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		em_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		em_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(em_lbl)

	# Status effects (only for the active card instance)
	if card != null and show_status:
		var effects: Array[String] = ["poison", "armor", "freeze", "stun"]
		var colors: Array[Color] = [Color.GREEN, Color.CORNFLOWER_BLUE, Color.CYAN, Color.YELLOW]
		var labels: Array[String] = ["Poison", "Armor", "Freeze", "Stun"]
		for i in range(effects.size()):
			if not card.has_status(effects[i]):
				continue
			var st_lbl := Label.new()
			st_lbl.text = "%s: %d" % [labels[i], card.get_status_value(effects[i])]
			st_lbl.add_theme_font_size_override("font_size", _font(0.019))
			st_lbl.add_theme_color_override("font_color", colors[i])
			st_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			container.add_child(st_lbl)

func _close() -> void:
	closed.emit()
	queue_free()
