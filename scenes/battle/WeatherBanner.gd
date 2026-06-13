## Displays the active weather and its battle modifier in the BattleScene HUD.
## Shown at battle start if weather is active; hidden when weather is clear.
extends Control

const _MODIFIER_TEXTS: Dictionary = {
	"rain":       "RAIN: Ghosts gain +1 HP on summon",
	"heavy_rain": "HEAVY RAIN: Ghosts gain +2 HP on summon",
	"sandstorm":  "SANDSTORM: All minions -1 ATK (turn 1)",
	"ash_fall":   "ASH FALL: Enemy hero starts with 2 Poison",
	"volcanic":   "VOLCANIC: Enemy hero starts with 2 Poison",
	"snow":       "SNOW: First card each turn costs 1 less",
	"blizzard":   "BLIZZARD: First card costs 1 less; minions frozen turn 1",
	"dust_devil": "DUST DEVIL: Sandstorm conditions apply",
}

var _label: Label = null
var _panel: PanelContainer = null

func setup(weather_id: String) -> void:
	if weather_id == "" or not _MODIFIER_TEXTS.has(weather_id):
		hide()
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var vw: float = vp.x

	var panel_w: float = vw * 0.44
	var panel_h: float = vh * 0.055

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.15, 0.80)
	style.corner_radius_top_left    = 6
	style.corner_radius_top_right   = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_color = Color(0.4, 0.6, 0.9, 0.7)
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_width_left   = 1
	style.border_width_right  = 1
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_panel.position = Vector2((vw - panel_w) * 0.5, vh * 0.005)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_label = Label.new()
	_label.text = str(_MODIFIER_TEXTS.get(weather_id, weather_id))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", int(vh * 0.022))
	_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show()

static func modifier_text(weather_id: String) -> String:
	return str(_MODIFIER_TEXTS.get(weather_id, ""))
