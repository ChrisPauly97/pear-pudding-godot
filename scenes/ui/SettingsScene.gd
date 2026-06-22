extends "res://scenes/ui/BaseOverlay.gd"

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	_build_backdrop(0.72)

	var panel_w: float = _vw * 0.7
	var panel_h: float = _vh * 0.75
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var outer_vbox := _build_margin_vbox(panel, 0.04, 0.03)

	outer_vbox.add_child(_UiUtil.make_title_label("Settings", _vh))
	outer_vbox.add_child(_UiUtil.make_separator())

	# Scrollable settings area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)
	attach_drag_scroll(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(_ref * 0.025))
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# — Audio —
	var audio_lbl := Label.new()
	audio_lbl.text = "Audio"
	audio_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	audio_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	vbox.add_child(audio_lbl)

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

	vbox.add_child(_UiUtil.make_separator())

	# — Accessibility & Comfort —
	var access_lbl := Label.new()
	access_lbl.text = "Accessibility & Comfort"
	access_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	access_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	vbox.add_child(access_lbl)

	var shake_on: bool = bool(SceneManager.save_manager.get_setting("screen_shake", true))
	_add_toggle_row(vbox, "Screen Shake", shake_on, func(v: bool) -> void:
		SceneManager.save_manager.set_setting("screen_shake", v)
	)

	var text_scale: float = float(SceneManager.save_manager.get_setting("text_scale", 1.0))
	_add_option_row(vbox, "Text Size", ["Small (85%)", "Normal (100%)", "Large (125%)"],
		_scale_to_index(text_scale), func(idx: int) -> void:
			var scales: Array[float] = [0.85, 1.0, 1.25]
			var s: float = scales[clamp(idx, 0, 2)]
			SceneManager.save_manager.set_setting("text_scale", s)
	)

	if OS.has_feature("mobile") or OS.has_feature("android"):
		var haptics_on: bool = bool(SceneManager.save_manager.get_setting("haptics", true))
		_add_toggle_row(vbox, "Haptics", haptics_on, func(v: bool) -> void:
			SceneManager.save_manager.set_setting("haptics", v)
		)

	vbox.add_child(_UiUtil.make_separator())

	# — Battle —
	var battle_lbl := Label.new()
	battle_lbl.text = "Battle"
	battle_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	battle_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	vbox.add_child(battle_lbl)

	var speed_is_fast: bool = str(SceneManager.save_manager.get_setting("battle_speed", "normal")) == "fast"
	_add_option_row(vbox, "Battle Speed", ["Normal", "Fast"],
		1 if speed_is_fast else 0,
		func(idx: int) -> void:
			SceneManager.save_manager.set_setting("battle_speed", "fast" if idx == 1 else "normal")
	)

	# Close button pinned below the scroll area
	outer_vbox.add_child(_UiUtil.make_separator())
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(_UiUtil.make_close_button(_vh, _close))
	outer_vbox.add_child(btn_row)

func _scale_to_index(scale: float) -> int:
	if scale < 0.95:
		return 0
	elif scale > 1.1:
		return 2
	return 1

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

func _add_toggle_row(parent: VBoxContainer, label_text: String, initial: bool, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vh * 0.02))
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var chk := CheckButton.new()
	chk.button_pressed = initial
	chk.add_theme_font_size_override("font_size", int(_vh * 0.026))
	chk.toggled.connect(func(v: bool) -> void: on_change.call(v))
	row.add_child(chk)

func _add_option_row(parent: VBoxContainer, label_text: String, options: Array, initial_idx: int, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vh * 0.02))
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.add_theme_font_size_override("font_size", int(_vh * 0.024))
	opt.custom_minimum_size = Vector2(_vh * 0.22, _vh * 0.055)
	for item: String in options:
		opt.add_item(item)
	opt.selected = clamp(initial_idx, 0, options.size() - 1)
	opt.item_selected.connect(func(idx: int) -> void: on_change.call(idx))
	row.add_child(opt)
