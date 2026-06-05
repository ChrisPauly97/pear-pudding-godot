extends Control

signal closed

var _title: String = ""
var _body: String = ""

func setup(title: String, body: String) -> void:
	_title = title
	_body = body

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var vw: float = vp.x

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel_w: float = vw * 0.70
	var panel_h: float = vh * 0.50

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vw - panel_w) * 0.5, (vh - panel_h) * 0.5)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(vw * 0.025))
	margin.add_theme_constant_override("margin_right",  int(vw * 0.025))
	margin.add_theme_constant_override("margin_top",    int(vh * 0.025))
	margin.add_theme_constant_override("margin_bottom", int(vh * 0.025))
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.02))
	margin.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = _title
	title_lbl.add_theme_font_size_override("font_size", int(vh * 0.035))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var body_lbl := Label.new()
	body_lbl.text = _body
	body_lbl.add_theme_font_size_override("font_size", int(vh * 0.022))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn := Button.new()
	btn.text = "Got it"
	btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.065)
	btn.add_theme_font_size_override("font_size", int(vh * 0.022))
	btn.pressed.connect(_dismiss)
	btn_row.add_child(btn)

func _dismiss() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_dismiss()
		get_viewport().set_input_as_handled()
