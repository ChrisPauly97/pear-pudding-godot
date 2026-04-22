extends Control

signal closed

func _ready() -> void:
	var vh: float = get_viewport().get_visible_rect().size.y
	var vp: Vector2 = get_viewport().get_visible_rect().size

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = MOUSE_FILTER_PASS
	add_child(backdrop)

	backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close()
	)

	var panel_w: float = vp.x * 0.7
	var panel_h: float = vh * 0.52
	var panel := PanelContainer.new()
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
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = MOUSE_FILTER_STOP
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(vh * 0.04))
	margin.add_theme_constant_override("margin_right",  int(vh * 0.04))
	margin.add_theme_constant_override("margin_top",    int(vh * 0.04))
	margin.add_theme_constant_override("margin_bottom", int(vh * 0.03))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.03))
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", int(vh * 0.045))
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var music_vol: float = float(SceneManager.save_manager.get_setting("music_volume", 0.5))
	_add_slider_row(vbox, vh, "Music Volume", music_vol, func(v: float) -> void:
		SceneManager.save_manager.set_setting("music_volume", v)
		AudioManager.set_music_volume(v)
	)

	var sfx_vol: float = float(SceneManager.save_manager.get_setting("sfx_volume", 1.0))
	_add_slider_row(vbox, vh, "SFX Volume", sfx_vol, func(v: float) -> void:
		SceneManager.save_manager.set_setting("sfx_volume", v)
		AudioManager.set_sfx_volume(v)
	)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(vh * 0.22, vh * 0.065)
	close_btn.add_theme_font_size_override("font_size", int(vh * 0.028))
	close_btn.pressed.connect(_close)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(close_btn)
	vbox.add_child(btn_row)

func _add_slider_row(parent: VBoxContainer, vh: float, label_text: String, initial: float, on_change: Callable) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", int(vh * 0.008))
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", int(vh * 0.028))
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	row.add_child(lbl)

	var slider_row := HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", int(vh * 0.02))
	row.add_child(slider_row)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(get_viewport().get_visible_rect().size.x * 0.5, int(vh * 0.05))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(initial * 100)
	val_lbl.add_theme_font_size_override("font_size", int(vh * 0.026))
	val_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	val_lbl.custom_minimum_size = Vector2(vh * 0.07, 0)
	slider_row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%d%%" % int(v * 100)
		on_change.call(v)
	)

func _close() -> void:
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
