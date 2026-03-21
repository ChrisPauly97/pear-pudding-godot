extends Node

var map_stack: Array[String] = []
var door_stack: Array[String] = []
var current_map: String = ""
var _world_scene_packed := preload("res://scenes/world/WorldScene.tscn")
var _battle_scene_packed := preload("res://scenes/battle/BattleScene.tscn")
var _menu_scene_packed := preload("res://scenes/ui/MenuScene.tscn")
var _gameover_scene_packed := preload("res://scenes/ui/GameOverScene.tscn")
var _chest_scene_packed := preload("res://scenes/ui/ChestOpenScene.tscn")

var _battle_overlay: Node = null
var _chest_overlay: Node = null

# Tracks which enemy triggered the current battle (for defeat marking)
var _current_battle_enemy_id: String = ""

func _ready() -> void:
	GameBus.enemy_engaged.connect(_on_enemy_engaged)
	GameBus.battle_won.connect(_on_battle_won)
	GameBus.battle_lost.connect(_on_battle_lost)
	GameBus.chest_opened.connect(_on_chest_opened)

func go_to_menu() -> void:
	map_stack.clear()
	door_stack.clear()
	current_map = ""
	get_tree().change_scene_to_packed(_menu_scene_packed)

func start_new_game() -> void:
	map_stack.clear()
	door_stack.clear()
	SaveManager.new_game()
	enter_map("main", "")

func continue_game() -> void:
	if not SaveManager.load_save():
		start_new_game()
		return
	map_stack.assign(SaveManager.map_stack)
	door_stack.assign(SaveManager.door_stack)
	current_map = SaveManager.current_map
	_load_world(SaveManager.current_map, "")

func enter_map(map_name: String, target_door_id: String = "") -> void:
	_flush_position_save()
	if current_map != "":
		map_stack.push_back(current_map)
		door_stack.push_back("")
	current_map = map_name
	SaveManager.sync_stacks(map_stack, door_stack)
	SaveManager.save()
	_load_world(map_name, target_door_id)

func exit_map() -> void:
	_flush_position_save()
	if map_stack.is_empty():
		go_to_menu()
		return
	var parent: String = map_stack.pop_back()
	var return_door: String = door_stack.pop_back()
	current_map = parent
	SaveManager.sync_stacks(map_stack, door_stack)
	SaveManager.save()
	_load_world(parent, return_door)

func _load_world(map_name: String, target_door_id: String) -> void:
	var world = _world_scene_packed.instantiate()
	world.map_name = map_name
	world.target_door_id = target_door_id
	get_tree().change_scene_to_node(world)

# Ask the current WorldScene to flush its player position into SaveManager.
func _flush_position_save() -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("flush_save_position"):
		scene.flush_save_position()

func _on_enemy_engaged(enemy_data: Dictionary) -> void:
	if _battle_overlay != null:
		return
	_current_battle_enemy_id = str(enemy_data.get("id", ""))
	_battle_overlay = _battle_scene_packed.instantiate()
	_battle_overlay.enemy_data = enemy_data
	get_tree().current_scene.add_child(_battle_overlay)

func _on_battle_won(result: Dictionary) -> void:
	if not _current_battle_enemy_id.is_empty():
		SaveManager.mark_enemy_defeated(_current_battle_enemy_id)
		_current_battle_enemy_id = ""
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null

func _on_battle_lost() -> void:
	_current_battle_enemy_id = ""
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	get_tree().change_scene_to_packed(_gameover_scene_packed)

func _on_chest_opened(card_ids: Array) -> void:
	if _chest_overlay != null:
		return
	# Grant cards to the player's persistent deck
	SaveManager.add_cards_to_deck(card_ids)
	_chest_overlay = _chest_scene_packed.instantiate()
	_chest_overlay.card_ids = card_ids
	get_tree().current_scene.add_child(_chest_overlay)
	_chest_overlay.closed.connect(_on_chest_closed)

func _on_chest_closed() -> void:
	if _chest_overlay != null:
		_chest_overlay.queue_free()
		_chest_overlay = null
