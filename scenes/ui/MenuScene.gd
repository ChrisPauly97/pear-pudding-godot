extends Control

const SettingsScene = preload("res://scenes/ui/SettingsScene.gd")
const DiagnosticsScene = preload("res://scenes/ui/DiagnosticsScene.gd")
const MultiplayerLobbyScene = preload("res://scenes/ui/MultiplayerLobbyScene.gd")
const UiFx = preload("res://scenes/ui/UiFx.gd")

var _title: Label
var _continue_btn: Button
var _buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_title = Label.new()
	_title.text = "Pear Pudding TCG"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_continue_btn = _add_btn("Continue", _on_continue)
	_add_btn("New Game", _on_start)
	_add_btn("Co-op (Beta)", _on_coop)
	_add_btn("Achievements", _on_achievements)
	_add_btn("Map Editor", _on_editor)
	_add_btn("Settings", _on_settings)
	_add_btn("Diagnostics", _on_diagnostics)
	_add_btn("Quit", _on_quit)

	_continue_btn.visible = SceneManager.save_manager.has_save()

	_layout()
	_animate_title()
	_add_version_label()

func _add_btn(label: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.pressed.connect(cb)
	add_child(btn)
	_buttons.append(btn)
	UiFx.attach(btn)
	return btn

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout()

func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ref: float = minf(vp.y, vp.x)

	_title.add_theme_font_size_override("font_size", int(ref * 0.07))
	_title.size = Vector2(vp.x, ref * 0.12)
	_title.position = Vector2(0.0, ref * 0.06)

	var btn_w: float = ref * 0.38
	var btn_h: float = ref * 0.075
	var sep: float = ref * 0.018
	var btn_font: int = int(ref * 0.026)
	var btn_x: float = (vp.x - btn_w) * 0.5

	# Collect visible buttons and apply font size
	var vis_btns: Array[Button] = []
	for btn: Button in _buttons:
		btn.add_theme_font_size_override("font_size", btn_font)
		if btn.visible:
			vis_btns.append(btn)

	var n: int = vis_btns.size()
	var total_h: float = float(n) * btn_h + maxf(0.0, float(n - 1)) * sep
	var title_end: float = ref * 0.22  # 0.06 title_y + 0.12 title_h + 0.04 gap
	var remaining: float = vp.y - title_end - ref * 0.03
	var start_y: float = title_end + maxf(0.0, (remaining - total_h) * 0.5)

	# Set explicit size+position on each button — no Container layout pass needed.
	for i: int in range(n):
		var btn: Button = vis_btns[i]
		btn.size = Vector2(btn_w, btn_h)
		btn.position = Vector2(btn_x, start_y + float(i) * (btn_h + sep))

func _animate_title() -> void:
	_title.modulate.a = 0.0
	_title.scale = Vector2(0.85, 0.85)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_title, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.finished.connect(_idle_title_breathe)

func _idle_title_breathe() -> void:
	var tw: Tween = create_tween()
	tw.set_loops()
	tw.tween_property(_title, "scale", Vector2(1.02, 1.02), 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_title, "scale", Vector2(1.0, 1.0), 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _add_version_label() -> void:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	if version.is_empty():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ref: float = minf(vp.y, vp.x)
	var ver_lbl := Label.new()
	ver_lbl.text = "v" + version
	ver_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ver_lbl.add_theme_font_size_override("font_size", int(ref * 0.022))
	ver_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	ver_lbl.position = Vector2(ref * 0.015, vp.y - ref * 0.045)
	add_child(ver_lbl)

func _on_continue() -> void:
	SceneManager.go_to_slot_select()

func _on_start() -> void:
	SceneManager.go_to_slot_select()

func _on_achievements() -> void:
	SceneManager.go_to_achievements()

func _on_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MapEditorScene.tscn")

func _on_coop() -> void:
	var overlay: MultiplayerLobbyScene = MultiplayerLobbyScene.new()
	add_child(overlay)
	overlay.closed.connect(overlay.queue_free)

func _on_settings() -> void:
	var overlay: SettingsScene = SettingsScene.new()
	add_child(overlay)
	overlay.closed.connect(overlay.queue_free)

func _on_diagnostics() -> void:
	var overlay: DiagnosticsScene = DiagnosticsScene.new()
	add_child(overlay)
	overlay.closed.connect(overlay.queue_free)

func _on_quit() -> void:
	get_tree().quit()
