extends RefCounted

const SettingsScene = preload("res://scenes/ui/SettingsScene.gd")

var _parent: Node
var _vh: float = 0.0
var _float_layer: CanvasLayer = null
var _paused: bool = false
var _pause_overlay: CanvasLayer = null
var _make_save_fn: Callable   # () -> Dictionary
var _puzzle_mode_fn: Callable # () -> bool; if valid, save is skipped when true

func setup(parent: Node, vh: float, float_layer: CanvasLayer,
		make_save_fn: Callable, puzzle_mode_fn: Callable = Callable()) -> void:
	_parent = parent
	_vh = vh
	_float_layer = float_layer
	_make_save_fn = make_save_fn
	_puzzle_mode_fn = puzzle_mode_fn

func add_pause_button(side_panel: Control) -> void:
	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.custom_minimum_size = Vector2(_vh * 0.055, _vh * 0.055)
	pause_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.pressed.connect(toggle)
	side_panel.add_child(pause_btn)
	side_panel.move_child(pause_btn, 0)

func is_paused() -> bool:
	return _paused

func toggle() -> void:
	if _paused:
		hide_pause()
	else:
		show_pause()

func show_pause() -> void:
	if _paused:
		return
	_paused = true
	_parent.get_tree().paused = true
	if _float_layer:
		_float_layer.hide()

	var vp: Vector2 = _parent.get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_parent.add_child(layer)
	_pause_overlay = layer

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.7)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.55
	var panel_h: float = _vh * 0.52
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15, 0.97)
	style.corner_radius_top_left    = 12
	style.corner_radius_top_right   = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vh * 0.03))
	margin.add_theme_constant_override("margin_right",  int(_vh * 0.03))
	margin.add_theme_constant_override("margin_top",    int(_vh * 0.03))
	margin.add_theme_constant_override("margin_bottom", int(_vh * 0.03))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.025))
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", int(_vh * 0.05))
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var btn_size: Vector2 = Vector2(_vh * 0.3, _vh * 0.07)
	var btn_font: int = int(_vh * 0.03)

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = btn_size
	resume_btn.add_theme_font_size_override("font_size", btn_font)
	resume_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(hide_pause)
	vbox.add_child(resume_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = btn_size
	settings_btn.add_theme_font_size_override("font_size", btn_font)
	settings_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_btn.pressed.connect(open_settings)
	vbox.add_child(settings_btn)

	var flee_btn := Button.new()
	flee_btn.text = "Flee Battle"
	flee_btn.custom_minimum_size = btn_size
	flee_btn.add_theme_font_size_override("font_size", btn_font)
	flee_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	flee_btn.pressed.connect(on_flee_pressed)
	vbox.add_child(flee_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = btn_size
	menu_btn.add_theme_font_size_override("font_size", btn_font)
	menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_btn.pressed.connect(confirm_return_to_menu)
	vbox.add_child(menu_btn)

func hide_pause() -> void:
	if not _paused:
		return
	_paused = false
	_parent.get_tree().paused = false
	if _pause_overlay != null and is_instance_valid(_pause_overlay):
		_pause_overlay.queue_free()
	_pause_overlay = null
	if _float_layer:
		_float_layer.show()

func on_flee_pressed() -> void:
	_parent.get_tree().paused = false
	_paused = false
	if _pause_overlay != null and is_instance_valid(_pause_overlay):
		_pause_overlay.queue_free()
	_pause_overlay = null
	GameBus.battle_fled.emit()

func open_settings() -> void:
	var overlay: SettingsScene = SettingsScene.new()
	_pause_overlay.add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.closed.connect(overlay.queue_free)

func confirm_return_to_menu() -> void:
	var vp: Vector2 = _parent.get_viewport().get_visible_rect().size
	var dialog := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.05, 0.05, 0.98)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	dialog.add_theme_stylebox_override("panel", style)
	var dlg_w: float = vp.x * 0.5
	var dlg_h: float = _vh * 0.28
	dialog.custom_minimum_size = Vector2(dlg_w, dlg_h)
	dialog.position = Vector2((vp.x - dlg_w) * 0.5, (vp.y - dlg_h) * 0.5)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.add_child(dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vh * 0.025))
	margin.add_theme_constant_override("margin_right",  int(_vh * 0.025))
	margin.add_theme_constant_override("margin_top",    int(_vh * 0.025))
	margin.add_theme_constant_override("margin_bottom", int(_vh * 0.025))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.022))
	margin.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Return to menu?\nYour battle will be saved."
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(_vh * 0.03))
	vbox.add_child(row)

	var yes_btn := Button.new()
	yes_btn.text = "Yes, leave"
	yes_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.065)
	yes_btn.add_theme_font_size_override("font_size", int(_vh * 0.026))
	yes_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	yes_btn.pressed.connect(func() -> void:
		var is_puzzle: bool = _puzzle_mode_fn.call() if _puzzle_mode_fn.is_valid() else false
		if not is_puzzle and _make_save_fn.is_valid():
			SceneManager.save_manager.set_pending_battle_state(_make_save_fn.call())
		SceneManager.save_manager.save()
		_parent.get_tree().paused = false
		SceneManager.go_to_menu()
	)
	row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Cancel"
	no_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.065)
	no_btn.add_theme_font_size_override("font_size", int(_vh * 0.026))
	no_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	no_btn.pressed.connect(dialog.queue_free)
	row.add_child(no_btn)
