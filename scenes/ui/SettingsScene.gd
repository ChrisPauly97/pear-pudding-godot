extends "res://scenes/ui/BaseOverlay.gd"

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	_build_backdrop(0.72)

	var panel_w: float = _vw * 0.7
	var panel_h: float = _vh * 0.52
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var vbox := _build_margin_vbox(panel, 0.04, 0.03)

	vbox.add_child(_UiUtil.make_title_label("Settings", _vh))
	vbox.add_child(_UiUtil.make_separator())

	var music_vol: float = float(SceneManager.save_manager.get_setting("music_volume", 0.5))
	_add_slider_row(vbox, "Music Volume", music_vol, func(v: float) -> void:
		SceneManager.save_manager.set_setting("music_volume", v)
		AudioManager.set_music_volume(v)
	)

	var sfx_vol: float = float(SceneManager.save_manager.get_setting("sfx_volume", 1.0))
	_add_slider_row(vbox, "SFX Volume", sfx_vol, func(v: float) -> void:
		SceneManager.save_manager.set_setting("sfx_volume", v)
		AudioManager.set_sfx_volume(v)
	)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(_UiUtil.make_close_button(_vh, _close))
	vbox.add_child(btn_row)

func _add_slider_row(parent: VBoxContainer, label_text: String, initial: float, on_change: Callable) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vh * 0.008))
	parent.add_child(row)

	var lbl := _UiUtil.make_body_label(label_text, _vh)
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
	row.add_child(lbl)

	var slider_row := HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", int(_vh * 0.02))
	row.add_child(slider_row)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(_vw * 0.5, int(_vh * 0.05))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(initial * 100)
	val_lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
	val_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	val_lbl.custom_minimum_size = Vector2(_vh * 0.07, 0)
	slider_row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%d%%" % int(v * 100)
		on_change.call(v)
	)
