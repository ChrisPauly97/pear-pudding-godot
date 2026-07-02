extends Node

enum State {
	MENU,
	WORLD,
	BATTLE,
	INVENTORY,    # kept for backwards-compat; no longer used by routing
	SHOP,
	GAME_OVER,
	JOURNAL,      # kept for backwards-compat; no longer used by routing
	ACHIEVEMENTS,
	RUN_SUMMARY,
	CHARACTER,    # kept for backwards-compat; no longer used by routing
	SKILL_TREE,   # kept for backwards-compat; no longer used by routing
	PACK_OPEN,
	BOUNTY_BOARD,
	BLACKSMITH,
	MENU_HUB,
}

const _PackOpenSceneScript = preload("res://scenes/ui/PackOpenScene.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _AchievementToastScript = preload("res://scenes/ui/AchievementToast.gd")
const _TutorialPopupScript = preload("res://scenes/ui/TutorialPopup.gd")
const TutorialRegistry = preload("res://game_logic/TutorialRegistry.gd")
const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
const Gambits = preload("res://game_logic/battle/Gambits.gd")
const _GambitPickerOverlay = preload("res://scenes/battle/GambitPickerOverlay.gd")
const _MenuHubScript = preload("res://scenes/ui/MenuHubScene.gd")

# Ghost duels (GID-102 / TID-377): flat, modest, clearly-async coin reward on win.
# No rating change ever (see enter_ghost_duel doc comment) — coins only.
const GHOST_DUEL_COIN_REWARD: int = 25

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
var _bounty_board_scene_packed := preload("res://scenes/ui/BountyBoardScene.tscn")
var _blacksmith_scene_packed := preload("res://scenes/ui/BlacksmithScene.tscn")

var _state: State = State.MENU
var _battle_overlay: Node = null
var _overlays: Dictionary = {}  # State -> Node, for WORLD-state overlays
var _achievements_overlay: Node = null
var _spire_draft_overlay: Node = null
var _pack_open_overlay: Node = null
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
var _menu_hub_layer: CanvasLayer = null
var _defeat_overlay: Node = null
var _defeat_pending_enemy_data: Dictionary = {}

# Blocks proximity engagement for 2 s after returning from battle so the
# player isn't immediately chain-engaged by a nearby enemy on world re-entry.
var _proximity_engage_blocked: bool = false

## Returns true if tracking enemies may auto-engage the player on proximity.
func can_proximity_engage() -> bool:
	return _state == State.WORLD and not _proximity_engage_blocked

# Tracks which enemy triggered the current battle (for defeat marking)
var _current_battle_enemy_id: String = ""
# Tracks which duelist NPC triggered the current duel (for defeat tracking)
var _current_duel_npc_id: String = ""
# Legendary card to award on first champion duel win ("" = none)
var _current_champion_reward: String = ""
# Enemy type for the current co-op PvE battle (for achievement tracking)
var _coop_pve_enemy_type: String = ""

## Points at the SaveManager autoload so all systems share one instance.
## The autoload is registered before SceneManager in project.godot.
var save_manager: Node

func _ready() -> void:
	save_manager = SaveManager
	_toast = _AchievementToastScript.new()
	add_child(_toast)
	GameBus.enemy_engaged.connect(_on_enemy_engaged)
	GameBus.duel_requested.connect(_on_duel_requested)
	GameBus.battle_won.connect(_on_battle_won)
	GameBus.battle_lost.connect(_on_battle_lost)
	GameBus.battle_fled.connect(_on_battle_fled)
	GameBus.pvp_battle_ended.connect(_on_pvp_battle_ended)
	GameBus.coop_pve_battle_ended.connect(_on_coop_pve_battle_ended)
	GameBus.team_battle_ended.connect(_on_team_battle_ended)
	GameBus.duel_won.connect(_on_duel_won)
	GameBus.duel_lost.connect(_on_duel_lost)
	GameBus.ghost_duel_ended.connect(_on_ghost_duel_ended)
	GameBus.inventory_requested.connect(_on_inventory_requested)
	GameBus.shop_requested.connect(_on_shop_requested)
	GameBus.bounty_board_requested.connect(_on_bounty_board_requested)
	GameBus.blacksmith_requested.connect(_on_blacksmith_requested)
	GameBus.traveling_shop_requested.connect(_on_traveling_shop_requested)
	GameBus.journal_requested.connect(_on_journal_requested)
	GameBus.character_requested.connect(_on_character_requested)
	GameBus.skill_tree_requested.connect(_on_skill_tree_requested)
	GameBus.achievement_unlocked.connect(_on_achievement_unlocked)
	GameBus.level_up.connect(_on_level_up)
	GameBus.tutorial_popup_requested.connect(_on_tutorial_popup_requested)
	GameBus.puzzle_requested.connect(_on_puzzle_requested)
	GameBus.puzzle_solved.connect(_on_puzzle_solved)
	GameBus.fragment_collected.connect(_on_fragment_collected)
	GameBus.treasure_map_assembled.connect(_on_treasure_map_assembled)
	GameBus.treasure_excavated.connect(_on_treasure_excavated)
	GameBus.pack_purchased.connect(_on_pack_purchased)
	GameBus.bag_full.connect(func() -> void:
		GameBus.hud_message_requested.emit("Bag full! Sell or scrap cards to make room."))
	GameBus.siege_defeated.connect(func(coins_lost: int) -> void:
		show_toast("Siege Lost", "The town fell. Lost %d coins." % coins_lost))
	_maybe_boot_dedicated_server()

## Dedicated server boot (GID-097 / TID-352).
## Invocation: godot --headless -- --server [--port N] [--map NAME]
## Parses user args, sets NetworkManager server-mode, hosts on the given port with
## 4 client slots (no host-is-player slot consumed), and loads the shared map.
## Deferred so the main scene (MenuScene) finishes loading before we replace it.
func _maybe_boot_dedicated_server() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.has("--server"):
		return
	var port: int = NetworkManager.DEFAULT_PORT
	var map_name: String = "madrian"
	for i: int in range(args.size()):
		var arg: String = args[i]
		if arg == "--port" and i + 1 < args.size():
			port = int(args[i + 1])
		elif arg == "--map" and i + 1 < args.size():
			map_name = args[i + 1]
	print("[Server] Dedicated server starting — port %d, map '%s'" % [port, map_name])
	NetworkManager._server_mode = true
	var err: Error = NetworkManager.host(port, 4)
	if err != OK:
		push_error("[Server] Failed to bind port %d (error %d) — exiting." % [port, err])
		get_tree().quit(1)
		return
	print("[Server] Listening. Connect with: godot -- --join <server-ip> [--port %d]" % port)
	# Deferred so MenuScene's _ready completes before we change the scene.
	enter_map_coop.call_deferred(map_name)

func go_to_menu() -> void:
	_flush_position_save()
	var scene := get_tree().current_scene
	if scene and scene.has_method("flush_time_of_day"):
		scene.flush_time_of_day()
	# Spire retreat: restore entry point, end run, show Spire summary.
	if _state == State.WORLD and save_manager.is_spire_active():
		_restore_spire_entry_point()
		var stats: Dictionary = save_manager.end_spire_run()
		GameBus.spire_run_ended.emit(stats)
		save_manager.save()
		_exit_world_cleanup()
		var spire_summary: Node = _run_summary_scene_packed.instantiate()
		spire_summary.set("spire_stats", stats)
		TransitionManager.transition(func() -> void:
			get_tree().change_scene_to_node(spire_summary))
		_state = State.RUN_SUMMARY
		return
	save_manager.save()
	# Show session run summary only when leaving the world.
	if _state == State.WORLD:
		_exit_world_cleanup()
		var summary: Node = _run_summary_scene_packed.instantiate()
		TransitionManager.transition(func() -> void:
			get_tree().change_scene_to_node(summary))
		_state = State.RUN_SUMMARY
		return
	_exit_world_cleanup()
	TransitionManager.transition(func() -> void:
		get_tree().change_scene_to_packed(_menu_scene_packed))
	_state = State.MENU

func go_to_menu_direct() -> void:
	_exit_world_cleanup()
	TransitionManager.transition(func() -> void:
		get_tree().change_scene_to_packed(_menu_scene_packed))
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
	_apply_audio_settings()
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

# Co-op (GID-090): enter a shared named map for a networked session. Reuses the
# normal map-load path; an active NetworkManager session makes WorldScene wire up
# its co-op hooks (_setup_coop). Clears any prior world/stack so the session
# starts clean from the main menu. save() inside enter_map is a no-op when no
# game has been loaded, so this is safe without an active save slot.
func enter_map_coop(map_name: String) -> void:
	_exit_world_cleanup()
	# Cold co-op launched from the menu has no deck — seed a transient one so both
	# peers can pass the PvP DECK_MIN gate (TID-335). No-op for a loaded game; never
	# persists (save() is a no-op until a real game is loaded).
	save_manager.ensure_coop_deck()
	enter_map(map_name, "")

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

func go_to_slot_select() -> void:
	_exit_world_cleanup()
	TransitionManager.transition(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/SlotSelectScene.tscn"))
	_state = State.MENU

func _load_world(map_name: String, target_door_id: String) -> void:
	var world: Node = _world_scene_packed.instantiate()
	world.set("map_name", map_name)
	world.set("target_door_id", target_door_id)
	TransitionManager.transition(func() -> void:
		get_tree().change_scene_to_node(world)
		_state = State.WORLD)

func _exit_world_cleanup() -> void:
	if _menu_hub_layer != null and is_instance_valid(_menu_hub_layer):
		_menu_hub_layer.queue_free()
		_menu_hub_layer = null
	if _defeat_overlay != null:
		_defeat_overlay.queue_free()
		_defeat_overlay = null
	_defeat_pending_enemy_data = {}
	if _saved_world_scene != null:
		_saved_world_scene.queue_free()
		_saved_world_scene = null
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	for overlay: Node in _overlays.values():
		if overlay != null:
			overlay.queue_free()
	_overlays.clear()
	if _spire_draft_overlay != null:
		_spire_draft_overlay.queue_free()
		_spire_draft_overlay = null
	if _pack_open_overlay != null:
		_pack_open_overlay.queue_free()
		_pack_open_overlay = null
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
	var engaged_enemy_type: String = str(enemy_data.get("enemy_type", ""))
	if engaged_enemy_type != "":
		save_manager.record_enemy_seen(engaged_enemy_type)
	# Stamp battlefield context (GID-059): biome + time-of-day at engagement.
	# Skip if already present (resumed battle already has context in pending_battle_enemy_data).
	if not enemy_data.has("battlefield_biome"):
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("get_battlefield_context"):
			var ctx: Dictionary = scene.get_battlefield_context()
			enemy_data["battlefield_biome"] = ctx.get("biome", -1)
			enemy_data["battlefield_is_night"] = ctx.get("is_night", false)
			enemy_data["is_blighted"] = ctx.get("is_blighted", false)
			enemy_data["player_attuned"] = ctx.get("is_player_attuned", false)
		else:
			enemy_data["battlefield_biome"] = -1
			enemy_data["battlefield_is_night"] = false
			enemy_data["is_blighted"] = false
			enemy_data["player_attuned"] = false
	GameBus.tutorial_popup_requested.emit("mana")
	# Skip picker on resume (pending_battle_enemy_data already set from a prior session)
	# or when the player has enabled auto-skip via the "Don't ask again" checkbox.
	var is_resume: bool = not save_manager.pending_battle_enemy_data.is_empty()
	var auto_skip: bool = bool(save_manager.get_setting("auto_skip_gambits", false))
	if is_resume or auto_skip:
		_start_battle(enemy_data)
		return
	# Show gambit picker; battle starts once the player makes a choice.
	var picker := _GambitPickerOverlay.new()
	var layer := CanvasLayer.new()
	layer.layer = 200
	get_tree().root.add_child(layer)
	layer.add_child(picker)
	var captured: Dictionary = enemy_data
	picker.gambit_chosen.connect(func(gambit_id: String) -> void:
		layer.queue_free()
		if not gambit_id.is_empty():
			captured["gambit_id"] = gambit_id
		_start_battle(captured))

func _start_battle(enemy_data: Dictionary) -> void:
	save_manager.set_pending_battle(enemy_data)
	save_manager.save()
	var captured_enemy_data: Dictionary = enemy_data
	TransitionManager.transition(func() -> void:
		# Detach world scene from tree so it stops rendering/processing
		_saved_world_scene = get_tree().current_scene
		get_tree().root.remove_child(_saved_world_scene)
		# Promote battle to the active scene
		_battle_overlay = _battle_scene_packed.instantiate()
		_battle_overlay.enemy_data = captured_enemy_data
		get_tree().root.add_child(_battle_overlay)
		get_tree().current_scene = _battle_overlay)
	_state = State.BATTLE

func _on_duel_requested(enemy_data: Dictionary, wager: int) -> void:
	if _state != State.WORLD:
		return
	if save_manager.player_deck.size() < IsoConst.DECK_MIN:
		GameBus.hud_message_requested.emit("Deck too small — add at least %d cards first." % IsoConst.DECK_MIN)
		return
	_current_duel_npc_id = str(enemy_data.get("duel_npc_id", ""))
	_current_champion_reward = str(enemy_data.get("champion_reward_card", ""))
	var captured_duel_data: Dictionary = enemy_data
	var captured_wager: int = wager
	TransitionManager.transition(func() -> void:
		_saved_world_scene = get_tree().current_scene
		get_tree().root.remove_child(_saved_world_scene)
		_battle_overlay = _battle_scene_packed.instantiate()
		_battle_overlay.enemy_data = captured_duel_data
		_battle_overlay.duel_wager = captured_wager
		get_tree().root.add_child(_battle_overlay)
		get_tree().current_scene = _battle_overlay)
	_state = State.BATTLE

# ── Ghost duels (GID-102 / TID-377) ───────────────────────────────────────────

## Enters a local, single-player battle against an AI-piloted snapshot of another
## (possibly offline) session member's deck — async competition with ZERO live
## networking. Reuses the exact same solo-battle setup path as an NPC tavern duel
## (`_on_duel_requested`): no `_pvp`/`_coop_pve` flags are set, so BattleScene's
## plain `else` branch builds `_state.players[1]` from `enemy_data["enemy_deck"]`
## and BasicAI drives it, unchanged.
##
## `opponent_snapshot` is the dict from `SessionState.get_ghost_snapshot(token)`
## (`{token, name, deck, rating}`); an empty/invalid snapshot is rejected here so a
## bad caller can never launch a battle with an empty deck.
##
## Decision (documented, not silently chosen either way): a ghost duel NEVER moves
## PvP rating — win or lose. The opponent is AI-piloted, not the real remote
## player, so rating movement here would let a player farm free ELO against their
## own cached snapshot (or a stale/offline friend's) with no real matched risk.
## Only a flat, modest coin reward is granted, and only on a win — see
## `_on_ghost_duel_ended`.
func enter_ghost_duel(opponent_snapshot: Dictionary) -> void:
	if _state != State.WORLD:
		return
	var deck: Array = opponent_snapshot.get("deck", [])
	if deck.is_empty():
		GameBus.hud_message_requested.emit("That ghost has no deck to duel.")
		return
	if save_manager.player_deck.size() < IsoConst.DECK_MIN:
		GameBus.hud_message_requested.emit("Deck too small — add at least %d cards first." % IsoConst.DECK_MIN)
		return
	var opponent_name: String = str(opponent_snapshot.get("name", "Ghost"))
	var captured_enemy_data: Dictionary = {
		"display_name": "%s (Ghost)" % opponent_name,
		"enemy_type": "",
		"is_boss": false,
		"drop_pool": [],
		"coin_reward": 0,
		"enemy_deck": deck,
	}
	TransitionManager.transition(func() -> void:
		_saved_world_scene = get_tree().current_scene
		get_tree().root.remove_child(_saved_world_scene)
		_battle_overlay = _battle_scene_packed.instantiate()
		_battle_overlay.enemy_data = captured_enemy_data
		_battle_overlay.set("_ghost_duel", true)
		_battle_overlay.set("_ghost_duel_reward", GHOST_DUEL_COIN_REWARD)
		get_tree().root.add_child(_battle_overlay)
		get_tree().current_scene = _battle_overlay)
	_state = State.BATTLE

## Applies the (win-only) ghost-duel coin reward exactly once, then restores the
## world — mirrors `_on_duel_won`/`_on_duel_lost` structurally. No card drops, no
## enemy-defeat bookkeeping, no rating change (see `enter_ghost_duel` doc comment).
func _on_ghost_duel_ended(did_win: bool) -> void:
	if _state != State.BATTLE:
		return
	if did_win:
		save_manager.add_coins(GHOST_DUEL_COIN_REWARD)
		session_stats["coins_earned"] = int(session_stats.get("coins_earned", 0)) + GHOST_DUEL_COIN_REWARD
	save_manager.clear_pending_battle_state()
	save_manager.save()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	_restore_world()

# ── PvP card battles (GID-091) ────────────────────────────────────────────────

## Enters a networked PvP battle from the shared co-op world. The WorldScene is
## detached but kept alive (like a normal battle) so both peers return to the SAME
## madrian session afterwards; the NetworkManager co-op session is NOT torn down.
## local_player_idx: 0 on the host (authority), 1 on the client. opponent_token
## (GID-102 / TID-372) lets the host verify a later reconnect actually claims to be
## this same opponent — empty when unknown (e.g. an already-resumed duel re-entering
## via resume_pvp_battle, which doesn't have a token to pass; verification then
## falls back to accepting any reconnect, the documented same-LAN trust model).
## ranked (GID-102 / TID-373): when true, the duel's outcome moves both combatants'
## persistent ELO rating (TID-370) — both peers must pass the same value (set from the
## challenge handshake, mirroring how ante_coins is agreed before either side calls this).
## local_deck_override (GID-104 / TID-385, draft duels): when non-empty, the
## listen-server host builds its own players[0] deck from these transient instance
## dicts instead of SaveManager.get_deck_instances() — a drafted deck must never
## read (or write) the persisted collection. Empty = normal collection deck.
func enter_pvp_battle(local_player_idx: int, opponent_deck: Array, ante_coins: int = 0,
		opponent_token: String = "", ranked: bool = false,
		local_deck_override: Array = []) -> void:
	if _state != State.WORLD:
		return
	var captured_idx: int = local_player_idx
	var captured_deck: Array = opponent_deck
	var captured_ante: int = ante_coins
	var captured_token: String = opponent_token
	var captured_ranked: bool = ranked
	var captured_local_deck: Array = local_deck_override
	TransitionManager.transition(func() -> void:
		_saved_world_scene = get_tree().current_scene
		get_tree().root.remove_child(_saved_world_scene)
		_battle_overlay = _battle_scene_packed.instantiate()
		_battle_overlay.name = "BattleScene"  # fixed RPC path /root/BattleScene/BattleNetSync
		_battle_overlay.set("_pvp", true)
		_battle_overlay.set("_local_player_idx", captured_idx)
		_battle_overlay.set("pvp_opponent_deck", captured_deck)
		_battle_overlay.set("pvp_ante_coins", captured_ante)
		_battle_overlay.set("pvp_opponent_token", captured_token)
		_battle_overlay.set("pvp_ranked", captured_ranked)
		_battle_overlay.set("pvp_local_deck_override", captured_local_deck)
		_battle_overlay.enemy_data = {
			"display_name": "Player",
			"enemy_type": "",
			"is_boss": false,
			"drop_pool": [],
			"coin_reward": 0,
		}
		get_tree().root.add_child(_battle_overlay)
		get_tree().current_scene = _battle_overlay)
	_state = State.BATTLE

## Resumes a PvP duel after a reconnect (GID-102 / TID-372). Called from
## MultiplayerLobbyScene._on_connection_succeeded when NetworkManager.has_pvp_resume()
## instead of the normal enter_map_coop landing. Unlike enter_pvp_battle, this is
## reachable with no current WorldScene (the reconnecting client is coming cold from
## the lobby/menu, not from an active shared world) — so it first lands in the shared
## map (giving enter_pvp_battle a real "_saved_world_scene" to detach/restore later)
## and waits for that transition to actually finish before stacking the battle
## transition on top (TransitionManager.transition() is fire-and-forget async).
func resume_pvp_battle(local_player_idx: int, opponent_deck: Array, ante_coins: int) -> void:
	enter_map_coop("madrian")
	while _state != State.WORLD:
		await get_tree().process_frame
	enter_pvp_battle(local_player_idx, opponent_deck, ante_coins)

## Dedicated-server variant of enter_pvp_battle (GID-097 / TID-353).
## The server is the headless referee: _local_player_idx = -1 (no local player),
## both decks come from the clients, and _pvp_peer_to_idx maps peer_id → player_idx.
## token_a/token_b (GID-102 / TID-372) are the combatants' identity tokens, used to
## verify a later reconnect; empty strings fall back to accepting any reconnect.
func enter_pvp_referee(deck_a: Array, deck_b: Array, peer_a_id: int, peer_b_id: int, token_a: String = "", token_b: String = "") -> void:
	if _state != State.WORLD:
		return
	TransitionManager.transition(func() -> void:
		_saved_world_scene = get_tree().current_scene
		get_tree().root.remove_child(_saved_world_scene)
		_battle_overlay = _battle_scene_packed.instantiate()
		_battle_overlay.name = "BattleScene"  # fixed RPC path /root/BattleScene/BattleNetSync
		_battle_overlay.set("_pvp", true)
		_battle_overlay.set("_local_player_idx", -1)       # no local player
		_battle_overlay.set("pvp_player0_deck", deck_a)
		_battle_overlay.set("pvp_player1_deck", deck_b)
		_battle_overlay.set("_pvp_peer_to_idx", {peer_a_id: 0, peer_b_id: 1})
		_battle_overlay.set("_pvp_idx_to_token", {0: token_a, 1: token_b})
		_battle_overlay.enemy_data = {
			"display_name": "Player",
			"enemy_type": "",
			"is_boss": false,
			"drop_pool": [],
			"coin_reward": 0,
		}
		get_tree().root.add_child(_battle_overlay)
		get_tree().current_scene = _battle_overlay)
	_state = State.BATTLE

## Enters a PvP battle as a read-only spectator (GID-101 / TID-367). The spectator
## renders the board (from a neutral perspective, local_player_idx = -1) but sends
## no intents. The BattleScene's _pvp_spectating flag blocks all input gates.
func enter_pvp_spectator() -> void:
	if _state != State.WORLD:
		return
	TransitionManager.transition(func() -> void:
		_saved_world_scene = get_tree().current_scene
		get_tree().root.remove_child(_saved_world_scene)
		_battle_overlay = _battle_scene_packed.instantiate()
		_battle_overlay.name = "BattleScene"  # fixed RPC path /root/BattleScene/BattleNetSync
		_battle_overlay.set("_pvp", true)
		_battle_overlay.set("_local_player_idx", 0)   # neutral — same as host perspective
		_battle_overlay.set("_pvp_spectating", true)
		_battle_overlay.enemy_data = {
			"display_name": "Player",
			"enemy_type": "",
			"is_boss": false,
			"drop_pool": [],
			"coin_reward": 0,
		}
		get_tree().root.add_child(_battle_overlay)
		get_tree().current_scene = _battle_overlay)
	_state = State.BATTLE


## Enters a co-op PvE battle from the shared world (GID-099).
## All N allies fight a single shared boss together. The authority (host or dedicated
## server) owns the canonical GameState; each client sends intents and renders the
## mirror. local_ally_idx is 0 for the host, 1..N-1 for each additional ally client.
## all_ally_decks is an Array of N Arrays[Dictionary] (deck instances per ally, indexed
## by ally_idx); only the authority uses all N; clients supply their own at idx 0 of
## the outer array (the host re-orders by ally_idx).
## enemy_data is the boss enemy_data dict (same shape as NPC-battle enemy_data).
func enter_coop_pve_battle(local_ally_idx: int, all_ally_decks: Array, enemy_data: Dictionary) -> void:
	if _state != State.WORLD:
		return
	_coop_pve_enemy_type = str(enemy_data.get("enemy_type", ""))
	var captured_idx: int = local_ally_idx
	var captured_decks: Array = all_ally_decks
	var captured_edata: Dictionary = enemy_data
	TransitionManager.transition(func() -> void:
		_saved_world_scene = get_tree().current_scene
		get_tree().root.remove_child(_saved_world_scene)
		_battle_overlay = _battle_scene_packed.instantiate()
		_battle_overlay.name = "BattleScene"  # fixed RPC path /root/BattleScene/BattleNetSync
		_battle_overlay.set("_coop_pve", true)
		_battle_overlay.set("_local_player_idx", captured_idx)
		_battle_overlay.set("_coop_ally_decks", captured_decks)
		_battle_overlay.enemy_data = captured_edata
		get_tree().root.add_child(_battle_overlay)
		get_tree().current_scene = _battle_overlay)
	_state = State.BATTLE

## Enters a 2v2 team PvP duel from the shared world (GID-102 / TID-371). The host is
## always players[0]/team 0 in the canonical GameState; local_player_idx is the local
## participant's absolute index (0..3). team_assignments[i] is the team (0/1) for
## absolute index i. all_decks is an Array of 4 Arrays[Dictionary] (deck instances per
## absolute index); only the authority uses all 4, set by the host from the connected
## peers' relayed decks (see WorldScene's "Team Duel" trigger).
func enter_team_battle(local_player_idx: int, team_assignments: Array, all_decks: Array) -> void:
	if _state != State.WORLD:
		return
	var captured_idx: int = local_player_idx
	var captured_teams: Array = team_assignments
	var captured_decks: Array = all_decks
	TransitionManager.transition(func() -> void:
		_saved_world_scene = get_tree().current_scene
		get_tree().root.remove_child(_saved_world_scene)
		_battle_overlay = _battle_scene_packed.instantiate()
		_battle_overlay.name = "BattleScene"  # fixed RPC path /root/BattleScene/BattleNetSync
		_battle_overlay.set("_team_pvp", true)
		_battle_overlay.set("_local_player_idx", captured_idx)
		_battle_overlay.set("_team_assignments", captured_teams)
		_battle_overlay.set("_team_decks", captured_decks)
		_battle_overlay.enemy_data = {
			"display_name": "Player",
			"enemy_type": "",
			"is_boss": false,
			"drop_pool": [],
			"coin_reward": 0,
		}
		get_tree().root.add_child(_battle_overlay)
		get_tree().current_scene = _battle_overlay)
	_state = State.BATTLE

## Team PvP duel finished (2v2). Restore the shared world (duel-style: no card/coin
## rewards in v1, like unwagered 2-player PvP). Mirrors _on_coop_pve_battle_ended.
func _on_team_battle_ended(_did_win: bool) -> void:
	if _state != State.BATTLE:
		return
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	if _saved_world_scene != null and NetworkManager.is_active():
		_restore_world()
	else:
		if _saved_world_scene != null:
			_saved_world_scene.queue_free()
			_saved_world_scene = null
		go_to_menu_direct()

## Co-op PvE battle finished (all allies vs shared boss). Restore the shared world.
## Mirrors _on_pvp_battle_ended but emitted by GameBus.coop_pve_battle_ended.
func _on_coop_pve_battle_ended(did_win: bool) -> void:
	if _state != State.BATTLE:
		return
	if did_win:
		if not _coop_pve_enemy_type.is_empty():
			save_manager.increment_progress("enemies_defeated", 1)
		save_manager.increment_progress("battles_won", 1)
		save_manager.check_deck_achievements(save_manager.player_deck)
	_coop_pve_enemy_type = ""
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	if _saved_world_scene != null and NetworkManager.is_active():
		_restore_world()
	else:
		if _saved_world_scene != null:
			_saved_world_scene.queue_free()
			_saved_world_scene = null
		go_to_menu_direct()

## PvP battle finished (duel-style: no cards/coins/defeat tracking). Restore the
## shared co-op world. If the session ended (host vanished for a client), the
## world can't be restored → go to the menu cleanly.
func _on_pvp_battle_ended(_did_win: bool) -> void:
	if _state != State.BATTLE:
		return
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	if _saved_world_scene != null and NetworkManager.is_active():
		_restore_world()
	elif NetworkManager.is_dedicated_server():
		# Server restores its world scene — no menu to fall back to.
		if _saved_world_scene != null:
			get_tree().root.add_child(_saved_world_scene)
			get_tree().current_scene = _saved_world_scene
			_state = State.WORLD
	else:
		# No co-op session / world to return to.
		if _saved_world_scene != null:
			_saved_world_scene.queue_free()
			_saved_world_scene = null
		go_to_menu_direct()

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
	_proximity_engage_blocked = true
	get_tree().create_timer(2.0, false).timeout.connect(
		func() -> void: _proximity_engage_blocked = false)
	TransitionManager.transition(func() -> void:
		if _saved_world_scene != null:
			get_tree().root.add_child(_saved_world_scene)
			get_tree().current_scene = _saved_world_scene
			_saved_world_scene = null
		_state = State.WORLD)

func _on_puzzle_requested(puzzle_id: String) -> void:
	const PuzzleRegistry_cls = preload("res://autoloads/PuzzleRegistry.gd")
	var pdata: Resource = PuzzleRegistry_cls.get_puzzle(puzzle_id)
	if pdata == null:
		push_error("SceneManager: puzzle not found: " + puzzle_id)
		return
	_flush_position_save()
	var captured_pdata: Resource = pdata
	TransitionManager.transition(func() -> void:
		if get_tree().current_scene != null:
			_saved_world_scene = get_tree().current_scene
			get_tree().root.remove_child(_saved_world_scene)
		_battle_overlay = _battle_scene_packed.instantiate()
		_battle_overlay.puzzle_data = captured_pdata
		get_tree().root.add_child(_battle_overlay)
		get_tree().current_scene = _battle_overlay)
	_state = State.BATTLE

func _on_puzzle_solved(puzzle_id: String) -> void:
	if _state != State.BATTLE:
		return
	const PD = preload("res://game_logic/battle/PuzzleData.gd")
	if not save_manager.is_puzzle_solved(puzzle_id):
		var pdata: PD = PuzzleRegistry.get_puzzle(puzzle_id) as PD
		if pdata != null and not pdata.reward_card_id.is_empty():
			save_manager.add_card_instance(pdata.reward_card_id, "rare")
			session_stats["cards_earned"] = int(session_stats.get("cards_earned", 0)) + 1
		save_manager.mark_puzzle_solved(puzzle_id)
	save_manager.save()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	_restore_world()

func return_from_puzzle() -> void:
	save_manager.save()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	_restore_world()

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
		var spire_enemy_type: String = str(save_manager.pending_battle_enemy_data.get("enemy_type", ""))
		if not _current_battle_enemy_id.is_empty():
			save_manager.mark_enemy_defeated(_current_battle_enemy_id)
			save_manager.increment_progress("enemies_defeated", 1)
			session_stats["enemies_defeated"] = int(session_stats.get("enemies_defeated", 0)) + 1
			_current_battle_enemy_id = ""
		if spire_enemy_type != "":
			save_manager.record_enemy_defeated(spire_enemy_type)
			save_manager.increment_bounty_progress("defeat_enemy_type", {"enemy_type": spire_enemy_type})
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
	# Siege gauntlet: skip standard rewards; chain stages or apply siege victory.
	var _siege: Dictionary = save_manager.get_active_siege()
	if not _siege.is_empty():
		var _siege_hero_hp: int = int(result.get("hero_hp", 30))
		save_manager.set_siege_hero_hp(_siege_hero_hp)
		var _siege_stage: int = int(_siege.get("stage", 0))
		save_manager.increment_progress("battles_won", 1)
		session_stats["battles_won"] = int(session_stats.get("battles_won", 0)) + 1
		_current_battle_enemy_id = ""
		save_manager.clear_pending_battle()
		save_manager.clear_pending_battle_state()
		if _siege_stage < 2:
			save_manager.advance_siege_stage()
			save_manager.save()
			if _battle_overlay != null:
				_battle_overlay.queue_free()
				_battle_overlay = null
			_restore_world()
			_show_siege_interstitial(_siege_stage + 1, _siege_hero_hp)
			return
		else:
			_apply_siege_victory_rewards(str(_siege.get("town", "")))
			save_manager.end_siege_victory()
			save_manager.save()
			if _battle_overlay != null:
				_battle_overlay.queue_free()
				_battle_overlay = null
			_restore_world()
			return
	const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
	# Read enemy context before clearing pending_battle.
	var enemy_type: String = str(save_manager.pending_battle_enemy_data.get("enemy_type", ""))
	var is_boss: bool = bool(save_manager.pending_battle_enemy_data.get("is_boss", false))
	var gambit_id: String = str(save_manager.pending_battle_enemy_data.get("gambit_id", ""))
	var is_rival: bool = enemy_type.begins_with("rival_")
	var captured_enemy_id: String = _current_battle_enemy_id
	# Mimic chest victory: open the chest, grant loot directly to inventory, restore world.
	if enemy_type == "mimic" and not captured_enemy_id.is_empty():
		var mimic_chest_id: String = captured_enemy_id
		var wmap_node: Variant = _saved_world_scene.get("world_map") if _saved_world_scene != null else null
		if wmap_node != null:
			var mimic_chest: Dictionary = wmap_node.find_chest_by_id(mimic_chest_id)
			if not mimic_chest.is_empty():
				mimic_chest["opened"] = true
				var chest_cards: Array[String] = []
				chest_cards.assign(mimic_chest.get("card_ids", []))
				for card_id: String in chest_cards:
					var rarity: String = CardDropUtil.effective_rarity(card_id, CardDropUtil.roll_rarity(3))
					var stats: Dictionary = CardDropUtil.roll_stats(card_id, rarity)
					save_manager.add_card_instance(card_id, rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1)))
					session_stats["cards_earned"] = int(session_stats.get("cards_earned", 0)) + 1
		var mimic_drop_pool: Array[String] = EnemyRegistry.get_drop_pool("mimic")
		if not mimic_drop_pool.is_empty():
			var bonus_card: String = mimic_drop_pool[randi() % mimic_drop_pool.size()]
			var b_rarity: String = CardDropUtil.effective_rarity(bonus_card, CardDropUtil.roll_rarity(2))
			var b_stats: Dictionary = CardDropUtil.roll_stats(bonus_card, b_rarity)
			save_manager.add_card_instance(bonus_card, b_rarity, int(b_stats.get("attack", -1)), int(b_stats.get("health", -1)), int(b_stats.get("cost", -1)))
			session_stats["cards_earned"] = int(session_stats.get("cards_earned", 0)) + 1
		var mimic_coins: int = EnemyRegistry.get_coin_reward("mimic")
		save_manager.add_coins(mimic_coins)
		session_stats["coins_earned"] = int(session_stats.get("coins_earned", 0)) + mimic_coins
		save_manager.mark_chest_opened(mimic_chest_id)
		save_manager.record_enemy_defeated("mimic")
		save_manager.increment_bounty_progress("defeat_enemy_type", {"enemy_type": "mimic"})
		save_manager.increment_progress("enemies_defeated", 1)
		session_stats["enemies_defeated"] = int(session_stats.get("enemies_defeated", 0)) + 1
		save_manager.increment_progress("battles_won", 1)
		session_stats["battles_won"] = int(session_stats.get("battles_won", 0)) + 1
		_current_battle_enemy_id = ""
		save_manager.clear_pending_battle()
		save_manager.clear_pending_battle_state()
		save_manager.save()
		if _battle_overlay != null:
			_battle_overlay.queue_free()
			_battle_overlay = null
		_restore_world()
		return
	var drop_tier: int = EnemyRegistry.get_difficulty_tier(enemy_type) if enemy_type != "" else 1
	if is_boss:
		drop_tier = 4
	elif EnemyRegistry.get_night_drop_boost(enemy_type):
		drop_tier = mini(drop_tier + 1, 4)
	drop_tier = mini(drop_tier + Gambits.get_rarity_tier_bonus(gambit_id), 4)
	var is_nocturnal: bool = enemy_type.begins_with("spectre_")
	if not _current_battle_enemy_id.is_empty():
		if not is_rival and not is_nocturnal:
			save_manager.mark_enemy_defeated(_current_battle_enemy_id)
		save_manager.increment_progress("enemies_defeated", 1)
		session_stats["enemies_defeated"] = int(session_stats.get("enemies_defeated", 0)) + 1
		_current_battle_enemy_id = ""
	if enemy_type != "" and not is_rival and not is_nocturnal:
		save_manager.record_enemy_defeated(enemy_type)
		save_manager.increment_bounty_progress("defeat_enemy_type", {"enemy_type": enemy_type})
	save_manager.increment_progress("battles_won", 1)
	save_manager.check_deck_achievements(save_manager.player_deck)
	session_stats["battles_won"] = int(session_stats.get("battles_won", 0)) + 1
	var reward: String = str(result.get("card_reward", ""))
	if reward != "":
		# Use pre-rolled rarity/stats from BattleScene if present; otherwise roll now.
		var rarity: String
		var stats: Dictionary
		if result.has("reward_rarity"):
			rarity = str(result["reward_rarity"])
			stats = result.get("reward_stats", {})
		else:
			rarity = CardDropUtil.effective_rarity(reward, CardDropUtil.roll_rarity(drop_tier))
			stats = CardDropUtil.roll_stats(reward, rarity)
		save_manager.add_card_instance(reward, rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1)))
		session_stats["cards_earned"] = int(session_stats.get("cards_earned", 0)) + 1
	var weapon_reward: String = str(result.get("weapon_reward", ""))
	if weapon_reward != "":
		save_manager.add_weapon(weapon_reward)
	# Soulbind signature capture (GID-061): grant signature card + persist capture.
	var sig_capture: String = str(result.get("signature_capture", ""))
	if sig_capture != "":
		var sig_stats: Dictionary = CardDropUtil.roll_stats(sig_capture, "rare")
		save_manager.add_card_instance(sig_capture, "rare", int(sig_stats.get("attack", -1)), int(sig_stats.get("health", -1)), int(sig_stats.get("cost", -1)))
		save_manager.mark_signature_captured(sig_capture)
		session_stats["cards_earned"] = int(session_stats.get("cards_earned", 0)) + 1
	# Boss battles emit card_rewards (list of all drop_pool cards)
	var rewards: Array = result.get("card_rewards", [])
	var pre_rolled: Array = result.get("reward_rarities", [])
	var pre_stats: Array = result.get("reward_stats_list", [])
	for ri in range(rewards.size()):
		var rs: String = str(rewards[ri])
		if rs != "":
			var r_rarity: String
			var r_stats: Dictionary
			if ri < pre_rolled.size():
				r_rarity = str(pre_rolled[ri])
				r_stats = pre_stats[ri] if ri < pre_stats.size() else {}
			else:
				r_rarity = CardDropUtil.effective_rarity(rs, CardDropUtil.roll_rarity(drop_tier))
				r_stats = CardDropUtil.roll_stats(rs, r_rarity)
			save_manager.add_card_instance(rs, r_rarity, int(r_stats.get("attack", -1)), int(r_stats.get("health", -1)), int(r_stats.get("cost", -1)))
			session_stats["cards_earned"] = int(session_stats.get("cards_earned", 0)) + 1
	# Award coins based on enemy type, multiplied by active gambit reward factor.
	if enemy_type != "":
		var coins: int = Gambits.apply_reward_multiplier(EnemyRegistry.get_coin_reward(enemy_type), gambit_id)
		save_manager.add_coins(coins)
		session_stats["coins_earned"] = int(session_stats.get("coins_earned", 0)) + coins
	# Award XP based on enemy type (table lives in EnemyRegistry).
	var xp_amount: int = EnemyRegistry.get_xp_reward(enemy_type, is_boss)
	save_manager.add_xp(xp_amount)
	session_stats["xp_earned"] = int(session_stats.get("xp_earned", 0)) + xp_amount
	# Rival encounter win: don't count as standard kill; update rival progress instead.
	if is_rival:
		if enemy_type == "rival_isfig_3":
			if not save_manager.rival_defeated:
				save_manager.set_rival_defeated()
				save_manager.add_card_instance("isfig_shadow_echo", "legendary")
				save_manager.mark_scroll_collected("scroll_isfig_shadow")
				GameBus.story_scroll_collected.emit("scroll_isfig_shadow")
		else:
			save_manager.record_rival_win()
			if captured_enemy_id == "rival_enc2":
				save_manager.set_story_flag("chapter1_received_letter")
		GameBus.rival_encounter_won.emit(save_manager.rival_encounters_won)
	# Apply veterancy: attribute kills/survival to collection instances (GID-060).
	var veterancy: Dictionary = result.get("veterancy", {})
	for vet_uid: String in veterancy.keys():
		var vdata: Dictionary = veterancy[vet_uid]
		save_manager.record_veterancy(vet_uid, int(vdata.get("kills", 0)), bool(vdata.get("survived", true)))
	# Branch-play currency accrual (GID-086): 1 corruption per Dawn card, 1 redemption per Dusk card.
	const CORRUPTION_PER_CARD: int = 1
	const REDEMPTION_PER_CARD: int = 1
	var dawn_played: int = int(result.get("dawn_played", 0))
	var dusk_played: int = int(result.get("dusk_played", 0))
	if dawn_played > 0:
		save_manager.add_corruption_points(dawn_played * CORRUPTION_PER_CARD)
	if dusk_played > 0:
		save_manager.add_redemption_points(dusk_played * REDEMPTION_PER_CARD)
	# Blight Heart cleansing (GID-066): mark the heart purified and award corruption points.
	var blight_heart_id: String = str(save_manager.pending_battle_enemy_data.get("blight_heart_id", ""))
	if blight_heart_id != "":
		save_manager.mark_heart_cleansed(blight_heart_id)
		save_manager.add_corruption_points(5)
		GameBus.blight_changed.emit()
		GameBus.hud_message_requested.emit("The blight recedes… +5 Corruption Points.")
	save_manager.clear_pending_battle()
	save_manager.clear_pending_battle_state()
	save_manager.save()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	# End the roaming boss world event if the defeated enemy was the roaming terror.
	if enemy_type == "roaming_terror":
		var wem: Node = get_node_or_null("/root/WorldEventManager")
		if wem != null:
			wem.end_event("roaming_boss")
	_restore_world()

func _on_battle_lost() -> void:
	if _state != State.BATTLE:
		return
	_current_battle_enemy_id = ""
	session_stats["battles_lost"] = int(session_stats.get("battles_lost", 0)) + 1
	# Siege defeat: apply coin penalty, end siege, then show standard game over.
	var _siege_on_lost: Dictionary = save_manager.get_active_siege()
	if not _siege_on_lost.is_empty():
		var _loss_coins: int = int(save_manager.coins * 0.10)
		if _loss_coins > 0:
			save_manager.add_coins(-_loss_coins)
		save_manager.end_siege_defeat()
		GameBus.siege_defeated.emit(_loss_coins)
	if save_manager.is_spire_active():
		_restore_spire_entry_point()
		var stats: Dictionary = save_manager.end_spire_run()
		GameBus.spire_run_ended.emit(stats)
		save_manager.clear_pending_battle()
		save_manager.clear_pending_battle_state()
		save_manager.save()
		if _battle_overlay != null:
			_battle_overlay.queue_free()
			_battle_overlay = null
		if _saved_world_scene != null:
			_saved_world_scene.queue_free()
			_saved_world_scene = null
		_exit_world_cleanup()
		var summary: Node = _run_summary_scene_packed.instantiate()
		summary.set("spire_stats", stats)
		get_tree().change_scene_to_node(summary)
		_state = State.RUN_SUMMARY
		return
	# Regular battle loss: keep world alive and show defeat overlay with Retry/Respawn/Menu.
	_defeat_pending_enemy_data = save_manager.pending_battle_enemy_data.duplicate()
	save_manager.clear_pending_battle_state()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	# Restore world to tree without clearing pending_battle (needed for Retry).
	TransitionManager.transition(func() -> void:
		if _saved_world_scene != null:
			get_tree().root.add_child(_saved_world_scene)
			get_tree().current_scene = _saved_world_scene
			_saved_world_scene = null
		_show_defeat_overlay())
	_state = State.GAME_OVER

func _show_defeat_overlay() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var layer := CanvasLayer.new()
	layer.layer = 190
	get_tree().root.add_child(layer)
	_defeat_overlay = layer

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.58
	var panel_h: float = vh * 0.50
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.04, 0.04, 0.97)
	style.corner_radius_top_left    = 12
	style.corner_radius_top_right   = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(vh * 0.03))
	margin.add_theme_constant_override("margin_right",  int(vh * 0.03))
	margin.add_theme_constant_override("margin_top",    int(vh * 0.03))
	margin.add_theme_constant_override("margin_bottom", int(vh * 0.03))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(vh * 0.028))
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Defeated"
	title.add_theme_font_size_override("font_size", int(vh * 0.055))
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var has_retry: bool = not _defeat_pending_enemy_data.is_empty()
	if has_retry:
		var retry_btn := Button.new()
		retry_btn.text = "Retry Battle"
		retry_btn.custom_minimum_size = Vector2(vh * 0.32, vh * 0.07)
		retry_btn.add_theme_font_size_override("font_size", int(vh * 0.03))
		retry_btn.pressed.connect(_on_defeat_retry)
		vbox.add_child(retry_btn)

	var respawn_btn := Button.new()
	respawn_btn.text = "Respawn in World"
	respawn_btn.custom_minimum_size = Vector2(vh * 0.32, vh * 0.07)
	respawn_btn.add_theme_font_size_override("font_size", int(vh * 0.03))
	respawn_btn.pressed.connect(_on_defeat_respawn)
	vbox.add_child(respawn_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(vh * 0.32, vh * 0.07)
	menu_btn.add_theme_font_size_override("font_size", int(vh * 0.03))
	menu_btn.pressed.connect(_on_defeat_menu)
	vbox.add_child(menu_btn)

func _on_defeat_retry() -> void:
	if _defeat_overlay != null:
		_defeat_overlay.queue_free()
		_defeat_overlay = null
	var enemy_data: Dictionary = _defeat_pending_enemy_data.duplicate()
	_defeat_pending_enemy_data = {}
	_state = State.WORLD
	_start_battle(enemy_data)

func _on_defeat_respawn() -> void:
	if _defeat_overlay != null:
		_defeat_overlay.queue_free()
		_defeat_overlay = null
	_defeat_pending_enemy_data = {}
	save_manager.clear_pending_battle()
	save_manager.save()
	_proximity_engage_blocked = true
	get_tree().create_timer(2.0, false).timeout.connect(
		func() -> void: _proximity_engage_blocked = false)
	_state = State.WORLD

func _on_defeat_menu() -> void:
	if _defeat_overlay != null:
		_defeat_overlay.queue_free()
		_defeat_overlay = null
	_defeat_pending_enemy_data = {}
	save_manager.clear_pending_battle()
	go_to_menu()

func _on_battle_fled() -> void:
	if _state != State.BATTLE:
		return
	# PvP: fleeing is a surrender — let BattleScene notify the opponent and drive
	# the synced end (which routes back through _on_pvp_battle_ended).
	if _battle_overlay != null and bool(_battle_overlay.get("_pvp")):
		_battle_overlay.call("_pvp_surrender")
		return
	save_manager.clear_pending_battle()
	save_manager.clear_pending_battle_state()
	save_manager.save()
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null
	_restore_world()

func has_open_overlay() -> bool:
	return _state != State.WORLD

func _open_overlay(packed_scene: PackedScene, overlay_state: State, setup: Callable = Callable()) -> void:
	if _state != State.WORLD:
		return
	var overlay: Node = packed_scene.instantiate()
	if setup.is_valid():
		setup.call(overlay)
	get_tree().current_scene.add_child(overlay)
	overlay.closed.connect(_close_overlay.bind(overlay_state))
	_overlays[overlay_state] = overlay
	_state = overlay_state

func _close_overlay(overlay_state: State) -> void:
	if _state != overlay_state:
		return
	var overlay: Node = _overlays.get(overlay_state, null)
	if overlay != null:
		overlay.queue_free()
		_overlays.erase(overlay_state)
	_state = State.WORLD

## Opens the unified Menu Hub overlay on the specified tab.
## Replaces the four separate INVENTORY / CHARACTER / SKILL_TREE / JOURNAL overlays.
func open_menu_hub(tab: String = "deck") -> void:
	if _state == State.MENU_HUB:
		var existing: Node = _overlays.get(State.MENU_HUB, null)
		if existing != null and is_instance_valid(existing):
			existing.call("show_tab", tab)
		return
	if _state != State.WORLD:
		return
	# Host the hub on a CanvasLayer above the HUD (default layer 1) so it
	# always renders on top of the minimap and other HUD elements.
	_menu_hub_layer = CanvasLayer.new()
	_menu_hub_layer.layer = 10
	_menu_hub_layer.name = "MenuHubLayer"
	get_tree().current_scene.add_child(_menu_hub_layer)
	var hub: Node = _MenuHubScript.new()
	hub.name = "MenuHub"
	_menu_hub_layer.add_child(hub)
	hub.show_tab(tab)
	hub.closed.connect(_on_menu_hub_closed)
	_overlays[State.MENU_HUB] = hub
	_state = State.MENU_HUB

func _on_menu_hub_closed() -> void:
	var hub: Node = _overlays.get(State.MENU_HUB, null)
	if hub != null and is_instance_valid(hub):
		_overlays.erase(State.MENU_HUB)
	if _menu_hub_layer != null and is_instance_valid(_menu_hub_layer):
		_menu_hub_layer.queue_free()
		_menu_hub_layer = null
	_state = State.WORLD

func _on_inventory_requested() -> void:
	open_menu_hub("deck")

func _on_shop_requested() -> void:
	_open_overlay(_shop_scene_packed, State.SHOP, func(o: Node) -> void:
		o.set("town_name", current_map))

func _on_traveling_shop_requested(stock: Array[String], price: int) -> void:
	_open_overlay(_shop_scene_packed, State.SHOP, func(o: Node) -> void:
		o.set("_custom_stock", stock)
		o.set("_custom_price", price)
		o.set("_custom_title", "Traveling Merchant's Rare Wares"))

func _on_bounty_board_requested() -> void:
	_open_overlay(_bounty_board_scene_packed, State.BOUNTY_BOARD)

func _on_blacksmith_requested() -> void:
	_open_overlay(_blacksmith_scene_packed, State.BLACKSMITH)

func _on_journal_requested() -> void:
	open_menu_hub("journal")

func _on_character_requested() -> void:
	open_menu_hub("character")

func _on_skill_tree_requested() -> void:
	GameBus.tutorial_popup_requested.emit("skill_tree")
	open_menu_hub("skills")

## Applies siege victory rewards: 150 coins + a rare-or-better card.
func _apply_siege_victory_rewards(town: String) -> void:
	const _CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
	const _CardRegistry = preload("res://autoloads/CardRegistry.gd")
	const SIEGE_VICTORY_COINS: int = 150
	save_manager.add_coins(SIEGE_VICTORY_COINS)
	session_stats["coins_earned"] = int(session_stats.get("coins_earned", 0)) + SIEGE_VICTORY_COINS
	var all_ids: Array[String] = _CardRegistry.get_all_ids()
	if not all_ids.is_empty():
		var reward_id: String = all_ids[randi() % all_ids.size()]
		var rarity: String = _CardDropUtil.roll_rarity(3)   # tier 3 = rare-or-better weighted
		var stats: Dictionary = _CardDropUtil.roll_stats(reward_id, rarity)
		save_manager.add_card_instance(reward_id, rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1)))
		session_stats["cards_earned"] = int(session_stats.get("cards_earned", 0)) + 1
	GameBus.siege_victory.emit()
	show_toast("Siege Defeated!", "%s thanks you! +%d coins + rare card" % [town.capitalize(), SIEGE_VICTORY_COINS])

## Shows a brief overlay between gauntlet stages, then chains the next battle after 2 s.
func _show_siege_interstitial(next_stage: int, hero_hp: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	get_tree().root.add_child(layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var vh: float = get_viewport().get_visible_rect().size.y
	var title_lbl := Label.new()
	title_lbl.text = _SiegeDefs.get_stage_name(next_stage)
	title_lbl.add_theme_font_size_override("font_size", int(vh * 0.04))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var hp_lbl := Label.new()
	hp_lbl.text = "Hero HP: %d / 30" % hero_hp
	hp_lbl.add_theme_font_size_override("font_size", int(vh * 0.03))
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.modulate = Color(0.9, 0.3, 0.3) if hero_hp <= 10 else Color(1.0, 1.0, 1.0)
	vbox.add_child(hp_lbl)

	# Dismiss automatically and chain the next raider battle.
	get_tree().create_timer(2.0, false).timeout.connect(func() -> void:
		layer.queue_free()
		var next_type: String = "martarquas_raider_%d" % (next_stage + 1)
		var deck_ids: Array[String] = _SiegeDefs.get_raider_deck_ids(next_stage)
		var enemy_dict: Dictionary = {
			"enemy_type": next_type,
			"enemy_deck": deck_ids,
			"display_name": EnemyRegistry.get_display_name(next_type),
			"is_boss": false,
			"boss_hp": 0,
			"drop_pool": [],
			"coin_reward": 0,
		}
		GameBus.enemy_engaged.emit(enemy_dict))

func _on_achievement_unlocked(achievement_id: String) -> void:
	const AchievementRegistry = preload("res://game_logic/AchievementRegistry.gd")
	var a: Dictionary = AchievementRegistry.get_achievement(achievement_id)
	var reward_card: String = str(a.get("reward_card_id", ""))
	if reward_card != "":
		save_manager.grant_achievement_card(reward_card)
	if OS.has_feature("mobile") and bool(save_manager.get_setting("haptics", true)):
		Input.vibrate_handheld(60)

func _on_level_up(new_level: int) -> void:
	var pts: int = save_manager.skill_points
	_toast.show_text("Level Up!", "Level %d — %d skill point%s to spend!" % [new_level, pts, "s" if pts != 1 else ""])
	GameBus.hud_message_requested.emit("Level %d! Open the Skill Tree to spend %d skill point%s." % [new_level, pts, "s" if pts != 1 else ""])

func _on_fragment_collected() -> void:
	_toast.show_text("Fragment Found!", "You have %d/3 fragments" % save_manager.treasure_fragments)

func _on_treasure_map_assembled() -> void:
	_toast.show_text("Map Complete!", "A dig site has been revealed!")

func _on_treasure_excavated(coins: int, card_id: String) -> void:
	_toast.show_text("Treasure Excavated!", "+%d coins + %s" % [coins, card_id])

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

## Starts or resumes an Endless Spire run from the entrance door in a town map.
func enter_spire() -> void:
	if save_manager.is_spire_active():
		var run: Dictionary = save_manager.get_spire_run()
		var floor: int = int(run.get("floor", 1))
		var run_seed: int = int(run.get("seed", 0))
		enter_map("spire_floor_%d_%d" % [floor, run_seed], "")
	else:
		var seed: int = randi()
		save_manager.start_spire_run(seed)
		GameBus.tutorial_popup_requested.emit("spire_intro")
		enter_map("spire_floor_1_%d" % seed, "")

func _show_spire_draft(floor: int) -> void:
	_spire_draft_overlay = _spire_draft_scene_packed.instantiate()
	get_tree().current_scene.add_child(_spire_draft_overlay)
	_spire_draft_overlay.setup(floor)
	_spire_draft_overlay.picked.connect(_on_spire_draft_picked)

func _on_spire_draft_picked(_card_id: String) -> void:
	_spire_draft_overlay = null  # SpireDraftScene.queue_free()s itself in _on_pick

func _on_pack_purchased(pack_id: String, rolled_cards: Array[Dictionary]) -> void:
	if _state != State.SHOP:
		return
	# Close the shop overlay before showing the opening ceremony.
	var shop_overlay: Node = _overlays.get(State.SHOP, null)
	if shop_overlay != null:
		shop_overlay.queue_free()
		_overlays.erase(State.SHOP)
	_pack_open_overlay = _PackOpenSceneScript.new()
	_pack_open_overlay.set("_rolled_cards", rolled_cards)
	_pack_open_overlay.closed.connect(_on_pack_open_closed)
	get_tree().current_scene.add_child(_pack_open_overlay)
	_state = State.PACK_OPEN

func _on_pack_open_closed() -> void:
	if _pack_open_overlay != null:
		_pack_open_overlay.queue_free()
		_pack_open_overlay = null
	_state = State.WORLD

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

func show_toast(title: String, desc: String) -> void:
	_toast.show_text(title, desc)

## Teleports the player to an activated waystone.
## Named-map waystone (id = "map:mapname"): enters the named map.
## World waystone (id = "world:tx:tz"): sets player position and reloads infinite world.
func teleport_to_waystone(waystone_id: String) -> void:
	if _state != State.WORLD:
		return
	if waystone_id.begins_with("map:"):
		var target_map: String = waystone_id.substr(4)
		enter_map(target_map, "")
	elif waystone_id.begins_with("world:"):
		var parts: PackedStringArray = waystone_id.split(":")
		if parts.size() >= 3:
			var tx: int = int(parts[1])
			var tz: int = int(parts[2])
			var wx: float = float(tx) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			var wz: float = float(tz) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
			save_manager.player_x = wx
			save_manager.player_z = wz
			save_manager.current_map = "main"
			map_stack.clear()
			door_stack.clear()
			current_map = "main"
			save_manager.sync_stacks(map_stack, door_stack)
			save_manager.save()
			_load_world("main", "")

## Restores map position to the pre-Spire entry point (e.g. madrian) before ending
## a run, so that continuing after death/retreat loads the entrance map, not a spire floor.
func _restore_spire_entry_point() -> void:
	if not map_stack.is_empty():
		var entry_map: String = map_stack.pop_back()
		if not door_stack.is_empty():
			door_stack.pop_back()
		current_map = entry_map
		save_manager.current_map = entry_map
	else:
		current_map = "madrian"
		save_manager.current_map = "madrian"
	save_manager.sync_stacks(map_stack, door_stack)
