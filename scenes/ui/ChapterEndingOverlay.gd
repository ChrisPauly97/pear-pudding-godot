extends "res://scenes/ui/BaseOverlay.gd"

## Chapter-ending narration overlay (GID-108 / TID-405) — reuses the BaseOverlay
## dark-glass panel style. Shows `_pages` one at a time with a Next/Continue
## button; tap-through via ui_accept. Purely narrative — no scene transition;
## the caller is already in the world and the world stays exactly as it is.

var _title: String = "Chapter 1 Complete"
var _pages: Array[String] = []
var _page_idx: int = 0

var _body_lbl: Label
var _next_btn: Button

func setup(pages: Array[String], title: String = "Chapter 1 Complete") -> void:
	_pages = pages
	_title = title

func _ready() -> void:
	super._ready()

	_build_backdrop(0.85)

	var panel_w: float = _vw * 0.72
	var panel_h: float = _vh * 0.5
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var vbox := _build_margin_vbox(panel, 0.03, 0.025)

	var title_lbl := Label.new()
	title_lbl.text = _title
	title_lbl.add_theme_font_size_override("font_size", int(_ref * 0.04))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(1.0, 0.85, 0.4)
	vbox.add_child(title_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_body_lbl = Label.new()
	_body_lbl.add_theme_font_size_override("font_size", int(_ref * 0.024))
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_body_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_next_btn = Button.new()
	_next_btn.custom_minimum_size = Vector2(_ref * 0.2, _ref * 0.065)
	_next_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	_next_btn.pressed.connect(_advance)
	btn_row.add_child(_next_btn)

	_refresh_page()

func _refresh_page() -> void:
	_body_lbl.text = _pages[_page_idx] if _page_idx < _pages.size() else ""
	_next_btn.text = "Continue" if _page_idx >= _pages.size() - 1 else "Next"

func _advance() -> void:
	if _page_idx >= _pages.size() - 1:
		_close()
		return
	_page_idx += 1
	_refresh_page()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()
