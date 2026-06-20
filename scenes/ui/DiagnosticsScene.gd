extends "res://scenes/ui/BaseOverlay.gd"

const _LEVEL_COLORS: Dictionary = {
	"INFO":  "green",
	"WARN":  "yellow",
	"ERROR": "red",
}

var _rich: RichTextLabel

func _ready() -> void:
	super._ready()
	_build_backdrop()

	var panel_w: float = _vw * 0.88
	var panel_h: float = _vh * 0.82
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", BaseOverlay._make_dark_glass_style())

	var vbox := _build_margin_vbox(panel, 0.018, 0.012)

	var title := Label.new()
	title.text = "Diagnostics"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(_vh * 0.038))
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_rich = RichTextLabel.new()
	_rich.bbcode_enabled = true
	_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rich.add_theme_font_size_override("normal_font_size", int(_vh * 0.022))
	_rich.scroll_active = false
	scroll.add_child(_rich)

	_populate()

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(_vh * 0.015))
	vbox.add_child(hbox)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	clear_btn.add_theme_font_size_override("font_size", int(_vh * 0.026))
	clear_btn.pressed.connect(_on_clear)
	hbox.add_child(clear_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	close_btn.add_theme_font_size_override("font_size", int(_vh * 0.026))
	close_btn.pressed.connect(_close)
	hbox.add_child(close_btn)

func _populate() -> void:
	_rich.clear()
	var entries: Array[Dictionary] = AppLog.get_entries()
	for entry: Dictionary in entries:
		var ts: float = entry.get("ts", 0.0)
		var level: String = entry.get("level", "INFO")
		var msg: String = entry.get("msg", "")
		var col: String = _LEVEL_COLORS.get(level, "white")
		_rich.append_text(
			"[color=#888888][%.1fs][/color] [color=%s][%s][/color] %s\n" % [ts, col, level, msg]
		)

func _on_clear() -> void:
	AppLog.clear()
	_populate()
