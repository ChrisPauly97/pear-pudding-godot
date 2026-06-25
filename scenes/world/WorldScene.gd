extends Node3D

const WorldEvents     = preload("res://game_logic/WorldEvents.gd")
const WorldMap        = preload("res://game_logic/world/WorldMap.gd")
const DungeonGen      = preload("res://game_logic/world/DungeonGen.gd")
const SpireFloorGen   = preload("res://game_logic/spire/SpireFloorGen.gd")
const GrassBlades     = preload("res://scenes/world/GrassBlades.gd")
const VirtualJoystick = preload("res://scenes/ui/VirtualJoystick.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const ChunkStreamingManager = preload("res://scenes/world/ChunkStreamingManager.gd")
const DungeonSessionUI  = preload("res://scenes/world/DungeonSessionUI.gd")
const WorldHUD          = preload("res://scenes/world/WorldHUD.gd")
const DayNightCycle     = preload("res://scenes/world/DayNightCycle.gd")
const BlightField      = preload("res://game_logic/world/BlightField.gd")
const ChunkRenderer   = preload("res://scenes/world/ChunkRenderer.gd")
const BiomeDef        = preload("res://game_logic/world/BiomeDef.gd")
const TerrainMath     = preload("res://game_logic/TerrainMath.gd")
const Minimap         = preload("res://scenes/world/Minimap.gd")
const MapViewOverlay  = preload("res://scenes/ui/MapViewOverlay.gd")
const WeaponRegistry  = preload("res://autoloads/WeaponRegistry.gd")
const EnemyRegistry   = preload("res://autoloads/EnemyRegistry.gd")
const WeaponData      = preload("res://data/WeaponData.gd")
const SaveManager        = preload("res://autoloads/SaveManager.gd")
const MountRegistry      = preload("res://game_logic/MountRegistry.gd")
const TrophyRegistry     = preload("res://game_logic/TrophyRegistry.gd")
const WeatherParticles   = preload("res://scenes/world/WeatherParticles.gd")
const _TerrainShader: Shader = preload("res://assets/shaders/terrain.gdshader")
const TextureGen = preload("res://game_logic/TextureGen.gd")
const Pathfinder  = preload("res://game_logic/Pathfinder.gd")
const RivalSystem = preload("res://game_logic/RivalSystem.gd")
const CantripManager = preload("res://game_logic/world/CantripManager.gd")
const LandmarkNames  = preload("res://game_logic/world/LandmarkNames.gd")
const _BurialMoundScene = preload("res://scenes/world/entities/BurialMound.tscn")

const _TexGrass:     Texture2D = preload("res://assets/textures/pixel_art/grass_pixel.png")
const _TexHillSide:  Texture2D = preload("res://assets/textures/pixel_art/hill_side_pixel.png")
const _TexHillTop:   Texture2D = preload("res://assets/textures/pixel_art/hill_top_pixel.png")
const _TexWallSide:  Texture2D = preload("res://assets/textures/pixel_art/wall_side_pixel.png")
const _TexWallTop:   Texture2D = preload("res://assets/textures/pixel_art/wall_top_pixel.png")

# Preload entity scenes — avoids filesystem hits during spawning
const _OverworldPauseOverlay = preload("res://scenes/ui/OverworldPauseOverlay.gd")
const _PlayerScene       = preload("res://scenes/world/entities/Player.tscn")
const _EnemyScene        = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _ChestScene        = preload("res://scenes/world/entities/Chest.tscn")
const _DoorScene         = preload("res://scenes/world/entities/Door.tscn")
const _WorldItemScene    = preload("res://scenes/world/entities/WorldItem.tscn")
const _StoryScrollScene  = preload("res://scenes/world/entities/StoryScroll.tscn")
const _PuzzleShrineScene = preload("res://scenes/world/entities/PuzzleShrine.tscn")
const _WaystoneScene     = preload("res://scenes/world/entities/Waystone.tscn")
const _GardenPlotScript  = preload("res://scenes/world/entities/GardenPlot.gd")
const GardenDefs         = preload("res://game_logic/GardenDefs.gd")

# Co-op multiplayer (GID-090)
const _NetSyncScript     = preload("res://scenes/world/NetSync.gd")
const _RemotePlayerScene = preload("res://scenes/world/entities/RemotePlayer.tscn")
const _AvatarSync        = preload("res://game_logic/net/AvatarSync.gd")
const _PlayerIdentity    = preload("res://game_logic/net/PlayerIdentity.gd")
const _NET_BROADCAST_INTERVAL: float = 1.0 / 15.0  # 15 Hz avatar broadcast

@export var map_name: String = "main"
@export var target_door_id: String = ""

# Computed in _ready from map_name; true for "main" and "infinite", false for named dungeon maps
var _is_infinite: bool = false

# Named-map path
var world_map: WorldMap

# Common
var _player: CharacterBody3D
var _grass: Node3D
var _enemy_nodes: Dictionary = {}   # id -> Node3D
var _chest_nodes: Dictionary = {}   # id -> Node3D
# Co-op multiplayer (GID-090) — guarded by _coop_active; inert in single-player
var _remote_player_nodes: Dictionary = {}  # peer_id -> RemotePlayer Node3D
var _remote_identities: Dictionary = {}    # peer_id -> {token, name, color} (TID-342)
var _coop_roster: VBoxContainer = null     # in-world session roster panel (TID-342)
var _net_sync: Node = null
var _coop_active: bool = false
var _net_broadcast_accum: float = 0.0
var _initial_ready_done: bool = false  # so _enter_tree re-setup only runs on re-entry
# PvP challenges (GID-091)
var _challenge_btn: Button = null
var _challenge_target_peer: int = -1     # nearby remote peer eligible to challenge
var _pending_challenge_from: int = -1    # incoming challenge awaiting our response
var _pending_challenge_deck: Array = []  # challenger's deck stored until we accept
var _challenge_accept_panel: Node = null
const _CHALLENGE_RANGE: float = 3.0      # tiles; proximity to show the prompt
var _door_nodes: Dictionary = {}    # id -> Node3D
var _npc_nodes: Dictionary = {}     # id -> Node3D
var _scroll_nodes: Array[Node3D] = []
var _shrine_nodes: Array[Node3D] = []
var _siege_raider_nodes: Array[Node3D] = []
var _siege_banner: Label = null
var _waystone_nodes: Dictionary = {}    # id -> Node3D
var _active_waystone_data: Dictionary = {}  # id -> Dictionary
var _garden_plot_nodes: Array[Node3D] = []  # ordered by plot_idx
var _tile_meshes: Node3D
var _wall_meshes: Node3D
var _entity_root: Node3D

# Chunk streaming delegated to ChunkStreamingManager (_csm)
var _csm: ChunkStreamingManager = null

var _active_chest_data: Dictionary = {}  # chest_id -> Dictionary
var _active_door_data: Dictionary = {}   # door_id -> Dictionary
var _active_npc_data: Dictionary = {}    # npc_id -> Dictionary
var _digspot_node: Node3D = null         # the one active DigSpot entity (nil if none loaded)
var _burial_mound_nodes: Dictionary = {} # mound_id -> Node3D
var _blight_heart_nodes: Dictionary = {} # heart_id -> Node3D
var _active_landmark_data: Dictionary = {} # landmark_id -> Dictionary
var _mana_well_nodes: Dictionary = {}    # well_id -> Node3D
var _ghost_phase_active: bool = false    # true while ghost-phase tween runs
var _ghost_tween: Tween = null
var _current_biome: int = -1

const _BIOME_MUSIC: Array = [
	"res://assets/audio/music/grasslands.ogg",
	"res://assets/audio/music/forest.ogg",
	"res://assets/audio/music/desert.ogg",
	"res://assets/audio/music/scorched.ogg",
	"res://assets/audio/music/mountains.ogg",
]
var _terrain_mat: ShaderMaterial
var _last_save_pos: Vector2 = Vector2(-9999, -9999)
var _interact_timer: float = 0.0
var _roaming_boss_timer: float = 0.0
var _traveling_merchant_timer: float = 0.0
var _card_shower_items: Array[Node3D] = []

# Nocturnal spawn system (GID-055 Night Hunts)
var _nocturnal_enemies: Dictionary = {}        # spawn_id -> {"node": Node3D, "chunk": Vector2i}
var _nocturnal_spawn_timer: float = 0.0
var _nocturnal_spawn_interval: float = 45.0   # randomised each spawn
var _night_cue_played: bool = false
var _night_hunt_tutorial_shown_session: bool = false
var _nocturnal_id_counter: int = 0

# Day/night cycle — delegated to DayNightCycle component
var _world_env: WorldEnvironment
@export var day_duration: float = 600.0   # seconds per full day
var _dnc: DayNightCycle = null

# Weather visuals
var _active_weather_particles: Node3D = null
var _weather_tint: Color = Color(1.0, 1.0, 1.0)
var _weather_tint_target: Color = Color(1.0, 1.0, 1.0)
var _weather_tint_lerp_t: float = 1.0
const _WEATHER_TINT_SPEED: float = 2.0  # tint blends in 0.5s

# Camera smoothing: lerped toward player each _process frame to eliminate
# micro-stutter on high-refresh displays (camera runs at render rate, physics at ~60 Hz).
var _smooth_camera_target: Vector3 = Vector3.ZERO

var WORLD_SEED: int = 42  # overwritten in _ready() for infinite worlds
const INTERACT_INTERVAL: float = 0.15  # check interactions at ~7 Hz, not 60

@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD
@onready var _interact_label: Label = $HUD/InteractPrompt
@onready var _map_label: Label = $HUD/MapLabel
@onready var _coin_label: Label = $HUD/CoinLabel
@onready var _sun: DirectionalLight3D = $DirectionalLight3D
@onready var _moon: DirectionalLight3D = $MoonLight
var _fill_light: DirectionalLight3D

var _pause_overlay: Node = null
var _world_hud: WorldHUD = null
var _dungeon_session_ui: DungeonSessionUI = null
var _minimap: Node
var _map_overlay: Node = null
var _fast_travel_layer: CanvasLayer = null

# Tap-to-move
var _dest_marker: Node3D = null
var _dest_tween: Tween = null
var _joystick_ref: Node = null
var _tap_start_screen: Vector2 = Vector2.ZERO
var _tap_touch_index: int = -2  # -2 = no tracked tap; -1 reserved for mouse
const _TAP_DRAG_THRESHOLD: float = 30.0  # screen pixels; beyond this is a drag, not a tap
var _drag_last_tile: Vector2i = Vector2i(-9999, -9999)  # throttle drag-steer re-pathing

# Terrain height constants — named-map path uses a wider ramp than chunks

func _setup_environment() -> void:
	var env := Environment.new()
	# Procedural sky with depth gradient — updated each frame by DayNightCycle
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.04, 0.10, 0.32)
	sky_mat.sky_horizon_color    = Color(0.25, 0.50, 0.85)
	sky_mat.ground_horizon_color = Color(0.20, 0.42, 0.70)
	sky_mat.ground_bottom_color  = Color(0.08, 0.06, 0.04)
	sky_mat.sun_angle_max = 55.0
	sky_mat.sun_curve     = 0.25
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Distance fog for horizon depth
	env.fog_enabled            = true
	env.fog_density            = 0.004
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect         = 0.7
	env.fog_light_color        = Color(0.70, 0.85, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_energy = 1.0
	# Filmic tone mapping lifts shadow detail and prevents blown highlights
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	# Bloom so emissive materials (items, coins) visibly glow
	env.glow_enabled = true
	env.glow_bloom = 0.25
	env.glow_intensity = 1.5
	env.glow_strength = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.5
	env.glow_hdr_luminance_cap = 12.0
	_world_env = WorldEnvironment.new()
	_world_env.environment = env
	add_child(_world_env)
	# Fill light: soft sky-blue from above-opposite, no shadows, lifts black areas
	_fill_light = DirectionalLight3D.new()
	_fill_light.light_color = Color(0.55, 0.65, 0.85)
	_fill_light.light_energy = 0.5
	_fill_light.shadow_enabled = false
	_fill_light.rotation_degrees = Vector3(60.0, 45.0, 0.0)
	add_child(_fill_light)
	_setup_vignette()

func _setup_vignette() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 127
	var cr := ColorRect.new()
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vshader := Shader.new()
	vshader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 uv = UV - vec2(0.5);\n\tfloat d = length(uv * vec2(1.0, 1.2));\n\tfloat vig = smoothstep(0.35, 0.75, d) * 0.45;\n\tCOLOR = vec4(0.0, 0.0, 0.0, vig);\n}"
	var vmat := ShaderMaterial.new()
	vmat.shader = vshader
	cr.material = vmat
	cl.add_child(cr)
	add_child(cl)

func _ready() -> void:
	_setup_environment()
	_sun.shadow_opacity = 0.2
	_tile_meshes = Node3D.new()
	_tile_meshes.name = "TileGrid"
	add_child(_tile_meshes)
	_wall_meshes = Node3D.new()
	_wall_meshes.name = "WallGrid"
	add_child(_wall_meshes)
	_entity_root = Node3D.new()
	_entity_root.name = "Entities"
	add_child(_entity_root)

	_is_infinite = (map_name == "infinite" or map_name == "main")
	if _is_infinite:
		WORLD_SEED = SceneManager.save_manager.world_seed
		InfiniteWorldGen.forced_start_biome = SceneManager.save_manager.starting_biome
	_terrain_mat = _make_terrain_material(WORLD_SEED)
	_build_grass_blades_node()

	if not _is_infinite:
		if map_name.begins_with("dungeon_"):
			var dseed: int = int(map_name.substr(8))
			# Use the saved .tres if this dungeon was already generated, otherwise
			# generate fresh and save it (DungeonGen.generate calls save_to_file).
			if MapRegistry.get_map(map_name) != null:
				world_map = WorldMap.new(map_name)
			else:
				world_map = DungeonGen.generate(map_name, dseed)
		elif map_name.begins_with("spire_floor_"):
			if MapRegistry.get_map(map_name) != null:
				world_map = WorldMap.new(map_name)
			else:
				var parts: PackedStringArray = map_name.split("_")
				var sp_floor: int = int(parts[2]) if parts.size() > 2 else 1
				var sp_seed: int  = int(parts[3]) if parts.size() > 3 else 0
				world_map = SpireFloorGen.generate(sp_floor, sp_seed)
		else:
			world_map = WorldMap.new(map_name)
			if world_map.is_fallback:
				# Deferred so the dialogue label exists and the world is visible
				_show_dialogue.call_deferred(
					"Map '%s' could not be loaded — using a generated map instead." % map_name)

	# ChunkStreamingManager owns all chunk lifecycle state and thread work.
	# Created after world_map is ready so it receives the correct reference.
	_csm = ChunkStreamingManager.new()
	_csm.name = "ChunkStreamingManager"
	add_child(_csm)
	_csm.setup(WORLD_SEED, _is_infinite, world_map, _terrain_mat, self)
	_csm.player_chunk_changed.connect(_on_player_chunk_changed)
	_csm.chunk_committed.connect(_on_chunk_committed)
	_csm.chunk_unloading.connect(_on_chunk_unloading)

	_spawn_player()

	if _is_infinite:
		var floor_body := StaticBody3D.new()
		floor_body.collision_layer = 2
		floor_body.collision_mask = 0
		var floor_col := CollisionShape3D.new()
		floor_col.shape = WorldBoundaryShape3D.new()
		floor_body.add_child(floor_col)
		add_child(floor_body)
		_csm.build_initial_infinite(_player.position)
		_spawn_open_world_rival_enc2()
		if map_name == "main":
			_spawn_return_portal()
	else:
		# Named map: load all chunks covering the 100×100 tile map synchronously
		var max_cx: int = (WorldMap.MAP_WIDTH + IsoConst.CHUNK_SIZE - 1) / IsoConst.CHUNK_SIZE
		var max_cz: int = (WorldMap.MAP_HEIGHT + IsoConst.CHUNK_SIZE - 1) / IsoConst.CHUNK_SIZE
		_csm.build_all_named_map(max_cx, max_cz, _player.position)
		_spawn_named_map_scrolls()
		_spawn_named_map_shrines()
		_spawn_named_map_waystones()
		_spawn_named_map_rivals()
		if map_name == "player_home":
			_spawn_player_home_trophies()
			_spawn_player_home_garden()
		_check_siege_spawn(map_name)
		# Set chapter1_reached_blancogov when the player enters blancogov
		if map_name == "blancogov" or map_name == "blancogov_temple":
			SceneManager.save_manager.set_story_flag("chapter1_reached_blancogov")

	# Re-enter any battle that was interrupted (e.g. app quit mid-fight)
	if not SceneManager.save_manager.pending_battle_enemy_data.is_empty():
		GameBus.enemy_engaged.emit.call_deferred(SceneManager.save_manager.pending_battle_enemy_data)
	_interact_label.hide()
	_interact_label.text = "[Tap] Interact" if OS.has_feature("android") else "[E] Interact"

	var joystick := VirtualJoystick.new()
	_hud.add_child(joystick)
	_joystick_ref = joystick

	var vh: float = get_viewport().get_visible_rect().size.y
	_map_label.add_theme_font_size_override("font_size", int(vh * 0.032))
	_coin_label.add_theme_font_size_override("font_size", int(vh * 0.03))
	_interact_label.add_theme_font_size_override("font_size", int(vh * 0.03))

	# WorldHUD owns all dynamically-created buttons, labels, and display state.
	_world_hud = WorldHUD.new()
	_world_hud.name = "WorldHUD"
	add_child(_world_hud)
	_world_hud.setup(_hud, _is_infinite, map_name, _interact_label, self)
	_world_hud.build_bounty_tracker()

	# Must run after _world_hud exists — _update_hud refreshes the XP bar via it.
	_update_hud()

	if not SceneManager.save_manager.get_story_flag("tutorial_inventory_tip"):
		SceneManager.save_manager.set_story_flag("tutorial_inventory_tip")
		var inv_tip: String = "Tap the Inventory button to manage your deck." \
			if OS.has_feature("android") else "Press I or tap Inventory to manage your deck."
		_world_hud.show_tip.call_deferred(inv_tip)

	_minimap = Minimap.new()
	add_child(_minimap)
	_minimap.setup(self, _hud, _player, _enemy_nodes, _chest_nodes, _door_nodes, _npc_nodes)
	_minimap.tapped.connect(_open_map_view)

	GameBus.hud_message_requested.connect(func(text: String) -> void: _world_hud.show_dialogue(text))
	GameBus.story_scroll_collected.connect(_on_scroll_collected)
	GameBus.waystone_activated.connect(_on_waystone_activated)

	# DungeonSessionUI owns dungeon room overlay panels and hero HP tracking.
	_dungeon_session_ui = DungeonSessionUI.new()
	_dungeon_session_ui.name = "DungeonSessionUI"
	add_child(_dungeon_session_ui)
	_dungeon_session_ui.setup(_hud, func(text: String) -> void: _world_hud.show_dialogue(text))

	# DayNightCycle owns time-of-day advancement, sun/moon lighting, and sky color.
	_dnc = DayNightCycle.new()
	_dnc.name = "DayNightCycle"
	add_child(_dnc)
	_dnc.setup(_sun, _moon, _world_env, _is_infinite, day_duration,
		SceneManager.save_manager.time_of_day)
	_dnc.day_passed.connect(func() -> void:
		SceneManager.save_manager.increment_day()
		GameBus.blight_changed.emit()
	)
	if _is_infinite:
		_dnc.night_started.connect(func() -> void:
			if not _night_cue_played:
				_night_cue_played = true
				AudioManager.play_sfx("nightfall_ambient")
		)
		_dnc.dawn_arrived.connect(func() -> void:
			_despawn_nocturnal_enemies(true)
			_night_cue_played = false
		)

	if _is_infinite:
		WorldEvents.register_all(self)
		WeatherManager.on_world_entered()
		GameBus.weather_changed.connect(_on_weather_changed)

	if not _is_infinite:
		AudioManager.play_music("res://assets/audio/music/dungeon.ogg")
		AudioManager.set_ambience(-1)  # -1 = named map / no biome ambience
		GameBus.entered_named_map.emit(map_name)
		if map_name.begins_with("dungeon_"):
			_dungeon_session_ui.reset_hero_hp()
	GameBus.battle_won.connect(_on_battle_won)
	GameBus.enemy_engaged.connect(_on_enemy_engaged_for_mount)
	GameBus.blight_changed.connect(_refresh_blight_tints)

	# Auto-remount when returning to the overworld from a named map
	if map_name == "main":
		var sm_ready := SceneManager.save_manager
		if sm_ready.active_mount != "" and not sm_ready.is_mounted:
			sm_ready.summon_mount(sm_ready.active_mount)

	# Cancel tap-to-move path when battle or menu interrupts movement.
	GameBus.enemy_engaged.connect(_clear_dest_marker)
	GameBus.inventory_requested.connect(_clear_dest_marker)
	GameBus.journal_requested.connect(_clear_dest_marker)

	_setup_coop()
	_initial_ready_done = true

# Re-establish co-op when the world is re-attached after a PvP battle detached it
# (SceneManager keeps the WorldScene alive but removes it from the tree, which runs
# _exit_tree → _teardown_coop). On first load _ready handles setup, so this only
# fires on re-entry.
func _enter_tree() -> void:
	if _initial_ready_done and not _coop_active and NetworkManager.is_active():
		_setup_coop()

func _exit_tree() -> void:
	_teardown_coop()
	if _csm != null:
		_csm.exit_cleanup()
	if _active_weather_particles != null and is_instance_valid(_active_weather_particles):
		_active_weather_particles.queue_free()
	_active_weather_particles = null

# ── Co-op multiplayer (GID-090) ───────────────────────────────────────────────
# All of this is inert unless a NetworkManager session is active when the world
# loads. Single-player behaviour is unchanged.

func _setup_coop() -> void:
	if not NetworkManager.is_active():
		return
	if _coop_active:
		return
	_coop_active = true

	# Fixed-name RPC relay child. Path /root/WorldScene/NetSync matches on both
	# peers. Reused across a PvP battle detach (not freed in _teardown_coop).
	if _net_sync == null or not is_instance_valid(_net_sync):
		_net_sync = _NetSyncScript.new()
		_net_sync.name = "NetSync"
		_net_sync.set("world_scene", self)
		add_child(_net_sync)

	NetworkManager.peer_connected.connect(_on_coop_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_coop_peer_disconnected)
	NetworkManager.session_ended.connect(_on_coop_session_ended)

	_ensure_challenge_button()

	# Host: surface the LAN IP so the other player knows what to type into
	# "Join by IP" (only shown on the first co-op entry, not on battle re-attach).
	if NetworkManager.is_host() and not _initial_ready_done:
		var lan_ip: String = NetworkManager.get_lan_ip()
		if lan_ip != "":
			SceneManager.show_toast("Hosting", "Other player: Join by IP  →  %s" % lan_ip)

	# Spawn avatars for peers already connected when this world loads (the
	# client-joining-host case; the host's peer is already present).
	for pid in multiplayer.get_peers():
		_spawn_remote_player(int(pid))

	# Identity handshake (TID-342): this just-loaded peer broadcasts its identity
	# to everyone already in-world. Each recipient replies once directly, so both
	# sides learn each other without relying on the connect-signal ordering.
	_build_coop_roster()
	_send_local_identity(false, 0)

func _teardown_coop() -> void:
	if not _coop_active:
		return
	if NetworkManager.peer_connected.is_connected(_on_coop_peer_connected):
		NetworkManager.peer_connected.disconnect(_on_coop_peer_connected)
	if NetworkManager.peer_disconnected.is_connected(_on_coop_peer_disconnected):
		NetworkManager.peer_disconnected.disconnect(_on_coop_peer_disconnected)
	if NetworkManager.session_ended.is_connected(_on_coop_session_ended):
		NetworkManager.session_ended.disconnect(_on_coop_session_ended)
	# Keep _net_sync alive across a battle detach so the RPC node persists; set
	# inactive so re-entry (_enter_tree) re-runs setup and reconnects signals.
	_coop_active = false

func _spawn_remote_player(pid: int) -> void:
	if _remote_player_nodes.has(pid):
		return
	# Seed near the local player but fan out by a deterministic per-peer ring offset
	# so up to 4 avatars don't stack on the shared SPAWN tile before packets flow.
	var base_x: float = _player.position.x if _player != null else 0.0
	var base_z: float = _player.position.z if _player != null else 0.0
	var off: Vector2 = _AvatarSync.spawn_offset(pid, IsoConst.TILE_SIZE)
	var spawn_x: float = base_x + off.x
	var spawn_z: float = base_z + off.y
	var rp: Node3D = _RemotePlayerScene.instantiate() as Node3D
	rp.set("world_scene", self)
	rp.init_from_data({"peer_id": pid, "x": spawn_x, "z": spawn_z})
	_entity_root.add_child(rp)
	_remote_player_nodes[pid] = rp
	# Apply identity if it already arrived before the avatar spawned (lazy ordering).
	if _remote_identities.has(pid):
		_apply_identity_to_avatar(pid)

func _on_coop_peer_connected(pid: int) -> void:
	_spawn_remote_player(pid)

func _on_coop_peer_disconnected(pid: int) -> void:
	var rp: Node = _remote_player_nodes.get(pid) as Node
	if is_instance_valid(rp):
		rp.queue_free()
	_remote_player_nodes.erase(pid)
	_remote_identities.erase(pid)
	_refresh_coop_roster()

func _on_coop_session_ended() -> void:
	for pid in _remote_player_nodes.keys():
		var rp: Node = _remote_player_nodes[pid] as Node
		if is_instance_valid(rp):
			rp.queue_free()
	_remote_player_nodes.clear()
	_remote_identities.clear()
	_refresh_coop_roster()
	_coop_active = false

# ── Player identity handshake (GID-094 / TID-342) ─────────────────────────────

## Broadcast (target_peer == 0) or unicast this peer's identity. `is_reply` marks
## the one-shot direct answer so the exchange terminates after one round-trip.
func _send_local_identity(is_reply: bool, target_peer: int) -> void:
	if not _coop_active or _net_sync == null or not NetworkManager.is_active():
		return
	var payload: Array = _PlayerIdentity.encode(
		MpProfile.get_token(), MpProfile.get_display_name(), MpProfile.get_color())
	if target_peer == 0:
		_net_sync.rpc("recv_identity", payload, is_reply)
	else:
		_net_sync.rpc_id(target_peer, "recv_identity", payload, is_reply)

## Called by NetSync when a peer's identity packet arrives.
func _on_identity_received(sender: int, payload: Array, is_reply: bool) -> void:
	var d: Dictionary = _PlayerIdentity.decode(payload)
	_remote_identities[sender] = d
	_apply_identity_to_avatar(sender)
	_refresh_coop_roster()
	# Answer an initiator's broadcast exactly once so it learns our identity too.
	if not is_reply:
		_send_local_identity(true, sender)

## Push a stored identity onto the matching RemotePlayer avatar, if spawned.
func _apply_identity_to_avatar(pid: int) -> void:
	var rp: Node = _remote_player_nodes.get(pid) as Node
	if not is_instance_valid(rp) or not rp.has_method("set_player_identity"):
		return
	var d: Dictionary = _remote_identities.get(pid, {})
	var nm: String = str(d.get("name", "Player"))
	var col: Color = d.get("color", Color.WHITE)
	rp.set_player_identity(nm, col)

# ── In-world session roster (GID-094 / TID-342) ───────────────────────────────

func _build_coop_roster() -> void:
	if _coop_roster != null and is_instance_valid(_coop_roster):
		_refresh_coop_roster()
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var panel := PanelContainer.new()
	panel.name = "CoopRoster"
	panel.position = Vector2(vp.x * 0.012, vp.y * 0.30)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.92)
	_coop_roster = VBoxContainer.new()
	_coop_roster.add_theme_constant_override("separation", int(vp.y * 0.006))
	panel.add_child(_coop_roster)
	_hud.add_child(panel)
	_refresh_coop_roster()

## Rebuild the roster rows: local player first, then each connected remote.
func _refresh_coop_roster() -> void:
	if _coop_roster == null or not is_instance_valid(_coop_roster):
		return
	var panel: Node = _coop_roster.get_parent()
	if is_instance_valid(panel):
		(panel as CanvasItem).visible = _coop_active
	for c in _coop_roster.get_children():
		c.queue_free()
	if not _coop_active:
		return
	_add_roster_row("%s (you)" % MpProfile.get_display_name(), MpProfile.get_color())
	for pid in _remote_player_nodes.keys():
		var d: Dictionary = _remote_identities.get(pid, {})
		var nm: String = str(d.get("name", "Player"))
		var col: Color = d.get("color", Color(0.7, 0.85, 1.0))
		_add_roster_row(nm, col)

func _add_roster_row(text: String, col: Color) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(vp.y * 0.01))
	var swatch := ColorRect.new()
	swatch.color = Color(col.r, col.g, col.b, 1.0)
	swatch.custom_minimum_size = Vector2(vp.y * 0.022, vp.y * 0.022)
	row.add_child(swatch)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(vp.y * 0.022))
	row.add_child(lbl)
	_coop_roster.add_child(row)

# Called by NetSync when a remote avatar packet arrives.
func _on_avatar_received(sender: int, payload: Array) -> void:
	var rp: Node = _remote_player_nodes.get(sender) as Node
	if not is_instance_valid(rp):
		# Packet arrived before the connect signal was processed — spawn now.
		_spawn_remote_player(sender)
		rp = _remote_player_nodes.get(sender) as Node
	if is_instance_valid(rp) and rp.has_method("set_net_state"):
		var d: Dictionary = _AvatarSync.decode(payload)
		rp.set_net_state(d["x"], d["z"], d["flip_h"], d["moving"])

# Broadcast the local avatar's state at 15 Hz. Called from _process.
func _broadcast_local_avatar(delta: float) -> void:
	if not _coop_active or _net_sync == null or _player == null:
		return
	if not NetworkManager.is_active():
		return
	_net_broadcast_accum += delta
	if _net_broadcast_accum < _NET_BROADCAST_INTERVAL:
		return
	_net_broadcast_accum = 0.0
	var flip_h: bool = false
	var spr: AnimatedSprite3D = _player.get("_sprite") as AnimatedSprite3D
	if spr != null:
		flip_h = spr.flip_h
	var moving: bool = bool(_player.get("_is_moving"))
	var payload: Array = _AvatarSync.encode(
		_player.position.x, _player.position.z, flip_h, moving)
	_net_sync.rpc("recv_avatar", payload)

# ── PvP challenge handshake (GID-091) ─────────────────────────────────────────

## Creates the hidden "Challenge to Battle" HUD button (mobile + desktop parity).
func _ensure_challenge_button() -> void:
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_challenge_btn = Button.new()
	_challenge_btn.text = "Challenge to Battle"
	_challenge_btn.custom_minimum_size = Vector2(vp.y * 0.34, vp.y * 0.07)
	_challenge_btn.add_theme_font_size_override("font_size", int(vp.y * 0.026))
	_challenge_btn.position = Vector2((vp.x - vp.y * 0.34) * 0.5, vp.y * 0.80)
	_challenge_btn.hide()
	_challenge_btn.pressed.connect(_request_challenge)
	_hud.add_child(_challenge_btn)

## Shows/hides the challenge button based on proximity to a remote player. Called
## each frame from _process while co-op is active.
func _update_challenge_proximity() -> void:
	if _challenge_btn == null or not is_instance_valid(_challenge_btn):
		return
	# Suppress while a challenge is pending or we're not in the world.
	if _pending_challenge_from != -1 or SceneManager._state != SceneManager.State.WORLD:
		_challenge_btn.hide()
		return
	if _player == null:
		_challenge_btn.hide()
		return
	var range_world: float = _CHALLENGE_RANGE * IsoConst.TILE_SIZE
	var nearest_pid: int = -1
	var nearest_d: float = range_world
	for pid in _remote_player_nodes.keys():
		var rp: Node3D = _remote_player_nodes[pid] as Node3D
		if not is_instance_valid(rp):
			continue
		var d: float = Vector2(rp.position.x, rp.position.z).distance_to(
			Vector2(_player.position.x, _player.position.z))
		if d <= nearest_d:
			nearest_d = d
			nearest_pid = int(pid)
	_challenge_target_peer = nearest_pid
	_challenge_btn.visible = nearest_pid != -1

## Local deck as a plain Array of Dictionaries for RPC transmission.
func _local_deck_for_net() -> Array:
	var out: Array = []
	for inst in SceneManager.save_manager.get_deck_instances():
		out.append(inst)
	return out

## Send a challenge to the nearby peer.
func _request_challenge() -> void:
	if _challenge_target_peer == -1 or _net_sync == null:
		return
	var my_deck: Array = _local_deck_for_net()
	if my_deck.size() < IsoConst.DECK_MIN:
		_show_tip("Your deck is too small to duel — add at least %d cards." % IsoConst.DECK_MIN)
		return
	_net_sync.rpc_id(_challenge_target_peer, "request_battle", my_deck)
	_show_tip("Challenge sent…")

## Incoming challenge — show an Accept/Decline prompt.
func _on_battle_requested(from_id: int, challenger_deck: Array) -> void:
	if _pending_challenge_from != -1:
		return  # already handling one
	_pending_challenge_from = from_id
	_pending_challenge_deck = challenger_deck
	_show_challenge_accept_panel(from_id)

## Challenger learns the response.
func _on_battle_responded(_from_id: int, accepted: bool, responder_deck: Array) -> void:
	if not accepted:
		_show_tip("Challenge declined.")
		return
	_enter_pvp(responder_deck)

func _show_challenge_accept_panel(from_id: int) -> void:
	if _challenge_accept_panel != null and is_instance_valid(_challenge_accept_panel):
		_challenge_accept_panel.queue_free()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 180
	add_child(layer)
	_challenge_accept_panel = layer

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vp.y * 0.025))
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "A player challenges you to a card battle!"
	lbl.add_theme_font_size_override("font_size", int(vp.y * 0.03))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(vp.y * 0.03))
	vbox.add_child(row)

	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.custom_minimum_size = Vector2(vp.y * 0.2, vp.y * 0.07)
	accept_btn.add_theme_font_size_override("font_size", int(vp.y * 0.026))
	accept_btn.pressed.connect(_accept_challenge.bind(from_id))
	row.add_child(accept_btn)

	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.custom_minimum_size = Vector2(vp.y * 0.2, vp.y * 0.07)
	decline_btn.add_theme_font_size_override("font_size", int(vp.y * 0.026))
	decline_btn.pressed.connect(_decline_challenge.bind(from_id))
	row.add_child(decline_btn)

func _dismiss_challenge_panel() -> void:
	if _challenge_accept_panel != null and is_instance_valid(_challenge_accept_panel):
		_challenge_accept_panel.queue_free()
	_challenge_accept_panel = null

func _accept_challenge(from_id: int) -> void:
	_dismiss_challenge_panel()
	var my_deck: Array = _local_deck_for_net()
	if my_deck.size() < IsoConst.DECK_MIN:
		_show_tip("Your deck is too small to duel.")
		if _net_sync != null:
			_net_sync.rpc_id(from_id, "respond_battle", false, [])
		_pending_challenge_from = -1
		return
	var opp_deck: Array = _pending_challenge_deck
	_pending_challenge_from = -1
	_pending_challenge_deck = []
	if _net_sync != null:
		_net_sync.rpc_id(from_id, "respond_battle", true, my_deck)
	_enter_pvp(opp_deck)

func _decline_challenge(from_id: int) -> void:
	_dismiss_challenge_panel()
	if _net_sync != null:
		_net_sync.rpc_id(from_id, "respond_battle", false, [])
	_pending_challenge_from = -1
	_pending_challenge_deck = []

## Both peers route into SceneManager. The co-op host is always the battle
## authority (canonical player 0); the client is player 1.
func _enter_pvp(opponent_deck: Array) -> void:
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		_challenge_btn.hide()
	var local_idx: int = 0 if NetworkManager.is_host() else 1
	SceneManager.enter_pvp_battle(local_idx, opponent_deck)

## Returns the biome and time context at the moment of engagement (GID-059).
## Called by SceneManager._on_enemy_engaged() to stamp context into enemy_data.
func get_battlefield_context() -> Dictionary:
	var sm := SceneManager.save_manager
	var px: float = _player.position.x if _player != null else 0.0
	var pz: float = _player.position.z if _player != null else 0.0
	var cx: int = int(floor(px / (float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE)))
	var cz: int = int(floor(pz / (float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE)))
	var blighted: bool = _is_infinite and BlightField.is_blighted(
		cx, cz, WORLD_SEED, sm.days_elapsed, sm.blight_cleansed_hearts)
	var attuned: bool = _is_infinite and TerrainMath.is_on_ley_line(px, pz, WORLD_SEED)
	return {
		"biome": _current_biome if _is_infinite else -1,
		"is_night": _dnc != null and _dnc.is_night_now(),
		"is_blighted": blighted,
		"is_player_attuned": attuned,
	}

func _update_hud() -> void:
	if _is_infinite:
		_map_label.text = "World: Infinite"
	elif map_name.begins_with("spire_floor_"):
		var _parts: PackedStringArray = map_name.split("_")
		var _sf: int = int(_parts[2]) if _parts.size() > 2 else 1
		_map_label.text = "Spire — Floor %d" % _sf
	else:
		_map_label.text = "Map: %s" % map_name
	_coin_label.text = "Coins: %d" % SceneManager.save_manager.coins
	SceneManager.save_manager.coins_changed.connect(_on_coins_changed)
	_world_hud.refresh_xp_bar()
	_world_hud.update_xp_label()

func _refresh_xp_bar() -> void:
	_world_hud.refresh_xp_bar()

# ── Infinite world: chunk streaming ────────────────────────────────────────

func _build_grass_blades_node() -> void:
	_grass = GrassBlades.new()
	_grass.name = "GrassBlades"
	add_child(_grass)

func _spawn_player() -> void:
	var px: float = 3.0 * IsoConst.TILE_SIZE
	var pz: float = 3.0 * IsoConst.TILE_SIZE

	if _is_infinite:
		if SceneManager.save_manager.current_map == map_name and \
				(SceneManager.save_manager.player_x != 0.0 or SceneManager.save_manager.player_z != 0.0):
			px = SceneManager.save_manager.player_x
			pz = SceneManager.save_manager.player_z
	else:
		var default_px: float = (float(world_map.player_spawn_x) + 0.5) * IsoConst.TILE_SIZE \
				if world_map.has_player_spawn() else 3.0 * IsoConst.TILE_SIZE
		var default_pz: float = (float(world_map.player_spawn_z) + 0.5) * IsoConst.TILE_SIZE \
				if world_map.has_player_spawn() else 3.0 * IsoConst.TILE_SIZE
		if not target_door_id.is_empty():
			var door := world_map.find_door_by_id(target_door_id)
			px = door.get("x", default_px) if not door.is_empty() else default_px
			pz = door.get("z", default_pz) if not door.is_empty() else default_pz
		elif SceneManager.save_manager.current_map == map_name and \
				(SceneManager.save_manager.player_x != 0.0 or SceneManager.save_manager.player_z != 0.0):
			# Restore saved position when the save file records this map as the player's
			# last location. The current_map == map_name guard is sufficient — it is only
			# true when loading a save where the player was already in this map. Fresh
			# entries (new game, door travel, waystone) always leave save_manager.current_map
			# pointing to the previous map, so they fall through to the spawn default.
			px = SceneManager.save_manager.player_x
			pz = SceneManager.save_manager.player_z
		else:
			px = default_px
			pz = default_pz

	# Co-op: nudge the joining client +2 tiles so the two avatars don't perfectly
	# overlap at the shared spawn marker (cosmetic; they walk apart immediately).
	if NetworkManager.is_active() and not multiplayer.is_server():
		px += 2.0 * IsoConst.TILE_SIZE

	_player = _create_player_node()
	_player.position = Vector3(px, get_terrain_height(px, pz), pz)
	_entity_root.add_child(_player)
	_smooth_camera_target = _player.position + Vector3(20, 20, 20)
	_camera.position = _smooth_camera_target

# Returns the tile type at global tile coordinates (wtx, wtz).
# Used by ChunkRenderer during terrain height computation so hills blend
# seamlessly across chunk borders.
func get_tile_global(wtx: int, wtz: int) -> int:
	return _csm.get_tile_global(wtx, wtz)

func _get_height_global(wtx: int, wtz: int) -> int:
	return _csm.get_height_global(wtx, wtz)

# Compute terrain height at a world position using the shared smoothstep algorithm.
func get_terrain_height(wx: float, wz: float) -> float:
	if _is_infinite:
		return TerrainMath.get_height_at(wx, wz, get_tile_global, _get_height_global,
				IsoConst.HILL_CURVE_R, IsoConst.HILL_PEAK_H)
	return TerrainMath.get_height_at(wx, wz, world_map.get_tile, world_map.get_height,
			IsoConst.HILL_CURVE_R, IsoConst.HILL_PEAK_H)

# ── ChunkStreamingManager signal handlers ─────────────────────────────────────

func _on_player_chunk_changed(_chunk: Vector2i, biome_id: int) -> void:
	_current_biome = biome_id
	AudioManager.play_music(_BIOME_MUSIC[biome_id])
	AudioManager.set_ambience(biome_id)
	SceneManager.save_manager.visit_biome(biome_id)
	WeatherManager.set_biome(biome_id)
	GameBus.biome_changed.emit(biome_id)
	_apply_biome_color_grade(biome_id)

func _apply_biome_color_grade(biome_id: int) -> void:
	if _world_env == null or _world_env.environment == null:
		return
	if biome_id < 0 or biome_id >= BiomeDef.ADJ_PARAMS.size():
		return
	var adj: Dictionary = BiomeDef.ADJ_PARAMS[biome_id] as Dictionary
	var env: Environment = _world_env.environment
	env.adjustment_enabled    = true
	env.adjustment_brightness = float(adj.get("brightness", 1.0))
	env.adjustment_contrast   = float(adj.get("contrast",   1.0))
	env.adjustment_saturation = float(adj.get("saturation", 1.0))

func _on_chunk_committed(_key: Vector2i, chunk_data: RefCounted) -> void:
	for l_data: Dictionary in chunk_data.landmarks:
		var lid: String = str(l_data.get("id", ""))
		_active_landmark_data[lid] = l_data

func _on_chunk_unloading(chunk_key: Vector2i, chunk_data: RefCounted) -> void:
	for e_data in chunk_data.enemies:
		var eid: String = str(e_data.get("id", ""))
		var enode: Node3D = _enemy_nodes.get(eid) as Node3D
		if is_instance_valid(enode):
			enode.queue_free()
		_enemy_nodes.erase(eid)
	for c_data in chunk_data.chests:
		var cid: String = str(c_data.get("id", ""))
		_active_chest_data.erase(cid)
		var cnode: Node3D = _chest_nodes.get(cid) as Node3D
		if is_instance_valid(cnode):
			cnode.queue_free()
		_chest_nodes.erase(cid)
	for d_data in chunk_data.doors:
		var did: String = str(d_data.get("id", ""))
		_active_door_data.erase(did)
		var dnode: Node3D = _door_nodes.get(did) as Node3D
		if is_instance_valid(dnode):
			dnode.queue_free()
		_door_nodes.erase(did)
	for n_data in chunk_data.npcs:
		var nid: String = str(n_data.get("id", ""))
		_active_npc_data.erase(nid)
		var nnode: Node3D = _npc_nodes.get(nid) as Node3D
		if is_instance_valid(nnode):
			nnode.queue_free()
		_npc_nodes.erase(nid)
	for w_data in chunk_data.waystones:
		var wid: String = str(w_data.get("id", ""))
		_active_waystone_data.erase(wid)
		var wnode: Node3D = _waystone_nodes.get(wid) as Node3D
		if is_instance_valid(wnode):
			wnode.queue_free()
		_waystone_nodes.erase(wid)
	for m_data in chunk_data.burial_mounds:
		var mid: String = str(m_data.get("id", ""))
		var mnode: Node3D = _burial_mound_nodes.get(mid) as Node3D
		if is_instance_valid(mnode):
			mnode.queue_free()
		_burial_mound_nodes.erase(mid)
	for l_data: Dictionary in chunk_data.landmarks:
		var lid: String = str(l_data.get("id", ""))
		_active_landmark_data.erase(lid)
	for w_data in chunk_data.mana_wells:
		var wid: String = str(w_data.get("id", ""))
		var wnode: Node3D = _mana_well_nodes.get(wid) as Node3D
		if is_instance_valid(wnode):
			wnode.queue_free()
		_mana_well_nodes.erase(wid)
	_evict_nocturnal_enemies_in_chunk(chunk_key)

# ── ChunkRenderer registration callbacks (called via duck typing) ──────────────

# Called by ChunkRenderer after spawning an enemy
func register_enemy(eid: String, node: Node3D) -> void:
	_enemy_nodes[eid] = node

func get_entity_root() -> Node3D:
	return _entity_root

func _tick_traveling_merchant(delta: float) -> void:
	if not _active_npc_data.has("traveling_merchant"):
		return
	_traveling_merchant_timer += delta
	if _traveling_merchant_timer >= 300.0:
		var wem: Node = get_node_or_null("/root/WorldEventManager")
		if wem != null:
			wem.end_event("traveling_merchant")

func _tick_roaming_boss(delta: float) -> void:
	if not _enemy_nodes.has("roaming_boss"):
		return
	_roaming_boss_timer += delta
	var boss: Node3D = _enemy_nodes.get("roaming_boss") as Node3D
	var expired: bool = _roaming_boss_timer >= 300.0
	var fled: bool = boss == null or not is_instance_valid(boss) or \
		_player.position.distance_to(boss.position) > 160.0
	if expired or fled:
		var wem: Node = get_node_or_null("/root/WorldEventManager")
		if wem != null:
			wem.end_event("roaming_boss")

func _tick_card_shower() -> void:
	if _card_shower_items.is_empty():
		return
	for item: Node3D in _card_shower_items:
		if is_instance_valid(item):
			return
	# All items gone — end the event
	var wem: Node = get_node_or_null("/root/WorldEventManager")
	if wem != null:
		wem.call("end_event", "card_shower")
	_card_shower_items.clear()

# ── Nocturnal spawn system (GID-055 Night Hunts) ──────────────────────────────

func _update_nocturnal_spawns(delta: float) -> void:
	if not _is_infinite:
		return
	var currently_night: bool = _dnc != null and _dnc.is_night_now()
	if not currently_night:
		_nocturnal_spawn_timer = 0.0
		return

	_nocturnal_spawn_timer -= delta
	if _nocturnal_spawn_timer > 0.0:
		return
	_nocturnal_spawn_timer = randf_range(30.0, 60.0)

	# Cap total nocturnal enemies globally to 12
	var alive_count: int = 0
	for sid: String in _nocturnal_enemies.keys():
		var entry: Dictionary = _nocturnal_enemies[sid]
		var n: Node3D = entry.get("node") as Node3D
		if not is_instance_valid(n):
			_nocturnal_enemies.erase(sid)
		else:
			alive_count += 1
	if alive_count >= 12:
		return

	# Find a walkable grass tile 6–12 world units from the player
	var spawn_pos: Vector3 = _find_nocturnal_spawn_pos()
	if spawn_pos == Vector3.ZERO:
		return

	# Pick spectre tier based on world distance from origin
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var dist: int = int(Vector2(_player.position.x, _player.position.z).length() / chunk_world)
	var enemy_type: String = "spectre_wisp"
	if dist >= 8:
		enemy_type = "spectre_dread"
	elif dist >= 3:
		enemy_type = "spectre_haunt"

	var node: Node3D = _EnemyScene.instantiate() as Node3D
	if node == null:
		return
	_nocturnal_id_counter += 1
	var spawn_id: String = "nocturnal_%d" % _nocturnal_id_counter
	var data: Dictionary = {
		"id": spawn_id,
		"enemy_type": enemy_type,
		"tracking": true,
		"nocturnal": true,
	}
	node.set_meta("is_nocturnal", true)
	node.call("init_from_data", data)
	node.position = spawn_pos
	node.modulate = Color(0.7, 0.85, 1.0, 0.85)
	_entity_root.add_child(node)

	var pcx: int = int(floor(spawn_pos.x / chunk_world))
	var pcz: int = int(floor(spawn_pos.z / chunk_world))
	_nocturnal_enemies[spawn_id] = {"node": node, "chunk": Vector2i(pcx, pcz)}
	_enemy_nodes[spawn_id] = node

	# Tutorial popup — once per session on first night spawn
	if not _night_hunt_tutorial_shown_session:
		_night_hunt_tutorial_shown_session = true
		if not SceneManager.save_manager.get_story_flag("seen_tutorial_night_hunts"):
			SceneManager.save_manager.set_story_flag("seen_tutorial_night_hunts")
			GameBus.tutorial_popup_requested.emit("night_hunts")

func _find_nocturnal_spawn_pos() -> Vector3:
	var min_dist: float = 6.0
	var max_dist: float = 14.0
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for _try: int in range(20):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(min_dist, max_dist)
		var tx: float = _player.position.x + cos(angle) * dist
		var tz: float = _player.position.z + sin(angle) * dist
		var cx: int = int(floor(tx / chunk_world))
		var cz: int = int(floor(tz / chunk_world))
		var key := Vector2i(cx, cz)
		if not _csm.has_chunk_data(key):
			continue
		var chunk: RefCounted = _csm.get_chunk_data(key)
		var tile_x: int = int(tx / IsoConst.TILE_SIZE) - cx * IsoConst.CHUNK_SIZE
		var tile_z: int = int(tz / IsoConst.TILE_SIZE) - cz * IsoConst.CHUNK_SIZE
		tile_x = clampi(tile_x, 0, IsoConst.CHUNK_SIZE - 1)
		tile_z = clampi(tile_z, 0, IsoConst.CHUNK_SIZE - 1)
		var li: int = tile_z * IsoConst.CHUNK_SIZE + tile_x
		if li < 0 or li >= chunk.tiles.size():
			continue
		var tile_type: int = chunk.tiles[li]
		if tile_type != IsoConst.TILE_GRASS:
			continue
		var world_y: float = get_terrain_height(tx, tz) + 0.5
		return Vector3(tx, world_y, tz)
	return Vector3.ZERO

func _despawn_nocturnal_enemies(fade: bool) -> void:
	for sid: String in _nocturnal_enemies.keys():
		var entry: Dictionary = _nocturnal_enemies[sid]
		var n: Node3D = entry.get("node") as Node3D
		if not is_instance_valid(n):
			_enemy_nodes.erase(sid)
			continue
		_enemy_nodes.erase(sid)
		if fade:
			var tw: Tween = create_tween()
			tw.tween_property(n, "modulate:a", 0.0, 1.0)
			tw.tween_callback(n.queue_free)
		else:
			n.queue_free()
	_nocturnal_enemies.clear()

func _evict_nocturnal_enemies_in_chunk(chunk_key: Vector2i) -> void:
	var to_erase: Array[String] = []
	for sid: String in _nocturnal_enemies.keys():
		var entry: Dictionary = _nocturnal_enemies[sid]
		if entry.get("chunk") == chunk_key:
			var n: Node3D = entry.get("node") as Node3D
			if is_instance_valid(n):
				n.queue_free()
			_enemy_nodes.erase(sid)
			to_erase.append(sid)
	for sid: String in to_erase:
		_nocturnal_enemies.erase(sid)

# Called by ChunkRenderer after spawning a chest
func register_chest(cid: String, node: Node3D, c_data: Dictionary) -> void:
	_chest_nodes[cid] = node
	_active_chest_data[cid] = c_data

# Called by ChunkRenderer after spawning a door
func register_door(did: String, node: Node3D, d_data: Dictionary) -> void:
	_door_nodes[did] = node
	_active_door_data[did] = d_data

# Called by ChunkRenderer after spawning an NPC
func register_npc(nid: String, node: Node3D, n_data: Dictionary) -> void:
	_npc_nodes[nid] = node
	_active_npc_data[nid] = n_data

func get_player() -> Node3D:
	return _player

func register_digspot(node: Node3D) -> void:
	_digspot_node = node

func register_scroll(node: Node3D) -> void:
	_scroll_nodes.append(node)

func _spawn_named_map_scrolls() -> void:
	if world_map == null:
		return
	for entry in world_map.scrolls:
		var wx: float = float(entry["x"])
		var wz: float = float(entry["z"])
		var wy: float = get_terrain_height(wx, wz) + 0.1
		var node := _StoryScrollScene.instantiate() as Node3D
		_entity_root.add_child(node)
		node.position = Vector3(wx, wy, wz)
		if node.has_method("setup"):
			node.setup(str(entry["scroll_id"]), _player)
		if is_instance_valid(node):
			_scroll_nodes.append(node)

func _find_nearby_scroll(px: float, pz: float, range_dist: float) -> Node3D:
	var range_sq: float = range_dist * range_dist
	for s in _scroll_nodes:
		if not is_instance_valid(s):
			continue
		var ddx: float = s.position.x - px
		var ddz: float = s.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return s
	return null

func _spawn_named_map_shrines() -> void:
	if world_map == null:
		return
	for entry in world_map.shrines:
		var wx: float = float(entry["x"])
		var wz: float = float(entry["z"])
		var wy: float = get_terrain_height(wx, wz) + 0.1
		var node := _PuzzleShrineScene.instantiate() as Node3D
		_entity_root.add_child(node)
		node.position = Vector3(wx, wy, wz)
		if node.has_method("setup"):
			node.setup(str(entry["puzzle_id"]), _player)
		if is_instance_valid(node):
			_shrine_nodes.append(node)

func _find_nearby_shrine(px: float, pz: float, range_dist: float) -> Node3D:
	var range_sq: float = range_dist * range_dist
	for sh in _shrine_nodes:
		if not is_instance_valid(sh):
			continue
		var ddx: float = sh.position.x - px
		var ddz: float = sh.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return sh
	return null

# Named-map waystone positions (near spawn, one per town map).
# Used when the map's .tres data has no waystones array populated.
const _NAMED_MAP_WAYSTONE_LABELS: Dictionary = {
	"main": "Main Outpost",
	"madrian": "Madrian",
	"maykalene": "Maykalene",
	"blancogov": "Blancogov",
	"farsyth_mansion": "Farsyth Mansion",
	"blancogov_temple": "Temple of Blancogov",
}

func _spawn_named_map_waystones() -> void:
	if world_map == null:
		return
	var source_list: Array[Dictionary] = []
	if not world_map.waystones.is_empty():
		source_list = world_map.waystones
	elif _NAMED_MAP_WAYSTONE_LABELS.has(map_name):
		# Inject a waystone near the map spawn when none defined in .tres
		var tx: int = world_map.player_spawn_x + 3 if world_map.has_player_spawn() else 8
		var tz: int = world_map.player_spawn_z if world_map.has_player_spawn() else 8
		tx = clamp(tx, 1, WorldMap.MAP_WIDTH - 2)
		tz = clamp(tz, 1, WorldMap.MAP_HEIGHT - 2)
		var w_id: String = "map:%s" % map_name
		var label: String = str(_NAMED_MAP_WAYSTONE_LABELS[map_name])
		source_list = [{
			"id": w_id,
			"x": float(tx) * WorldMap.TILE_SIZE,
			"z": float(tz) * WorldMap.TILE_SIZE,
			"label": label,
			"active": SceneManager.save_manager.is_waystone_activated(w_id),
		}]
	for entry in source_list:
		var wx: float = float(entry["x"])
		var wz: float = float(entry["z"])
		var wy: float = get_terrain_height(wx, wz) + 0.75
		var wid: String = str(entry.get("id", "map:%s" % map_name))
		var is_active: bool = SceneManager.save_manager.is_waystone_activated(wid)
		var w_dict: Dictionary = entry.duplicate()
		w_dict["active"] = is_active
		var node := _WaystoneScene.instantiate() as Node3D
		_entity_root.add_child(node)
		node.position = Vector3(wx, wy, wz)
		if node.has_method("init_from_data"):
			node.init_from_data(w_dict)
		_waystone_nodes[wid] = node
		_active_waystone_data[wid] = w_dict

## Checks if a siege is active for this named map and spawns raiders + siege banner if so.
func _check_siege_spawn(p_map_name: String) -> void:
	const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
	if not _SiegeDefs.is_siege_town(p_map_name):
		return
	var active_siege: Dictionary = SceneManager.save_manager.get_active_siege()
	if active_siege.is_empty() or str(active_siege.get("town", "")) != p_map_name:
		return
	var siege_stage: int = int(active_siege.get("stage", 0))
	_spawn_siege_raiders(p_map_name, siege_stage)
	_setup_siege_banner(p_map_name)

## Instantiates 3 raider EnemyNPC nodes near the town gate.
func _spawn_siege_raiders(p_map_name: String, stage: int) -> void:
	const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
	if not _SiegeDefs.TOWN_GATES.has(p_map_name):
		return
	var gate_pos: Vector3 = _SiegeDefs.TOWN_GATES[p_map_name]
	var enemy_type: String = "martarquas_raider_%d" % (stage + 1)
	var offsets: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(2.0, 1.0), Vector2(-2.0, 1.0)]
	for i: int in range(offsets.size()):
		var off: Vector2 = offsets[i]
		var node: Node3D = _EnemyScene.instantiate() as Node3D
		if node == null:
			continue
		var world_y: float = get_terrain_height(gate_pos.x + off.x, gate_pos.z + off.y) + 0.5
		node.position = Vector3(gate_pos.x + off.x, world_y, gate_pos.z + off.y)
		node.set("enemy_type", enemy_type)
		_entity_root.add_child(node)
		var raider_id: String = "siege_raider_%d_%d" % [stage, i]
		_enemy_nodes[raider_id] = node
		_siege_raider_nodes.append(node)

## Creates the siege banner label in the HUD (visible while siege is active).
func _setup_siege_banner(p_map_name: String) -> void:
	if _hud == null:
		return
	var vh: float = get_viewport().get_visible_rect().size.y
	var vw: float = get_viewport().get_visible_rect().size.x
	_siege_banner = Label.new()
	_siege_banner.text = "%s Under Attack!" % p_map_name.capitalize().replace("_", " ")
	_siege_banner.add_theme_font_size_override("font_size", int(vh * 0.03))
	_siege_banner.modulate = Color(1.0, 0.3, 0.1)
	_siege_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_siege_banner.position = Vector2((vw - vh * 0.6) * 0.5, vh * 0.005)
	_siege_banner.custom_minimum_size = Vector2(vh * 0.6, int(vh * 0.04))
	_hud.add_child(_siege_banner)

func register_waystone(wid: String, node: Node3D, w_data: Dictionary) -> void:
	_waystone_nodes[wid] = node
	_active_waystone_data[wid] = w_data

func register_burial_mound(mid: String, node: Node3D) -> void:
	_burial_mound_nodes[mid] = node

func register_blight_heart(heart_id: String, node: Node3D) -> void:
	_blight_heart_nodes[heart_id] = node

func register_landmark(landmark_id: String, l_data: Dictionary) -> void:
	_active_landmark_data[landmark_id] = l_data

func register_mana_well(wid: String, node: Node3D) -> void:
	_mana_well_nodes[wid] = node

func _find_nearby_mana_well(px: float, pz: float, range_dist: float) -> Node3D:
	var range_sq: float = range_dist * range_dist
	for wid: String in _mana_well_nodes:
		var wnode: Node3D = _mana_well_nodes[wid] as Node3D
		if not is_instance_valid(wnode):
			continue
		var ddx: float = wnode.position.x - px
		var ddz: float = wnode.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return wnode
	return null

func _find_nearby_blight_heart(px: float, pz: float, range_dist: float) -> Node3D:
	var range_sq: float = range_dist * range_dist
	for hid: String in _blight_heart_nodes:
		var hnode: Node3D = _blight_heart_nodes[hid] as Node3D
		if not is_instance_valid(hnode):
			continue
		var ddx: float = hnode.position.x - px
		var ddz: float = hnode.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return hnode
	return null

const LANDMARK_DISCOVERY_RANGE: float = 9.0

func _check_nearby_landmark(px: float, pz: float) -> void:
	if not _is_infinite:
		return
	var range_sq: float = LANDMARK_DISCOVERY_RANGE * LANDMARK_DISCOVERY_RANGE
	var sm := SceneManager.save_manager
	for lid: String in _active_landmark_data:
		if sm.is_landmark_discovered(lid):
			continue
		var l: Dictionary = _active_landmark_data[lid]
		var ddx: float = float(l.get("x", 0.0)) - px
		var ddz: float = float(l.get("z", 0.0)) - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			_discover_landmark(lid, l)

func _discover_landmark(lid: String, l_data: Dictionary) -> void:
	var sm := SceneManager.save_manager
	sm.mark_landmark_discovered(lid)
	var cx: int = int(l_data.get("cx", 0))
	var cz: int = int(l_data.get("cz", 0))
	var display_name: String = LandmarkNames.get_name(cx, cz, WORLD_SEED)
	GameBus.landmark_discovered.emit(lid, display_name)
	SceneManager.show_toast("Discovery!", display_name)
	# One-time reward: coins + random card
	sm.add_coins(50)
	var card_ids: Array[String] = ["ghost", "skeleton", "zombie", "ghoul"]
	var rng := RandomNumberGenerator.new()
	rng.seed = (cx * 73856093) ^ (cz * 19349663) ^ WORLD_SEED
	rng.seed = rng.seed & 0x7FFFFFFF
	var card_id: String = card_ids[rng.randi_range(0, card_ids.size() - 1)]
	sm.add_card_instance(card_id, "rare")
	GameBus.hud_message_requested.emit("You discovered %s! +50 coins, +1 card." % display_name)

func _refresh_blight_tints() -> void:
	var sm := SceneManager.save_manager
	_csm.for_each_renderer(func(key: Vector2i, cr: ChunkRenderer) -> void:
		var intensity: float = BlightField.blight_intensity(
			key.x, key.y, WORLD_SEED, sm.days_elapsed, sm.blight_cleansed_hearts)
		cr.set_blight_amount(intensity)
	)

func _find_nearby_burial_mound(px: float, pz: float, range_dist: float) -> Node3D:
	var range_sq: float = range_dist * range_dist
	for mid in _burial_mound_nodes:
		var mnode: Node3D = _burial_mound_nodes[mid] as Node3D
		if not is_instance_valid(mnode) or not mnode.visible:
			continue
		var ddx: float = mnode.position.x - px
		var ddz: float = mnode.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return mnode
	return null

func _find_nearby_waystone(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	for wid in _active_waystone_data:
		var w: Dictionary = _active_waystone_data[wid]
		var ddx: float = float(w.get("x", 0.0)) - px
		var ddz: float = float(w.get("z", 0.0)) - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return w
	return {}

func _on_waystone_activated(waystone_id: String) -> void:
	var w_data: Dictionary = _active_waystone_data.get(waystone_id, {})
	var label: String = str(w_data.get("label", "Unknown"))
	SceneManager.show_toast("Waystone Activated", label)

func _waystone_friendly_label(wid: String) -> String:
	if wid.begins_with("map:"):
		return wid.substr(4).capitalize().replace("_", " ")
	elif wid.begins_with("world:"):
		var parts: PackedStringArray = wid.split(":")
		if parts.size() >= 3:
			return "Waystone (%s, %s)" % [parts[1], parts[2]]
	return wid

func _open_fast_travel_panel() -> void:
	if _fast_travel_layer != null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y

	var layer := CanvasLayer.new()
	layer.layer = 50
	_hud.add_child(layer)
	_fast_travel_layer = layer

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.55
	var panel_h: float = vh * 0.62
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.10, 0.96)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
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
	vbox.add_theme_constant_override("separation", int(vh * 0.018))
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Fast Travel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(vh * 0.035))
	title.add_theme_color_override("font_color", Color(0.40, 0.90, 1.00))
	vbox.add_child(title)

	var is_blocked: bool = SceneManager.current_map.begins_with("dungeon_")
	var activated: Array[String] = SceneManager.save_manager.activated_waystones
	if activated.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No waystones activated yet.\nFind and interact with a waystone pillar to unlock fast travel."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", int(vh * 0.022))
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(empty_lbl)
	elif is_blocked:
		var block_lbl := Label.new()
		block_lbl.text = "Fast travel is unavailable inside dungeons."
		block_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		block_lbl.add_theme_font_size_override("font_size", int(vh * 0.022))
		block_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		block_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(block_lbl)
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, panel_h * 0.62)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(scroll)

		var btn_vbox := VBoxContainer.new()
		btn_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_vbox.add_theme_constant_override("separation", int(vh * 0.010))
		scroll.add_child(btn_vbox)

		var btn_h: float = vh * 0.060
		for wid: String in activated:
			var btn := Button.new()
			btn.text = _waystone_friendly_label(wid)
			btn.custom_minimum_size = Vector2(0, btn_h)
			btn.add_theme_font_size_override("font_size", int(vh * 0.024))
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var captured_id: String = wid
			btn.pressed.connect(func() -> void:
				_fast_travel_layer = null
				layer.queue_free()
				SceneManager.teleport_to_waystone(captured_id)
			)
			btn_vbox.add_child(btn)

	var close_btn := Button.new()
	close_btn.text = "Close  [Esc]" if not OS.has_feature("android") else "Close"
	close_btn.custom_minimum_size = Vector2(vh * 0.20, vh * 0.06)
	close_btn.add_theme_font_size_override("font_size", int(vh * 0.024))
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func() -> void:
		_fast_travel_layer = null
		layer.queue_free()
	)
	vbox.add_child(close_btn)

	backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE and event.pressed:
			_fast_travel_layer = null
			layer.queue_free()
	)

# ── Rival Encounter Spawning ───────────────────────────────────────────────────

func _spawn_named_map_rivals() -> void:
	if world_map == null:
		return
	var sm := SceneManager.save_manager
	if map_name == "maykalene" and sm.get_story_flag("chapter1_left_madrian") and sm.rival_encounters_won == 0:
		_spawn_rival("rival_enc1", 50, 40, "rival_isfig_1",
			"You again? Let's see if you're worth the effort, wee warrior.")
	elif map_name == "blancogov_temple" and sm.get_story_flag("chapter1_temple_council") \
			and sm.rival_encounters_won >= 2 and not sm.rival_defeated:
		_spawn_rival("rival_enc3", 50, 80, "rival_isfig_3",
			"Maiteln warned me you'd come far. Perhaps it's time I stood beside him, not against.")

func _spawn_open_world_rival_enc2() -> void:
	var sm := SceneManager.save_manager
	if not sm.get_story_flag("chapter1_warned_farsyth"):
		return
	if sm.get_story_flag("chapter1_received_letter"):
		return
	if sm.rival_encounters_won >= 2:
		return
	var rival_type: String = RivalSystem.get_rival_type(sm.rival_encounters_won, sm.level)
	var wx: float = _player.position.x + 3.0 * IsoConst.TILE_SIZE
	var wz: float = _player.position.z + 5.0 * IsoConst.TILE_SIZE
	_spawn_rival_at("rival_enc2", wx, wz, rival_type,
		"Maiteln's sent word of the Martarquas. I aim to warn him you're no mere apprentice.")

func _spawn_rival(rival_id: String, tile_x: int, tile_z: int, enemy_type: String, pre_battle_dialogue: String) -> void:
	var wx: float = float(tile_x) * IsoConst.TILE_SIZE
	var wz: float = float(tile_z) * IsoConst.TILE_SIZE
	_spawn_rival_at(rival_id, wx, wz, enemy_type, pre_battle_dialogue)

func _spawn_rival_at(rival_id: String, wx: float, wz: float, enemy_type: String, pre_battle_dialogue: String) -> void:
	if _enemy_nodes.has(rival_id):
		return
	var wy: float = get_terrain_height(wx, wz) + 0.5
	var edata: Dictionary = {
		"id": rival_id,
		"x": wx,
		"z": wz,
		"alive": true,
		"tracking": false,
		"enemy_type": enemy_type,
		"enemy_deck": EnemyRegistry.get_deck(enemy_type),
		"pre_battle_dialogue": pre_battle_dialogue,
	}
	var node := _EnemyScene.instantiate() as Node3D
	_entity_root.add_child(node)
	node.position = Vector3(wx, wy, wz)
	if node.has_method("init_from_data"):
		node.init_from_data(edata)
	_enemy_nodes[rival_id] = node


# Find nearest entities — checks the player's chunk + 8 neighbours for enemies/chests;
# scans active data dicts for doors and NPCs.
func _find_nearby_enemy(px: float, pz: float, range_dist: float) -> Node3D:
	var range_sq: float = range_dist * range_dist
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var pcx: int = int(floor(px / chunk_world))
	var pcz: int = int(floor(pz / chunk_world))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(pcx + dx, pcz + dz)
			if not _csm.has_chunk_data(key):
				continue
			var chunk: RefCounted = _csm.get_chunk_data(key)
			for e_data in chunk.enemies:
				var eid: String = str(e_data.get("id", ""))
				var node: Node3D = _enemy_nodes.get(eid) as Node3D
				if not is_instance_valid(node):
					continue
				var ddx: float = node.global_position.x - px
				var ddz: float = node.global_position.z - pz
				if ddx * ddx + ddz * ddz <= range_sq:
					return node
	return null

func _find_nearby_chest(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var pcx: int = int(floor(px / chunk_world))
	var pcz: int = int(floor(pz / chunk_world))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(pcx + dx, pcz + dz)
			if not _csm.has_chunk_data(key):
				continue
			var chunk: RefCounted = _csm.get_chunk_data(key)
			for c_data in chunk.chests:
				var cid: String = str(c_data.get("id", ""))
				var d: Dictionary = _active_chest_data.get(cid, {})
				if d.is_empty() or d.get("opened", false):
					continue
				var ddx: float = float(d.get("x", 0.0)) - px
				var ddz: float = float(d.get("z", 0.0)) - pz
				if ddx * ddx + ddz * ddz <= range_sq:
					return d
	return {}

func _find_nearby_door(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	var best: Dictionary = {}
	var best_dist_sq: float = range_sq + 1.0
	for did in _active_door_data:
		var d: Dictionary = _active_door_data[did]
		var fk: String = d.get("flag_key", "")
		if fk != "" and not SceneManager.save_manager.get_story_flag(fk):
			continue
		var ddx: float = float(d.get("x", 0.0)) - px
		var ddz: float = float(d.get("z", 0.0)) - pz
		var dist_sq: float = ddx * ddx + ddz * ddz
		if dist_sq <= range_sq and dist_sq < best_dist_sq:
			best = d
			best_dist_sq = dist_sq
	return best

func _find_nearby_digspot(px: float, pz: float, range_dist: float) -> Node3D:
	if _digspot_node == null or not is_instance_valid(_digspot_node):
		_digspot_node = null
		return null
	var ddx: float = _digspot_node.position.x - px
	var ddz: float = _digspot_node.position.z - pz
	if ddx * ddx + ddz * ddz <= range_dist * range_dist:
		return _digspot_node
	return null

func _break_cracked_wall(tx: int, tz: int) -> void:
	world_map.set_tile(tx, tz, IsoConst.TILE_GRASS)
	AudioManager.play_sfx("chest_open")
	SceneManager.show_toast("Secret passage!", "A hidden room is revealed.")
	_rebuild_terrain_around_tile(tx, tz)
	world_map.save_to_file(SceneManager.save_manager.current_map)

func _rebuild_terrain_around_tile(tx: int, tz: int) -> void:
	_csm.rebuild_terrain_around_tile(tx, tz)

func _find_nearby_npc(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	for nid in _active_npc_data:
		var n: Dictionary = _active_npc_data[nid]
		var ddx: float = float(n.get("x", 0.0)) - px
		var ddz: float = float(n.get("z", 0.0)) - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return n
	return {}

func _make_terrain_material(_seed: int = 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _TerrainShader
	mat.set_shader_parameter("grass_texture",     _TexGrass)
	mat.set_shader_parameter("hill_side_texture", _TexHillSide)
	mat.set_shader_parameter("hill_texture",      _TexHillTop)
	mat.set_shader_parameter("wall_side_texture", _TexWallSide)
	mat.set_shader_parameter("wall_top_texture",  _TexWallTop)
	mat.set_shader_parameter("path_texture",      TextureGen.path())
	mat.set_shader_parameter("uv_scale", 0.5)
	return mat

func _create_player_node() -> CharacterBody3D:
	var p: CharacterBody3D = _PlayerScene.instantiate()
	p.add_to_group("player")
	return p

# ── Camera pixel-snapping ──────────────────────────────────────────────────
# Snaps a world-space position to the nearest screen pixel along the camera's
# screen-plane axes (right and up).  The depth axis is left unsnapped.
# This prevents sub-pixel camera drift from causing the procedural terrain and
# grass noise to shimmer — every world point stays on the same screen pixel
# between frames as long as the camera hasn't moved a full pixel.
func _snap_to_pixel(pos: Vector3) -> Vector3:
	var vp_h: float = float(get_viewport().get_visible_rect().size.y)
	var pixel: float = IsoConst.CAM_ORTHO_SIZE * 2.0 / vp_h
	var right: Vector3 = _camera.global_transform.basis.x
	var up: Vector3    = _camera.global_transform.basis.y
	var fwd: Vector3   = _camera.global_transform.basis.z
	var r: float = round(pos.dot(right) / pixel) * pixel
	var u: float = round(pos.dot(up)    / pixel) * pixel
	var d: float = pos.dot(fwd)
	return right * r + up * u + fwd * d

# ── Per-frame update ───────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _player == null:
		return
	# Software floor: snap player back to terrain surface if physics misses it.
	var rx: float = _player.position.x
	var rz: float = _player.position.z
	var floor_y: float = get_terrain_height(rx, rz)
	if _player.position.y < floor_y:
		_player.position = Vector3(rx, floor_y, rz)
		_player.cancel_fall()
		_smooth_camera_target = _player.position + Vector3(20, 20, 20)
	var cam_target := _player.position + Vector3(20, 20, 20)
	_smooth_camera_target = _smooth_camera_target.lerp(cam_target, clampf(20.0 * delta, 0.0, 1.0))
	_camera.position = _snap_to_pixel(_smooth_camera_target)
	if _minimap:
		_minimap.update()
	if _world_hud:
		var tx: int = int(_player.position.x / IsoConst.TILE_SIZE)
		var tz: int = int(_player.position.z / IsoConst.TILE_SIZE)
		_world_hud.update_coords(tx, tz)
	if _dnc:
		_dnc.tick(delta, _weather_tint)
	if _grass:
		_grass.update_player(_player.position, delta, _player.is_on_floor())

	# Lerp weather tint toward target and invalidate ambient cache to force GPU write
	if _weather_tint_lerp_t < 1.0:
		_weather_tint_lerp_t = minf(_weather_tint_lerp_t + delta * _WEATHER_TINT_SPEED, 1.0)
		_weather_tint = _weather_tint.lerp(_weather_tint_target, delta * _WEATHER_TINT_SPEED)
		if _dnc:
			_dnc.invalidate_ambient_cache()

	# Keep particle rig centred on the player
	if _active_weather_particles != null and is_instance_valid(_active_weather_particles):
		_active_weather_particles.position = _player.position + Vector3(0.0, 12.0, 0.0)

	if _is_infinite:
		if _world_hud != null:
			_world_hud.set_ley_indicator_visible(TerrainMath.is_on_ley_line(
				_player.position.x, _player.position.z, WORLD_SEED))
		_tick_roaming_boss(delta)
		_tick_traveling_merchant(delta)
		_tick_card_shower()
		_update_nocturnal_spawns(delta)
		_csm.process_streaming(_player.position, _player.velocity, _camera.get_frustum())

	# Co-op: broadcast local avatar state to peers (inert in single-player)
	if _coop_active:
		_broadcast_local_avatar(delta)
		_update_challenge_proximity()

	# Only update save position when player moves > 1 unit (not every frame)
	var cur_pos := Vector2(_player.position.x, _player.position.z)
	if cur_pos.distance_squared_to(_last_save_pos) > 1.0:
		_last_save_pos = cur_pos
		SceneManager.save_manager.update_position(map_name, _player.position.x, _player.position.z)
		if _dnc:
			SceneManager.save_manager.time_of_day = _dnc.get_time_of_day()

	# Throttle interaction checks — no need to scan every frame
	_interact_timer += delta
	if _interact_timer >= INTERACT_INTERVAL:
		_interact_timer = 0.0
		_check_interactions()

	# Hide dest marker once the player's path is complete.
	if _dest_marker != null and _dest_marker.visible:
		if _player != null and _player.has_method("cancel_path"):
			var active: bool = _player.get("_has_active_path")
			if not active:
				if _dest_tween != null and _dest_tween.is_valid():
					_dest_tween.kill()
				_dest_tween = null
				_dest_marker.hide()

	if Input.is_action_just_pressed("interact"):
		_handle_interact()

	if Input.is_action_just_pressed("mount"):
		_toggle_mount()

func _check_interactions() -> void:
	var px: float = _player.position.x
	var pz: float = _player.position.z
	var enemy := _find_nearby_enemy(px, pz, IsoConst.INTERACT_RANGE)
	var chest := _find_nearby_chest(px, pz, IsoConst.INTERACT_RANGE)
	var door := _find_nearby_door(px, pz, IsoConst.INTERACT_RANGE * 2.0)
	var npc := _find_nearby_npc(px, pz, IsoConst.INTERACT_RANGE)
	var scroll := _find_nearby_scroll(px, pz, IsoConst.INTERACT_RANGE)
	var shrine := _find_nearby_shrine(px, pz, IsoConst.INTERACT_RANGE)
	var digspot := _find_nearby_digspot(px, pz, IsoConst.INTERACT_RANGE)
	var waystone := _find_nearby_waystone(px, pz, IsoConst.INTERACT_RANGE)
	var garden_plot := _find_nearby_garden_plot(px, pz, IsoConst.INTERACT_RANGE)
	var burial_mound := _find_nearby_burial_mound(px, pz, IsoConst.INTERACT_RANGE)
	var blight_heart := _find_nearby_blight_heart(px, pz, IsoConst.INTERACT_RANGE)
	# Landmarks auto-trigger on approach (no button press needed)
	_check_nearby_landmark(px, pz)
	var mana_well := _find_nearby_mana_well(px, pz, IsoConst.INTERACT_RANGE)
	var has_entity: bool = enemy != null or not chest.is_empty() or not door.is_empty() or not npc.is_empty() or scroll != null or shrine != null or digspot != null or not waystone.is_empty() or garden_plot != null or burial_mound != null or blight_heart != null or mana_well != null
	var interact_label: String = "USE"
	if enemy != null:
		interact_label = "ATTACK"
	elif not chest.is_empty():
		interact_label = "OPEN"
	elif not door.is_empty():
		interact_label = "ENTER"
	elif not npc.is_empty():
		match str(npc.get("npc_type", "")):
			"merchant", "traveling_merchant": interact_label = "SHOP"
			"blacksmith": interact_label = "FORGE"
			"bounty_board": interact_label = "BOARD"
			"stable": interact_label = "STABLE"
			"duelist": interact_label = "DUEL"
			"rest_site", "bed": interact_label = "REST"
			_: interact_label = "TALK"
	elif scroll != null:
		interact_label = "READ"
	elif shrine != null:
		interact_label = "PRAY"
	elif digspot != null:
		interact_label = "DIG"
	elif not waystone.is_empty():
		interact_label = "WARP"
	elif garden_plot != null:
		interact_label = "TEND"
	elif burial_mound != null:
		interact_label = "DIG"
	elif blight_heart != null:
		interact_label = "CLEANSE"
	elif mana_well != null:
		interact_label = "FILL"
	_world_hud.show_interact_prompt(has_entity and not SceneManager.has_open_overlay(), interact_label)

	var is_android: bool = OS.has_feature("android")
	if not npc.is_empty() and not SceneManager.save_manager.get_story_flag("tutorial_npc_tip"):
		SceneManager.save_manager.set_story_flag("tutorial_npc_tip")
		_show_tip("Tap to talk" if is_android else "Press E to talk to NPCs")
	elif not chest.is_empty() and not SceneManager.save_manager.get_story_flag("tutorial_chest_tip"):
		SceneManager.save_manager.set_story_flag("tutorial_chest_tip")
		_show_tip("Tap to open chests" if is_android else "Press E to open chests")
	elif enemy != null and not SceneManager.save_manager.get_story_flag("tutorial_enemy_tip"):
		SceneManager.save_manager.set_story_flag("tutorial_enemy_tip")
		var interact_key: String = "Tap" if OS.has_feature("android") else "Press E"
		_show_tip("Some enemies attack on sight — others wait. %s to challenge any enemy." % interact_key)

func _open_map_view() -> void:
	if _is_infinite:
		_open_fast_travel_panel()
		return
	if _map_overlay != null:
		_map_overlay.queue_free()
		_map_overlay = null
		return
	_map_overlay = MapViewOverlay.new()
	add_child(_map_overlay)
	_map_overlay.setup(world_map, map_name, _player,
		_npc_nodes, _active_npc_data,
		_enemy_nodes, _chest_nodes, _door_nodes, _waystone_nodes)
	_map_overlay.closed.connect(func() -> void: _map_overlay = null)

func _open_pause() -> void:
	if _pause_overlay != null:
		return
	_pause_overlay = _OverworldPauseOverlay.new()
	_pause_overlay.resumed.connect(func() -> void: _pause_overlay = null)
	_pause_overlay.quit_to_menu.connect(func() -> void: _pause_overlay = null)
	add_child(_pause_overlay)

# ── Cantrip activation (GID-065) ───────────────────────────────────────────

func _activate_ghost_phase() -> void:
	if _player == null or _ghost_phase_active:
		return
	var sm := SceneManager.save_manager
	var template_ids: Array[String] = sm.get_deck_template_ids()
	if not CantripManager.is_available("ghost_phase", template_ids):
		GameBus.hud_message_requested.emit("Ghost Phase requires 4+ Ghost-family cards in your deck.")
		return
	var current_time: float = Time.get_unix_time_from_system()
	if CantripManager.is_on_cooldown("ghost_phase", sm.cantrip_cooldowns, current_time):
		var remaining: int = CantripManager.cooldown_remaining("ghost_phase", sm.cantrip_cooldowns, current_time)
		GameBus.hud_message_requested.emit("Ghost Phase on cooldown (%ds)." % remaining)
		return
	if not _do_ghost_phase():
		GameBus.hud_message_requested.emit("No wall to phase through in this direction.")
		return
	sm.cantrip_cooldowns["ghost_phase"] = current_time + CantripManager.get_cooldown("ghost_phase")
	sm.mark_dirty()
	GameBus.cantrip_used.emit("ghost_phase")

func _do_ghost_phase() -> bool:
	var px: float = _player.position.x
	var pz: float = _player.position.z
	var tile_size: float = IsoConst.TILE_SIZE
	var wtx: int = int(floor(px / tile_size))
	var wtz: int = int(floor(pz / tile_size))

	# Build ordered list of directions to try: facing first, then all 4 cardinals
	var dirs: Array[Vector2i] = []
	var _last_move_dir: Vector2 = _csm.get_last_move_dir() if _csm != null else Vector2.ZERO
	if _last_move_dir.length_squared() > 0.01:
		var primary: Vector2i
		if abs(_last_move_dir.x) >= abs(_last_move_dir.y):
			primary = Vector2i(1 if _last_move_dir.x > 0 else -1, 0)
		else:
			primary = Vector2i(0, 1 if _last_move_dir.y > 0 else -1)
		dirs.append(primary)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not dirs.has(d):
			dirs.append(d)

	for d: Vector2i in dirs:
		var wall_tx: int = wtx + d.x
		var wall_tz: int = wtz + d.y
		var beyond_tx: int = wtx + d.x * 2
		var beyond_tz: int = wtz + d.y * 2
		if get_tile_global(wall_tx, wall_tz) != IsoConst.TILE_WALL:
			continue
		if get_tile_global(beyond_tx, beyond_tz) == IsoConst.TILE_WALL:
			continue  # two walls — too thick to phase through
		var target_x: float = float(beyond_tx) * tile_size + tile_size * 0.5
		var target_z: float = float(beyond_tz) * tile_size + tile_size * 0.5
		var target_y: float = get_terrain_height(target_x, target_z) + 0.5
		_start_ghost_phase_tween(Vector3(target_x, target_y, target_z))
		return true
	return false

func _start_ghost_phase_tween(target: Vector3) -> void:
	_ghost_phase_active = true
	_player.collision_layer = 0
	_player.collision_mask = 0
	_set_player_alpha(0.5)
	if _ghost_tween != null and _ghost_tween.is_valid():
		_ghost_tween.kill()
	_ghost_tween = create_tween()
	_ghost_tween.tween_property(_player, "position", target, 0.3)
	_ghost_tween.tween_callback(_on_ghost_phase_done)

func _on_ghost_phase_done() -> void:
	_player.collision_layer = 1
	_player.collision_mask = 2 | 4
	_set_player_alpha(1.0)
	_ghost_phase_active = false

func _set_player_alpha(alpha: float) -> void:
	if _player == null:
		return
	var sprites: Array[Node] = _player.find_children("*", "Sprite3D", true, false)
	for s: Node in sprites:
		var sp: Sprite3D = s as Sprite3D
		if sp != null:
			var c: Color = sp.modulate
			c.a = alpha
			sp.modulate = c

func _activate_skeleton_dig() -> void:
	if _player == null:
		return
	var px: float = _player.position.x
	var pz: float = _player.position.z
	var mound := _find_nearby_burial_mound(px, pz, IsoConst.INTERACT_RANGE)
	if mound == null:
		GameBus.hud_message_requested.emit("No burial mound nearby to dig.")
		return
	if mound.has_method("interact"):
		mound.interact()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _pause_overlay == null:
			_open_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map_view"):
		_clear_dest_marker()
		_open_map_view()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		_clear_dest_marker()
		GameBus.inventory_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		_clear_dest_marker()
		GameBus.journal_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("character"):
		_clear_dest_marker()
		GameBus.character_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_tree"):
		_clear_dest_marker()
		GameBus.skill_tree_requested.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_G:
		_activate_ghost_phase()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_D:
		_activate_skeleton_dig()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		_on_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _tap_touch_index:
			# Joystick guard: if the drag moves over the joystick, let joystick win.
			if _joystick_ref != null and _joystick_ref.has_method("is_touch_in_control_area"):
				if _joystick_ref.call("is_touch_in_control_area", drag.position):
					_tap_touch_index = -2
					return
			# Steer the move target continuously once the drag threshold is crossed.
			if drag.position.distance_to(_tap_start_screen) >= _TAP_DRAG_THRESHOLD:
				if _camera != null:
					var drag_tile: Vector2i = _screen_to_tile(drag.position)
					if drag_tile != _drag_last_tile:
						_drag_last_tile = drag_tile
						_handle_tap_to_move(drag.position)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_drag_last_tile = Vector2i(-9999, -9999)
			_handle_tap_to_move(mb.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _camera != null:
			var mt: Vector2i = _screen_to_tile((event as InputEventMouseMotion).position)
			if mt != _drag_last_tile:
				_drag_last_tile = mt
				_handle_tap_to_move((event as InputEventMouseMotion).position)
				get_viewport().set_input_as_handled()

func _on_screen_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		if _tap_touch_index != -2:
			return  # already tracking another finger
		# Reject taps in the virtual joystick interactive areas.
		if _joystick_ref != null and _joystick_ref.has_method("is_touch_in_control_area"):
			if _joystick_ref.call("is_touch_in_control_area", touch.position):
				return
		# Reject taps on any visible HUD button (USE, Mount, Ghost Phase, etc.).
		if _world_hud != null and _world_hud.is_touch_on_hud_button(touch.position):
			return
		_tap_start_screen = touch.position
		_tap_touch_index = touch.index
		_drag_last_tile = Vector2i(-9999, -9999)
	else:
		if touch.index != _tap_touch_index:
			return
		var drag_dist: float = touch.position.distance_to(_tap_start_screen)
		_tap_touch_index = -2
		if drag_dist < _TAP_DRAG_THRESHOLD:
			_handle_tap_to_move(touch.position)
			get_viewport().set_input_as_handled()

func _handle_interact() -> void:
	if _player == null:
		return
	var px: float = _player.position.x
	var pz: float = _player.position.z

	var door := _find_nearby_door(px, pz, IsoConst.INTERACT_RANGE * 2.0)
	if not door.is_empty():
		var door_id: String = str(door.get("id", ""))
		if door_id == "house_door":
			_show_house_door_panel()
			return
		var target_map: String = door.get("target_map", "")
		var tdoor: String = door.get("target_door_id", "")
		AudioManager.play_sfx("door_enter")
		# Auto-dismount when leaving the overworld for any named map
		if SceneManager.save_manager.is_mounted and target_map != "main" and not target_map.is_empty():
			SceneManager.save_manager.auto_dismiss_mount()
		if target_map == "spire":
			_show_spire_entrance_panel()
		elif target_map.is_empty():
			SceneManager.exit_map()
		else:
			if SceneManager.save_manager.current_map == "madrian" and target_map == "maykalene":
				SceneManager.save_manager.set_story_flag("chapter1_left_madrian")
			SceneManager.enter_map(target_map, tdoor)
		return

	var enemy := _find_nearby_enemy(px, pz, IsoConst.INTERACT_RANGE)
	if enemy != null and enemy.has_method("engage"):
		if enemy.get("enemy_data") != null:
			var etype: String = str(enemy.enemy_data.get("enemy_type", ""))
			if etype.begins_with("rival_"):
				var dlg: String = str(enemy.enemy_data.get("pre_battle_dialogue", ""))
				if dlg != "":
					_show_dialogue(dlg)
		enemy.engage()
		return

	var chest := _find_nearby_chest(px, pz, IsoConst.INTERACT_RANGE)
	if not chest.is_empty() and not chest.get("opened", false):
		if chest.get("is_mimic", false):
			AudioManager.play_sfx("enemy_alert")
			SceneManager.show_toast("It's a Mimic!", "Prepare for battle!")
			var mimic_deck: Array[String] = []
			mimic_deck.assign(EnemyRegistry.get_deck("mimic"))
			var mimic_data: Dictionary = {
				"id": str(chest.get("id", "mimic_0")),
				"x": chest.get("x", px),
				"z": chest.get("z", pz),
				"alive": true, "tracking": false,
				"enemy_type": "mimic",
				"enemy_deck": mimic_deck,
			}
			GameBus.enemy_engaged.emit(mimic_data)
			return
		chest["opened"] = true
		AudioManager.play_sfx("chest_open")
		if OS.has_feature("mobile") and bool(SceneManager.save_manager.get_setting("haptics", true)):
			Input.vibrate_handheld(40)
		var cid: String = str(chest.get("id", ""))
		SceneManager.save_manager.mark_chest_opened(cid)
		SceneManager.save_manager.increment_bounty_progress("open_chests", {})
		SceneManager.session_stats["chests_opened"] = int(SceneManager.session_stats.get("chests_opened", 0)) + 1
		var node := _chest_nodes.get(cid) as Node3D
		if node and node.has_method("mark_opened"):
			node.mark_opened()
		var chest_pos := Vector3(float(chest.get("x", px)), get_terrain_height(float(chest.get("x", px)), float(chest.get("z", pz))) + 0.25, float(chest.get("z", pz)))
		var chest_card_ids: Array[String] = []
		chest_card_ids.assign(chest.get("card_ids", []))
		# Tier: treasure rooms (dtr_) = 3, dungeon chests (dc_) = 2, world chests = 1
		var chest_tier: int = 1
		if cid.begins_with("dtr_"):
			chest_tier = 3
		elif cid.begins_with("dc_"):
			chest_tier = 2
		# 20% chance to drop a map fragment instead of normal loot (only if no active map)
		var sm := SceneManager.save_manager
		if _is_infinite and sm.active_treasure.is_empty() and randf() < 0.20:
			sm.collect_treasure_fragment()
		else:
			_spawn_card_items(chest_card_ids, chest_pos, chest_tier)
			_spawn_coin_piles(chest_pos)
			# Treasure rooms (dtr_ prefix) have a 40% weapon drop chance vs standard 15%
			var weapon_chance: float = 0.40 if cid.begins_with("dtr_") else 0.15
			_maybe_drop_equipment_from_chest(weapon_chance)
		return

	if not _is_infinite and world_map != null:
		var cracked := world_map.find_nearby_cracked_wall(px, pz, IsoConst.INTERACT_RANGE)
		if cracked != Vector2i(-1, -1):
			_break_cracked_wall(cracked.x, cracked.y)
			return

	var npc := _find_nearby_npc(px, pz, IsoConst.INTERACT_RANGE)
	if not npc.is_empty():
		if str(npc.get("npc_type", "")) == "traveling_merchant":
			var stock: Array[String] = []
			var raw: Variant = npc.get("merchant_stock", [])
			if raw is Array:
				stock.assign(raw as Array)
			GameBus.traveling_shop_requested.emit(stock, 30)
			return
		if str(npc.get("npc_type", "")) == "merchant":
			GameBus.shop_requested.emit()
			return
		if str(npc.get("npc_type", "")) == "blacksmith":
			GameBus.blacksmith_requested.emit()
			return
		if str(npc.get("npc_type", "")) == "bounty_board":
			GameBus.bounty_board_requested.emit()
			return
		if str(npc.get("npc_type", "")) == "stable":
			_show_stable_panel()
			return
		if str(npc.get("npc_type", "")) == "duelist":
			_show_duel_offer_panel(npc)
			return
		if str(npc.get("npc_type", "")) == "rest_site":
			_dungeon_session_ui.show_rest_site_panel(npc)
			return
		if str(npc.get("npc_type", "")) == "event_room":
			_dungeon_session_ui.show_event_panel(npc)
			return
		if str(npc.get("npc_type", "")) == "bed":
			_handle_bed_interaction()
			return
		if str(npc.get("npc_type", "")) == "trophy_pedestal":
			_show_trophy_info(npc)
			return
		var nid: String = str(npc.get("id", ""))
		var nnode := _npc_nodes.get(nid) as Node3D
		var dlg: String
		if nnode != null and nnode.has_method("get_dialogue"):
			dlg = nnode.get_dialogue()
			var fk: String = str(npc.get("flag_key", ""))
			if fk != "":
				SceneManager.save_manager.set_story_flag(fk)
		else:
			dlg = str(npc.get("dialogue", "..."))
		_show_dialogue(dlg)
		return

	var scroll := _find_nearby_scroll(px, pz, IsoConst.INTERACT_RANGE)
	if scroll != null and scroll.has_method("interact"):
		scroll.interact()
		return

	var shrine := _find_nearby_shrine(px, pz, IsoConst.INTERACT_RANGE)
	if shrine != null and shrine.has_method("interact"):
		shrine.interact()
		return

	var digspot := _find_nearby_digspot(px, pz, IsoConst.INTERACT_RANGE)
	if digspot != null and digspot.has_method("dig"):
		digspot.dig()
		return

	var burial_mound_node := _find_nearby_burial_mound(px, pz, IsoConst.INTERACT_RANGE)
	if burial_mound_node != null and burial_mound_node.has_method("interact"):
		burial_mound_node.interact()
		return

	var blight_heart_node := _find_nearby_blight_heart(px, pz, IsoConst.INTERACT_RANGE)
	if blight_heart_node != null and blight_heart_node.has_method("engage"):
		blight_heart_node.engage()
		return

	var mana_well_node := _find_nearby_mana_well(px, pz, IsoConst.INTERACT_RANGE)
	if mana_well_node != null:
		var wid: String = str(mana_well_node.get_meta("well_id", ""))
		if wid != "" and not SceneManager.save_manager.is_mana_well_collected(wid):
			SceneManager.save_manager.mark_mana_well_collected(wid)
			GameBus.essence_changed.emit(15)
			SceneManager.save_manager.essence += 15
			AudioManager.play_sfx("chest_open")
			mana_well_node.queue_free()
			_mana_well_nodes.erase(wid)
			GameBus.hud_message_requested.emit("Mana Well absorbed: +15 essence.")
		return

	var waystone := _find_nearby_waystone(px, pz, IsoConst.INTERACT_RANGE)
	if not waystone.is_empty():
		var wid: String = str(waystone.get("id", ""))
		if bool(waystone.get("active", false)):
			_open_fast_travel_panel()
		else:
			var wnode := _waystone_nodes.get(wid) as Node3D
			if wnode != null and wnode.has_method("mark_activated"):
				wnode.mark_activated()
		return

	var garden_plot := _find_nearby_garden_plot(px, pz, IsoConst.INTERACT_RANGE)
	if garden_plot != null:
		_show_garden_plot_panel(garden_plot)

# ── Spire entrance ─────────────────────────────────────────────────────────

func _show_spire_entrance_panel() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var is_active: bool = SceneManager.save_manager.is_spire_active()
	var curr_floor: int = 1
	if is_active:
		curr_floor = int(SceneManager.save_manager.get_spire_run().get("floor", 1))

	var layer := CanvasLayer.new()
	layer.layer = 50
	_hud.add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.64
	var panel_h: float = vh * 0.40
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.14, 0.96)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
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
	vbox.add_theme_constant_override("separation", int(vh * 0.022))
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "The Endless Spire"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(vh * 0.038))
	title.modulate = Color(0.85, 0.50, 1.0)
	vbox.add_child(title)

	var desc := Label.new()
	if is_active:
		desc.text = "A run is in progress — Floor %d.\nResume your climb?" % curr_floor
	else:
		desc.text = "Your deck stays behind.\nDraft new cards as you climb — or fall."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", int(vh * 0.026))
	desc.modulate = Color(0.85, 0.85, 0.85)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(vh * 0.03))
	vbox.add_child(row)

	var enter_btn := Button.new()
	enter_btn.text = "Resume (Floor %d)" % curr_floor if is_active else "Enter"
	enter_btn.custom_minimum_size = Vector2(vh * 0.20, vh * 0.07)
	enter_btn.add_theme_font_size_override("font_size", int(vh * 0.028))
	enter_btn.modulate = Color(0.85, 0.50, 1.0)
	enter_btn.pressed.connect(func() -> void:
		layer.queue_free()
		SceneManager.enter_spire()
	)
	row.add_child(enter_btn)

	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(vh * 0.16, vh * 0.07)
	leave_btn.add_theme_font_size_override("font_size", int(vh * 0.028))
	leave_btn.pressed.connect(func() -> void: layer.queue_free())
	row.add_child(leave_btn)

# ── Player Home ────────────────────────────────────────────────────────────

const _HOUSE_PRICE: int = 500

func _show_house_door_panel() -> void:
	var sm := SceneManager.save_manager
	if sm.home_owned:
		AudioManager.play_sfx("door_enter")
		SceneManager.enter_map("player_home", "exit_door")
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y

	var layer := CanvasLayer.new()
	layer.layer = 50
	_hud.add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.60
	var panel_h: float = vh * 0.32
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.14, 0.96)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(vh * 0.03))
	margin.add_theme_constant_override("margin_right",  int(vh * 0.03))
	margin.add_theme_constant_override("margin_top",    int(vh * 0.02))
	margin.add_theme_constant_override("margin_bottom", int(vh * 0.02))
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.015))
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "House For Sale"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(vh * 0.035))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Purchase this cozy home for %d coins.\nCurrent balance: %d coins." % [_HOUSE_PRICE, sm.coins]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", int(vh * 0.027))
	vbox.add_child(desc)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", int(vh * 0.02))
	vbox.add_child(hbox)

	var buy_btn := Button.new()
	buy_btn.text = "Buy (%d coins)" % _HOUSE_PRICE
	buy_btn.custom_minimum_size = Vector2(vh * 0.26, vh * 0.065)
	buy_btn.add_theme_font_size_override("font_size", int(vh * 0.027))
	buy_btn.disabled = sm.coins < _HOUSE_PRICE
	hbox.add_child(buy_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(vh * 0.16, vh * 0.065)
	cancel_btn.add_theme_font_size_override("font_size", int(vh * 0.027))
	hbox.add_child(cancel_btn)

	cancel_btn.pressed.connect(func() -> void: layer.queue_free())
	buy_btn.pressed.connect(func() -> void:
		sm.add_coins(-_HOUSE_PRICE)
		sm.home_owned = true
		sm.mark_dirty()
		layer.queue_free()
		AudioManager.play_sfx("door_enter")
		SceneManager.enter_map("player_home", "exit_door")
	)

const MOUNT_PRICE: int = 750
const MOUNT_LEVEL_REQ: int = 10

func _toggle_mount() -> void:
	var sm := SceneManager.save_manager
	if sm.current_map != "main":
		return
	if sm.owned_mounts.size() == 0:
		return
	if sm.is_mounted:
		sm.dismiss_mount()
	else:
		sm.summon_mount(str(sm.owned_mounts[0]))

func _on_enemy_engaged_for_mount(_enemy_data: Dictionary) -> void:
	if SceneManager.save_manager.is_mounted:
		SceneManager.save_manager.auto_dismiss_mount()

func _on_battle_won(_result: Dictionary) -> void:
	if _is_infinite and _current_biome >= 0:
		AudioManager.play_music(_BIOME_MUSIC[_current_biome])
		AudioManager.set_ambience(_current_biome)
		const BountyGen_cls = preload("res://game_logic/BountyGen.gd")
		if _current_biome < BountyGen_cls.BIOME_NAMES.size():
			var biome_name: String = BountyGen_cls.BIOME_NAMES[_current_biome]
			SceneManager.save_manager.increment_bounty_progress("defeat_in_biome", {"biome_name": biome_name})
	else:
		AudioManager.play_music("res://assets/audio/music/dungeon.ogg")
	var sm := SceneManager.save_manager
	if sm.active_mount != "" and sm.current_map == "main":
		sm.summon_mount(sm.active_mount)

func _on_coins_changed(n: int) -> void:
	_coin_label.text = "Coins: %d" % n

func _on_xp_changed(_xp: int, _level: int) -> void:
	_world_hud.refresh_xp_bar()
	_world_hud.update_xp_label()

func _show_stable_panel() -> void:
	var sm := SceneManager.save_manager
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y

	if sm.owned_mounts.has("stable_horse"):
		_show_dialogue("You already own a Stable Horse!")
		return

	var layer := CanvasLayer.new()
	layer.layer = 50
	_hud.add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.60
	var panel_h: float = vh * 0.36
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.14, 0.96)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(vh * 0.03))
	margin.add_theme_constant_override("margin_right",  int(vh * 0.03))
	margin.add_theme_constant_override("margin_top",    int(vh * 0.02))
	margin.add_theme_constant_override("margin_bottom", int(vh * 0.02))
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.015))
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Madrian Stables"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(vh * 0.035))
	vbox.add_child(title)

	var mount: Dictionary = MountRegistry.get_mount("stable_horse")
	var desc := Label.new()
	desc.text = "%s\n  Speed: ×%.1f   Price: %d coins" % [
		str(mount.get("display_name", "Stable Horse")),
		float(mount.get("speed_multiplier", 2.0)),
		MOUNT_PRICE,
	]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", int(vh * 0.027))
	vbox.add_child(desc)

	var level_lbl := Label.new()
	var level_ok: bool = sm.level >= MOUNT_LEVEL_REQ
	var coins_ok: bool = sm.coins >= MOUNT_PRICE
	if not level_ok:
		level_lbl.text = "Requires level %d (you are level %d)" % [MOUNT_LEVEL_REQ, sm.level]
		level_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	elif not coins_ok:
		level_lbl.text = "Insufficient coins (need %d, have %d)" % [MOUNT_PRICE, sm.coins]
		level_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		level_lbl.text = "Balance: %d coins" % sm.coins
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", int(vh * 0.025))
	vbox.add_child(level_lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", int(vh * 0.02))
	vbox.add_child(hbox)

	var buy_btn := Button.new()
	buy_btn.text = "Buy (%d coins)" % MOUNT_PRICE
	buy_btn.custom_minimum_size = Vector2(vh * 0.28, vh * 0.065)
	buy_btn.add_theme_font_size_override("font_size", int(vh * 0.027))
	buy_btn.disabled = not level_ok or not coins_ok
	hbox.add_child(buy_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(vh * 0.16, vh * 0.065)
	cancel_btn.add_theme_font_size_override("font_size", int(vh * 0.027))
	hbox.add_child(cancel_btn)

	cancel_btn.pressed.connect(func() -> void: layer.queue_free())
	buy_btn.pressed.connect(func() -> void:
		sm.add_coins(-MOUNT_PRICE)
		sm.owned_mounts.append("stable_horse")
		sm.summon_mount("stable_horse")
		layer.queue_free()
		_world_hud.update_mount_btn()
		_show_dialogue("You purchased a Stable Horse! Press T or tap Mount to ride.")
	)

func _handle_bed_interaction() -> void:
	var sm := SceneManager.save_manager
	sm.set_respawn_point("player_home", float(50) * IsoConst.TILE_SIZE, float(53) * IsoConst.TILE_SIZE)
	sm.time_of_day = 0.25
	_show_dialogue("You rest peacefully at home. Respawn point set!")

func _spawn_player_home_trophies() -> void:
	var sm := SceneManager.save_manager
	var trophy_ids: Array[String] = ["champion", "spire_7", "first_boss"]
	var tile_positions: Array[Vector2i] = [
		Vector2i(44, 49),
		Vector2i(47, 49),
		Vector2i(50, 49),
	]
	for i: int in range(trophy_ids.size()):
		var tid: String = trophy_ids[i]
		var trophy: Dictionary = TrophyRegistry.get_trophy(tid)
		if trophy.is_empty():
			continue
		var earned: bool = TrophyRegistry.is_earned(tid, sm)
		var tp: Vector2i = tile_positions[i]
		var wx: float = float(tp.x) * IsoConst.TILE_SIZE
		var wz: float = float(tp.y) * IsoConst.TILE_SIZE
		var terrain_y: float = get_terrain_height(wx, wz)
		var npc_data: Dictionary = {
			"id": "trophy_" + tid,
			"x": wx,
			"z": wz,
			"npc_type": "trophy_pedestal",
			"trophy_id": tid,
			"trophy_earned": earned,
			"dialogue": trophy.get("display_name", tid) + (": " + trophy.get("description", "") if earned else " (not yet earned)"),
			"flag_key": "",
		}
		var pedestal := _make_trophy_pedestal(earned, trophy.get("display_name", tid))
		pedestal.position = Vector3(wx, terrain_y, wz)
		_entity_root.add_child(pedestal)
		register_npc("trophy_" + tid, pedestal, npc_data)

func _make_trophy_pedestal(earned: bool, display_name: String) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.8, 0.65, 0.2) if earned else Color(0.4, 0.4, 0.4)

	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.9, 0.5, 0.9)
	var base := MeshInstance3D.new()
	base.mesh = base_mesh
	base.material_override = mat
	base.position = Vector3(0.0, 0.25, 0.0)
	root.add_child(base)

	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(0.5, 0.5, 0.5)
	var top := MeshInstance3D.new()
	top.mesh = top_mesh
	top.material_override = mat
	top.position = Vector3(0.0, 0.75, 0.0)
	root.add_child(top)

	var lbl := Label3D.new()
	lbl.text = display_name if earned else "???"
	lbl.font_size = 28
	lbl.pixel_size = 0.022
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0.0, 1.4, 0.0)
	lbl.modulate = Color(1.0, 0.9, 0.3) if earned else Color(0.5, 0.5, 0.5)
	root.add_child(lbl)

	return root

func _show_trophy_info(npc: Dictionary) -> void:
	var dlg: String = str(npc.get("dialogue", "A mysterious trophy."))
	_show_dialogue(dlg)

# ── Garden plots ────────────────────────────────────────────────────────────

func _spawn_player_home_garden() -> void:
	_garden_plot_nodes.clear()
	var tile_positions: Array[Vector2i] = [
		Vector2i(52, 54),
		Vector2i(55, 54),
		Vector2i(58, 54),
	]
	for i: int in range(tile_positions.size()):
		var tp: Vector2i = tile_positions[i]
		var wx: float = float(tp.x) * IsoConst.TILE_SIZE
		var wz: float = float(tp.y) * IsoConst.TILE_SIZE
		var terrain_y: float = get_terrain_height(wx, wz)
		var plot: Node3D = _GardenPlotScript.new()
		plot.init_from_data({"plot_idx": i})
		plot.position = Vector3(wx, terrain_y, wz)
		_entity_root.add_child(plot)
		_garden_plot_nodes.append(plot)

func _find_nearby_garden_plot(px: float, pz: float, range_dist: float) -> Node3D:
	var range_sq: float = range_dist * range_dist
	for plot in _garden_plot_nodes:
		if not is_instance_valid(plot):
			continue
		var ddx: float = plot.position.x - px
		var ddz: float = plot.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return plot
	return null

func _show_garden_plot_panel(plot: Node3D) -> void:
	var sm := SceneManager.save_manager
	var vh: float = get_viewport().get_visible_rect().size.y
	var vw: float = get_viewport().get_visible_rect().size.x
	var font_size: int = int(vh * 0.03)
	var btn_h: float = vh * 0.07

	var panel := PanelContainer.new()
	panel.position = Vector2(vw * 0.15, vh * 0.2)
	panel.custom_minimum_size = Vector2(vw * 0.7, vh * 0.5)
	_hud.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.012))
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Garden Plot %d" % (int(plot.plot_idx) + 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(vh * 0.045))
	vbox.add_child(title)

	var plot_data: Dictionary = plot.get_plot_data()
	var stage: int = plot.get_growth_stage() if not plot_data.is_empty() else 0

	if plot_data.is_empty():
		# Empty plot — seed picker
		var info := Label.new()
		info.text = "Choose a seed to plant:"
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_font_size_override("font_size", font_size)
		vbox.add_child(info)

		var has_any_seed: bool = false
		for seed_id in GardenDefs.SEEDS:
			var seed_count: int = int(sm.seeds.get(seed_id, 0))
			var sdata: Dictionary = GardenDefs.SEEDS[seed_id]
			var sname: String = str(sdata.get("display_name", seed_id))
			var days: int = int(sdata.get("growth_days", 2))
			var row := HBoxContainer.new()
			vbox.add_child(row)
			var lbl := Label.new()
			lbl.text = "%s — %d days  (owned: %d)" % [sname, days, seed_count]
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.add_theme_font_size_override("font_size", font_size)
			row.add_child(lbl)
			var plant_btn := Button.new()
			plant_btn.text = "Plant"
			plant_btn.custom_minimum_size = Vector2(vh * 0.14, btn_h)
			plant_btn.add_theme_font_size_override("font_size", font_size)
			plant_btn.disabled = seed_count <= 0
			var captured_seed_id: String = seed_id
			var captured_sname: String = sname
			plant_btn.pressed.connect(func() -> void:
				if sm.remove_seeds(captured_seed_id, 1):
					sm.set_plot(plot.plot_idx, captured_seed_id, sm.days_elapsed)
					plot.refresh_visual()
					SceneManager.show_toast("Planted!", captured_sname + " planted.")
					panel.queue_free()
			)
			row.add_child(plant_btn)
			if seed_count > 0:
				has_any_seed = true

		if not has_any_seed:
			var hint := Label.new()
			hint.text = "No seeds — buy some from a merchant."
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.add_theme_font_size_override("font_size", font_size)
			vbox.add_child(hint)

	elif stage < 3:
		# Growing — show info
		var seed_id: String = str(plot_data.get("seed_id", ""))
		var sdata: Dictionary = GardenDefs.SEEDS.get(seed_id, {})
		var sname: String = str(sdata.get("display_name", seed_id))
		var growth_days: int = int(sdata.get("growth_days", 2))
		var planted_day: int = int(plot_data.get("planted_day", 0))
		var days_left: int = max(0, planted_day + growth_days - sm.days_elapsed)
		var info := Label.new()
		info.text = "%s growing — ready in %d day(s)" % [sname, days_left]
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", font_size)
		vbox.add_child(info)

	else:
		# Mature — show harvest button
		var seed_id: String = str(plot_data.get("seed_id", ""))
		var sdata: Dictionary = GardenDefs.SEEDS.get(seed_id, {})
		var sname: String = str(sdata.get("display_name", seed_id))
		var plant_id: String = str(sdata.get("plant_id", ""))
		var yield_count: int = int(sdata.get("yield", 1))
		var info := Label.new()
		info.text = "%s is ready to harvest!" % sname
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_font_size_override("font_size", font_size)
		vbox.add_child(info)

		var harvest_btn := Button.new()
		harvest_btn.text = "Harvest (%d× %s)" % [yield_count, sname]
		harvest_btn.custom_minimum_size = Vector2(0, btn_h)
		harvest_btn.add_theme_font_size_override("font_size", font_size)
		harvest_btn.pressed.connect(func() -> void:
			sm.add_plants(plant_id, yield_count)
			sm.clear_plot(plot.plot_idx)
			GameBus.plant_harvested.emit(plot.plot_idx, yield_count)
			SceneManager.show_toast("Harvested!", "%d× %s" % [yield_count, sname])
			panel.queue_free()
		)
		vbox.add_child(harvest_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Close"
	cancel_btn.custom_minimum_size = Vector2(0, btn_h)
	cancel_btn.add_theme_font_size_override("font_size", font_size)
	cancel_btn.pressed.connect(func() -> void: panel.queue_free())
	vbox.add_child(cancel_btn)

# ── Dialogue ───────────────────────────────────────────────────────────────

func _show_dialogue(text: String) -> void:
	_world_hud.show_dialogue(text)

func _show_duel_offer_panel(npc: Dictionary) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var npc_id: String = str(npc.get("id", ""))
	var enemy_id: String = str(npc.get("duelist_enemy_id", "duelist_novice"))
	var wager: int = int(npc.get("wager_coins", 10))
	var is_rematch: bool = SceneManager.save_manager.defeated_duelists.has(npc_id)
	var player_coins: int = SceneManager.save_manager.coins
	var champion_reward: String = str(npc.get("champion_reward_card", ""))
	if is_rematch:
		wager = max(1, wager / 2)

	# Champion gate: count required duelists not yet beaten.
	var req_ids: Variant = npc.get("required_duelist_ids")
	var gate_remaining: int = 0
	if req_ids is PackedStringArray:
		var defeated: Array[String] = SceneManager.save_manager.defeated_duelists
		for rid: String in (req_ids as PackedStringArray):
			if not defeated.has(rid):
				gate_remaining += 1

	var layer := CanvasLayer.new()
	layer.layer = 50
	_hud.add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.6
	var panel_h: float = vh * 0.38
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.18, 0.96)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
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
	vbox.add_theme_constant_override("separation", int(vh * 0.022))
	margin.add_child(vbox)

	var offer_lbl := Label.new()
	if gate_remaining > 0:
		offer_lbl.text = "I only duel proven players. Beat the others in town first. (%d more to go.)" % gate_remaining
	elif player_coins < wager:
		offer_lbl.text = "Come back when you can cover the wager."
	elif is_rematch:
		offer_lbl.text = "A rematch? Wager: %d coins." % wager
	else:
		offer_lbl.text = "Care for a friendly duel?\nWager: %d coins." % wager
	offer_lbl.add_theme_font_size_override("font_size", int(vh * 0.028))
	offer_lbl.add_theme_color_override("font_color", Color.WHITE)
	offer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offer_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(offer_lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(vh * 0.03))
	vbox.add_child(row)

	if gate_remaining == 0 and player_coins >= wager:
		var duel_btn := Button.new()
		duel_btn.text = "Duel!"
		duel_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.07)
		duel_btn.add_theme_font_size_override("font_size", int(vh * 0.028))
		duel_btn.pressed.connect(func() -> void:
			layer.queue_free()
			var enemy_deck: Array[String] = EnemyRegistry.get_deck(enemy_id)
			var enemy_data_dict: Dictionary = {
				"enemy_type": enemy_id,
				"enemy_deck": enemy_deck,
				"duel_npc_id": npc_id,
				"champion_reward_card": champion_reward,
			}
			GameBus.duel_requested.emit(enemy_data_dict, wager)
		)
		row.add_child(duel_btn)

	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.07)
	decline_btn.add_theme_font_size_override("font_size", int(vh * 0.028))
	decline_btn.pressed.connect(func() -> void: layer.queue_free())
	row.add_child(decline_btn)

func _show_tip(text: String) -> void:
	_world_hud.show_tip(text)

func _on_scroll_collected(scroll_id: String) -> void:
	var scroll: Dictionary = ScrollRegistry.get_scroll(scroll_id)
	var title: String = scroll.get("title", scroll_id) if not scroll.is_empty() else scroll_id
	_show_tip("Lore scroll found: " + title)
	if SceneManager.save_manager.collected_scrolls.size() >= ScrollRegistry.SCROLL_COUNT:
		GameBus.all_scrolls_collected.emit()

# ── Card item spawning ──────────────────────────────────────────────────────

func _spawn_card_items(card_ids: Array[String], origin: Vector3, chest_tier: int = 1) -> void:
	const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
	var rng := RandomNumberGenerator.new()
	for i: int in range(card_ids.size()):
		var cid: String = str(card_ids[i])
		var rarity: String = CardDropUtil.effective_rarity(cid, CardDropUtil.roll_rarity(chest_tier))
		var stats: Dictionary = CardDropUtil.roll_stats(cid, rarity)
		var angle: float = (float(i) / float(max(card_ids.size(), 1))) * TAU + rng.randf_range(-0.4, 0.4)
		var dist: float = rng.randf_range(1.0, 1.8)
		var land_pos := origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var item: Node3D = _WorldItemScene.instantiate()
		_entity_root.add_child(item)
		if item.has_method("setup"):
			item.setup(cid, origin, land_pos, rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1)))

func _spawn_coin_piles(origin: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	var pile_count: int = rng.randi_range(3, 5)
	for i: int in range(pile_count):
		var angle: float = (float(i) / float(pile_count)) * TAU + rng.randf_range(-0.5, 0.5)
		var dist: float = rng.randf_range(0.8, 2.0)
		var land_pos := origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var amount: int = rng.randi_range(5, 20)
		var item: Node3D = _WorldItemScene.instantiate()
		_entity_root.add_child(item)
		if item.has_method("setup_coin"):
			item.setup_coin(amount, origin, land_pos)

func _maybe_drop_equipment_from_chest(chance: float = 0.15) -> void:
	if randf() >= chance:
		return
	var sm := SceneManager.save_manager
	var candidates: Array[String] = []

	var owned_w: Array[String] = sm.get_owned_by_slot("weapon")
	for wid: String in WeaponRegistry.get_by_slot("weapon"):
		if wid != "rusty_dagger" and not owned_w.has(wid):
			candidates.append(wid)

	var owned_a: Array[String] = sm.owned_armor
	for eid: String in WeaponRegistry.get_by_slot("armor"):
		if not owned_a.has(eid):
			candidates.append(eid)

	var owned_r: Array[String] = sm.owned_rings
	for eid: String in WeaponRegistry.get_by_slot("ring"):
		if not owned_r.has(eid):
			candidates.append(eid)

	var owned_t: Array[String] = sm.owned_trinkets
	for eid: String in WeaponRegistry.get_by_slot("trinket"):
		if not owned_t.has(eid):
			candidates.append(eid)

	if candidates.is_empty():
		return
	var picked: String = candidates[randi() % candidates.size()]
	var weapon: WeaponData = WeaponRegistry.get_weapon(picked)
	if weapon == null:
		return
	if weapon.slot == "weapon":
		sm.add_weapon(picked)
	else:
		sm.add_equipment(picked, weapon.slot)
	GameBus.hud_message_requested.emit("Found: %s!" % weapon.display_name)
	GameBus.equipment_dropped.emit(picked)

# ── Weather visuals ────────────────────────────────────────────────────────

func _on_weather_changed(weather_id: String, _duration: float) -> void:
	# Swap particle rig
	if _active_weather_particles != null and is_instance_valid(_active_weather_particles):
		_active_weather_particles.queue_free()
	_active_weather_particles = null

	if weather_id != "":
		var particles: GPUParticles3D = WeatherParticles.make(weather_id) as GPUParticles3D
		if particles != null:
			_entity_root.add_child(particles)
			if _player != null:
				particles.position = _player.position + Vector3(0.0, 12.0, 0.0)
			_active_weather_particles = particles

	# Begin tint transition
	_weather_tint_target = WeatherParticles.get_screen_tint(weather_id)
	_weather_tint_lerp_t = 0.0

	# Update grass wind direction
	if _grass != null:
		var grass_node: GrassBlades = _grass as GrassBlades
		if grass_node != null:
			grass_node.set_wind_direction(WeatherParticles.get_wind_direction(weather_id))

# ── Tap-to-move ────────────────────────────────────────────────────────────

# Entry point called by both touch and mouse input after basic validation.
func _handle_tap_to_move(screen_pos: Vector2) -> void:
	if _player == null or _camera == null:
		return
	var tile: Vector2i = _screen_to_tile(screen_pos)
	var tile_type: int = get_tile_global(tile.x, tile.y)
	var is_walkable: bool = (tile_type == IsoConst.TILE_GRASS
		or tile_type == IsoConst.TILE_HILL
		or tile_type == IsoConst.TILE_PATH)
	if not is_walkable:
		_show_tip("Can't go there")
		return
	var player_tile: Vector2i = IsoConst.world_to_tile(_player.position.x, _player.position.z)
	var path: Array[Vector2i] = Pathfinder.find_path(
		Callable(self, "get_tile_global"), player_tile, tile, 64)
	if path.is_empty():
		_show_tip("Can't reach that tile")
		return
	_place_dest_marker(tile)
	if _player.has_method("set_destination_path"):
		_player.call("set_destination_path", path)

# Convert a screen position to the nearest tile coordinate via analytic
# ray–plane intersection with the y=0 tile plane.
func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = _camera.project_ray_normal(screen_pos)
	# Solve: ray_origin.y + t * ray_dir.y = 0 → t = -ray_origin.y / ray_dir.y
	if abs(ray_dir.y) < 0.0001:
		return IsoConst.world_to_tile(_player.position.x, _player.position.z)
	var t: float = -ray_origin.y / ray_dir.y
	var world_pos: Vector3 = ray_origin + t * ray_dir
	return IsoConst.world_to_tile(world_pos.x, world_pos.z)

# Place or move the destination marker to the centre of the given tile.
func _place_dest_marker(tile: Vector2i) -> void:
	var wx: float = (float(tile.x) + 0.5) * IsoConst.TILE_SIZE
	var wz: float = (float(tile.y) + 0.5) * IsoConst.TILE_SIZE
	var wy: float = 0.08  # just above the tile surface

	if _dest_marker == null or not is_instance_valid(_dest_marker):
		_dest_marker = _make_dest_marker()
		add_child(_dest_marker)

	_dest_marker.position = Vector3(wx, wy, wz)
	_dest_marker.show()

	if _dest_tween != null and _dest_tween.is_valid():
		_dest_tween.kill()
	_dest_tween = create_tween().set_loops()
	_dest_tween.tween_property(_dest_marker, "scale",
		Vector3(1.2, 1.0, 1.2), 0.45).set_trans(Tween.TRANS_SINE)
	_dest_tween.tween_property(_dest_marker, "scale",
		Vector3(0.85, 1.0, 0.85), 0.45).set_trans(Tween.TRANS_SINE)

func _make_dest_marker() -> Node3D:
	var root := Node3D.new()
	root.name = "DestMarker"
	var mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.50
	torus.outer_radius = 0.72
	torus.rings = 12
	torus.ring_segments = 16
	mesh_inst.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.25, 1.0, 0.55, 0.90)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.25, 1.0, 0.55)
	mat.emission_energy_multiplier = 1.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	root.add_child(mesh_inst)
	return root

func _clear_dest_marker() -> void:
	if _dest_tween != null and _dest_tween.is_valid():
		_dest_tween.kill()
	_dest_tween = null
	if _dest_marker != null and is_instance_valid(_dest_marker):
		_dest_marker.hide()
	if _player != null and _player.has_method("cancel_path"):
		_player.call("cancel_path")

# ── Return portal (TID-339) ───────────────────────────────────────────────
# Spawns a visible "Return to Town" portal in the main overworld near the
# player's initial spawn so there is always an exit that doesn't require a
# waystone. Registers itself in _active_door_data with target_map = "" so
# _handle_interact → exit_map() pops the map stack back to madrian.

func _spawn_return_portal() -> void:
	const PORTAL_TX: int = 3
	const PORTAL_TZ: int = 6  # 3 tiles south of the default infinite-world spawn
	var wx: float = (float(PORTAL_TX) + 0.5) * IsoConst.TILE_SIZE
	var wz: float = (float(PORTAL_TZ) + 0.5) * IsoConst.TILE_SIZE
	var wy: float = get_terrain_height(wx, wz)

	# Visual: glowing golden pillar with a label above it.
	var root := Node3D.new()
	root.name = "ReturnPortal"
	root.position = Vector3(wx, wy, wz)
	_entity_root.add_child(root)

	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.20
	cyl.bottom_radius = 0.20
	cyl.height        = 2.0
	mesh_inst.mesh = cyl
	mesh_inst.position = Vector3(0.0, 1.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.20, 0.90)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.10)
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	root.add_child(mesh_inst)

	var lbl := Label3D.new()
	lbl.text = "Return to Town"
	lbl.font_size = 24
	lbl.modulate = Color(1.0, 0.95, 0.60)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 2.5, 0.0)
	root.add_child(lbl)

	# Register as a door with empty target_map so _handle_interact calls exit_map().
	var portal_data: Dictionary = {
		"id":             "return_portal",
		"x":              wx,
		"z":              wz,
		"target_map":     "",
		"target_door_id": "",
	}
	_active_door_data["return_portal"] = portal_data
	_door_nodes["return_portal"] = root
