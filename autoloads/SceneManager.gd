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
	enter_map("main", "")

func enter_map(map_name: String, target_door_id: String = "") -> void:
	if current_map != "":
		map_stack.push_back(current_map)
		door_stack.push_back("")
	current_map = map_name
	var world = _world_scene_packed.instantiate()
	world.map_name = map_name
	world.target_door_id = target_door_id
	get_tree().change_scene_to_node(world)

func exit_map() -> void:
	if map_stack.is_empty():
		go_to_menu()
		return
	var parent = map_stack.pop_back()
	var return_door = door_stack.pop_back()
	current_map = parent
	var world = _world_scene_packed.instantiate()
	world.map_name = parent
	world.target_door_id = return_door
	get_tree().change_scene_to_node(world)

func _on_enemy_engaged(enemy_data: Dictionary) -> void:
	if _battle_overlay != null:
		return
	_battle_overlay = _battle_scene_packed.instantiate()
	_battle_overlay.enemy_data = enemy_data
	get_tree().current_scene.add_child(_battle_overlay)

func _on_battle_won(result: Dictionary) -> void:
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null

func _on_battle_lost() -> void:
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	get_tree().change_scene_to_packed(_gameover_scene_packed)

func _on_chest_opened(card_ids: Array) -> void:
	if _chest_overlay != null:
		return
	_chest_overlay = _chest_scene_packed.instantiate()
	_chest_overlay.card_ids = card_ids
	get_tree().current_scene.add_child(_chest_overlay)
	_chest_overlay.closed.connect(_on_chest_closed)

func _on_chest_closed() -> void:
	if _chest_overlay != null:
		_chest_overlay.queue_free()
		_chest_overlay = null
