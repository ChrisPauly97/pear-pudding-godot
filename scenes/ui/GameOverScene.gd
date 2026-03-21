extends Control

@onready var _menu_btn: Button = $VBox/MenuButton
@onready var _msg_label: Label = $VBox/MessageLabel

func _ready() -> void:
	_msg_label.text = "Game Over"
	_menu_btn.pressed.connect(_on_menu)
	_apply_ui_sizes()

func _apply_ui_sizes() -> void:
	var vh: float = get_viewport().get_visible_rect().size.y
	_msg_label.add_theme_font_size_override("font_size", int(vh * 0.04))
	_menu_btn.custom_minimum_size = Vector2(vh * 0.22, vh * 0.07)

func _on_menu() -> void:
	SceneManager.go_to_menu()
