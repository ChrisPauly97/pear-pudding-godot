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
	_apply_respawn_if_available()
	SceneManager.go_to_menu()

func _apply_respawn_if_available() -> void:
	var sm: Object = SceneManager.save_manager
	if not sm.call("has_respawn_point"):
		return
	# Route the player to their home bed on continue after game over.
	sm.set("current_map", sm.get("respawn_map"))
	sm.set("player_x", sm.get("respawn_x"))
	sm.set("player_z", sm.get("respawn_z"))
	var empty_map: Array[String] = []
	var empty_door: Array[String] = []
	sm.call("sync_stacks", empty_map, empty_door)
	sm.call("mark_dirty")
