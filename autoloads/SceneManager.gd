# gdlint: disable=max-file-lines, max-public-methods
# BID-053 lint debt: oversized script. Shrink it by extraction; don't add to it.
extends Node

## Every state change, after it is applied. `from == to` for a map reload.
signal state_changed(from: State, to: State)

const _SceneFlow = preload("res://game_logic/SceneFlow.gd")
const _BattleVictory = preload("res://autoloads/scene_manager/BattleVictory.gd")
const _BattleDefeat = preload("res://autoloads/scene_manager/BattleDefeat.gd")
const _NetBattles = preload("res://autoloads/scene_manager/NetBattles.gd")
# gdlint:ignore = constant-name
const State = _SceneFlow.State  # enum alias: keeps `SceneManager.State.X` working


const _PackOpenSceneScript = preload("res://scenes/ui/PackOpenScene.gd")
const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _AchievementToastScript = preload("res://scenes/ui/AchievementToast.gd")
const _TutorialPopupScript = preload("res://scenes/ui/TutorialPopup.gd")
const TutorialRegistry = preload("res://game_logic/TutorialRegistry.gd")
const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
const _SpireFloorGen = preload("res://game_logic/spire/SpireFloorGen.gd")
const _CoopNightHunts = preload("res://game_logic/CoopNightHunts.gd")
const Gambits = preload("res://game_logic/battle/Gambits.gd")
const _GambitPickerOverlay = preload("res://scenes/battle/GambitPickerOverlay.gd")
const _MenuHubScript = preload("res://scenes/ui/MenuHubScene.gd")

## Rebindable keyboard actions exposed in the Keybindings settings section.
## Order is the display order in SettingsScene.
const REBINDABLE_ACTIONS: Array[String] = [
	"move_up", "move_down", "move_left", "move_right",
	"interact", "jump",
	"inventory", "map_view", "character", "skill_tree", "journal", "mount", "pause",
]

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

# Ephemeral session statistics — reset on new/continue game, not persisted.
## Per-run tally shown on the run-summary screen. `_reset_session_stats()` is
## the only writer of the whole dict; individual counters go through
## `_bump_session_stat()`.
const _SESSION_STAT_KEYS: PackedStringArray = [
	"battles_won", "battles_lost", "enemies_defeated",
	"cards_earned", "coins_earned", "chests_opened",
]

# Fixed world seeds — one per biome, giving each a distinct world layout.
const _BIOME_SEEDS: Array[int] = [42, 73856135, 100033, 19349705, 294967337]

var map_stack: Array[String] = []
var door_stack: Array[String] = []
var current_map: String = ""
var session_stats: Dictionary = _fresh_session_stats(0)

## Points at the SaveManager autoload so all systems share one instance.
## The autoload is registered before SceneManager in project.godot.
var save_manager: Node
## Child modules (see autoloads/scene_manager/), created by `_ensure_modules()`.
var victory: _BattleVictory
var defeat: _BattleDefeat
var net_battles: _NetBattles

var _world_scene_packed := preload("res://scenes/world/WorldScene.tscn")
var _battle_scene_packed := preload("res://scenes/battle/BattleScene.tscn")
var _menu_scene_packed := preload("res://scenes/ui/MenuScene.tscn")
var _shop_scene_packed := preload("res://scenes/ui/ShopScene.tscn")
var _achievements_scene_packed := preload("res://scenes/ui/AchievementsScene.tscn")
var _run_summary_scene_packed := preload("res://scenes/ui/RunSummaryScene.tscn")
var _spire_draft_scene_packed := preload("res://scenes/ui/SpireDraftScene.tscn")
var _bounty_board_scene_packed := preload("res://scenes/ui/BountyBoardScene.tscn")
var _mailbox_scene_packed := preload("res://scenes/ui/MailboxScene.tscn")
var _blacksmith_scene_packed := preload("res://scenes/ui/BlacksmithScene.tscn")

var _state: State = State.MENU
var _battle_overlay: Node = null
var _overlays: Dictionary = {}  # State -> Node, for WORLD-state overlays
var _achievements_overlay: Node = null
var _spire_draft_overlay: Node = null
var _pack_open_overlay: Node = null
var _saved_world_scene: Node = null

var _toast: CanvasLayer = null
var _menu_hub_layer: CanvasLayer = null

# Blocks proximity engagement for 2 s after returning from battle so the
# player isn't immediately chain-engaged by a nearby enemy on world re-entry.
var _proximity_engage_blocked: bool = false

# Tracks which enemy triggered the current battle (for defeat marking)
var _current_battle_enemy_id: String = ""
# Tracks which duelist NPC triggered the current duel (for defeat tracking)
var _current_duel_npc_id: String = ""
# Legendary card to award on first champion duel win ("" = none)
var _current_champion_reward: String = ""

# Co-op Endless Spire run (GID-106 / TID-390). Transient, in-memory only — never
# persisted to save.json or the session file (mirrors SaveManager.spire_run's shape
# but lives here because it must survive floor-to-floor map transitions, which
# destroy/recreate WorldScene). Authoritative on the host; every peer keeps a
# locally-mirrored copy kept in sync via NetSync broadcasts (same model as
# WorldScene's _leaderboard_rows/_remote_identities caches). picker_order/picker_idx
# are only meaningful on the host — clients never read them.
var _coop_spire_run: Dictionary = {"active": false}

# ── Android back gesture (GID-120 / TID-453) ────────────────────────────────
# quit_on_go_back is disabled in project.godot, so the OS back request lands
# here. Everywhere except the main menu it synthesizes an Escape press —
# `pause` and `ui_cancel` are both Escape-bound, so WorldScene pause,
# BattleScene pause, BaseOverlay._close(), and MenuHub close all just work.
# At the main menu, quit only on a second back press within 2 seconds.

var _back_quit_deadline_ms: int = 0
var _back_quit_toast: CanvasLayer = null

## Returns true if tracking enemies may auto-engage the player on proximity.
func can_proximity_engage() -> bool:
	return _state == State.WORLD and not _proximity_engage_blocked

## The state machine's current state. Read-only outside SceneManager: every
## change goes through `_transition_to`.
func current_state() -> State:
	return _state

func is_in_world() -> bool:
	return _state == State.WORLD

## The single write path for `_state`. Undeclared edges (see
## SceneFlow.TRANSITIONS) are still applied, since refusing one would strand the
## player on a half-swapped scene, but they warn so a new route shows up in the
## test log instead of drifting silently.
func _transition_to(to: State) -> void:
	var from: State = _state
	if not _SceneFlow.can_transition(from, to):
		push_warning("SceneManager: undeclared transition %s -> %s"
			% [_SceneFlow.state_name(from), _SceneFlow.state_name(to)])
	_state = to
	state_changed.emit(from, to)

func _ready() -> void:
	save_manager = SaveManager
	_ensure_modules()
	apply_keybindings()
	_toast = _AchievementToastScript.new()
	add_child(_toast)
	GameBus.enemy_engaged.connect(_on_enemy_engaged)
	GameBus.duel_requested.connect(_on_duel_requested)
	GameBus.battle_won.connect(victory._on_battle_won)
	GameBus.battle_lost.connect(defeat._on_battle_lost)
	GameBus.battle_fled.connect(_on_battle_fled)
	GameBus.pvp_battle_ended.connect(net_battles._on_pvp_battle_ended)
	GameBus.coop_pve_battle_ended.connect(net_battles._on_coop_pve_battle_ended)
	GameBus.team_battle_ended.connect(net_battles._on_team_battle_ended)
	GameBus.duel_won.connect(_on_duel_won)
	GameBus.duel_lost.connect(_on_duel_lost)
	GameBus.ghost_duel_ended.connect(net_battles._on_ghost_duel_ended)
	GameBus.inventory_requested.connect(_on_inventory_requested)
	GameBus.shop_requested.connect(_on_shop_requested)
	GameBus.bounty_board_requested.connect(_on_bounty_board_requested)
	GameBus.mailbox_requested.connect(_on_mailbox_requested)
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
	GameBus.scripted_battle_requested.connect(_on_scripted_battle_requested)
	GameBus.scripted_battle_ended.connect(_on_scripted_battle_ended)
	GameBus.fragment_collected.connect(_on_fragment_collected)
	GameBus.treasure_map_assembled.connect(_on_treasure_map_assembled)
	GameBus.treasure_excavated.connect(_on_treasure_excavated)
	GameBus.pack_purchased.connect(_on_pack_purchased)
	GameBus.bag_full.connect(func() -> void:
		GameBus.hud_message_requested.emit("Bag full! Sell or scrap cards to make room."))
	GameBus.card_routed_to_mailbox.connect(func(template_id: String) -> void:
		var card_name: String = str(CardRegistry.get_template(template_id).get("name", template_id))
		GameBus.hud_message_requested.emit("%s couldn't fit in your bag — sent to the mailbox." % card_name))
	GameBus.siege_defeated.connect(func(coins_lost: int) -> void:
		show_toast("Siege Lost", "The town fell. Lost %d coins." % coins_lost))
	_maybe_boot_dedicated_server()

## Builds the battle-outcome and networked-battle modules. Idempotent, so a test
## that instantiates SceneManager cold can call it before `_ready`.
func _ensure_modules() -> void:
	if victory != null:
		return
	victory = _BattleVictory.new(self)
	victory.name = "BattleVictory"
	add_child(victory)
	defeat = _BattleDefeat.new(self)
	defeat.name = "BattleDefeat"
	add_child(defeat)
	net_battles = _NetBattles.new(self)
	net_battles.name = "NetBattles"
	add_child(net_battles)

## Shutdown cleanup. During battles/puzzles the WorldScene is detached from the
## tree and held only by _saved_world_scene (see _start_battle and friends).
## SceneTree teardown frees in-tree nodes only — an orphan detached scene is
## never freed, so quitting mid-battle (window close, Android back-quit) leaked
## every physics body in the detached world: "N RID allocations of type
## 'GodotBody3D' were leaked on exit". Free it here with free(), not
## queue_free() — no more frames run this late, a queued free never executes.
func _exit_tree() -> void:
	if _saved_world_scene != null and is_instance_valid(_saved_world_scene) \
			and not _saved_world_scene.is_inside_tree():
		_saved_world_scene.free()
	_saved_world_scene = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_request()

func _handle_back_request() -> void:
	if _state != State.MENU:
		_synthesize_escape()
		return
	if Time.get_ticks_msec() <= _back_quit_deadline_ms:
		get_tree().quit()
		return
	_back_quit_deadline_ms = Time.get_ticks_msec() + 2000
	_show_back_quit_toast()

func _synthesize_escape() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_ESCAPE
	press.physical_keycode = KEY_ESCAPE
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.keycode = KEY_ESCAPE
	release.physical_keycode = KEY_ESCAPE
	release.pressed = false
	Input.parse_input_event(release)

func _show_back_quit_toast() -> void:
	if _back_quit_toast != null and is_instance_valid(_back_quit_toast):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 250
	var lbl := _UiUtil.make_label("Press back again to exit", int(vp.y * 0.026))
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(vp.x * 0.5, vp.y * 0.06)
	lbl.position = Vector2(vp.x * 0.25, vp.y * 0.82)
	layer.add_child(lbl)
	add_child(layer)
	_back_quit_toast = layer
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if _back_quit_toast != null and is_instance_valid(_back_quit_toast):
			_back_quit_toast.queue_free()
		_back_quit_toast = null)

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
	# Any active co-op/PvP session ends the moment the player returns to the main
	# menu — otherwise NetworkManager.is_active() stays stuck true across scene
	# changes and the next New Game wrongly inherits co-op (chat/party/session
	# adoption) in WorldScene._setup_coop().
	if NetworkManager.is_active():
		NetworkManager.leave()
	var scene := get_tree().current_scene
	if scene and scene.has_method("flush_time_of_day"):
		scene.flush_time_of_day()
	# Spire retreat: restore entry point, end run, show Spire summary.
	if _state == State.WORLD and save_manager.spire.is_spire_active():
		_restore_spire_entry_point()
		var stats: Dictionary = save_manager.spire.end_spire_run()
		GameBus.spire_run_ended.emit(stats)
		save_manager.save()
		_exit_world_cleanup()
		var spire_summary: Node = _run_summary_scene_packed.instantiate()
		spire_summary.set("spire_stats", stats)
		TransitionManager.transition(func() -> void:
			get_tree().change_scene_to_node(spire_summary))
		_transition_to(State.RUN_SUMMARY)
		return
	save_manager.save()
	# Show session run summary only when leaving the world.
	if _state == State.WORLD:
		_exit_world_cleanup()
		var summary: Node = _run_summary_scene_packed.instantiate()
		TransitionManager.transition(func() -> void:
			get_tree().change_scene_to_node(summary))
		_transition_to(State.RUN_SUMMARY)
		return
	_exit_world_cleanup()
	TransitionManager.transition(func() -> void:
		get_tree().change_scene_to_packed(_menu_scene_packed))
	_transition_to(State.MENU)

func go_to_menu_direct() -> void:
	# See go_to_menu(): returning to the main menu must always end any active
	# co-op/PvP session, or the stale peer makes the next New Game inherit co-op.
	if NetworkManager.is_active():
		NetworkManager.leave()
	_exit_world_cleanup()
	TransitionManager.transition(func() -> void:
		get_tree().change_scene_to_packed(_menu_scene_packed))
	_transition_to(State.MENU)

func go_to_achievements() -> void:
	if _state != State.MENU:
		return
	_achievements_overlay = _achievements_scene_packed.instantiate()
	get_tree().current_scene.add_child(_achievements_overlay)
	_achievements_overlay.closed.connect(_on_achievements_closed)
	_transition_to(State.ACHIEVEMENTS)

func _on_achievements_closed() -> void:
	if _state != State.ACHIEVEMENTS:
		return
	if _achievements_overlay != null:
		_achievements_overlay.queue_free()
		_achievements_overlay = null
	_transition_to(State.MENU)

func start_new_game() -> void:
	start_new_game_with_biome(0)   # default: Grasslands

func start_new_game_with_biome(biome_id: int, head_start: bool = false) -> void:
	_exit_world_cleanup()
	save_manager.world_seed = _BIOME_SEEDS[clamp(biome_id, 0, _BIOME_SEEDS.size() - 1)]
	save_manager.starting_biome = biome_id
	save_manager.new_game(head_start)
	_apply_audio_settings()
	_reset_session_stats()
	enter_map("madrian", "")

func _apply_audio_settings() -> void:
	var mv: float = float(save_manager.get_setting("music_volume", 0.5))
	var sv: float = float(save_manager.get_setting("sfx_volume", 1.0))
	AudioManager.set_music_volume(mv)
	AudioManager.set_sfx_volume(sv)

## Apply saved keybinding overrides to InputMap.
## Called at startup (via _ready) and whenever the player saves a new binding.
## Reloads project defaults first so clearing an override always restores the
## original key. Joypad events are untouched because load_from_project_settings
## restores the full action list including joypad bindings.
func apply_keybindings() -> void:
	# Restore all actions to project.godot defaults first.
	# This guarantees that removing an override re-exposes the default key.
	InputMap.load_from_project_settings()
	var raw: Variant = SaveManager.get_setting("keybindings", {})
	if not raw is Dictionary:
		return
	var overrides: Dictionary = raw as Dictionary
	for action: String in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		if not overrides.has(action):
			continue  # No override — project default restored above is correct
		# Erase all existing InputEventKey entries (WASD, arrow keys, etc.)
		# so the custom binding is the only keyboard event for this action.
		var key_events: Array[InputEventKey] = []
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				key_events.append(ev as InputEventKey)
		for ev in key_events:
			InputMap.action_erase_event(action, ev)
		var new_ev := InputEventKey.new()
		new_ev.physical_keycode = int(overrides[action])
		InputMap.action_add_event(action, new_ev)

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

## Zeroes every counter and stamps the run's start time.
func _reset_session_stats() -> void:
	session_stats = _fresh_session_stats(Time.get_ticks_msec())

static func _fresh_session_stats(start_msec: int) -> Dictionary:
	var d: Dictionary = {"session_start_msec": start_msec}
	for k: String in _SESSION_STAT_KEYS:
		d[k] = 0
	return d

## Adds `amount` to one run counter, defaulting a missing key to 0.
func _bump_session_stat(key: String, amount: int) -> void:
	session_stats[key] = int(session_stats.get(key, 0)) + amount

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
	if save_manager.spire.is_spire_active() and current_map.begins_with("spire_floor_"):
		# The draft overlay doesn't pause world input, so the player can reach the
		# exit door with a pick still owed. Advancing would rebuild the scene and
		# take the unclaimed card with it, so hold the door until they pick.
		if is_spire_draft_open():
			GameBus.hud_message_requested.emit("Choose a card before climbing higher.")
			return
		_advance_spire_floor()
		return
	# Co-op Endless Spire (GID-106 / TID-391): floor advancement is fully automatic
	# right after the shared draft resolves (WorldScene._resolve_coop_spire_draft) —
	# the arena's authored exit door is single-player-only machinery and is never
	# meant to drive co-op progression. Treat it as an inert no-op rather than
	# falling through to the empty-map_stack go_to_menu() below. Checked via
	# NetworkManager (accurate on every peer) rather than is_coop_spire_active()
	# (only ever true on the host — see that function's doc comment) since any
	# peer, not just the host, could reach this door.
	if NetworkManager.is_active() and current_map.begins_with("spire_floor_"):
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
	_transition_to(State.MENU)

func _load_world(map_name: String, target_door_id: String) -> void:
	var world: Node = _world_scene_packed.instantiate()
	world.set("map_name", map_name)
	world.set("target_door_id", target_door_id)
	TransitionManager.transition(func() -> void:
		get_tree().change_scene_to_node(world)
		_transition_to(State.WORLD))

func _exit_world_cleanup() -> void:
	if _menu_hub_layer != null and is_instance_valid(_menu_hub_layer):
		_menu_hub_layer.queue_free()
		_menu_hub_layer = null
	defeat.clear()
	if _saved_world_scene != null:
		_saved_world_scene.queue_free()
		_saved_world_scene = null
	_dismiss_battle_overlay()
	for overlay: Node in _overlays.values():
		if overlay != null:
			overlay.queue_free()
	_overlays.clear()
	if is_instance_valid(_spire_draft_overlay):
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

## True when `enemy_data` identifies an enemy that a co-op session routes to a
## *joint* party battle (WorldScene._on_enemy_engaged_coop) rather than a solo
## duel — the Endless Spire floor boss (GID-106 / TID-391) and the Town Siege
## boss (BID-044 / TID-430). Pure and map/id-only so it's unit-testable without
## a live NetworkManager session; callers still gate on NetworkManager.is_active()
## since single-player instances of these enemies legitimately use the solo path.
static func _is_coop_joint_battle_enemy(enemy_data: Dictionary, current_map_name: String) -> bool:
	var eid: String = str(enemy_data.get("id", ""))
	# Prefix, not equality: floor enemies carry a per-floor id (SpireFloorGen.
	# enemy_id_for), and pre-existing maps still carry the bare "spire_enemy".
	if current_map_name.begins_with("spire_floor_") and _SpireFloorGen.is_spire_enemy_id(eid):
		return true
	if eid.begins_with("siege_boss_"):
		return true
	return false

func _on_enemy_engaged(enemy_data: Dictionary) -> void:
	if _state != State.WORLD:
		return
	# Co-op Endless Spire boss / Town Siege boss: both are joint battles for the
	# whole party, not solo fights — WorldScene._on_enemy_engaged_coop routes them
	# to enter_coop_pve_battle instead. Skip here so this handler (connected first,
	# at autoload boot) never races that routing and starts a solo battle
	# underneath it; without this guard enter_coop_pve_battle's
	# `_state == State.WORLD` check silently no-ops and the host ends up dueling
	# the boss alone while clients enter the joint battle (BID-044). Checked via
	# current_map (accurate on every peer) rather than is_coop_spire_active() (only
	# ever true on the host — see that function's doc comment). Single-player
	# instances of these enemies have no active co-op session, so
	# NetworkManager.is_active() correctly leaves them on the solo path.
	if NetworkManager.is_active() and _is_coop_joint_battle_enemy(enemy_data, current_map):
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
	_enter_battle(func(b: Node) -> void:
		b.enemy_data = captured_enemy_data)

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
	_enter_battle(func(b: Node) -> void:
		b.enemy_data = captured_duel_data
		b.duel_wager = captured_wager)

# ── Ghost duels (GID-102 / TID-377) ───────────────────────────────────────────


# ── PvP card battles (GID-091) ────────────────────────────────────────────────


func _on_duel_won() -> void:
	if _state != State.BATTLE:
		return
	# Champion first-win: award legendary before marking defeated (so the "first win" check is accurate).
	var grant_card: String = ""
	if not _current_champion_reward.is_empty() and not _current_duel_npc_id.is_empty():
		if not save_manager.defeated_duelists.has(_current_duel_npc_id):
			grant_card = _current_champion_reward
			save_manager.grant_card_reward(grant_card, "legendary")
			_bump_session_stat("cards_earned", 1)
			save_manager.set_story_flag("champion_blancogov_defeated")
	_current_champion_reward = ""
	if not _current_duel_npc_id.is_empty():
		save_manager.mark_duelist_defeated(_current_duel_npc_id)
		_current_duel_npc_id = ""
	_finish_battle(false)
	_restore_world()
	if grant_card != "":
		GameBus.hud_message_requested.emit("Champion defeated! %s added to your collection." % grant_card)

func _on_duel_lost() -> void:
	if _state != State.BATTLE:
		return
	_current_duel_npc_id = ""
	_current_champion_reward = ""
	_finish_battle(false)
	_restore_world()

## BATTLE's enter transition, shared by every battle kind. Inside the fade it
## detaches the live WorldScene (kept in `_saved_world_scene` for
## `_restore_world`, BATTLE's exit), runs `configure` on a fresh BattleScene and
## promotes it to `current_scene`. `networked` fixes the node name, because
## BattleNetSync's RPC path is /root/BattleScene/BattleNetSync on every peer.
func _enter_battle(configure: Callable, networked: bool = false) -> void:
	TransitionManager.transition(func() -> void:
		var world: Node = get_tree().current_scene
		if world != null:
			_saved_world_scene = world
			get_tree().root.remove_child(world)
		_battle_overlay = _battle_scene_packed.instantiate()
		if networked:
			_battle_overlay.name = "BattleScene"
		configure.call(_battle_overlay)
		get_tree().root.add_child(_battle_overlay)
		get_tree().current_scene = _battle_overlay)
	_transition_to(State.BATTLE)


## Frees the battle overlay if one is up. Every battle exit path ends here.
func _dismiss_battle_overlay() -> void:
	if _battle_overlay != null:
		_battle_overlay.queue_free()
		_battle_overlay = null

## Standard battle teardown: clear the in-progress battle fields, persist, and
## drop the overlay. `clear_pending` also discards the queued encounter — a
## defeat that offers Retry keeps it, every other exit drops it.
func _finish_battle(clear_pending: bool = true) -> void:
	if clear_pending:
		save_manager.clear_pending_battle()
	save_manager.clear_pending_battle_state()
	save_manager.save()
	_dismiss_battle_overlay()

## Re-attaches the world scene that was detached for a battle/puzzle.
##
## `after` runs *inside* the transition callback, once `current_scene` is the
## live WorldScene again. Anything that parents an overlay to `current_scene`
## must go through it: TransitionManager.transition() awaits a 0.2 s fade before
## running its callback, so a caller that does `_restore_world()` then
## `current_scene.add_child(overlay)` on the next line is still looking at the
## already-`queue_free()`d battle overlay and the overlay dies with it at the end
## of the frame (the Spire draft never appearing after a floor win — see
## tests/spire_draft_smoke.gd).
func _restore_world(after: Callable = Callable()) -> void:
	_proximity_engage_blocked = true
	get_tree().create_timer(2.0, false).timeout.connect(
		func() -> void: _proximity_engage_blocked = false)
	TransitionManager.transition(func() -> void:
		if _saved_world_scene != null:
			get_tree().root.add_child(_saved_world_scene)
			get_tree().current_scene = _saved_world_scene
			_saved_world_scene = null
		_transition_to(State.WORLD)
		if after.is_valid():
			after.call())

func _on_puzzle_requested(puzzle_id: String) -> void:
	const PuzzleRegistry_cls = preload("res://autoloads/PuzzleRegistry.gd")
	var pdata: Resource = PuzzleRegistry_cls.get_puzzle(puzzle_id)
	if pdata == null:
		push_error("SceneManager: puzzle not found: " + puzzle_id)
		return
	_flush_position_save()
	var captured_pdata: Resource = pdata
	_enter_battle(func(b: Node) -> void:
		b.puzzle_data = captured_pdata)

func _on_puzzle_solved(puzzle_id: String) -> void:
	if _state != State.BATTLE:
		return
	const PD = preload("res://game_logic/battle/PuzzleData.gd")
	if not save_manager.is_puzzle_solved(puzzle_id):
		var pdata: PD = PuzzleRegistry.get_puzzle(puzzle_id) as PD
		if pdata != null and not pdata.reward_card_id.is_empty():
			save_manager.grant_card_reward(pdata.reward_card_id, "rare")
			_bump_session_stat("cards_earned", 1)
		save_manager.mark_puzzle_solved(puzzle_id)
	save_manager.save()
	_dismiss_battle_overlay()
	_restore_world()

func return_from_puzzle() -> void:
	save_manager.save()
	_dismiss_battle_overlay()
	_restore_world()

## Scripted story battles (GID-108) — fixed-deck tutorial battles like the rabbit
## hunt. See ScriptedBattleData / ScriptedBattleRegistry / GameState.load_scripted_battle.
func _on_scripted_battle_requested(battle_id: String) -> void:
	var sdata: Resource = ScriptedBattleRegistry.get_battle(battle_id)
	if sdata == null:
		push_error("SceneManager: scripted battle not found: " + battle_id)
		return
	_flush_position_save()
	var captured_sdata: Resource = sdata
	_enter_battle(func(b: Node) -> void:
		b.scripted_data = captured_sdata)

func _on_scripted_battle_ended(battle_id: String, did_win: bool) -> void:
	if _state != State.BATTLE:
		return
	if did_win:
		const SBD = preload("res://game_logic/battle/ScriptedBattleData.gd")
		var sdata: SBD = ScriptedBattleRegistry.get_battle(battle_id)
		if sdata != null:
			if not sdata.completion_flag.is_empty() and not save_manager.get_story_flag(sdata.completion_flag):
				save_manager.set_story_flag(sdata.completion_flag)
			if not sdata.reward_card_id.is_empty():
				save_manager.grant_card_reward(sdata.reward_card_id, "rare")
				_bump_session_stat("cards_earned", 1)
	save_manager.save()
	_dismiss_battle_overlay()
	_restore_world()


func _on_battle_fled() -> void:
	if _state != State.BATTLE:
		return
	# PvP: fleeing is a surrender — let BattleScene notify the opponent and drive
	# the synced end (which routes back through _on_pvp_battle_ended).
	if _battle_overlay != null and bool(_battle_overlay.get("_pvp")):
		_battle_overlay.call("_pvp_surrender")
		return
	_finish_battle()
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
	_transition_to(overlay_state)

func _close_overlay(overlay_state: State) -> void:
	if _state != overlay_state:
		return
	var overlay: Node = _overlays.get(overlay_state, null)
	if overlay != null:
		overlay.queue_free()
		_overlays.erase(overlay_state)
	_transition_to(State.WORLD)

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
	_transition_to(State.MENU_HUB)

func _on_menu_hub_closed() -> void:
	var hub: Node = _overlays.get(State.MENU_HUB, null)
	if hub != null and is_instance_valid(hub):
		_overlays.erase(State.MENU_HUB)
	if _menu_hub_layer != null and is_instance_valid(_menu_hub_layer):
		_menu_hub_layer.queue_free()
		_menu_hub_layer = null
	_transition_to(State.WORLD)

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

func _on_mailbox_requested() -> void:
	_open_overlay(_mailbox_scene_packed, State.MAILBOX)

func _on_blacksmith_requested() -> void:
	_open_overlay(_blacksmith_scene_packed, State.BLACKSMITH)

func _on_journal_requested() -> void:
	open_menu_hub("journal")

func _on_character_requested() -> void:
	open_menu_hub("character")

func _on_skill_tree_requested() -> void:
	GameBus.tutorial_popup_requested.emit("skill_tree")
	open_menu_hub("skills")


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
	GameBus.hud_message_requested.emit("Level %d! Open the Skill Tree to spend %d skill point%s." % [new_level, pts,
			"s" if pts != 1 else ""])

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
	if save_manager.spire.is_spire_active():
		var run: Dictionary = save_manager.spire.get_spire_run()
		var floor: int = int(run.get("floor", 1))
		var run_seed: int = int(run.get("seed", 0))
		enter_map("spire_floor_%d_%d" % [floor, run_seed], "")
	else:
		var seed: int = randi()
		save_manager.spire.start_spire_run(seed)
		GameBus.tutorial_popup_requested.emit("spire_intro")
		enter_map("spire_floor_1_%d" % seed, "")

## Shows the post-floor draft. Only ever called from _restore_world's post-swap
## callback (see _spire_battle_won) — parenting it to a `current_scene` that is
## still the battle overlay silently destroys it.
func _show_spire_draft(floor: int) -> void:
	if is_spire_draft_open():
		return
	var host: Node = get_tree().current_scene
	if host == null or not host.is_inside_tree():
		push_warning("SceneManager: no live scene to host the Spire draft — skipping floor %d draft." % floor)
		return
	_spire_draft_overlay = _spire_draft_scene_packed.instantiate()
	host.add_child(_spire_draft_overlay)
	_spire_draft_overlay.setup(floor)
	_spire_draft_overlay.picked.connect(_on_spire_draft_picked)

## True while the player still owes a pick. The overlay has no cancel path, so
## this is also what keeps the exit door from advancing the floor out from under
## an unclaimed draft (see exit_map).
func is_spire_draft_open() -> bool:
	return is_instance_valid(_spire_draft_overlay)

func _on_spire_draft_picked(_card_id: String) -> void:
	_spire_draft_overlay = null  # SpireDraftScene.queue_free()s itself in _on_pick

func _on_pack_purchased(_pack_id: String, rolled_cards: Array[Dictionary]) -> void:
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
	_transition_to(State.PACK_OPEN)

func _on_pack_open_closed() -> void:
	if _pack_open_overlay != null:
		_pack_open_overlay.queue_free()
		_pack_open_overlay = null
	_transition_to(State.WORLD)

func _advance_spire_floor() -> void:
	save_manager.spire.advance_spire_floor()
	var run: Dictionary = save_manager.spire.get_spire_run()
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
	AudioManager.play_sfx("waystone_travel")
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

# ── Co-op Endless Spire (GID-106 / TID-390) ─────────────────────────────────
# Mirrors the single-player enter_spire/start_spire_run/advance_spire_floor/
# add_drafted_card/end_spire_run shape above, but entirely transient — see the
# _coop_spire_run field comment. WorldScene._start_coop_spire() is the only caller
# of enter_spire_coop(); it is host-only (enforced by the caller, matching
# _start_dungeon_crawl's defensive precedent).

func is_coop_spire_active() -> bool:
	return bool(_coop_spire_run.get("active", false))

func get_coop_spire_run() -> Dictionary:
	return _coop_spire_run

## Starts (or resumes) a co-op Spire run. `picker_order` is the draft turn rotation,
## built by the caller from currently-connected session tokens (host + peers present
## at run start — late joiners simply aren't in the rotation, a v1 scope decision
## mirroring the loot-roll "present = connected" simplification). Broadcasting the
## map transition and loading the floor locally is the caller's job (reuses the
## existing recv_map_transition RPC verbatim, exactly like _start_dungeon_crawl) —
## this function only owns the run's data.
func enter_spire_coop(picker_order: Array[String] = []) -> String:
	if is_coop_spire_active():
		var run: Dictionary = _coop_spire_run
		var floor: int = int(run.get("floor", 1))
		var run_seed: int = int(run.get("seed", 0))
		return "spire_floor_%d_%d" % [floor, run_seed]
	var seed: int = randi()
	_coop_spire_run = {
		"active": true,
		"floor": 1,
		"seed": seed,
		"shared_deck": [],
		"hero_hp": 30,
		"picker_order": picker_order.duplicate(),
		"picker_idx": 0,
	}
	return "spire_floor_1_%d" % seed

## Appends a drafted card to the shared run deck (no-op if the run is inactive).
## Mirrors SaveManager.add_drafted_card.
func add_coop_drafted_card(card_id: String) -> void:
	if not is_coop_spire_active():
		return
	var deck: Array = _coop_spire_run.get("shared_deck", [])
	deck.append(card_id)
	_coop_spire_run["shared_deck"] = deck

## Advances the picker rotation to the next member's turn (mod party size).
## No-op if the run is inactive or the rotation is empty.
func advance_coop_spire_picker() -> void:
	if not is_coop_spire_active():
		return
	var order: Array = _coop_spire_run.get("picker_order", [])
	if order.is_empty():
		return
	var idx: int = int(_coop_spire_run.get("picker_idx", 0))
	_coop_spire_run["picker_idx"] = (idx + 1) % order.size()

## Bumps the run to the next floor (mirrors SaveManager.advance_spire_floor, minus
## the SaveManager-only enemies_defeated counter, which has no co-op equivalent here).
func advance_coop_spire_floor() -> void:
	if not is_coop_spire_active():
		return
	_coop_spire_run["floor"] = int(_coop_spire_run.get("floor", 1)) + 1

## Ends the run and returns its final stats (mirrors SaveManager.end_spire_run's
## return shape, minus the coin-reward/story-flag side effects — those are
## single-player-save concepts with no session equivalent; TID-391 owns whatever
## session-scoped reward/leaderboard submission replaces them).
func end_coop_spire_run() -> Dictionary:
	var floors_cleared: int = int(_coop_spire_run.get("floor", 1)) - 1
	var stats: Dictionary = {
		"floors_cleared": floors_cleared,
		"seed": int(_coop_spire_run.get("seed", 0)),
		"shared_deck": (_coop_spire_run.get("shared_deck", []) as Array).duplicate(),
	}
	_coop_spire_run = {"active": false}
	return stats

## Enters a map without pushing the current map onto map_stack (mirrors
## _advance_spire_floor's pattern above). TID-391 uses this for the co-op Spire's
## automatic floor-to-floor transitions and the final return to madrian — all
## fully automatic, one-way moves with no "go back" concept. Using the normal
## enter_map() for a whole run would leave map_stack permanently polluted with a
## chain of floor names nothing ever pops (exit_map()'s co-op-spire branch is a
## deliberate no-op, so they'd never be popped there either).
func enter_coop_map_no_stack(target_map: String, target_door_id: String = "") -> void:
	current_map = target_map
	save_manager.sync_stacks(map_stack, door_stack)
	save_manager.save()
	_load_world(target_map, target_door_id)

## Lets a non-host peer overwrite its local mirror wholesale from a host broadcast.
## Clients never mutate _coop_spire_run directly.
func set_coop_spire_run_mirror(run: Dictionary) -> void:
	_coop_spire_run = run.duplicate(true)
