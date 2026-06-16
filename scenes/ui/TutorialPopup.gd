extends "res://scenes/ui/BaseOverlay.gd"

var _title: String = ""
var _body: String = ""

func setup(title: String, body: String) -> void:
	_title = title
	_body = body

func _ready() -> void:
	super._ready()

	_build_backdrop(0.65)

	var panel_w: float = _vw * 0.70
	var panel_h: float = _vh * 0.50

	var panel := _build_centered_panel(panel_w, panel_h)

	var vbox := _build_margin_vbox(panel, 0.025, 0.02)

	var title_lbl := Label.new()
	title_lbl.text = _title
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.035))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var body_lbl := Label.new()
	body_lbl.text = _body
	body_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn := Button.new()
	btn.text = "Got it"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.065)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	btn.pressed.connect(_close)
	btn_row.add_child(btn)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_close()
		get_viewport().set_input_as_handled()
