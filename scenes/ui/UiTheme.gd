extends RefCounted
## Project-wide UI theme (GID-131 / TID-507).
##
## Before this every panel and button was Godot's default flat grey box. The
## theme is built in code (no .tres to keep in sync) and `install()` merges it
## into the engine default theme at SceneManager startup, so every Control
## falls back to it — a theme on the root Window would not reach Controls under
## a CanvasLayer (HUD, popups, overlays). Explicit `add_theme_*_override` calls
## and any Control/`theme` set lower down still win. Pixel values are in the 1920×1080
## canvas_items base resolution, so they scale with the window.

const _BODY_FONT = preload("res://assets/fonts/Nunito-Bold.woff2")
const _TITLE_FONT = preload("res://assets/fonts/Cinzel-Bold.woff2")
## Theme type variation for headings (Cinzel); `UiUtil.make_title_label` uses it.
const TITLE_VARIATION := "TitleLabel"

const INK := Color(0.95, 0.92, 0.84)
const INK_DIM := Color(0.62, 0.60, 0.56)
const INK_HOVER := Color(1.0, 0.95, 0.74)
const GOLD := Color(0.66, 0.53, 0.29)
const GOLD_BRIGHT := Color(0.95, 0.78, 0.40)
const PANEL_BG := Color(0.09, 0.10, 0.15, 0.95)
const BUTTON_BG := Color(0.18, 0.20, 0.30)
const BUTTON_HOVER := Color(0.25, 0.28, 0.42)
const BUTTON_PRESSED := Color(0.12, 0.13, 0.21)
const BUTTON_DISABLED := Color(0.14, 0.14, 0.18, 0.75)
const FIELD_BG := Color(0.06, 0.07, 0.11, 0.95)
const ACCENT := Color(0.36, 0.62, 0.95)

const PANEL_RADIUS: int = 14
const BUTTON_RADIUS: int = 10

static var _installed: bool = false


static func _box(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_w: int = 0,
		pad_h: float = 12.0, pad_v: float = 8.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.anti_aliasing = true
	return sb


static func panel_style() -> StyleBoxFlat:
	var sb := _box(PANEL_BG, PANEL_RADIUS, GOLD, 2, 18.0, 14.0)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func _button_styles(t: Theme, type: String) -> void:
	t.set_stylebox("normal", type, _box(BUTTON_BG, BUTTON_RADIUS, GOLD.darkened(0.25), 2))
	t.set_stylebox("hover", type, _box(BUTTON_HOVER, BUTTON_RADIUS, GOLD, 2))
	t.set_stylebox("pressed", type, _box(BUTTON_PRESSED, BUTTON_RADIUS, GOLD_BRIGHT, 2))
	t.set_stylebox("hover_pressed", type, _box(BUTTON_PRESSED, BUTTON_RADIUS, GOLD_BRIGHT, 2))
	t.set_stylebox("disabled", type, _box(BUTTON_DISABLED, BUTTON_RADIUS, Color(0.3, 0.3, 0.34, 0.6), 1))
	var focus := _box(Color(0, 0, 0, 0), BUTTON_RADIUS + 2, GOLD_BRIGHT, 2)
	focus.draw_center = false
	t.set_stylebox("focus", type, focus)
	t.set_color("font_color", type, INK)
	t.set_color("font_hover_color", type, INK_HOVER)
	t.set_color("font_pressed_color", type, GOLD_BRIGHT)
	t.set_color("font_hover_pressed_color", type, GOLD_BRIGHT)
	t.set_color("font_focus_color", type, INK)
	t.set_color("font_disabled_color", type, INK_DIM)


## Merges the project theme into ThemeDB's default theme (once).
static func install() -> void:
	if _installed:
		return
	var project := build()
	var base: Theme = ThemeDB.get_default_theme()
	base.merge_with(project)
	# merge_with leaves the default font alone; set it explicitly (Controls
	# without a font item fall back to ThemeDB.fallback_font).
	base.default_font = project.default_font
	ThemeDB.fallback_font = project.default_font
	_installed = true


## Fonts (GID-132 / TID-509), both SIL OFL 1.1 (assets/fonts/OFL-*.txt,
## CREDITS.md). Latin subset only, so each falls back to the engine font for
## symbols and anything outside Latin.
static func body_font() -> Font:
	return _with_fallback(_BODY_FONT)


static func title_font() -> Font:
	return _with_fallback(_TITLE_FONT)


static func _with_fallback(f: FontFile) -> Font:
	if ThemeDB.fallback_font != null and not f.fallbacks.has(ThemeDB.fallback_font):
		var fb: Array[Font] = f.fallbacks.duplicate()
		fb.append(ThemeDB.fallback_font)
		f.fallbacks = fb
	return f


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.set_type_variation(TITLE_VARIATION, "Label")
	t.set_font("font", TITLE_VARIATION, title_font())
	t.set_color("font_color", TITLE_VARIATION, GOLD_BRIGHT.lerp(INK, 0.35))
	t.set_color("font_shadow_color", TITLE_VARIATION, Color(0, 0, 0, 0.55))
	for type: String in ["Panel", "PanelContainer", "PopupPanel", "PopupMenu", "TooltipPanel", "AcceptDialog"]:
		t.set_stylebox("panel", type, panel_style())
	for type: String in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		_button_styles(t, type)
	# Check boxes and toggles read as text rows, not framed buttons.
	for type: String in ["CheckBox", "CheckButton"]:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(state, type, _box(Color(0, 0, 0, 0), BUTTON_RADIUS, Color(0, 0, 0, 0), 0, 6.0, 4.0))

	t.set_color("font_color", "Label", INK)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 2)

	for type: String in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_stylebox("normal", type, _box(FIELD_BG, 8, GOLD.darkened(0.4), 1, 10.0, 6.0))
		t.set_stylebox("focus", type, _box(FIELD_BG, 8, GOLD_BRIGHT, 2, 10.0, 6.0))
		t.set_color("font_color", type, INK)
		t.set_color("caret_color", type, GOLD_BRIGHT)

	t.set_stylebox("background", "ProgressBar", _box(FIELD_BG, 8, GOLD.darkened(0.4), 1, 0.0, 0.0))
	t.set_stylebox("fill", "ProgressBar", _box(ACCENT, 8, Color(0, 0, 0, 0), 0, 0.0, 0.0))
	t.set_color("font_color", "ProgressBar", INK)

	for type: String in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, _box(FIELD_BG, 6, GOLD.darkened(0.4), 1, 0.0, 4.0))
		t.set_stylebox("grabber_area", type, _box(ACCENT, 6, Color(0, 0, 0, 0), 0, 0.0, 4.0))
		t.set_stylebox("grabber_area_highlight", type, _box(ACCENT.lightened(0.2), 6, Color(0, 0, 0, 0), 0, 0.0, 4.0))

	for type: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, _box(Color(0, 0, 0, 0.25), 6, Color(0, 0, 0, 0), 0, 4.0, 4.0))
		t.set_stylebox("grabber", type, _box(GOLD.darkened(0.2), 6, Color(0, 0, 0, 0), 0, 4.0, 4.0))
		t.set_stylebox("grabber_highlight", type, _box(GOLD, 6, Color(0, 0, 0, 0), 0, 4.0, 4.0))
		t.set_stylebox("grabber_pressed", type, _box(GOLD_BRIGHT, 6, Color(0, 0, 0, 0), 0, 4.0, 4.0))

	t.set_stylebox("tab_selected", "TabBar", _box(BUTTON_HOVER, BUTTON_RADIUS, GOLD_BRIGHT, 2))
	t.set_stylebox("tab_unselected", "TabBar", _box(BUTTON_BG, BUTTON_RADIUS, GOLD.darkened(0.3), 1))
	t.set_stylebox("tab_hovered", "TabBar", _box(BUTTON_HOVER, BUTTON_RADIUS, GOLD, 1))
	t.set_stylebox("tab_selected", "TabContainer", _box(BUTTON_HOVER, BUTTON_RADIUS, GOLD_BRIGHT, 2))
	t.set_stylebox("tab_unselected", "TabContainer", _box(BUTTON_BG, BUTTON_RADIUS, GOLD.darkened(0.3), 1))
	t.set_stylebox("panel", "TabContainer", panel_style())

	var sep := StyleBoxLine.new()
	sep.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.45)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 12)
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK_HOVER)
	t.set_stylebox("hover", "PopupMenu", _box(BUTTON_HOVER, 8))
	return t
