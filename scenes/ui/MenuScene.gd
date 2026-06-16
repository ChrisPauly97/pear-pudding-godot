extends Control

const SettingsScene = preload("res://scenes/ui/SettingsScene.gd")

@onready var _title: Label = $Title
@onready var _vbox: VBoxContainer = $VBox
@onready var _continue_btn: Button = $VBox/ContinueButton
@onready var _start_btn: Button = $VBox/StartButton
@onready var _achievements_btn: Button = $VBox/AchievementsButton
@onready var _editor_btn: Button = $VBox/EditorButton
@onready var _settings_btn: Button = $VBox/SettingsButton
@onready var _quit_btn: Button = $VBox/QuitButton

func _ready() -> void:
	_continue_btn.pressed.connect(_on_continue)
	_start_btn.pressed.connect(_on_start)
	_achievements_btn.pressed.connect(_on_achievements)
	_editor_btn.pressed.connect(_on_editor)
	_settings_btn.pressed.connect(_on_settings)
	_quit_btn.pressed.connect(_on_quit)

	_continue_btn.visible = SceneManager.save_manager.has_save()
	_apply_ui_sizes()
	_animate_title()
	_add_version_label()

func _apply_ui_sizes() -> void:
	var vh: float = get_viewport().get_visible_rect().size.y
	_title.add_theme_font_size_override("font_size", int(vh * 0.07))
	_vbox.add_theme_constant_override("separation", int(vh * 0.018))
	var btn_size := Vector2(vh * 0.35, vh * 0.075)
	var btn_font: int = int(vh * 0.026)
	for btn: Button in [_continue_btn, _start_btn, _achievements_btn, _editor_btn, _settings_btn, _quit_btn]:
		btn.custom_minimum_size = btn_size
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
	var vh: float = get_viewport().get_visible_rect().size.y
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ver_lbl := Label.new()
	ver_lbl.text = "v" + version
	ver_lbl.add_theme_font_size_override("font_size", int(vh * 0.022))
	ver_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	ver_lbl.position = Vector2(vh * 0.015, vp.y - vh * 0.045)
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

func _on_quit() -> void:
	get_tree().quit()
