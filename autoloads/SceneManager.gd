extends Node

var map_stack: Array[String] = []
var door_stack: Array[String] = []
var current_map: String = ""
var _world_scene_packed := preload("res://scenes/world/WorldScene.tscn")
var _battle_scene_packed := preload("res://scenes/battle/BattleScene.tscn")
var _menu_scene_packed := preload("res://scenes/ui/MenuScene.tscn")
var _gameover_scene_packed := preload("res://scenes/ui/GameOverScene.tscn")
var _inventory_scene_packed := preload("res://scenes/ui/InventoryScene.tscn")

var _battle_overlay: Node = null
var _inventory_overlay: Node = null

# Tracks which enemy triggered the current battle (for defeat marking)
var _current_battle_enemy_id: String = ""

func _ready() -> void:
	GameBus.enemy_engaged.connect(_on_enemy_engaged)
	GameBus.battle_won.connect(_on_battle_won)
	GameBus.battle_lost.connect(_on_battle_lost)
	GameBus.inventory_requested.connect(_on_inventory_requested)

func go_to_menu() -> void:
	get_tree().paused = false
	_battle_overlay = null
	_inventory_overlay = null
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
	# Named sub-maps (dungeons, etc.) use the fixed WorldMap path, not infinite generation
	if map_name != "infinite" and map_name != "main":
		world.infinite = false
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
	SaveManager.set_pending_battle(enemy_data)
	SaveManager.save()
	_battle_overlay = _battle_scene_packed.instantiate()
	_battle_overlay.enemy_data = enemy_data
	_battle_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(_battle_overlay)
	get_tree().paused = true

func _on_battle_won(_result: Dictionary) -> void:
	get_tree().paused = false
	if not _current_battle_enemy_id.is_empty():
		SaveManager.mark_enemy_defeated(_current_battle_enemy_id)
		_current_battle_enemy_id = ""
	SaveManager.clear_pending_battle()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null

func _on_battle_lost() -> void:
	get_tree().paused = false
	_current_battle_enemy_id = ""
	SaveManager.clear_pending_battle()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	get_tree().change_scene_to_packed(_gameover_scene_packed)

func _on_inventory_requested() -> void:
	if _inventory_overlay != null:
		return
	if _battle_overlay != null:
		return
	_inventory_overlay = _inventory_scene_packed.instantiate()
	get_tree().current_scene.add_child(_inventory_overlay)
	_inventory_overlay.closed.connect(_on_inventory_closed)

func _on_inventory_closed() -> void:
	if _inventory_overlay != null:
		_inventory_overlay.queue_free()
		_inventory_overlay = null
