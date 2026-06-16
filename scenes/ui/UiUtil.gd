extends Object

# ---------------------------------------------------------------------------
# Rarity
# ---------------------------------------------------------------------------

static func rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color(0.80, 0.80, 0.80)
		"rare":      return Color(0.20, 0.50, 1.00)
		"epic":      return Color(0.70, 0.20, 1.00)
		"legendary": return Color(1.00, 0.75, 0.00)
	return Color(0.80, 0.80, 0.80)

static func rarity_badge(rarity: String) -> String:
	match rarity:
		"common":    return "[C]"
		"rare":      return "[R]"
		"epic":      return "[E]"
		"legendary": return "[L]"
	return "[?]"

# ---------------------------------------------------------------------------
# Weapon / equipment effect summary
# ---------------------------------------------------------------------------

static func effect_summary(battle_effect_type: String, battle_effect_value: int,
		injected_card_count: int = 0, injected_card_id: String = "") -> String:
	match battle_effect_type:
		"deck_inject":   return "Inject %d× %s" % [injected_card_count, injected_card_id]
		"starting_mana": return "+%d starting mana" % battle_effect_value
		"starting_hp":   return "+%d starting HP" % battle_effect_value
		"passive_atk":   return "+%d hero ATK" % battle_effect_value
	return battle_effect_type

# ---------------------------------------------------------------------------
# Label factories
# ---------------------------------------------------------------------------

static func make_title_label(text: String, vh: float) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(vh * 0.038))
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

static func make_body_label(text: String, vh: float) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(vh * 0.022))
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	return lbl

static func make_separator() -> HSeparator:
	return HSeparator.new()

static func make_close_button(vh: float, on_pressed: Callable) -> Button:
	var btn := Button.new()
	btn.text = "Close"
	btn.custom_minimum_size = Vector2(vh * 0.22, vh * 0.065)
	btn.add_theme_font_size_override("font_size", int(vh * 0.028))
	btn.pressed.connect(on_pressed)
	return btn
