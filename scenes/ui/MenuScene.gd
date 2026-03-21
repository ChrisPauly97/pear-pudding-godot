extends Control

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
	_continue_btn.visible = SaveManager.has_save()

func _on_continue() -> void:
	SceneManager.continue_game()

func _on_start() -> void:
	SceneManager.start_new_game()

func _on_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MapEditorScene.tscn")

func _on_quit() -> void:
	get_tree().quit()
