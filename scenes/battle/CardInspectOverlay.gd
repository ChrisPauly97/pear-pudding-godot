extends "res://scenes/ui/BaseOverlay.gd"

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")

# Mirrors BattleScene._SPELL_EFFECT_LABELS and _EMERGENCE_LABELS (TID-140, TID-142). Keep both in sync.
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
}

const _EMERGENCE_LABELS: Dictionary = {
	"emergence_deal_damage":   "Emergence: Deal [power] damage to the enemy hero",
	"emergence_heal_hero":     "Emergence: Restore [power] HP to your hero",
	"emergence_draw":          "Emergence: Draw [power] card(s)",
	"emergence_buff_friendly": "Emergence: Give a friendly minion +[power] attack",
	"emergence_apply_poison":  "Emergence: Poison a random enemy minion for [power]",
}

var _card: CardInstance = null

func _ready() -> void:
	super._ready()

func show_card(card: CardInstance) -> void:
	_card = card
	_build_ui()

func _build_ui() -> void:
	_build_backdrop(0.72, true)

	var panel_w: float = _vw * 0.6
	var panel_h: float = _vh * 0.62
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var inner := _build_margin_vbox(panel, 0.025, 0.016)

	# Card color bar
	var color_bar := ColorRect.new()
	color_bar.custom_minimum_size = Vector2(0, _vh * 0.008)
	if _card != null:
		var tmpl := CardRegistry.get_template(_card.template_id)
		color_bar.color = tmpl.get("color", Color(0.4, 0.4, 0.4)) if not tmpl.is_empty() else Color(0.4, 0.4, 0.4)
	inner.add_child(color_bar)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = _card.name if _card != null else "?"
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.038))
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(name_lbl)

	# Class / type row
	var class_lbl := Label.new()
	var class_text: String = ""
	if _card != null:
		class_text = _card.card_class.capitalize()
		if _card.card_class == "spell":
			var tmpl := CardRegistry.get_template(_card.template_id)
			var mt: String = str(tmpl.get("magic_type", ""))
			var mb_val: String = str(tmpl.get("magic_branch", ""))
			if mt != "":
				class_text += "  ·  " + mt.capitalize()
			if mb_val != "":
				class_text += " / " + mb_val.capitalize()
	class_lbl.text = class_text
	class_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	class_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(class_lbl)

	# Stats row
	var stats_lbl := Label.new()
	if _card != null and _card.card_class == "minion":
		stats_lbl.text = "Cost %d   ·   %d / %d" % [_card.cost, _card.attack, _card.health]
	elif _card != null:
		stats_lbl.text = "Cost %d" % _card.cost
	stats_lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
	stats_lbl.add_theme_color_override("font_color", Color.WHITE)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(stats_lbl)

	# Divider
	var sep := HSeparator.new()
	inner.add_child(sep)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = _card.description if _card != null else ""
	desc_lbl.add_theme_font_size_override("font_size", int(_vh * 0.024))
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc_lbl)

	# Spell effect plain-english
	if _card != null and _card.card_class == "spell" and _card.spell_effect != "":
		var effect_lbl := Label.new()
		var template_str: String = _SPELL_EFFECT_LABELS.get(_card.spell_effect, _card.spell_effect)
		effect_lbl.text = template_str.replace("[power]", str(_card.spell_power))
		effect_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		effect_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
		effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(effect_lbl)

	# Keyword descriptions (minion keywords only)
	if _card != null and not _card.keywords.is_empty():
		var kw_sep := HSeparator.new()
		inner.add_child(kw_sep)
		var kw_descs: Dictionary = {
			Keywords.WARD:   "Enemy attacks must target this minion first.",
			Keywords.SURGE:  "Can attack the turn it is summoned.",
			Keywords.SHROUD: "Absorbs the first hit.",
		}
		for kw: String in _card.keywords:
			var base_desc: String = str(kw_descs.get(kw, kw))
			if kw == Keywords.SHROUD:
				base_desc += " (" + ("Active" if _card.shroud_active else "Consumed") + ")"
			var kw_lbl := Label.new()
			kw_lbl.text = kw.capitalize() + " — " + base_desc
			kw_lbl.add_theme_font_size_override("font_size", int(_vh * 0.02))
			kw_lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
			kw_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			kw_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			inner.add_child(kw_lbl)

	# Emergence effect (minion on-play ability)
	if _card != null and _card.emergence_effect != "":
		var em_sep := HSeparator.new()
		inner.add_child(em_sep)
		var em_lbl := Label.new()
		var em_tmpl: String = str(_EMERGENCE_LABELS.get(_card.emergence_effect, _card.emergence_effect))
		em_lbl.text = em_tmpl.replace("[power]", str(_card.emergence_power))
		em_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		em_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		em_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		em_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(em_lbl)

	# Current status effects (if any)
	if _card != null:
		var effects: Array[String] = ["poison", "armor", "freeze", "stun"]
		var colors: Array[Color] = [Color.GREEN, Color.CORNFLOWER_BLUE, Color.CYAN, Color.YELLOW]
		var labels: Array[String] = ["Poison", "Armor", "Freeze", "Stun"]
		for i in range(effects.size()):
			if not _card.has_status(effects[i]):
				continue
			var st_lbl := Label.new()
			st_lbl.text = "%s: %d" % [labels[i], _card.get_status_value(effects[i])]
			st_lbl.add_theme_font_size_override("font_size", int(_vh * 0.02))
			st_lbl.add_theme_color_override("font_color", colors[i])
			st_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			inner.add_child(st_lbl)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.055)
	close_btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	close_btn.pressed.connect(_close)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(close_btn)
	inner.add_child(btn_row)

func _close() -> void:
	closed.emit()
	queue_free()
