extends Control

@onready var _title: Label = $Title
@onready var _vbox: VBoxContainer = $VBox
@onready var _continue_btn: Button = $VBox/ContinueButton
@onready var _start_btn: Button = $VBox/StartButton
@onready var _editor_btn: Button = $VBox/EditorButton
@onready var _quit_btn: Button = $VBox/QuitButton

func _ready() -> void:
	_continue_btn.pressed.connect(_on_continue)
	_start_btn.pressed.connect(_on_start)
	_editor_btn.pressed.connect(_on_editor)
	_quit_btn.pressed.connect(_on_quit)

	# Only show Continue if a save file exists
	_continue_btn.visible = SceneManager.save_manager.has_save()
	_apply_ui_sizes()

func _apply_ui_sizes() -> void:
	var vh: float = get_viewport().get_visible_rect().size.y
	_title.add_theme_font_size_override("font_size", int(vh * 0.07))
	_vbox.add_theme_constant_override("separation", int(vh * 0.018))
	var btn_size := Vector2(vh * 0.35, vh * 0.075)
	var btn_font: int = int(vh * 0.026)
	for btn: Button in [_continue_btn, _start_btn, _editor_btn, _quit_btn]:
		btn.custom_minimum_size = btn_size
		btn.add_theme_font_size_override("font_size", btn_font)

func _on_continue() -> void:
	SceneManager.continue_game()

func _on_start() -> void:
	SceneManager.start_new_game()

func _on_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MapEditorScene.tscn")

func _on_quit() -> void:
	get_tree().quit()
