extends "res://scenes/ui/BaseOverlay.gd"

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

# Keybindings capture state
var _capture_action: String = ""
var _capture_key_lbl: Label = null
var _capture_overlay: PanelContainer = null
var _kb_vbox: VBoxContainer = null

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

	# — Keybindings (desktop only) —
	if not (OS.has_feature("mobile") or OS.has_feature("android")):
		vbox.add_child(_UiUtil.make_separator())
		_build_keybindings_section(vbox)

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

# ---------------------------------------------------------------------------
# Keybindings section
# ---------------------------------------------------------------------------

func _build_keybindings_section(parent: VBoxContainer) -> void:
	var kb_lbl := Label.new()
	kb_lbl.text = "Keybindings"
	kb_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	kb_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	parent.add_child(kb_lbl)

	_kb_vbox = VBoxContainer.new()
	_kb_vbox.add_theme_constant_override("separation", int(_ref * 0.015))
	parent.add_child(_kb_vbox)

	_rebuild_keybinding_rows()

	# Reset to Defaults button
	var reset_row := HBoxContainer.new()
	reset_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(reset_row)

	var reset_btn := Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.add_theme_font_size_override("font_size", int(_vh * 0.026))
	reset_btn.custom_minimum_size = Vector2(_vh * 0.28, _vh * 0.05)
	reset_btn.pressed.connect(_on_reset_keybindings)
	reset_row.add_child(reset_btn)

## Returns a human-readable name for a physical keycode.
func _key_label(physical_keycode: int) -> String:
	if physical_keycode <= 0:
		return "—"
	return OS.get_keycode_string(DisplayServer.keyboard_get_label_from_physical(physical_keycode))

## Returns a display name for an action: replace underscores with spaces, title-case.
func _action_display_name(action: String) -> String:
	var words: PackedStringArray = action.split("_")
	var result: String = ""
	for word: String in words:
		if result != "":
			result += " "
		if word.length() > 0:
			result += word[0].to_upper() + word.substr(1)
	return result

## Returns the physical_keycode currently bound to action's first InputEventKey, or 0.
func _current_keycode(action: String) -> int:
	if not InputMap.has_action(action):
		return 0
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return (ev as InputEventKey).physical_keycode
	return 0

func _rebuild_keybinding_rows() -> void:
	for child in _kb_vbox.get_children():
		child.queue_free()

	var overrides: Dictionary = SceneManager.save_manager.get_setting("keybindings", {})

	for action: String in SceneManager.REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(_vh * 0.012))
		_kb_vbox.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = _action_display_name(action)
		name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		# Current key display (informational, not interactive)
		var key_lbl := Label.new()
		var kc: int = _current_keycode(action)
		key_lbl.text = _key_label(kc)
		key_lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
		key_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		key_lbl.custom_minimum_size = Vector2(_vh * 0.15, 0)
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(key_lbl)

		# Change button
		var change_btn := Button.new()
		change_btn.text = "Change"
		change_btn.add_theme_font_size_override("font_size", int(_vh * 0.024))
		change_btn.custom_minimum_size = Vector2(_vh * 0.15, _vh * 0.05)
		change_btn.pressed.connect(_start_capture.bind(action, key_lbl))
		row.add_child(change_btn)

func _start_capture(action: String, key_lbl: Label) -> void:
	_capture_action = action
	_capture_key_lbl = key_lbl
	_show_capture_overlay(action)

func _show_capture_overlay(action: String) -> void:
	if _capture_overlay != null:
		_capture_overlay.queue_free()

	_capture_overlay = PanelContainer.new()
	_capture_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_capture_overlay)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_capture_overlay.add_child(vbox)

	var prompt := Label.new()
	prompt.text = "Press any key for «%s»…\n(Esc to cancel)" % _action_display_name(action)
	prompt.add_theme_font_size_override("font_size", int(_vh * 0.03))
	prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 0.8))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(prompt)

	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if _capture_action == "":
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	get_viewport().set_input_as_handled()

	if key_event.physical_keycode == KEY_ESCAPE:
		_cancel_capture()
		return

	# Check for conflict and warn (but still allow)
	var conflict: String = ""
	var overrides: Dictionary = SceneManager.save_manager.get_setting("keybindings", {})
	for other_action: String in SceneManager.REBINDABLE_ACTIONS:
		if other_action == _capture_action:
			continue
		var other_kc: int = _current_keycode(other_action)
		if other_kc == key_event.physical_keycode:
			conflict = other_action
			break

	# Save the new binding
	overrides[_capture_action] = key_event.physical_keycode
	SceneManager.save_manager.set_setting("keybindings", overrides)
	SceneManager.apply_keybindings()

	# Update label
	if is_instance_valid(_capture_key_lbl):
		_capture_key_lbl.text = _key_label(key_event.physical_keycode)
		if conflict != "":
			_capture_key_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
			_capture_key_lbl.tooltip_text = "Also used by: " + _action_display_name(conflict)
		else:
			_capture_key_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
			_capture_key_lbl.tooltip_text = ""

	_cancel_capture()

func _cancel_capture() -> void:
	_capture_action = ""
	_capture_key_lbl = null
	set_process_unhandled_input(false)
	if _capture_overlay != null:
		_capture_overlay.queue_free()
		_capture_overlay = null

func _on_reset_keybindings() -> void:
	SceneManager.save_manager.set_setting("keybindings", {})
	SceneManager.apply_keybindings()
	_rebuild_keybinding_rows()
