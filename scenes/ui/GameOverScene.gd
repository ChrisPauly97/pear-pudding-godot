extends Control

@onready var _menu_btn: Button = $VBox/MenuButton
@onready var _msg_label: Label = $VBox/MessageLabel

func _ready() -> void:
	_msg_label.text = "Game Over"
	_menu_btn.pressed.connect(_on_menu)

func _on_menu() -> void:
	SceneManager.go_to_menu()
