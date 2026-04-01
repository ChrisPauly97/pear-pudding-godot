extends Node

enum State {
	MENU,
	WORLD,
	BATTLE,
	INVENTORY,
	SHOP,
	GAME_OVER,
}

const _SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var map_stack: Array[String] = []
var door_stack: Array[String] = []
var current_map: String = ""
var _world_scene_packed := preload("res://scenes/world/WorldScene.tscn")
var _battle_scene_packed := preload("res://scenes/battle/BattleScene.tscn")
var _menu_scene_packed := preload("res://scenes/ui/MenuScene.tscn")
var _gameover_scene_packed := preload("res://scenes/ui/GameOverScene.tscn")
var _inventory_scene_packed := preload("res://scenes/ui/InventoryScene.tscn")
var _shop_scene_packed := preload("res://scenes/ui/ShopScene.tscn")

var _state: State = State.MENU
var _battle_overlay: Node = null
var _inventory_overlay: Node = null
var _shop_overlay: Node = null
var _saved_world_scene: Node = null

# Tracks which enemy triggered the current battle (for defeat marking)
var _current_battle_enemy_id: String = ""

## SaveManager is owned here so its lifecycle is explicit rather than being a
## magic autoload. Other systems access it via SceneManager.save_manager.
var save_manager: Node

func _ready() -> void:
	save_manager = _SaveManagerScript.new()
	add_child(save_manager)
	GameBus.enemy_engaged.connect(_on_enemy_engaged)
	GameBus.battle_won.connect(_on_battle_won)
	GameBus.battle_lost.connect(_on_battle_lost)
	GameBus.inventory_requested.connect(_on_inventory_requested)
	GameBus.shop_requested.connect(_on_shop_requested)

func go_to_menu() -> void:
	_flush_position_save()
	var scene := get_tree().current_scene
	if scene and scene.has_method("flush_time_of_day"):
		scene.flush_time_of_day()
	save_manager.save()
	_exit_world_cleanup()
	get_tree().change_scene_to_packed(_menu_scene_packed)
	_state = State.MENU

# Fixed world seeds — one per biome, giving each a distinct world layout.
const _BIOME_SEEDS: Array[int] = [42, 73856135, 100033, 19349705, 294967337]

func start_new_game() -> void:
	start_new_game_with_biome(0)   # default: Grasslands

func start_new_game_with_biome(biome_id: int) -> void:
	_exit_world_cleanup()
	save_manager.world_seed = _BIOME_SEEDS[clamp(biome_id, 0, _BIOME_SEEDS.size() - 1)]
	save_manager.starting_biome = biome_id
	save_manager.new_game()
	enter_map("madrian", "")

func continue_game() -> void:
	if not save_manager.load_save():
		start_new_game()
		return
	map_stack.assign(save_manager.map_stack)
	door_stack.assign(save_manager.door_stack)
	current_map = save_manager.current_map
	_load_world(save_manager.current_map, "")

func enter_map(map_name: String, target_door_id: String = "") -> void:
	_flush_position_save()
	if current_map != "":
		map_stack.push_back(current_map)
		door_stack.push_back("")
	current_map = map_name
	save_manager.sync_stacks(map_stack, door_stack)
	save_manager.save()
	_load_world(map_name, target_door_id)

func exit_map() -> void:
	_flush_position_save()
	if map_stack.is_empty():
		go_to_menu()
		return
	var parent: String = map_stack.pop_back()
	var return_door: String = door_stack.pop_back()
	current_map = parent
	save_manager.sync_stacks(map_stack, door_stack)
	save_manager.save()
	_load_world(parent, return_door)

func _load_world(map_name: String, target_door_id: String) -> void:
	var world: Node = _world_scene_packed.instantiate()
	world.set("map_name", map_name)
	world.set("target_door_id", target_door_id)
	get_tree().change_scene_to_node(world)
	_state = State.WORLD

func _exit_world_cleanup() -> void:
	if _saved_world_scene != null:
		_saved_world_scene.queue_free()
		_saved_world_scene = null
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	if _inventory_overlay != null:
		_inventory_overlay.queue_free()
		_inventory_overlay = null
	if _shop_overlay != null:
		_shop_overlay.queue_free()
		_shop_overlay = null
	map_stack.clear()
	door_stack.clear()
	current_map = ""

# Ask the current WorldScene to flush its player position into save_manager.
func _flush_position_save() -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("flush_save_position"):
		scene.flush_save_position()

func _on_enemy_engaged(enemy_data: Dictionary) -> void:
	if _state != State.WORLD:
		return
	if save_manager.player_deck.size() < IsoConst.DECK_MIN:
		GameBus.hud_message_requested.emit("Deck too small — add at least %d cards first." % IsoConst.DECK_MIN)
		return
	_current_battle_enemy_id = str(enemy_data.get("id", ""))
	save_manager.set_pending_battle(enemy_data)
	save_manager.save()
	# Detach world scene from tree so it stops rendering/processing
	_saved_world_scene = get_tree().current_scene
	get_tree().root.remove_child(_saved_world_scene)
	# Promote battle to the active scene
	_battle_overlay = _battle_scene_packed.instantiate()
	_battle_overlay.enemy_data = enemy_data
	get_tree().root.add_child(_battle_overlay)
	get_tree().current_scene = _battle_overlay
	_state = State.BATTLE

func _restore_world() -> void:
	if _saved_world_scene != null:
		get_tree().root.add_child(_saved_world_scene)
		get_tree().current_scene = _saved_world_scene
		_saved_world_scene = null
	_state = State.WORLD

func _on_battle_won(result: Dictionary) -> void:
	if _state != State.BATTLE:
		return
	if not _current_battle_enemy_id.is_empty():
		save_manager.mark_enemy_defeated(_current_battle_enemy_id)
		_current_battle_enemy_id = ""
	var reward: String = str(result.get("card_reward", ""))
	if reward != "":
		save_manager.add_cards_to_deck([reward])
	save_manager.clear_pending_battle()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	_restore_world()

func _on_battle_lost() -> void:
	if _state != State.BATTLE:
		return
	_current_battle_enemy_id = ""
	save_manager.clear_pending_battle()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	if _saved_world_scene != null:
		_saved_world_scene.queue_free()
		_saved_world_scene = null
	get_tree().change_scene_to_packed(_gameover_scene_packed)
	_state = State.GAME_OVER

func _on_inventory_requested() -> void:
	if _state != State.WORLD:
		return
	_inventory_overlay = _inventory_scene_packed.instantiate()
	get_tree().current_scene.add_child(_inventory_overlay)
	_inventory_overlay.closed.connect(_on_inventory_closed)
	_state = State.INVENTORY

func _on_inventory_closed() -> void:
	if _state != State.INVENTORY:
		return
	if _inventory_overlay != null:
		_inventory_overlay.queue_free()
		_inventory_overlay = null
	_state = State.WORLD

func _on_shop_requested() -> void:
	if _state != State.WORLD:
		return
	_shop_overlay = _shop_scene_packed.instantiate()
	get_tree().current_scene.add_child(_shop_overlay)
	_shop_overlay.closed.connect(_on_shop_closed)
	_state = State.SHOP

func _on_shop_closed() -> void:
	if _state != State.SHOP:
		return
	if _shop_overlay != null:
		_shop_overlay.queue_free()
		_shop_overlay = null
	_state = State.WORLD
