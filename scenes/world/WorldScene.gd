extends Node3D

const WorldEvents     = preload("res://game_logic/WorldEvents.gd")
const WorldMap        = preload("res://game_logic/world/WorldMap.gd")
const DungeonGen      = preload("res://game_logic/world/DungeonGen.gd")
const SpireFloorGen   = preload("res://game_logic/spire/SpireFloorGen.gd")
const GrassBlades     = preload("res://scenes/world/GrassBlades.gd")
const VirtualJoystick = preload("res://scenes/ui/VirtualJoystick.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const ChunkRenderer   = preload("res://scenes/world/ChunkRenderer.gd")
const TerrainMath     = preload("res://game_logic/TerrainMath.gd")
const Minimap         = preload("res://scenes/world/Minimap.gd")
const MapViewOverlay  = preload("res://scenes/ui/MapViewOverlay.gd")
const WeaponRegistry  = preload("res://autoloads/WeaponRegistry.gd")
const EnemyRegistry   = preload("res://autoloads/EnemyRegistry.gd")
const WeaponData      = preload("res://data/WeaponData.gd")
const SaveManager        = preload("res://autoloads/SaveManager.gd")
const TrophyRegistry     = preload("res://game_logic/TrophyRegistry.gd")
const WeatherParticles   = preload("res://scenes/world/WeatherParticles.gd")
const _TerrainShader: Shader = preload("res://assets/shaders/terrain.gdshader")
const TextureGen = preload("res://game_logic/TextureGen.gd")

const _TexGrass:     Texture2D = preload("res://assets/textures/pixel_art/grass_pixel.png")
const _TexHillSide:  Texture2D = preload("res://assets/textures/pixel_art/hill_side_pixel.png")
const _TexHillTop:   Texture2D = preload("res://assets/textures/pixel_art/hill_top_pixel.png")
const _TexWallSide:  Texture2D = preload("res://assets/textures/pixel_art/wall_side_pixel.png")
const _TexWallTop:   Texture2D = preload("res://assets/textures/pixel_art/wall_top_pixel.png")

# Preload entity scenes — avoids filesystem hits during spawning
const _PlayerScene       = preload("res://scenes/world/entities/Player.tscn")
const _EnemyScene        = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _ChestScene        = preload("res://scenes/world/entities/Chest.tscn")
const _DoorScene         = preload("res://scenes/world/entities/Door.tscn")
const _WorldItemScene    = preload("res://scenes/world/entities/WorldItem.tscn")
const _TownspersonScene  = preload("res://scenes/world/entities/TownspersonNPC.tscn")
const _StoryScrollScene  = preload("res://scenes/world/entities/StoryScroll.tscn")
const _PuzzleShrineScene = preload("res://scenes/world/entities/PuzzleShrine.tscn")
const _WaystoneScene     = preload("res://scenes/world/entities/Waystone.tscn")

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
var _door_nodes: Dictionary = {}    # id -> Node3D
var _npc_nodes: Dictionary = {}     # id -> Node3D
var _scroll_nodes: Array[Node3D] = []
var _shrine_nodes: Array[Node3D] = []
var _waystone_nodes: Dictionary = {}    # id -> Node3D
var _active_waystone_data: Dictionary = {}  # id -> Dictionary
var _tile_meshes: Node3D
var _wall_meshes: Node3D
var _entity_root: Node3D

# Chunk streaming (both infinite and named-map paths use ChunkRenderer)
var _chunk_data_cache: Dictionary = {}    # Vector2i -> ChunkData (RefCounted)
var _chunk_renderers: Dictionary = {}     # Vector2i -> ChunkRenderer
var _active_chest_data: Dictionary = {}  # chest_id -> Dictionary
var _active_door_data: Dictionary = {}   # door_id -> Dictionary
var _active_npc_data: Dictionary = {}    # npc_id -> Dictionary
var _digspot_node: Node3D = null         # the one active DigSpot entity (nil if none loaded)
var _last_player_chunk: Vector2i = Vector2i(-9999, -9999)
var _last_move_dir: Vector2 = Vector2.ZERO
var _current_biome: int = -1

const _BIOME_MUSIC: Array = [
	"res://assets/audio/music/grasslands.ogg",
	"res://assets/audio/music/forest.ogg",
	"res://assets/audio/music/desert.ogg",
	"res://assets/audio/music/scorched.ogg",
	"res://assets/audio/music/mountains.ogg",
]
var _terrain_mat: ShaderMaterial
var _chunk_build_queue: Array[Vector2i] = []
var _last_save_pos: Vector2 = Vector2(-9999, -9999)
var _interact_timer: float = 0.0
var _roaming_boss_timer: float = 0.0
var _traveling_merchant_timer: float = 0.0
var _card_shower_items: Array[Node3D] = []

# Day/night cycle
var _world_env: WorldEnvironment
@export var day_duration: float = 600.0   # seconds per full day
var _time_of_day: float = 0.4             # loaded from save; 0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset
var _day_night_timer: float = 0.0
const DAY_NIGHT_INTERVAL: float = 0.5     # update lighting at 2 Hz
# Cached day/night values — skip GPU writes when unchanged
var _cached_sun_energy: float = -1.0
var _cached_sun_color: Color = Color.BLACK
var _cached_moon_energy: float = -1.0
var _cached_sky_color: Color = Color.BLACK
var _cached_ambient_color: Color = Color.BLACK
var _cached_ambient_energy: float = -1.0

# Weather visuals
var _active_weather_particles: Node3D = null
var _weather_tint: Color = Color(1.0, 1.0, 1.0)
var _weather_tint_target: Color = Color(1.0, 1.0, 1.0)
var _weather_tint_lerp_t: float = 1.0
const _WEATHER_TINT_SPEED: float = 2.0  # tint blends in 0.5s

# Threaded chunk building
var _chunk_data_pending: Dictionary = {}    # Vector2i -> true (job in flight)
var _chunk_build_results: Array[Dictionary] = []  # completed terrain prep, waiting for commit
var _chunk_build_mutex: Mutex = Mutex.new()
var _chunk_task_ids: Array[int] = []        # WorkerThreadPool task IDs in flight
var _chunk_queued: Dictionary = {}          # Vector2i -> true (O(1) queue membership)
var _chunk_queue_dirty: bool = false       # only re-sort when new items were added
var _pending_physics: Array[Node3D] = []    # ChunkRenderers awaiting physics build
var _last_dir_update_time: float = -999.0  # throttle direction-change chunk updates

const LOAD_RADIUS:        int = 6
const UNLOAD_RADIUS:      int = 7
const CACHE_EVICT_RADIUS: int = 10  # evict chunk data beyond this to bound memory
var WORLD_SEED:           int = 42  # overwritten in _ready() for infinite worlds
const MAX_CHUNK_JOBS:     int = 4   # concurrent WorkerThreadPool tasks
const INTERACT_INTERVAL: float = 0.15  # check interactions at ~7 Hz, not 60

@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD
@onready var _interact_label: Label = $HUD/InteractPrompt
@onready var _map_label: Label = $HUD/MapLabel
@onready var _coin_label: Label = $HUD/CoinLabel
@onready var _sun: DirectionalLight3D = $DirectionalLight3D
@onready var _moon: DirectionalLight3D = $MoonLight
var _fill_light: DirectionalLight3D

var _dialogue_label: Label
var _coord_label: Label
var _minimap: Node
var _level_label: Label
var _xp_bar: ProgressBar
var _map_overlay: Node = null
var _interact_btn: Button = null
var _dialogue_timer: float = 0.0
const DIALOGUE_DURATION: float = 4.0

var _tip_label: Label
var _tip_timer: float = 0.0
const TIP_DURATION: float = 5.0

# Dungeon session hero HP — tracks HP across rooms; reset fresh each dungeon entry.
# Not saved to SaveManager (dying resets the session).
var _dungeon_hero_hp: int = 30

# Terrain height constants — named-map path uses a wider ramp than chunks
const HILL_PEAK_H:    float = 1.5
const HILL_RAMP_R:    float = 4.0
const TERRAIN_VDENSITY: int = 2

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.5, 0.85)   # daytime sky; updated every frame
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

func _ready() -> void:
	_setup_environment()
	_time_of_day = SceneManager.save_manager.time_of_day
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

	_spawn_player()

	if _is_infinite:
		_update_chunks()
		# Build the inner 5×5 ring synchronously for an immediate view;
		# outer chunks stream in via threaded jobs in _process.
		var sync_cx: int = _last_player_chunk.x
		var sync_cz: int = _last_player_chunk.y
		var deferred: Array[Vector2i] = []
		while not _chunk_build_queue.is_empty():
			var key: Vector2i = _chunk_build_queue.pop_front()
			if abs(key.x - sync_cx) <= 2 and abs(key.y - sync_cz) <= 2:
				_build_chunk_sync(key)
			else:
				deferred.append(key)
		_chunk_build_queue.assign(deferred)
	else:
		# Named map: load all chunks covering the 100×100 tile map synchronously
		const CHUNK_SIZE: int = 16
		var max_cx: int = (WorldMap.MAP_WIDTH + CHUNK_SIZE - 1) / CHUNK_SIZE
		var max_cz: int = (WorldMap.MAP_HEIGHT + CHUNK_SIZE - 1) / CHUNK_SIZE
		for cz in range(max_cz):
			for cx in range(max_cx):
				_build_chunk_sync(Vector2i(cx, cz))
		var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
		_last_player_chunk = Vector2i(
			int(floor(_player.position.x / chunk_world)),
			int(floor(_player.position.z / chunk_world)))
		_spawn_named_map_scrolls()
		_spawn_named_map_shrines()
		_spawn_named_map_waystones()
		if map_name == "player_home":
			_spawn_player_home_trophies()

	_update_hud()

	# Re-enter any battle that was interrupted (e.g. app quit mid-fight)
	if not SceneManager.save_manager.pending_battle_enemy_data.is_empty():
		GameBus.enemy_engaged.emit.call_deferred(SceneManager.save_manager.pending_battle_enemy_data)
	_interact_label.hide()
	_interact_label.text = "[Tap] Interact" if OS.has_feature("android") else "[E] Interact"

	var joystick := VirtualJoystick.new()
	_hud.add_child(joystick)

	var vh: float = get_viewport().get_visible_rect().size.y
	var vw: float = get_viewport().get_visible_rect().size.x
	var font_size: int = int(vh * 0.03)
	var btn_w: float = vh * 0.14
	var btn_h: float = vh * 0.07

	# Apply font size to the tscn-defined labels
	_map_label.add_theme_font_size_override("font_size", int(vh * 0.032))
	_coin_label.add_theme_font_size_override("font_size", font_size)
	_interact_label.add_theme_font_size_override("font_size", font_size)

	var menu_btn := Button.new()
	menu_btn.text = "Menu"
	menu_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	menu_btn.position = Vector2(vh * 0.01, vh * 0.01)
	menu_btn.add_theme_font_size_override("font_size", font_size)
	menu_btn.pressed.connect(func() -> void: SceneManager.go_to_menu())
	_hud.add_child(menu_btn)

	# Minimap: top=vh*0.01, height=vh*0.20, bottom≈vh*0.21; buttons sit below it.
	var minimap_bottom: float = vh * 0.01 + vh * 0.20 + vh * 0.01  # ≈ vh * 0.22
	var btn_x: float = vw - btn_w * 1.3 - vh * 0.01

	var inv_btn := Button.new()
	inv_btn.text = "Inventory"
	inv_btn.custom_minimum_size = Vector2(btn_w * 1.3, btn_h)
	inv_btn.position = Vector2(btn_x, minimap_bottom)
	inv_btn.add_theme_font_size_override("font_size", font_size)
	inv_btn.pressed.connect(func() -> void: GameBus.inventory_requested.emit())
	_hud.add_child(inv_btn)

	var journal_btn := Button.new()
	journal_btn.text = "Journal"
	journal_btn.custom_minimum_size = Vector2(btn_w * 1.3, btn_h)
	journal_btn.position = Vector2(btn_x, minimap_bottom + btn_h + vh * 0.005)
	journal_btn.add_theme_font_size_override("font_size", font_size)
	journal_btn.pressed.connect(func() -> void: GameBus.journal_requested.emit())
	_hud.add_child(journal_btn)

	var char_btn := Button.new()
	char_btn.text = "Character"
	char_btn.custom_minimum_size = Vector2(btn_w * 1.3, btn_h)
	char_btn.position = Vector2(btn_x, minimap_bottom + (btn_h + vh * 0.005) * 2)
	char_btn.add_theme_font_size_override("font_size", font_size)
	char_btn.pressed.connect(func() -> void: GameBus.character_requested.emit())
	_hud.add_child(char_btn)

	var skill_btn := Button.new()
	skill_btn.text = "Skills"
	skill_btn.custom_minimum_size = Vector2(btn_w * 1.3, btn_h)
	skill_btn.position = Vector2(btn_x, minimap_bottom + (btn_h + vh * 0.005) * 3)
	skill_btn.add_theme_font_size_override("font_size", font_size)
	skill_btn.pressed.connect(func() -> void: GameBus.skill_tree_requested.emit())
	_hud.add_child(skill_btn)

	if OS.has_feature("android"):
		_interact_btn = Button.new()
		_interact_btn.text = "USE"
		_interact_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.08)
		_interact_btn.add_theme_font_size_override("font_size", int(vh * 0.032))
		_interact_btn.position = Vector2(vw * 0.5 - vh * 0.09, vh * 0.80)
		_interact_btn.pressed.connect(_handle_interact)
		_interact_btn.hide()
		_hud.add_child(_interact_btn)

	var vp := get_viewport().get_visible_rect().size
	_dialogue_label = Label.new()
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.add_theme_font_size_override("font_size", font_size)
	_dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	_dialogue_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_dialogue_label.add_theme_constant_override("shadow_offset_x", 2)
	_dialogue_label.add_theme_constant_override("shadow_offset_y", 2)
	_dialogue_label.size = Vector2(vp.x * 0.6, vp.y * 0.15)
	_dialogue_label.position = Vector2(vp.x * 0.2, vp.y * 0.78)
	_dialogue_label.hide()
	_hud.add_child(_dialogue_label)
	GameBus.hud_message_requested.connect(_show_dialogue)
	GameBus.story_scroll_collected.connect(_on_scroll_collected)
	GameBus.waystone_activated.connect(_on_waystone_activated)

	_tip_label = Label.new()
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_font_size_override("font_size", font_size)
	_tip_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	_tip_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_tip_label.add_theme_constant_override("shadow_offset_x", 2)
	_tip_label.add_theme_constant_override("shadow_offset_y", 2)
	_tip_label.size = Vector2(vp.x * 0.6, vp.y * 0.12)
	_tip_label.position = Vector2(vp.x * 0.2, vp.y * 0.14)
	_tip_label.hide()
	_hud.add_child(_tip_label)

	if not SceneManager.save_manager.get_story_flag("tutorial_inventory_tip"):
		SceneManager.save_manager.set_story_flag("tutorial_inventory_tip")
		var inv_tip: String = "Tap the Inventory button to manage your deck." \
			if OS.has_feature("android") else "Press I or tap Inventory to manage your deck."
		_show_tip.call_deferred(inv_tip)

	_coord_label = Label.new()
	_coord_label.add_theme_font_size_override("font_size", font_size)
	_coord_label.add_theme_color_override("font_color", Color.WHITE)
	_coord_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_coord_label.add_theme_constant_override("shadow_offset_x", 1)
	_coord_label.add_theme_constant_override("shadow_offset_y", 1)
	_coord_label.position = Vector2(vh * 0.01, vh * 0.11)
	_hud.add_child(_coord_label)

	_minimap = Minimap.new()
	add_child(_minimap)
	_minimap.setup(self, _hud, _player, _enemy_nodes, _chest_nodes, _door_nodes, _npc_nodes)
	_minimap.tapped.connect(_open_map_view)

	if _is_infinite:
		WorldEvents.register_all(self)
		WeatherManager.on_world_entered()
		GameBus.weather_changed.connect(_on_weather_changed)

	if not _is_infinite:
		AudioManager.play_music("res://assets/audio/music/dungeon.ogg")
		if map_name.begins_with("dungeon_"):
			_dungeon_hero_hp = 30
	GameBus.battle_won.connect(func(_r: Dictionary) -> void:
		if _is_infinite and _current_biome >= 0:
			AudioManager.play_music(_BIOME_MUSIC[_current_biome])
		else:
			AudioManager.play_music("res://assets/audio/music/dungeon.ogg"))

func _exit_tree() -> void:
	# Wait for any in-flight worker tasks before the GDScript instance is freed.
	# Without this, WorkerThreadPool holds a Callable referencing this object and
	# crashes on shutdown when it tries to clean up while the instance is gone.
	for task_id: int in _chunk_task_ids:
		WorkerThreadPool.wait_for_task_completion(task_id)
	_chunk_task_ids.clear()
	if _active_weather_particles != null and is_instance_valid(_active_weather_particles):
		_active_weather_particles.queue_free()
	_active_weather_particles = null

func flush_time_of_day() -> void:
	SceneManager.save_manager.time_of_day = _time_of_day

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
	SceneManager.save_manager.coins_changed.connect(func(n: int) -> void: _coin_label.text = "Coins: %d" % n)

	# XP bar — bottom-left of screen
	var vh: float = get_viewport().get_visible_rect().size.y
	var xp_row := HBoxContainer.new()
	xp_row.position = Vector2(vh * 0.01, vh * 0.88)
	xp_row.add_theme_constant_override("separation", int(vh * 0.008))
	_hud.add_child(xp_row)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", int(vh * 0.028))
	_level_label.custom_minimum_size = Vector2(vh * 0.08, 0)
	xp_row.add_child(_level_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(vh * 0.22, vh * 0.032)
	_xp_bar.show_percentage = false
	xp_row.add_child(_xp_bar)

	var xp_lbl := Label.new()
	xp_lbl.add_theme_font_size_override("font_size", int(vh * 0.025))
	xp_row.add_child(xp_lbl)

	GameBus.xp_changed.connect(func(_x: int, _l: int) -> void:
		_refresh_xp_bar()
		xp_lbl.text = "%d / %d XP" % [
			SceneManager.save_manager.xp - SaveManager.xp_for_level(SceneManager.save_manager.level - 1),
			SaveManager.xp_for_level(SceneManager.save_manager.level) - SaveManager.xp_for_level(SceneManager.save_manager.level - 1)])

	_refresh_xp_bar()
	var sm := SceneManager.save_manager
	xp_lbl.text = "%d / %d XP" % [
		sm.xp - SaveManager.xp_for_level(sm.level - 1),
		SaveManager.xp_for_level(sm.level) - SaveManager.xp_for_level(sm.level - 1)]

func _refresh_xp_bar() -> void:
	if _level_label == null or _xp_bar == null:
		return
	var sm := SceneManager.save_manager
	var lvl: int = sm.level
	var xp_prev: int = SaveManager.xp_for_level(lvl - 1)
	var xp_next: int = SaveManager.xp_for_level(lvl)
	_level_label.text = "Lv.%d" % lvl
	_xp_bar.max_value = xp_next - xp_prev
	_xp_bar.value = sm.xp - xp_prev

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
		elif not world_map.has_player_spawn() and \
				SceneManager.save_manager.current_map == map_name and \
				(SceneManager.save_manager.player_x != 0.0 or SceneManager.save_manager.player_z != 0.0):
			# Only restore saved position for maps without an explicit SPAWN marker.
			# Maps with a SPAWN marker (like madrian) always use it so key NPCs
			# placed near the spawn (e.g. Maiteln) are always visible on arrival.
			px = SceneManager.save_manager.player_x
			pz = SceneManager.save_manager.player_z
		else:
			px = default_px
			pz = default_pz

	_player = _create_player_node()
	_player.position = Vector3(px, get_terrain_height(px, pz) + 0.5, pz)
	_entity_root.add_child(_player)
	_camera.position = _player.position + Vector3(20, 20, 20)

# Returns the tile type at global tile coordinates (wtx, wtz).
# Used by ChunkRenderer during terrain height computation so hills blend
# seamlessly across chunk borders.
func get_tile_global(wtx: int, wtz: int) -> int:
	if not _is_infinite:
		return world_map.get_tile(wtx, wtz)
	var cx: int = int(floor(float(wtx) / float(IsoConst.CHUNK_SIZE)))
	var cz: int = int(floor(float(wtz) / float(IsoConst.CHUNK_SIZE)))
	var key := Vector2i(cx, cz)
	if not _chunk_data_cache.has(key):
		_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk_data_only(cx, cz, WORLD_SEED)
	var lx: int = wtx - cx * IsoConst.CHUNK_SIZE
	var lz: int = wtz - cz * IsoConst.CHUNK_SIZE
	var chunk: RefCounted = _chunk_data_cache[key]
	return chunk.get_tile(lx, lz)

func _get_height_global(wtx: int, wtz: int) -> int:
	if not _is_infinite:
		return world_map.get_height(wtx, wtz)
	var cx: int = int(floor(float(wtx) / float(IsoConst.CHUNK_SIZE)))
	var cz: int = int(floor(float(wtz) / float(IsoConst.CHUNK_SIZE)))
	var key := Vector2i(cx, cz)
	if not _chunk_data_cache.has(key):
		_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk_data_only(cx, cz, WORLD_SEED)
	var lx: int = wtx - cx * IsoConst.CHUNK_SIZE
	var lz: int = wtz - cz * IsoConst.CHUNK_SIZE
	var chunk: RefCounted = _chunk_data_cache[key]
	return chunk.get_height(lx, lz)

# Compute terrain height at a world position using the shared smoothstep algorithm.
func get_terrain_height(wx: float, wz: float) -> float:
	if _is_infinite:
		# Use the same radii as ChunkRenderer so entity Y matches the rendered terrain
		return TerrainMath.get_height_at(wx, wz, get_tile_global, _get_height_global,
				ChunkRenderer.CURVE_R, HILL_PEAK_H, ChunkRenderer.WALL_CURVE_R)
	return TerrainMath.get_height_at(wx, wz, world_map.get_tile, world_map.get_height,
			HILL_RAMP_R, HILL_PEAK_H)

# Returns false if the chunk AABB is definitely outside the camera frustum.
# Uses the standard separating-plane test: if all 8 corners of the chunk's
# bounding box are on the outside of any single frustum plane, it's culled.
func _chunk_in_frustum(cx: int, cz: int, frustum: Array[Plane]) -> bool:
	var ws: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var x0: float = float(cx) * ws
	var z0: float = float(cz) * ws
	var x1: float = x0 + ws
	var z1: float = z0 + ws
	# Y range: -1 (below flat ground) to 16 (above tallest mountain/ruin peak)
	for plane: Plane in frustum:
		if (not plane.is_point_over(Vector3(x0, -1.0, z0)) and
			not plane.is_point_over(Vector3(x1, -1.0, z0)) and
			not plane.is_point_over(Vector3(x0, -1.0, z1)) and
			not plane.is_point_over(Vector3(x1, -1.0, z1)) and
			not plane.is_point_over(Vector3(x0, 16.0, z0)) and
			not plane.is_point_over(Vector3(x1, 16.0, z0)) and
			not plane.is_point_over(Vector3(x0, 16.0, z1)) and
			not plane.is_point_over(Vector3(x1, 16.0, z1))):
			return false
	return true

func _update_chunks() -> void:
	if _player == null:
		return

	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var pcx: int = int(floor(_player.position.x / chunk_world))
	var pcz: int = int(floor(_player.position.z / chunk_world))
	var player_chunk := Vector2i(pcx, pcz)

	var new_biome: int = InfiniteWorldGen.biome_for_chunk(pcx, pcz, WORLD_SEED)
	if new_biome != _current_biome:
		_current_biome = new_biome
		AudioManager.play_music(_BIOME_MUSIC[new_biome])
		SceneManager.save_manager.visit_biome(new_biome)
		WeatherManager.set_biome(new_biome)

	# Camera frustum for visibility culling. Falls back to load-all if unavailable.
	var frustum: Array[Plane] = _camera.get_frustum()

	# Movement lookahead direction (XZ plane, normalised; zero when standing still).
	var vel_xz: Vector2 = Vector2(_player.velocity.x, _player.velocity.z)
	var look_dir: Vector2 = vel_xz.normalized() if vel_xz.length_squared() > 0.25 else Vector2.ZERO

	# Queue chunks that are visible or in the movement lookahead cone.
	# Tile data for neighbours is ensured lazily in _kick_chunk_jobs before dispatch.
	for dz in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var key := Vector2i(pcx + dx, pcz + dz)
			if _chunk_renderers.has(key) or _chunk_queued.has(key):
				continue
			# Trim square to a circle (skip far corners of the grid)
			if dx * dx + dz * dz > LOAD_RADIUS * LOAD_RADIUS:
				continue
			# Always load the immediate 3×3 neighbourhood around the player
			if abs(dx) <= 1 and abs(dz) <= 1:
				_chunk_build_queue.append(key)
				_chunk_queued[key] = true
				continue
			# Load if visible in camera frustum (or no frustum available)
			if frustum.is_empty() or _chunk_in_frustum(key.x, key.y, frustum):
				_chunk_build_queue.append(key)
				_chunk_queued[key] = true
				continue
			# Load if inside the forward movement cone (~120° arc ahead)
			if look_dir.length_squared() > 0.1:
				var to_chunk := Vector2(float(dx), float(dz))
				if to_chunk.length_squared() > 0.0 and to_chunk.normalized().dot(look_dir) > 0.3:
					_chunk_build_queue.append(key)
					_chunk_queued[key] = true

	_chunk_queue_dirty = true  # queue contents changed — re-sort before next dispatch

	# 3. Unload chunks beyond UNLOAD_RADIUS (distance-based, not frustum,
	#    so chunks behind you stay loaded while you might still turn around)
	var keys_to_remove: Array[Vector2i] = []
	for raw_key in _chunk_renderers:
		var typed_key: Vector2i = raw_key
		if abs(typed_key.x - pcx) > UNLOAD_RADIUS or abs(typed_key.y - pcz) > UNLOAD_RADIUS:
			keys_to_remove.append(typed_key)

	for key in keys_to_remove:
		var renderer: ChunkRenderer = _chunk_renderers[key]
		renderer.teardown()
		_chunk_renderers.erase(key)
		var grass_node: GrassBlades = _grass as GrassBlades
		if grass_node:
			grass_node.remove_chunk(key)
		# Remove entities belonging to this chunk from the active sets
		var chunk: RefCounted = _chunk_data_cache[key]
		for e_data in chunk.enemies:
			var eid: String = str(e_data.get("id", ""))
			var enode: Node3D = _enemy_nodes.get(eid) as Node3D
			if is_instance_valid(enode):
				enode.queue_free()
			_enemy_nodes.erase(eid)
		for c_data in chunk.chests:
			var cid: String = str(c_data.get("id", ""))
			_active_chest_data.erase(cid)
			var cnode: Node3D = _chest_nodes.get(cid) as Node3D
			if is_instance_valid(cnode):
				cnode.queue_free()
			_chest_nodes.erase(cid)
		for d_data in chunk.doors:
			var did: String = str(d_data.get("id", ""))
			_active_door_data.erase(did)
			var dnode: Node3D = _door_nodes.get(did) as Node3D
			if is_instance_valid(dnode):
				dnode.queue_free()
			_door_nodes.erase(did)
		for n_data in chunk.npcs:
			var nid: String = str(n_data.get("id", ""))
			_active_npc_data.erase(nid)
			var nnode: Node3D = _npc_nodes.get(nid) as Node3D
			if is_instance_valid(nnode):
				nnode.queue_free()
			_npc_nodes.erase(nid)
		for w_data in chunk.waystones:
			var wid: String = str(w_data.get("id", ""))
			_active_waystone_data.erase(wid)
			var wnode: Node3D = _waystone_nodes.get(wid) as Node3D
			if is_instance_valid(wnode):
				wnode.queue_free()
			_waystone_nodes.erase(wid)

	# Evict chunk data cache entries far beyond the unload radius to bound memory.
	# Keep a margin beyond UNLOAD_RADIUS so neighbour tile lookups still hit cache.
	var cache_keys_to_remove: Array[Vector2i] = []
	for raw_key in _chunk_data_cache:
		var typed_key: Vector2i = raw_key
		if abs(typed_key.x - pcx) > CACHE_EVICT_RADIUS or abs(typed_key.y - pcz) > CACHE_EVICT_RADIUS:
			cache_keys_to_remove.append(typed_key)
	for key in cache_keys_to_remove:
		_chunk_data_cache.erase(key)

	_last_player_chunk = player_chunk

# ── Tile-grid snapshot helpers ─────────────────────────────────────────────

# Ensure 3×3 neighbourhood of chunk key has tile-only data in the cache.
# Fast: only noise for 16×16 tiles each, no mesh work.
func _ensure_tile_data_around(key: Vector2i) -> void:
	if not _is_infinite:
		return  # named map reads tiles directly from world_map
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var nkey := Vector2i(key.x + dx, key.y + dz)
			if not _chunk_data_cache.has(nkey):
				_chunk_data_cache[nkey] = InfiniteWorldGen.generate_chunk_data_only(nkey.x, nkey.y, WORLD_SEED)

# Build the packed tile-type grid needed by ChunkRenderer.prepare_terrain().
# Returns [tile_grid, grid_min_x, grid_min_z, grid_w].
func _snapshot_tile_grid_for(key: Vector2i) -> Array:
	const CHUNK_SIZE: int = 16
	const TILE_CHECK: int = ChunkRenderer.TILE_CHECK
	var chunk_origin_x: float = float(key.x * CHUNK_SIZE) * IsoConst.TILE_SIZE
	var chunk_origin_z: float = float(key.y * CHUNK_SIZE) * IsoConst.TILE_SIZE
	var base_tx: int = int(chunk_origin_x / IsoConst.TILE_SIZE)
	var base_tz: int = int(chunk_origin_z / IsoConst.TILE_SIZE)
	var grid_min_x: int = base_tx - TILE_CHECK
	var grid_min_z: int = base_tz - TILE_CHECK
	var grid_w: int = CHUNK_SIZE + TILE_CHECK * 2 + 1
	var grid_h: int = CHUNK_SIZE + TILE_CHECK * 2 + 1
	var tile_grid := PackedInt32Array()
	var height_grid := PackedInt32Array()
	tile_grid.resize(grid_w * grid_h)
	height_grid.resize(grid_w * grid_h)
	for gz in range(grid_h):
		for gx in range(grid_w):
			var idx: int = gz * grid_w + gx
			var wtx: int = grid_min_x + gx
			var wtz: int = grid_min_z + gz
			tile_grid[idx] = get_tile_global(wtx, wtz)
			height_grid[idx] = _get_height_global(wtx, wtz)
	return [tile_grid, height_grid, grid_min_x, grid_min_z, grid_w]

# ── Threaded chunk building ────────────────────────────────────────────────

# Worker-thread task: does the heavy CPU work (height field, packed arrays,
# ArrayMesh, HeightMapShape3D) without touching the scene tree.
func _chunk_prepare_task(key: Vector2i, chunk_data: RefCounted,
		tile_grid: PackedInt32Array, height_grid: PackedInt32Array,
		grid_min_x: int, grid_min_z: int, grid_w: int) -> void:
	var terrain_res: Dictionary = ChunkRenderer.prepare_terrain(
			chunk_data, tile_grid, height_grid, grid_min_x, grid_min_z, grid_w)
	_chunk_build_mutex.lock()
	_chunk_build_results.append({ "key": key, "chunk_data": chunk_data, "terrain_res": terrain_res })
	_chunk_build_mutex.unlock()

# Called every frame: kick off thread jobs for queued chunks up to MAX_CHUNK_JOBS.
func _kick_chunk_jobs() -> void:
	var pcx: int = _last_player_chunk.x
	var pcz: int = _last_player_chunk.y
	# Only sort when new items were added — skipped every frame when idle.
	if _chunk_queue_dirty and _chunk_build_queue.size() > 1:
		_chunk_build_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da: int = (a.x - pcx) * (a.x - pcx) + (a.y - pcz) * (a.y - pcz)
			var db: int = (b.x - pcx) * (b.x - pcx) + (b.y - pcz) * (b.y - pcz)
			return da < db
		)
		_chunk_queue_dirty = false

	var i: int = 0
	while i < _chunk_build_queue.size():
		if _chunk_data_pending.size() >= MAX_CHUNK_JOBS:
			break
		var key: Vector2i = _chunk_build_queue[i]
		if _chunk_renderers.has(key) or _chunk_data_pending.has(key):
			_chunk_build_queue.remove_at(i)
			_chunk_queued.erase(key)
			continue
		if abs(key.x - pcx) > LOAD_RADIUS or abs(key.y - pcz) > LOAD_RADIUS:
			_chunk_build_queue.remove_at(i)
			_chunk_queued.erase(key)
			continue

		# Ensure neighbour tile data exists (fast, sync) then snapshot for thread
		_ensure_tile_data_around(key)
		var snap := _snapshot_tile_grid_for(key)

		# Ensure full chunk data (entities) is ready before handing to thread
		if not _chunk_data_cache.has(key) or not _chunk_data_cache[key].has_entities:
			if _is_infinite:
				_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk(key.x, key.y, WORLD_SEED)
			else:
				_chunk_data_cache[key] = world_map.get_chunk_data(key.x, key.y)
		var chunk_data: RefCounted = _chunk_data_cache[key]

		_chunk_data_pending[key] = true
		_chunk_build_queue.remove_at(i)
		_chunk_queued.erase(key)
		var task_id: int = WorkerThreadPool.add_task(_chunk_prepare_task.bind(
				key, chunk_data, snap[0], snap[1], snap[2], snap[3], snap[4]))
		_chunk_task_ids.append(task_id)
		# don't increment i — next item shifted into position

# Called every frame: commit one ready result to the scene tree (cheap).
func _commit_chunk_results() -> void:
	_chunk_build_mutex.lock()
	if _chunk_build_results.is_empty():
		_chunk_build_mutex.unlock()
		return
	var result: Dictionary = _chunk_build_results.pop_front()
	_chunk_build_mutex.unlock()

	var key: Vector2i = result["key"]
	_chunk_data_pending.erase(key)

	# Discard if the chunk was unloaded or is now out of range
	if _chunk_renderers.has(key):
		return
	if abs(key.x - _last_player_chunk.x) > LOAD_RADIUS or abs(key.y - _last_player_chunk.y) > LOAD_RADIUS:
		return

	var chunk: RefCounted = result["chunk_data"]
	for c_data in chunk.chests:
		var cid: String = str(c_data.get("id", ""))
		_active_chest_data[cid] = c_data
	for d_data in chunk.doors:
		var did: String = str(d_data.get("id", ""))
		_active_door_data[did] = d_data
	for n_data in chunk.npcs:
		var nid: String = str(n_data.get("id", ""))
		_active_npc_data[nid] = n_data
	for w_data in chunk.waystones:
		var wid: String = str(w_data.get("id", ""))
		_active_waystone_data[wid] = w_data

	var renderer: ChunkRenderer = ChunkRenderer.new()
	renderer.name = "Chunk_%d_%d" % [key.x, key.y]
	add_child(renderer)
	renderer.build_visual(chunk, key, self, _terrain_mat, result["terrain_res"])
	_chunk_renderers[key] = renderer
	# Defer physics bodies to next frame to avoid a double-hitch (mesh + physics)
	_pending_physics.append(renderer)

# Synchronous build used at startup so the world is ready before first frame.
func _build_chunk_sync(key: Vector2i) -> void:
	if _chunk_renderers.has(key):
		return
	_ensure_tile_data_around(key)
	var snap := _snapshot_tile_grid_for(key)
	if not _chunk_data_cache.has(key) or not _chunk_data_cache[key].has_entities:
		if _is_infinite:
			_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk(key.x, key.y, WORLD_SEED)
		else:
			_chunk_data_cache[key] = world_map.get_chunk_data(key.x, key.y)
	var chunk: RefCounted = _chunk_data_cache[key]
	var terrain_res: Dictionary = ChunkRenderer.prepare_terrain(chunk, snap[0], snap[1], snap[2], snap[3], snap[4])
	for c_data in chunk.chests:
		var cid: String = str(c_data.get("id", ""))
		_active_chest_data[cid] = c_data
	for d_data in chunk.doors:
		var did: String = str(d_data.get("id", ""))
		_active_door_data[did] = d_data
	for n_data in chunk.npcs:
		var nid: String = str(n_data.get("id", ""))
		_active_npc_data[nid] = n_data
	for w_data in chunk.waystones:
		var wid: String = str(w_data.get("id", ""))
		_active_waystone_data[wid] = w_data
	var renderer: ChunkRenderer = ChunkRenderer.new()
	renderer.name = "Chunk_%d_%d" % [key.x, key.y]
	add_child(renderer)
	# Sync path (startup): build visual and physics together — slowness is acceptable here.
	renderer.build_visual(chunk, key, self, _terrain_mat, terrain_res)
	renderer.build_physics()
	_chunk_renderers[key] = renderer

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

func register_waystone(wid: String, node: Node3D, w_data: Dictionary) -> void:
	_waystone_nodes[wid] = node
	_active_waystone_data[wid] = w_data

func _find_nearby_waystone(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	for wid in _active_waystone_data:
		var w: Dictionary = _active_waystone_data[wid]
		if bool(w.get("active", false)):
			continue
		var ddx: float = float(w.get("x", 0.0)) - px
		var ddz: float = float(w.get("z", 0.0)) - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return w
	return {}

func _on_waystone_activated(waystone_id: String) -> void:
	var w_data: Dictionary = _active_waystone_data.get(waystone_id, {})
	var label: String = str(w_data.get("label", "Unknown"))
	SceneManager.show_toast("Waystone Activated", label)

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
			if not _chunk_data_cache.has(key):
				continue
			var chunk: RefCounted = _chunk_data_cache[key]
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
			if not _chunk_data_cache.has(key):
				continue
			var chunk: RefCounted = _chunk_data_cache[key]
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

# ── Day / Night cycle ──────────────────────────────────────────────────────

func _update_day_night(delta: float) -> void:
	var prev_time: float = _time_of_day
	_time_of_day = fmod(_time_of_day + delta / day_duration, 1.0)
	if _time_of_day < prev_time:
		SceneManager.save_manager.increment_day()

	# sun_angle: 0 at sunrise (t=0.25), PI/2 at noon (t=0.5), PI at sunset (t=0.75)
	var sun_angle: float = (_time_of_day - 0.25) * TAU
	_sun.rotation = Vector3(-sun_angle, 0.0, 0.0)
	_moon.rotation = Vector3(-(sun_angle + PI), 0.0, 0.0)

	# sin: 0 at horizons, 1 at noon, -1 at midnight
	var sun_h: float = sin(sun_angle)
	var t_day: float = clampf(sun_h * 2.0 + 0.1, 0.0, 1.0)
	var t_horizon: float = clampf(1.0 - abs(sun_h) * 5.0, 0.0, 1.0)

	# Sun: warm white at midday, orange at horizon, off at night
	var sun_energy: float = clampf(sun_h * 1.5, 0.0, 1.5)
	var sun_color: Color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.45, 0.1), t_horizon)

	if not is_equal_approx(sun_energy, _cached_sun_energy):
		_sun.light_energy = sun_energy
		_cached_sun_energy = sun_energy
	if not sun_color.is_equal_approx(_cached_sun_color):
		_sun.light_color = sun_color
		_cached_sun_color = sun_color

	# Moon: opposite hemisphere, cool blue
	var moon_h: float = -sun_h
	var moon_energy: float = clampf(moon_h * 0.35, 0.0, 0.35)
	if not is_equal_approx(moon_energy, _cached_moon_energy):
		_moon.light_energy = moon_energy
		_cached_moon_energy = moon_energy

	# Sky colour: deep blue day → orange horizon → near-black night
	var sky: Color
	if sun_h >= 0.0:
		sky = Color(0.7, 0.3, 0.1).lerp(Color(0.25, 0.5, 0.85), clampf(sun_h * 3.0, 0.0, 1.0))
	else:
		sky = Color(0.02, 0.02, 0.08).lerp(Color(0.7, 0.3, 0.1), clampf((sun_h + 0.3) * 5.0, 0.0, 1.0))
	if not sky.is_equal_approx(_cached_sky_color):
		_world_env.environment.background_color = sky
		_cached_sky_color = sky

	# Ambient: dark blue night → soft grey day, multiplied by weather tint
	var base_ambient: Color = Color(0.1, 0.12, 0.22).lerp(Color(0.6, 0.65, 0.7), t_day)
	var ambient_color: Color = Color(base_ambient.r * _weather_tint.r,
		base_ambient.g * _weather_tint.g,
		base_ambient.b * _weather_tint.b)
	var ambient_energy: float = lerpf(0.35, 1.0, t_day)
	if not ambient_color.is_equal_approx(_cached_ambient_color):
		_world_env.environment.ambient_light_color = ambient_color
		_cached_ambient_color = ambient_color
	if not is_equal_approx(ambient_energy, _cached_ambient_energy):
		_world_env.environment.ambient_light_energy = ambient_energy
		_cached_ambient_energy = ambient_energy

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
	_camera.position = _snap_to_pixel(_player.position + Vector3(20, 20, 20))
	if _minimap:
		_minimap.update()
	if _coord_label:
		var tx: int = int(_player.position.x / IsoConst.TILE_SIZE)
		var tz: int = int(_player.position.z / IsoConst.TILE_SIZE)
		_coord_label.text = "tile (%d, %d)" % [tx, tz]
	_day_night_timer += delta
	if _day_night_timer >= DAY_NIGHT_INTERVAL:
		_update_day_night(_day_night_timer)
		_day_night_timer = 0.0
	if _grass:
		_grass.update_player(_player.position, delta, _player.is_on_floor())

	# Lerp weather tint toward target and invalidate ambient cache to force GPU write
	if _weather_tint_lerp_t < 1.0:
		_weather_tint_lerp_t = minf(_weather_tint_lerp_t + delta * _WEATHER_TINT_SPEED, 1.0)
		_weather_tint = _weather_tint.lerp(_weather_tint_target, delta * _WEATHER_TINT_SPEED)
		_cached_ambient_color = Color.BLACK  # force re-write next lighting tick

	# Keep particle rig centred on the player
	if _active_weather_particles != null and is_instance_valid(_active_weather_particles):
		_active_weather_particles.position = _player.position + Vector3(0.0, 12.0, 0.0)

	if _dialogue_timer > 0.0:
		_dialogue_timer -= delta
		if _dialogue_timer <= 0.0:
			_dialogue_label.hide()
			GameBus.dialogue_state_changed.emit(false)

	if _tip_timer > 0.0:
		_tip_timer -= delta
		if _tip_timer <= 0.0:
			_tip_label.hide()

	if _is_infinite:
		_tick_roaming_boss(delta)
		_tick_traveling_merchant(delta)
		_tick_card_shower()
		var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
		var pcx: int = int(floor(_player.position.x / chunk_world))
		var pcz: int = int(floor(_player.position.z / chunk_world))
		var needs_update: bool = Vector2i(pcx, pcz) != _last_player_chunk
		# Also re-evaluate when movement direction turns significantly —
		# new chunks may have entered the forward cone or become visible.
		if not needs_update:
			var vel_xz: Vector2 = Vector2(_player.velocity.x, _player.velocity.z)
			if vel_xz.length_squared() > 0.25:
				var new_dir: Vector2 = vel_xz.normalized()
				if new_dir.dot(_last_move_dir) < 0.7:  # > ~45° turn
					# Throttle: direction changes trigger at most twice per second to avoid
					# re-running the 169-chunk frustum scan every frame while turning.
					var now: float = Time.get_ticks_msec() * 0.001
					if now - _last_dir_update_time >= 0.5:
						needs_update = true
						_last_move_dir = new_dir
						_last_dir_update_time = now
		if needs_update:
			_update_chunks()
		# Dispatch thread jobs for queued chunks, commit completed results
		_kick_chunk_jobs()
		_commit_chunk_results()
		# Build physics for one deferred chunk per frame (spreads the hitch)
		if not _pending_physics.is_empty():
			var r: ChunkRenderer = _pending_physics.pop_front() as ChunkRenderer
			if is_instance_valid(r):
				r.build_physics()

	# Only update save position when player moves > 1 unit (not every frame)
	var cur_pos := Vector2(_player.position.x, _player.position.z)
	if cur_pos.distance_squared_to(_last_save_pos) > 1.0:
		_last_save_pos = cur_pos
		SceneManager.save_manager.update_position(map_name, _player.position.x, _player.position.z)

	# Throttle interaction checks — no need to scan every frame
	_interact_timer += delta
	if _interact_timer >= INTERACT_INTERVAL:
		_interact_timer = 0.0
		_check_interactions()

	if Input.is_action_just_pressed("interact"):
		_handle_interact()

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
	if enemy != null or not chest.is_empty() or not door.is_empty() or not npc.is_empty() or scroll != null or shrine != null or digspot != null or not waystone.is_empty():
		if _interact_btn != null:
			_interact_btn.show()
		else:
			_interact_label.show()
	else:
		_interact_label.hide()
		if _interact_btn != null:
			_interact_btn.hide()

	var is_android: bool = OS.has_feature("android")
	if not npc.is_empty() and not SceneManager.save_manager.get_story_flag("tutorial_npc_tip"):
		SceneManager.save_manager.set_story_flag("tutorial_npc_tip")
		_show_tip("Tap to talk" if is_android else "Press E to talk to NPCs")
	elif not chest.is_empty() and not SceneManager.save_manager.get_story_flag("tutorial_chest_tip"):
		SceneManager.save_manager.set_story_flag("tutorial_chest_tip")
		_show_tip("Tap to open chests" if is_android else "Press E to open chests")
	elif enemy != null and not SceneManager.save_manager.get_story_flag("tutorial_enemy_tip"):
		SceneManager.save_manager.set_story_flag("tutorial_enemy_tip")
		_show_tip("Walk into an enemy to start a battle")

func _open_map_view() -> void:
	if _is_infinite:
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_view"):
		_open_map_view()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		GameBus.inventory_requested.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_J:
		GameBus.journal_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("character"):
		GameBus.character_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_tree"):
		GameBus.skill_tree_requested.emit()
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
		enemy.engage()
		return

	var chest := _find_nearby_chest(px, pz, IsoConst.INTERACT_RANGE)
	if not chest.is_empty() and not chest.get("opened", false):
		chest["opened"] = true
		AudioManager.play_sfx("chest_open")
		var cid: String = str(chest.get("id", ""))
		SceneManager.save_manager.mark_chest_opened(cid)
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
		if str(npc.get("npc_type", "")) == "duelist":
			_show_duel_offer_panel(npc)
			return
		if str(npc.get("npc_type", "")) == "rest_site":
			_show_rest_site_panel(npc)
			return
		if str(npc.get("npc_type", "")) == "event_room":
			_show_event_panel(npc)
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

	var waystone := _find_nearby_waystone(px, pz, IsoConst.INTERACT_RANGE)
	if not waystone.is_empty():
		var wid: String = str(waystone.get("id", ""))
		var wnode := _waystone_nodes.get(wid) as Node3D
		if wnode != null and wnode.has_method("mark_activated"):
			wnode.mark_activated()

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

# ── Dialogue ───────────────────────────────────────────────────────────────

func _show_dialogue(text: String) -> void:
	_dialogue_label.text = text
	_dialogue_label.show()
	_dialogue_timer = DIALOGUE_DURATION
	GameBus.dialogue_state_changed.emit(true)

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
	_tip_label.text = text
	_tip_label.show()
	_tip_timer = TIP_DURATION

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

	var owned_w: Array[String] = sm.owned_weapons
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

# ── Dungeon room overlays (TID-090/091/092) ────────────────────────────────

func _show_rest_site_panel(npc_data: Dictionary) -> void:
	var room_key: String = str(npc_data.get("after_dialogue", ""))
	if SceneManager.save_manager.is_dungeon_room_used(room_key):
		_show_dialogue("This rest site has already been used.")
		return

	var vh: float = get_viewport().get_visible_rect().size.y
	var vw: float = get_viewport().get_visible_rect().size.x
	var font_size: int = int(vh * 0.03)
	var btn_h: float = vh * 0.07

	var panel := PanelContainer.new()
	panel.position = Vector2(vw * 0.2, vh * 0.2)
	panel.custom_minimum_size = Vector2(vw * 0.6, vh * 0.5)
	_hud.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.015))
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Rest Site"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(vh * 0.05))
	vbox.add_child(title)

	var hp_label := Label.new()
	hp_label.text = "Hero HP: %d / 30" % _dungeon_hero_hp
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", font_size)
	vbox.add_child(hp_label)

	var rest_btn := Button.new()
	rest_btn.text = "Rest — Recover 8 HP"
	rest_btn.custom_minimum_size = Vector2(0, btn_h)
	rest_btn.add_theme_font_size_override("font_size", font_size)
	rest_btn.disabled = _dungeon_hero_hp >= 30
	if rest_btn.disabled:
		rest_btn.tooltip_text = "Already at full health"
	vbox.add_child(rest_btn)

	var cull_btn := Button.new()
	cull_btn.text = "Cull — Remove a card from deck"
	cull_btn.custom_minimum_size = Vector2(0, btn_h)
	cull_btn.add_theme_font_size_override("font_size", font_size)
	cull_btn.disabled = SceneManager.save_manager.player_deck.size() < 2
	vbox.add_child(cull_btn)

	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(0, btn_h)
	leave_btn.add_theme_font_size_override("font_size", font_size)
	vbox.add_child(leave_btn)

	rest_btn.pressed.connect(func() -> void:
		_dungeon_hero_hp = mini(_dungeon_hero_hp + 8, 30)
		SceneManager.save_manager.mark_dungeon_room_used(room_key)
		panel.queue_free()
		_show_dialogue("You rest and recover. Hero HP: %d / 30" % _dungeon_hero_hp)
	)
	cull_btn.pressed.connect(func() -> void:
		panel.queue_free()
		SceneManager.save_manager.mark_dungeon_room_used(room_key)
		_show_cull_panel()
	)
	leave_btn.pressed.connect(func() -> void: panel.queue_free())


func _show_cull_panel() -> void:
	var vh: float = get_viewport().get_visible_rect().size.y
	var vw: float = get_viewport().get_visible_rect().size.x
	var font_size: int = int(vh * 0.03)
	var btn_h: float = vh * 0.065

	var panel := PanelContainer.new()
	panel.position = Vector2(vw * 0.1, vh * 0.1)
	panel.custom_minimum_size = Vector2(vw * 0.8, vh * 0.75)
	_hud.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.01))
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Choose a card to remove from your deck:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", font_size)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, vh * 0.55)
	vbox.add_child(scroll)

	var card_list := VBoxContainer.new()
	card_list.add_theme_constant_override("separation", int(vh * 0.008))
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card_list)

	var deck_copy: Array[String] = []
	deck_copy.assign(SceneManager.save_manager.player_deck)

	for ci in range(deck_copy.size()):
		var cid: String = deck_copy[ci]
		var inst: Dictionary = SceneManager.save_manager.get_instance_by_uid(cid)
		var display_name: String = str(inst.get("template_id", cid)).capitalize().replace("_", " ") if not inst.is_empty() else cid.capitalize().replace("_", " ")
		var btn := Button.new()
		btn.text = display_name
		btn.custom_minimum_size = Vector2(0, btn_h)
		btn.add_theme_font_size_override("font_size", font_size)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_list.add_child(btn)
		btn.pressed.connect(func() -> void:
			var new_deck: Array[String] = []
			var removed_once: bool = false
			for deck_card: String in SceneManager.save_manager.player_deck:
				if not removed_once and deck_card == cid:
					removed_once = true
				else:
					new_deck.append(deck_card)
			SceneManager.save_manager.set_active_deck(new_deck)
			panel.queue_free()
			_show_dialogue("Removed %s from your deck." % display_name)
		)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(0, btn_h)
	cancel_btn.add_theme_font_size_override("font_size", font_size)
	vbox.add_child(cancel_btn)
	cancel_btn.pressed.connect(func() -> void: panel.queue_free())


func _show_event_panel(npc_data: Dictionary) -> void:
	var room_key: String = str(npc_data.get("after_dialogue", ""))
	if SceneManager.save_manager.is_dungeon_room_used(room_key):
		_show_dialogue("The event here has already passed.")
		return

	var file := FileAccess.open("res://data/dungeon_events.json", FileAccess.READ)
	if not file:
		_show_dialogue("Nothing of interest here.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Array):
		_show_dialogue("Nothing of interest here.")
		return
	var events: Array = parsed
	if events.is_empty():
		_show_dialogue("Nothing of interest here.")
		return

	var event_rng := RandomNumberGenerator.new()
	event_rng.seed = room_key.hash()
	var event_idx: int = event_rng.randi() % events.size()
	var event: Dictionary = events[event_idx]

	var vh: float = get_viewport().get_visible_rect().size.y
	var vw: float = get_viewport().get_visible_rect().size.x
	var font_size: int = int(vh * 0.03)
	var btn_h: float = vh * 0.07

	var panel := PanelContainer.new()
	panel.position = Vector2(vw * 0.1, vh * 0.15)
	panel.custom_minimum_size = Vector2(vw * 0.8, vh * 0.65)
	_hud.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.015))
	panel.add_child(vbox)

	var event_text := Label.new()
	event_text.text = str(event.get("text", "Something happens."))
	event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_text.add_theme_font_size_override("font_size", font_size)
	vbox.add_child(event_text)

	var choices: Array = event.get("choices", [])
	for choice_idx in range(choices.size()):
		var choice: Dictionary = choices[choice_idx]
		if not (choice is Dictionary):
			continue
		var captured: Dictionary = choice
		var btn := Button.new()
		btn.text = str(captured.get("label", "Choose"))
		btn.custom_minimum_size = Vector2(0, btn_h)
		btn.add_theme_font_size_override("font_size", font_size)
		vbox.add_child(btn)
		btn.pressed.connect(func() -> void:
			panel.queue_free()
			SceneManager.save_manager.mark_dungeon_room_used(room_key)
			_apply_event_outcome(captured)
		)


func _apply_event_outcome(choice: Dictionary) -> void:
	var outcome_type: String = str(choice.get("outcome_type", "nothing"))
	var outcome_value: int = int(choice.get("outcome_value", 0))
	var outcome_text: String = str(choice.get("outcome_text", ""))
	var card_pool: Array[String] = ["ghost", "skeleton", "zombie", "ghoul"]

	match outcome_type:
		"gain_coins":
			SceneManager.save_manager.add_coins(outcome_value)
		"lose_hp":
			_dungeon_hero_hp = maxi(_dungeon_hero_hp - outcome_value, 1)
		"gain_card":
			var picked: String = card_pool[randi() % card_pool.size()]
			var new_cards: Array[String] = [picked]
			SceneManager.save_manager.add_cards_to_deck(new_cards)
			outcome_text += (" (Received: %s)" % picked) if not outcome_text.is_empty() else "Received: %s" % picked
		"lose_card":
			if not SceneManager.save_manager.player_deck.is_empty():
				var removed_uid: String = SceneManager.save_manager.player_deck[-1]
				var removed_inst: Dictionary = SceneManager.save_manager.get_instance_by_uid(removed_uid)
				var removed_name: String = str(removed_inst.get("template_id", removed_uid)).capitalize().replace("_", " ") if not removed_inst.is_empty() else removed_uid
				var trimmed: Array[String] = []
				trimmed.assign(SceneManager.save_manager.player_deck)
				trimmed.pop_back()
				SceneManager.save_manager.set_active_deck(trimmed)
				outcome_text += (" (Lost: %s)" % removed_name) if not outcome_text.is_empty() else "Lost: %s" % removed_name
		"lose_hp_gain_card":
			_dungeon_hero_hp = maxi(_dungeon_hero_hp - outcome_value, 1)
			var picked: String = card_pool[randi() % card_pool.size()]
			var new_cards: Array[String] = [picked]
			SceneManager.save_manager.add_cards_to_deck(new_cards)
			outcome_text += (" (Received: %s)" % picked) if not outcome_text.is_empty() else "Received: %s" % picked
		"gain_coins_lose_hp":
			SceneManager.save_manager.add_coins(outcome_value)
			_dungeon_hero_hp = maxi(_dungeon_hero_hp - 3, 1)
		"lose_coins_gain_card":
			if SceneManager.save_manager.coins >= outcome_value:
				SceneManager.save_manager.add_coins(-outcome_value)
				var picked: String = card_pool[randi() % card_pool.size()]
				var new_cards: Array[String] = [picked]
				SceneManager.save_manager.add_cards_to_deck(new_cards)
				outcome_text += (" (Received: %s)" % picked) if not outcome_text.is_empty() else "Received: %s" % picked
			else:
				outcome_text = "Not enough coins!"

	if not outcome_text.is_empty():
		_show_dialogue(outcome_text)

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
