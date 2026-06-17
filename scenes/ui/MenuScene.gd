extends Control

const SettingsScene = preload("res://scenes/ui/SettingsScene.gd")
const DiagnosticsScene = preload("res://scenes/ui/DiagnosticsScene.gd")

@onready var _outer: MarginContainer = $Outer
@onready var _inner_vbox: VBoxContainer = $Outer/InnerVBox
@onready var _title: Label = $Outer/InnerVBox/Title
@onready var _scroll: ScrollContainer = $Outer/InnerVBox/Scroll
@onready var _vbox: VBoxContainer = $Outer/InnerVBox/Scroll/VBox
@onready var _continue_btn: Button = $Outer/InnerVBox/Scroll/VBox/ContinueButton
@onready var _start_btn: Button = $Outer/InnerVBox/Scroll/VBox/StartButton
@onready var _achievements_btn: Button = $Outer/InnerVBox/Scroll/VBox/AchievementsButton
@onready var _editor_btn: Button = $Outer/InnerVBox/Scroll/VBox/EditorButton
@onready var _settings_btn: Button = $Outer/InnerVBox/Scroll/VBox/SettingsButton
@onready var _quit_btn: Button = $Outer/InnerVBox/Scroll/VBox/QuitButton

func _ready() -> void:
	_continue_btn.pressed.connect(_on_continue)
	_start_btn.pressed.connect(_on_start)
	_achievements_btn.pressed.connect(_on_achievements)
	_editor_btn.pressed.connect(_on_editor)
	_settings_btn.pressed.connect(_on_settings)
	_quit_btn.pressed.connect(_on_quit)

	_continue_btn.visible = SceneManager.save_manager.has_save()
	_add_diagnostics_button()
	_apply_ui_sizes()
	_animate_title()
	_add_version_label()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_ui_sizes()

func _add_diagnostics_button() -> void:
	var diag_btn := Button.new()
	diag_btn.text = "Diagnostics"
	diag_btn.pressed.connect(_on_diagnostics)
	_vbox.add_child(diag_btn)
	_vbox.move_child(diag_btn, _quit_btn.get_index())

func _apply_ui_sizes() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	# Use shorter dimension so portrait screens don't produce oversized elements.
	var ref: float = min(vh, vp.x)

	# Large horizontal margins center a ~38 % ref-wide column; never less than 3 % padding.
	var col_w: float = ref * 0.38
	var margin_h: int = int(max((vp.x - col_w) * 0.5, ref * 0.03))
	_outer.add_theme_constant_override("margin_left", margin_h)
	_outer.add_theme_constant_override("margin_right", margin_h)
	_outer.add_theme_constant_override("margin_top", int(ref * 0.06))
	_outer.add_theme_constant_override("margin_bottom", int(ref * 0.03))

	_title.add_theme_font_size_override("font_size", int(ref * 0.07))
	_inner_vbox.add_theme_constant_override("separation", int(ref * 0.04))
	_vbox.add_theme_constant_override("separation", int(ref * 0.018))

	# Height only — width fills the centered column so buttons don't overflow it.
	var btn_h: float = ref * 0.075
	var btn_font: int = int(ref * 0.026)
	for btn: Button in _vbox.get_children().filter(func(n: Node) -> bool: return n is Button):
		btn.custom_minimum_size = Vector2(0, btn_h)
		btn.add_theme_font_size_override("font_size", btn_font)

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
	var ref: float = min(vp.y, vp.x)
	var ver_lbl := Label.new()
	ver_lbl.text = "v" + version
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
