extends Control

signal closed

var _vh: float = 0.0
var _vw: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x

# Returns a full-screen dark backdrop. Optionally closes overlay on tap when
# close_on_tap is true.
func _build_backdrop(alpha: float = 0.78, close_on_tap: bool = false) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, alpha)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_PASS
	add_child(bg)
	if close_on_tap:
		bg.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				_close()
		)
	return bg

# Returns a centered PanelContainer. The caller is responsible for any custom
# StyleBoxFlat — most scenes use Godot's default panel style, so none is applied
# here. Call _make_dark_glass_style() if the scene needs the dark bordered look.
func _build_centered_panel(w: float, h: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(w, h)
	panel.size = Vector2(w, h)
	panel.position = Vector2((_vw - w) * 0.5, (_vh - h) * 0.5)
	panel.mouse_filter = MOUSE_FILTER_STOP
	add_child(panel)
	return panel

# Applies the standard dark-glass styled border to a PanelContainer.
# Call this after _build_centered_panel() when the scene needs it.
static func _make_dark_glass_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.98)
	style.corner_radius_top_left    = 12
	style.corner_radius_top_right   = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_color = Color(0.4, 0.4, 0.6, 0.7)
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_width_left   = 2
	style.border_width_right  = 2
	return style

# Adds a MarginContainer + VBoxContainer inside parent and returns the VBox.
func _build_margin_vbox(parent: Control, margin_frac: float = 0.015, sep_frac: float = 0.012) -> VBoxContainer:
	var margin := MarginContainer.new()
	var m: int = int(_vh * margin_frac)
	margin.add_theme_constant_override("margin_left",   m)
	margin.add_theme_constant_override("margin_right",  m)
	margin.add_theme_constant_override("margin_top",    m)
	margin.add_theme_constant_override("margin_bottom", m)
	parent.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(_vh * sep_frac))
	margin.add_child(vbox)
	return vbox

func _close() -> void:
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
