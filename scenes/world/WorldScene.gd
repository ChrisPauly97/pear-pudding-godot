extends Node3D

const WorldMap        = preload("res://game_logic/world/WorldMap.gd")
const DungeonGen      = preload("res://game_logic/world/DungeonGen.gd")
const GrassBlades     = preload("res://scenes/world/GrassBlades.gd")
const VirtualJoystick = preload("res://scenes/ui/VirtualJoystick.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const ChunkRenderer   = preload("res://scenes/world/ChunkRenderer.gd")
const TerrainMath     = preload("res://game_logic/TerrainMath.gd")
const Minimap         = preload("res://scenes/world/Minimap.gd")
const MapViewOverlay  = preload("res://scenes/ui/MapViewOverlay.gd")
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
var _tile_meshes: Node3D
var _wall_meshes: Node3D
var _entity_root: Node3D

# Chunk streaming (both infinite and named-map paths use ChunkRenderer)
var _chunk_data_cache: Dictionary = {}    # Vector2i -> ChunkData (RefCounted)
var _chunk_renderers: Dictionary = {}     # Vector2i -> ChunkRenderer
var _active_chest_data: Dictionary = {}  # chest_id -> Dictionary
var _active_door_data: Dictionary = {}   # door_id -> Dictionary
var _active_npc_data: Dictionary = {}    # npc_id -> Dictionary
var _last_player_chunk: Vector2i = Vector2i(-9999, -9999)
var _last_move_dir: Vector2 = Vector2.ZERO
var _terrain_mat: ShaderMaterial
var _chunk_build_queue: Array[Vector2i] = []
var _last_save_pos: Vector2 = Vector2(-9999, -9999)
var _interact_timer: float = 0.0

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
var _map_overlay: Node = null
var _dialogue_timer: float = 0.0
const DIALOGUE_DURATION: float = 4.0

var _tip_label: Label
var _tip_timer: float = 0.0
const TIP_DURATION: float = 5.0

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
			world_map = DungeonGen.generate(map_name, dseed)
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
	_map_label.add_theme_font_size_override("font_size", font_size)
	_coin_label.add_theme_font_size_override("font_size", font_size)
	_interact_label.add_theme_font_size_override("font_size", font_size)

	var menu_btn := Button.new()
	menu_btn.text = "Menu"
	menu_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	menu_btn.position = Vector2(vh * 0.01, vh * 0.01)
	menu_btn.add_theme_font_size_override("font_size", font_size)
	menu_btn.pressed.connect(func() -> void: SceneManager.go_to_menu())
	_hud.add_child(menu_btn)

	var inv_btn := Button.new()
	inv_btn.text = "Inventory"
	inv_btn.custom_minimum_size = Vector2(btn_w * 1.3, btn_h)
	inv_btn.position = Vector2(vw - btn_w * 1.3 - vh * 0.01, vh * 0.01)
	inv_btn.add_theme_font_size_override("font_size", font_size)
	inv_btn.pressed.connect(func() -> void: GameBus.inventory_requested.emit())
	_hud.add_child(inv_btn)

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

	if not SaveManager.get_story_flag("tutorial_inventory_tip"):
		SaveManager.set_story_flag("tutorial_inventory_tip")
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

func _exit_tree() -> void:
	# Wait for any in-flight worker tasks before the GDScript instance is freed.
	# Without this, WorkerThreadPool holds a Callable referencing this object and
	# crashes on shutdown when it tries to clean up while the instance is gone.
	for task_id: int in _chunk_task_ids:
		WorkerThreadPool.wait_for_task_completion(task_id)
	_chunk_task_ids.clear()

func flush_time_of_day() -> void:
	SceneManager.save_manager.time_of_day = _time_of_day

func _update_hud() -> void:
	if _is_infinite:
		_map_label.text = "World: Infinite"
	else:
		_map_label.text = "Map: %s" % map_name
	_coin_label.text = "Coins: %d" % SceneManager.save_manager.coins
	SceneManager.save_manager.coins_changed.connect(func(n: int) -> void: _coin_label.text = "Coins: %d" % n)

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
		if fk != "" and not SaveManager.get_story_flag(fk):
			continue
		var ddx: float = float(d.get("x", 0.0)) - px
		var ddz: float = float(d.get("z", 0.0)) - pz
		var dist_sq: float = ddx * ddx + ddz * ddz
		if dist_sq <= range_sq and dist_sq < best_dist_sq:
			best = d
			best_dist_sq = dist_sq
	return best

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

	# Ambient: dark blue night → soft grey day
	var ambient_color: Color = Color(0.1, 0.12, 0.22).lerp(Color(0.6, 0.65, 0.7), t_day)
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

	if _dialogue_timer > 0.0:
		_dialogue_timer -= delta
		if _dialogue_timer <= 0.0:
			_dialogue_label.hide()

	if _tip_timer > 0.0:
		_tip_timer -= delta
		if _tip_timer <= 0.0:
			_tip_label.hide()

	if _is_infinite:
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
	if enemy != null or not chest.is_empty() or not door.is_empty() or not npc.is_empty() or scroll != null:
		_interact_label.show()
	else:
		_interact_label.hide()

	var is_android: bool = OS.has_feature("android")
	if not npc.is_empty() and not SaveManager.get_story_flag("tutorial_npc_tip"):
		SaveManager.set_story_flag("tutorial_npc_tip")
		_show_tip("Tap to talk" if is_android else "Press E to talk to NPCs")
	elif not chest.is_empty() and not SaveManager.get_story_flag("tutorial_chest_tip"):
		SaveManager.set_story_flag("tutorial_chest_tip")
		_show_tip("Tap to open chests" if is_android else "Press E to open chests")
	elif enemy != null and not SaveManager.get_story_flag("tutorial_enemy_tip"):
		SaveManager.set_story_flag("tutorial_enemy_tip")
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
		_enemy_nodes, _chest_nodes, _door_nodes)
	_map_overlay.closed.connect(func() -> void: _map_overlay = null)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_view"):
		_open_map_view()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		GameBus.inventory_requested.emit()
		get_viewport().set_input_as_handled()

func _handle_interact() -> void:
	if _player == null:
		return
	var px: float = _player.position.x
	var pz: float = _player.position.z

	var door := _find_nearby_door(px, pz, IsoConst.INTERACT_RANGE * 2.0)
	if not door.is_empty():
		var target_map: String = door.get("target_map", "")
		var tdoor: String = door.get("target_door_id", "")
		AudioManager.play_sfx("door_enter")
		if target_map.is_empty():
			SceneManager.exit_map()
		else:
			if SaveManager.current_map == "madrian" and target_map == "maykalene":
				SaveManager.set_story_flag("chapter1_left_madrian")
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
		var node := _chest_nodes.get(cid) as Node3D
		if node and node.has_method("mark_opened"):
			node.mark_opened()
		var chest_pos := Vector3(float(chest.get("x", px)), get_terrain_height(float(chest.get("x", px)), float(chest.get("z", pz))) + 0.25, float(chest.get("z", pz)))
		var chest_card_ids: Array[String] = []
		chest_card_ids.assign(chest.get("card_ids", []))
		_spawn_card_items(chest_card_ids, chest_pos)
		_spawn_coin_piles(chest_pos)
		return

	var npc := _find_nearby_npc(px, pz, IsoConst.INTERACT_RANGE)
	if not npc.is_empty():
		if str(npc.get("npc_type", "")) == "merchant":
			GameBus.shop_requested.emit()
			return
		var nid: String = str(npc.get("id", ""))
		var nnode := _npc_nodes.get(nid) as Node3D
		var dlg: String
		if nnode != null and nnode.has_method("get_dialogue"):
			dlg = nnode.get_dialogue()
			var fk: String = str(npc.get("flag_key", ""))
			if fk != "":
				SaveManager.set_story_flag(fk)
		else:
			dlg = str(npc.get("dialogue", "..."))
		_show_dialogue(dlg)
		return

	var scroll := _find_nearby_scroll(px, pz, IsoConst.INTERACT_RANGE)
	if scroll != null and scroll.has_method("interact"):
		scroll.interact()

# ── Dialogue ───────────────────────────────────────────────────────────────

func _show_dialogue(text: String) -> void:
	_dialogue_label.text = text
	_dialogue_label.show()
	_dialogue_timer = DIALOGUE_DURATION

func _show_tip(text: String) -> void:
	_tip_label.text = text
	_tip_label.show()
	_tip_timer = TIP_DURATION

# ── Card item spawning ──────────────────────────────────────────────────────

func _spawn_card_items(card_ids: Array[String], origin: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	for i: int in range(card_ids.size()):
		var cid: String = str(card_ids[i])
		var angle: float = (float(i) / float(max(card_ids.size(), 1))) * TAU + rng.randf_range(-0.4, 0.4)
		var dist: float = rng.randf_range(1.0, 1.8)
		var land_pos := origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var item: Node3D = _WorldItemScene.instantiate()
		_entity_root.add_child(item)
		if item.has_method("setup"):
			item.setup(cid, origin, land_pos)

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
