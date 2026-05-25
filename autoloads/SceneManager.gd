extends Node

enum State {
	MENU,
	WORLD,
	BATTLE,
	INVENTORY,
	SHOP,
	GAME_OVER,
	JOURNAL,
	ACHIEVEMENTS,
	RUN_SUMMARY,
	CHARACTER,
}

const _SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _AchievementToastScript = preload("res://scenes/ui/AchievementToast.gd")

var map_stack: Array[String] = []
var door_stack: Array[String] = []
var current_map: String = ""
var _world_scene_packed := preload("res://scenes/world/WorldScene.tscn")
var _battle_scene_packed := preload("res://scenes/battle/BattleScene.tscn")
var _menu_scene_packed := preload("res://scenes/ui/MenuScene.tscn")
var _gameover_scene_packed := preload("res://scenes/ui/GameOverScene.tscn")
var _inventory_scene_packed := preload("res://scenes/ui/InventoryScene.tscn")
var _shop_scene_packed := preload("res://scenes/ui/ShopScene.tscn")
var _character_scene_packed := preload("res://scenes/ui/CharacterScene.tscn")
var _journal_scene_packed := preload("res://scenes/ui/JournalScene.tscn")
var _achievements_scene_packed := preload("res://scenes/ui/AchievementsScene.tscn")
var _run_summary_scene_packed := preload("res://scenes/ui/RunSummaryScene.tscn")

var _state: State = State.MENU
var _battle_overlay: Node = null
var _inventory_overlay: Node = null
var _shop_overlay: Node = null
var _journal_overlay: Node = null
var _achievements_overlay: Node = null
var _character_overlay: Node = null
var _saved_world_scene: Node = null

# Ephemeral session statistics — reset on new/continue game, not persisted.
var session_stats: Dictionary = {
	"battles_won": 0,
	"battles_lost": 0,
	"enemies_defeated": 0,
	"cards_earned": 0,
	"coins_earned": 0,
	"chests_opened": 0,
	"session_start_msec": 0,
}

var _toast: CanvasLayer = null

# Tracks which enemy triggered the current battle (for defeat marking)
var _current_battle_enemy_id: String = ""

## SaveManager is owned here so its lifecycle is explicit rather than being a
## magic autoload. Other systems access it via SceneManager.save_manager.
var save_manager: Node

func _ready() -> void:
	save_manager = _SaveManagerScript.new()
	add_child(save_manager)
	_toast = _AchievementToastScript.new()
	add_child(_toast)
	GameBus.enemy_engaged.connect(_on_enemy_engaged)
	GameBus.battle_won.connect(_on_battle_won)
	GameBus.battle_lost.connect(_on_battle_lost)
	GameBus.inventory_requested.connect(_on_inventory_requested)
	GameBus.shop_requested.connect(_on_shop_requested)
	GameBus.journal_requested.connect(_on_journal_requested)
	GameBus.character_requested.connect(_on_character_requested)
	GameBus.achievement_unlocked.connect(_on_achievement_unlocked)

func go_to_menu() -> void:
	_flush_position_save()
	var scene := get_tree().current_scene
	if scene and scene.has_method("flush_time_of_day"):
		scene.flush_time_of_day()
	save_manager.save()
	# Show run summary only when leaving the world (not after game over or from menu).
	if _state == State.WORLD:
		_exit_world_cleanup()
		var summary: Node = _run_summary_scene_packed.instantiate()
		get_tree().change_scene_to_node(summary)
		_state = State.RUN_SUMMARY
		return
	_exit_world_cleanup()
	get_tree().change_scene_to_packed(_menu_scene_packed)
	_state = State.MENU

func go_to_menu_direct() -> void:
	_exit_world_cleanup()
	get_tree().change_scene_to_packed(_menu_scene_packed)
	_state = State.MENU

func go_to_achievements() -> void:
	if _state != State.MENU:
		return
	_achievements_overlay = _achievements_scene_packed.instantiate()
	get_tree().current_scene.add_child(_achievements_overlay)
	_achievements_overlay.closed.connect(_on_achievements_closed)
	_state = State.ACHIEVEMENTS

func _on_achievements_closed() -> void:
	if _state != State.ACHIEVEMENTS:
		return
	if _achievements_overlay != null:
		_achievements_overlay.queue_free()
		_achievements_overlay = null
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
	_reset_session_stats()
	enter_map("madrian", "")

func _apply_audio_settings() -> void:
	var mv: float = float(save_manager.get_setting("music_volume", 0.5))
	var sv: float = float(save_manager.get_setting("sfx_volume", 1.0))
	AudioManager.set_music_volume(mv)
	AudioManager.set_sfx_volume(sv)

func continue_game() -> void:
	if not save_manager.load_save():
		start_new_game()
		return
	_apply_audio_settings()
	map_stack.assign(save_manager.map_stack)
	door_stack.assign(save_manager.door_stack)
	current_map = save_manager.current_map
	_reset_session_stats()
	_load_world(save_manager.current_map, "")

func _reset_session_stats() -> void:
	session_stats = {
		"battles_won": 0,
		"battles_lost": 0,
		"enemies_defeated": 0,
		"cards_earned": 0,
		"coins_earned": 0,
		"chests_opened": 0,
		"session_start_msec": Time.get_ticks_msec(),
	}

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
	if _journal_overlay != null:
		_journal_overlay.queue_free()
		_journal_overlay = null
	if _character_overlay != null:
		_character_overlay.queue_free()
		_character_overlay = null
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
	const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
	# Read enemy context before clearing pending_battle.
	var enemy_type: String = str(save_manager.pending_battle_enemy_data.get("enemy_type", ""))
	var is_boss: bool = bool(save_manager.pending_battle_enemy_data.get("is_boss", false))
	var drop_tier: int = EnemyRegistry.get_difficulty_tier(enemy_type) if enemy_type != "" else 1
	if is_boss:
		drop_tier = 4
	if not _current_battle_enemy_id.is_empty():
		save_manager.mark_enemy_defeated(_current_battle_enemy_id)
		save_manager.increment_progress("enemies_defeated", 1)
		session_stats["enemies_defeated"] = int(session_stats.get("enemies_defeated", 0)) + 1
		_current_battle_enemy_id = ""
	save_manager.increment_progress("battles_won", 1)
	save_manager.check_deck_achievements(save_manager.player_deck)
	session_stats["battles_won"] = int(session_stats.get("battles_won", 0)) + 1
	var reward: String = str(result.get("card_reward", ""))
	if reward != "":
		var rarity: String = CardDropUtil.effective_rarity(reward, CardDropUtil.roll_rarity(drop_tier))
		var stats: Dictionary = CardDropUtil.roll_stats(reward, rarity)
		save_manager.add_card_instance(reward, rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1)))
		session_stats["cards_earned"] = int(session_stats.get("cards_earned", 0)) + 1
	var weapon_reward: String = str(result.get("weapon_reward", ""))
	if weapon_reward != "":
		save_manager.add_weapon(weapon_reward)
	# Boss battles emit card_rewards (list of all drop_pool cards)
	var rewards: Array = result.get("card_rewards", [])
	for r in rewards:
		var rs: String = str(r)
		if rs != "":
			var r_rarity: String = CardDropUtil.effective_rarity(rs, CardDropUtil.roll_rarity(drop_tier))
			var r_stats: Dictionary = CardDropUtil.roll_stats(rs, r_rarity)
			save_manager.add_card_instance(rs, r_rarity, int(r_stats.get("attack", -1)), int(r_stats.get("health", -1)), int(r_stats.get("cost", -1)))
			session_stats["cards_earned"] = int(session_stats.get("cards_earned", 0)) + 1
	# Award coins based on enemy type
	if enemy_type != "":
		var coins: int = EnemyRegistry.get_coin_reward(enemy_type)
		save_manager.add_coins(coins)
		session_stats["coins_earned"] = int(session_stats.get("coins_earned", 0)) + coins
	save_manager.clear_pending_battle()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	_restore_world()

func _on_battle_lost() -> void:
	if _state != State.BATTLE:
		return
	_current_battle_enemy_id = ""
	session_stats["battles_lost"] = int(session_stats.get("battles_lost", 0)) + 1
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

func _on_journal_requested() -> void:
	if _state != State.WORLD:
		return
	_journal_overlay = _journal_scene_packed.instantiate()
	get_tree().current_scene.add_child(_journal_overlay)
	_journal_overlay.closed.connect(_on_journal_closed)
	_state = State.JOURNAL

func _on_journal_closed() -> void:
	if _state != State.JOURNAL:
		return
	if _journal_overlay != null:
		_journal_overlay.queue_free()
		_journal_overlay = null
	_state = State.WORLD

func _on_character_requested() -> void:
	if _state != State.WORLD:
		return
	_character_overlay = _character_scene_packed.instantiate()
	get_tree().current_scene.add_child(_character_overlay)
	_character_overlay.closed.connect(_on_character_closed)
	_state = State.CHARACTER

func _on_character_closed() -> void:
	if _state != State.CHARACTER:
		return
	if _character_overlay != null:
		_character_overlay.queue_free()
		_character_overlay = null
	_state = State.WORLD

func _on_achievement_unlocked(achievement_id: String) -> void:
	const AchievementRegistry = preload("res://game_logic/AchievementRegistry.gd")
	var a: Dictionary = AchievementRegistry.get_achievement(achievement_id)
	var reward_card: String = str(a.get("reward_card_id", ""))
	if reward_card != "":
		save_manager.grant_achievement_card(reward_card)
