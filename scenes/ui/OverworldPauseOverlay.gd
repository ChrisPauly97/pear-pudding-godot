extends CanvasLayer

const SettingsScene = preload("res://scenes/ui/SettingsScene.gd")
const DiagnosticsScene = preload("res://scenes/ui/DiagnosticsScene.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

signal resumed
signal quit_to_menu

var _vh: float = 0.0

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vh = get_viewport().get_visible_rect().size.y
	get_tree().paused = true
	_build_ui()

func _build_ui() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.7)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel_w: float = vp.x * 0.55
	var panel_h: float = _vh * 0.54
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
	add_child(panel)

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

	var title := _UiUtil.make_label("Paused", int(_vh * 0.05))
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume_btn := _UiUtil.make_button("Resume", Vector2(_vh * 0.3, _vh * 0.07), int(_vh * 0.03), _on_resume, vbox)
	resume_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.grab_focus()

	var settings_btn := _UiUtil.make_button("Settings", Vector2(_vh * 0.3, _vh * 0.07), int(_vh * 0.03), _on_settings, vbox)
	settings_btn.process_mode = Node.PROCESS_MODE_ALWAYS

	var diag_btn := _UiUtil.make_button("Diagnostics", Vector2(_vh * 0.3, _vh * 0.07), int(_vh * 0.03), _on_diagnostics, vbox)
	diag_btn.process_mode = Node.PROCESS_MODE_ALWAYS

	var save_quit_btn := _UiUtil.make_button("Save & Quit", Vector2(_vh * 0.3, _vh * 0.07), int(_vh * 0.03), _on_save_quit, vbox)
	save_quit_btn.process_mode = Node.PROCESS_MODE_ALWAYS

func _on_resume() -> void:
	get_tree().paused = false
	resumed.emit()
	queue_free()

func _on_settings() -> void:
	var overlay: SettingsScene = SettingsScene.new()
	add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.closed.connect(overlay.queue_free)

func _on_diagnostics() -> void:
	var overlay: DiagnosticsScene = DiagnosticsScene.new()
	add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.closed.connect(overlay.queue_free)

func _on_save_quit() -> void:
	get_tree().paused = false
	SceneManager.save_manager.save()
	quit_to_menu.emit()
	queue_free()
	SceneManager.go_to_menu_direct()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_resume()
		get_viewport().set_input_as_handled()
