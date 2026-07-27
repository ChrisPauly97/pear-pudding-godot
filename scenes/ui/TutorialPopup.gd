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

	var title_lbl := _UiUtil.make_label(_title, int(_vh * 0.035), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var body_lbl := _UiUtil.make_label(_body, int(_vh * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, vbox)
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var btn_row := _UiUtil.make_hbox(0, vbox)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var btn := _UiUtil.make_button("Got it", Vector2(_vh * 0.18, _vh * 0.065), int(_vh * 0.022), _close, btn_row)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_close()
		get_viewport().set_input_as_handled()
