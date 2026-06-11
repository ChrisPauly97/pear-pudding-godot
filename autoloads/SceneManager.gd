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
	SKILL_TREE,
}

const _SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _AchievementToastScript = preload("res://scenes/ui/AchievementToast.gd")
const _TutorialPopupScript = preload("res://scenes/ui/TutorialPopup.gd")
const TutorialRegistry = preload("res://game_logic/TutorialRegistry.gd")

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
var _skill_tree_scene_packed := preload("res://scenes/ui/SkillTreeScene.tscn")
var _journal_scene_packed := preload("res://scenes/ui/JournalScene.tscn")
var _achievements_scene_packed := preload("res://scenes/ui/AchievementsScene.tscn")
var _run_summary_scene_packed := preload("res://scenes/ui/RunSummaryScene.tscn")
var _spire_draft_scene_packed := preload("res://scenes/ui/SpireDraftScene.tscn")

var _state: State = State.MENU
var _battle_overlay: Node = null
var _inventory_overlay: Node = null
var _shop_overlay: Node = null
var _journal_overlay: Node = null
var _achievements_overlay: Node = null
var _character_overlay: Node = null
var _skill_tree_overlay: Node = null
var _spire_draft_overlay: Node = null
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
# Tracks which duelist NPC triggered the current duel (for defeat tracking)
var _current_duel_npc_id: String = ""
# Legendary card to award on first champion duel win ("" = none)
var _current_champion_reward: String = ""

## SaveManager is owned here so its lifecycle is explicit rather than being a
## magic autoload. Other systems access it via SceneManager.save_manager.
var save_manager: Node

func _ready() -> void:
	save_manager = _SaveManagerScript.new()
	add_child(save_manager)
	_toast = _AchievementToastScript.new()
	add_child(_toast)
	GameBus.enemy_engaged.connect(_on_enemy_engaged)
	GameBus.duel_requested.connect(_on_duel_requested)
	GameBus.battle_won.connect(_on_battle_won)
	GameBus.battle_lost.connect(_on_battle_lost)
	GameBus.duel_won.connect(_on_duel_won)
	GameBus.duel_lost.connect(_on_duel_lost)
	GameBus.inventory_requested.connect(_on_inventory_requested)
	GameBus.shop_requested.connect(_on_shop_requested)
	GameBus.journal_requested.connect(_on_journal_requested)
	GameBus.character_requested.connect(_on_character_requested)
	GameBus.skill_tree_requested.connect(_on_skill_tree_requested)
	GameBus.achievement_unlocked.connect(_on_achievement_unlocked)
	GameBus.level_up.connect(_on_level_up)
	GameBus.tutorial_popup_requested.connect(_on_tutorial_popup_requested)

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
	# Spire: exiting a floor loads the next floor rather than popping the map stack.
	if save_manager.is_spire_active() and current_map.begins_with("spire_floor_"):
		_advance_spire_floor()
		return
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
	if _skill_tree_overlay != null:
		_skill_tree_overlay.queue_free()
		_skill_tree_overlay = null
	if _spire_draft_overlay != null:
		_spire_draft_overlay.queue_free()
		_spire_draft_overlay = null
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
	GameBus.tutorial_popup_requested.emit("mana")
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

func _on_duel_requested(enemy_data: Dictionary, wager: int) -> void:
	if _state != State.WORLD:
		return
	if save_manager.player_deck.size() < IsoConst.DECK_MIN:
		GameBus.hud_message_requested.emit("Deck too small — add at least %d cards first." % IsoConst.DECK_MIN)
		return
	_current_duel_npc_id = str(enemy_data.get("duel_npc_id", ""))
	_current_champion_reward = str(enemy_data.get("champion_reward_card", ""))
	_saved_world_scene = get_tree().current_scene
	get_tree().root.remove_child(_saved_world_scene)
	_battle_overlay = _battle_scene_packed.instantiate()
	_battle_overlay.enemy_data = enemy_data
	_battle_overlay.duel_wager = wager
	get_tree().root.add_child(_battle_overlay)
	get_tree().current_scene = _battle_overlay
	_state = State.BATTLE

func _on_duel_won() -> void:
	if _state != State.BATTLE:
		return
	# Champion first-win: award legendary before marking defeated (so the "first win" check is accurate).
	var grant_card: String = ""
	if not _current_champion_reward.is_empty() and not _current_duel_npc_id.is_empty():
		if not save_manager.defeated_duelists.has(_current_duel_npc_id):
			grant_card = _current_champion_reward
			save_manager.add_card_instance(grant_card, "legendary")
			session_stats["cards_earned"] = int(session_stats.get("cards_earned", 0)) + 1
			save_manager.set_story_flag("champion_blancogov_defeated")
	_current_champion_reward = ""
	if not _current_duel_npc_id.is_empty():
		save_manager.mark_duelist_defeated(_current_duel_npc_id)
		_current_duel_npc_id = ""
	save_manager.clear_pending_battle_state()
	save_manager.save()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	_restore_world()
	if grant_card != "":
		GameBus.hud_message_requested.emit("Champion defeated! %s added to your collection." % grant_card)

func _on_duel_lost() -> void:
	if _state != State.BATTLE:
		return
	_current_duel_npc_id = ""
	_current_champion_reward = ""
	save_manager.clear_pending_battle_state()
	save_manager.save()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	_restore_world()

func _restore_world() -> void:
	if _saved_world_scene != null:
		get_tree().root.add_child(_saved_world_scene)
		get_tree().current_scene = _saved_world_scene
		_saved_world_scene = null
	_state = State.WORLD

func _on_battle_won(result: Dictionary) -> void:
	if _state != State.BATTLE:
		return
	# Spire run: skip standard card/coin rewards; save hero HP; show draft overlay.
	if save_manager.is_spire_active():
		var hero_hp: int = int(result.get("hero_hp", 30))
		save_manager.set_spire_hero_hp(hero_hp)
		var spire_run: Dictionary = save_manager.get_spire_run()
		var curr_floor: int = int(spire_run.get("floor", 1))
		var run_seed: int = int(spire_run.get("seed", 0))
		save_manager.set_story_flag("spire_floor_%d_%d_cleared" % [curr_floor, run_seed])
		if not _current_battle_enemy_id.is_empty():
			save_manager.mark_enemy_defeated(_current_battle_enemy_id)
			save_manager.increment_progress("enemies_defeated", 1)
			session_stats["enemies_defeated"] = int(session_stats.get("enemies_defeated", 0)) + 1
			_current_battle_enemy_id = ""
		save_manager.increment_progress("battles_won", 1)
		session_stats["battles_won"] = int(session_stats.get("battles_won", 0)) + 1
		save_manager.clear_pending_battle()
		save_manager.clear_pending_battle_state()
		save_manager.save()
		if _battle_overlay != null:
			_battle_overlay.queue_free()
			_battle_overlay = null
		_restore_world()
		_show_spire_draft(curr_floor)
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
	# Award XP based on enemy type
	const _XP_TABLE: Dictionary = {
		"undead_basic": 20, "undead_horde": 35, "ghoul_pack": 50, "undead_elite": 80,
	}
	var xp_amount: int = int(_XP_TABLE.get(enemy_type, 25)) if enemy_type != "" else 25
	if is_boss:
		xp_amount = int(xp_amount * 2)
	save_manager.add_xp(xp_amount)
	session_stats["xp_earned"] = int(session_stats.get("xp_earned", 0)) + xp_amount
	save_manager.clear_pending_battle()
	save_manager.clear_pending_battle_state()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	_restore_world()

func _on_battle_lost() -> void:
	if _state != State.BATTLE:
		return
	_current_battle_enemy_id = ""
	session_stats["battles_lost"] = int(session_stats.get("battles_lost", 0)) + 1
	if save_manager.is_spire_active():
		save_manager.end_spire_run()
	save_manager.clear_pending_battle()
	save_manager.clear_pending_battle_state()
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

func _on_skill_tree_requested() -> void:
	if _state != State.WORLD:
		return
	GameBus.tutorial_popup_requested.emit("skill_tree")
	_skill_tree_overlay = _skill_tree_scene_packed.instantiate()
	get_tree().current_scene.add_child(_skill_tree_overlay)
	_skill_tree_overlay.closed.connect(_on_skill_tree_closed)
	_state = State.SKILL_TREE

func _on_skill_tree_closed() -> void:
	if _state != State.SKILL_TREE:
		return
	if _skill_tree_overlay != null:
		_skill_tree_overlay.queue_free()
		_skill_tree_overlay = null
	_state = State.WORLD

func _on_achievement_unlocked(achievement_id: String) -> void:
	const AchievementRegistry = preload("res://game_logic/AchievementRegistry.gd")
	var a: Dictionary = AchievementRegistry.get_achievement(achievement_id)
	var reward_card: String = str(a.get("reward_card_id", ""))
	if reward_card != "":
		save_manager.grant_achievement_card(reward_card)

func _on_level_up(new_level: int) -> void:
	_toast.show_text("Level Up!", "You are now level %d" % new_level)

func _on_tutorial_popup_requested(popup_id: String) -> void:
	var flag: String = "seen_tutorial_" + popup_id
	if save_manager.get_story_flag(flag):
		return
	var entry: Dictionary = TutorialRegistry.get_entry(popup_id)
	if entry.is_empty():
		return
	save_manager.set_story_flag(flag)
	var popup := _TutorialPopupScript.new()
	popup.setup(str(entry.get("title", "")), str(entry.get("body", "")))
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 999
	get_tree().root.add_child(layer)
	layer.add_child(popup)
	popup.closed.connect(func() -> void: layer.queue_free())

# ── Endless Spire helpers ───────────────────────────────────────────────────

func _show_spire_draft(floor: int) -> void:
	_spire_draft_overlay = _spire_draft_scene_packed.instantiate()
	get_tree().current_scene.add_child(_spire_draft_overlay)
	_spire_draft_overlay.setup(floor)
	_spire_draft_overlay.picked.connect(_on_spire_draft_picked)

func _on_spire_draft_picked(_card_id: String) -> void:
	_spire_draft_overlay = null  # SpireDraftScene.queue_free()s itself in _on_pick

func _advance_spire_floor() -> void:
	save_manager.advance_spire_floor()
	var run: Dictionary = save_manager.get_spire_run()
	var next_floor: int = int(run.get("floor", 1))
	var run_seed: int = int(run.get("seed", 0))
	var next_map: String = "spire_floor_%d_%d" % [next_floor, run_seed]
	current_map = next_map
	save_manager.sync_stacks(map_stack, door_stack)
	save_manager.save()
	_load_world(next_map, "")
