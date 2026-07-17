extends Object

const _UiFx = preload("res://scenes/ui/UiFx.gd")

# ---------------------------------------------------------------------------
# Display safe area (GID-120 / TID-455)
# ---------------------------------------------------------------------------

## Safe-area insets in canvas coordinates: {left, top, right, bottom} floats.
## Landscape phones put camera cutouts / rounded corners at the screen edges;
## edge-anchored UI adds these to stay tappable. Zero on displays without
## cutouts (desktop, editor, headless).
static func safe_insets(viewport: Viewport) -> Dictionary:
	var zero: Dictionary = {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if viewport == null:
		return zero
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if screen_size.x <= 0 or screen_size.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return zero
	var vp_size: Vector2 = viewport.get_visible_rect().size
	var sx: float = vp_size.x / float(screen_size.x)
	var sy: float = vp_size.y / float(screen_size.y)
	return {
		"left":   maxf(0.0, float(safe.position.x)) * sx,
		"top":    maxf(0.0, float(safe.position.y)) * sy,
		"right":  maxf(0.0, float(screen_size.x - safe.position.x - safe.size.x)) * sx,
		"bottom": maxf(0.0, float(screen_size.y - safe.position.y - safe.size.y)) * sy,
	}

# ---------------------------------------------------------------------------
# Scroll-safe taps (GID-120 / TID-454)
# ---------------------------------------------------------------------------

## Connects `callback` to fire only on a clean tap of `btn`. Buttons capture the
## pointer once pressed, so a scroll gesture starting on a button neither
## scrolls the list nor differs from a tap on release. This guard drops the
## press when the finger travels beyond `slop`, and (when `scroll` is given)
## forwards the pan so tile-started drags still scroll the list.
static func bind_scroll_safe_press(btn: BaseButton, callback: Callable,
		scroll: ScrollContainer = null, slop: float = 14.0) -> void:
	var start := [Vector2.ZERO]
	var scroll_start := [0]
	var moved := [false]
	btn.button_down.connect(func() -> void:
		start[0] = btn.get_global_mouse_position()
		scroll_start[0] = scroll.scroll_vertical if scroll != null else 0
		moved[0] = false)
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion and btn.button_pressed:
			var pos: Vector2 = btn.get_global_mouse_position()
			if moved[0] or pos.distance_to(start[0] as Vector2) > slop:
				moved[0] = true
				if scroll != null:
					var dy: float = pos.y - (start[0] as Vector2).y
					scroll.scroll_vertical = int(scroll_start[0]) - int(dy))
	btn.pressed.connect(func() -> void:
		if not bool(moved[0]):
			callback.call())

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
	_UiFx.attach(btn)
	return btn

# ---------------------------------------------------------------------------
# Rarity selector: 4 connected buttons [C][R][E][L].
# on_select receives the chosen rarity string.
# ---------------------------------------------------------------------------

static func make_rarity_selector(current_rarity: String, ref: float, on_select: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for rarity: String in IsoConst.RARITY_ORDER:
		var btn := Button.new()
		btn.text = rarity_badge(rarity)
		btn.custom_minimum_size = Vector2(ref * 0.10, ref * 0.058)
		btn.add_theme_font_size_override("font_size", int(ref * 0.022))
		if rarity == current_rarity:
			btn.modulate = rarity_color(rarity)
		else:
			btn.modulate = Color(0.50, 0.50, 0.50)
		btn.pressed.connect(on_select.bind(rarity))
		row.add_child(btn)
		_UiFx.attach(btn)
	return row
