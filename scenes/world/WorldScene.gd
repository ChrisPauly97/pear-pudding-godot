extends Node3D

const WorldMap        = preload("res://game_logic/world/WorldMap.gd")
const GrassBlades     = preload("res://scenes/world/GrassBlades.gd")
const VirtualJoystick = preload("res://scenes/ui/VirtualJoystick.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const ChunkRenderer   = preload("res://scenes/world/ChunkRenderer.gd")
const _TerrainShader: Shader = preload("res://assets/shaders/terrain.gdshader")

const _TexGrass:     Texture2D = preload("res://assets/textures/grass.png")
const _TexHillSide:  Texture2D = preload("res://assets/textures/hill_side.png")
const _TexHillTop:   Texture2D = preload("res://assets/textures/hill_top.png")
const _TexWallTop:   Texture2D = preload("res://assets/textures/wall_top.png")
const _TexWallLeft:  Texture2D = preload("res://assets/textures/wall_side_left.png")
const _TexWallRight: Texture2D = preload("res://assets/textures/wall_side_right.png")

# Preload entity scenes — avoids filesystem hits during spawning
const _PlayerScene    = preload("res://scenes/world/entities/Player.tscn")
const _EnemyScene     = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _ChestScene     = preload("res://scenes/world/entities/Chest.tscn")
const _DoorScene      = preload("res://scenes/world/entities/Door.tscn")
const _WorldItemScene = preload("res://scenes/world/entities/WorldItem.tscn")

@export var map_name: String = "main"
@export var target_door_id: String = ""
@export var infinite: bool = true

# Named-map path
var world_map: WorldMap

# Common
var _player: CharacterBody3D
var _grass: Node3D
var _enemy_nodes: Dictionary = {}   # id -> Node3D
var _chest_nodes: Dictionary = {}   # id -> Node3D
var _door_nodes: Dictionary = {}    # id -> Node3D
var _tile_meshes: Node3D
var _wall_meshes: Node3D
var _entity_root: Node3D

# Infinite-world path
var _chunk_data_cache: Dictionary = {}    # Vector2i -> ChunkData (RefCounted)
var _chunk_renderers: Dictionary = {}     # Vector2i -> ChunkRenderer
var _active_chest_data: Dictionary = {}  # chest_id -> Dictionary
var _last_player_chunk: Vector2i = Vector2i(-9999, -9999)
var _last_move_dir: Vector2 = Vector2.ZERO
var _terrain_mat: ShaderMaterial
var _chunk_build_queue: Array[Vector2i] = []
var _last_save_pos: Vector2 = Vector2(-9999, -9999)
var _interact_timer: float = 0.0

# Day/night cycle
var _world_env: WorldEnvironment
@export var day_duration: float = 600.0   # seconds per full day
var _time_of_day: float = 0.4             # 0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset
var _day_night_timer: float = 0.0
const DAY_NIGHT_INTERVAL: float = 0.5     # update lighting at 2 Hz

# Threaded chunk building
var _chunk_data_pending: Dictionary = {}    # Vector2i -> true (job in flight)
var _chunk_build_results: Array = []        # completed terrain prep, waiting for commit
var _chunk_build_mutex: Mutex = Mutex.new()

const LOAD_RADIUS:        int = 6
const UNLOAD_RADIUS:      int = 7
const WORLD_SEED:         int = 42
const MAX_CHUNK_JOBS:     int = 4   # concurrent WorkerThreadPool tasks
const INTERACT_INTERVAL: float = 0.15  # check interactions at ~7 Hz, not 60

@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD
@onready var _interact_label: Label = $HUD/InteractPrompt
@onready var _map_label: Label = $HUD/MapLabel
@onready var _sun: DirectionalLight3D = $DirectionalLight3D
@onready var _moon: DirectionalLight3D = $MoonLight

const WALL_FACE_H: float = 1.0

# Terrain height constants
const HILL_PEAK_H:    float = 1.5
const HILL_RAMP_R:    float = 6.0
const TERRAIN_VDENSITY: int = 2

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.5, 0.85)   # daytime sky; updated every frame
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.45, 0.5)
	env.ambient_light_energy = 0.7
	_world_env = WorldEnvironment.new()
	_world_env.environment = env
	add_child(_world_env)

func _ready() -> void:
	_setup_environment()
	_tile_meshes = Node3D.new()
	_tile_meshes.name = "TileGrid"
	add_child(_tile_meshes)
	_wall_meshes = Node3D.new()
	_wall_meshes.name = "WallGrid"
	add_child(_wall_meshes)
	_entity_root = Node3D.new()
	_entity_root.name = "Entities"
	add_child(_entity_root)

	if infinite:
		_terrain_mat = _make_terrain_material(WORLD_SEED)
		_build_grass_blades_node()
		_spawn_player_infinite()
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
		world_map = WorldMap.new(map_name)
		_build_terrain()
		_build_walls()
		_build_grass_blades()
		_spawn_entities()
		_spawn_player()

	_update_hud()

	# Re-enter any battle that was interrupted (e.g. app quit mid-fight)
	if not SaveManager.pending_battle_enemy_data.is_empty():
		GameBus.enemy_engaged.emit.call_deferred(SaveManager.pending_battle_enemy_data)
	_interact_label.hide()

	var joystick := VirtualJoystick.new()
	_hud.add_child(joystick)

	var vh: float = get_viewport().get_visible_rect().size.y
	var menu_btn := Button.new()
	menu_btn.text = "Menu"
	menu_btn.custom_minimum_size = Vector2(vh * 0.12, vh * 0.05)
	menu_btn.position = Vector2(vh * 0.01, vh * 0.01)
	menu_btn.pressed.connect(func() -> void: SceneManager.go_to_menu())
	_hud.add_child(menu_btn)

func _update_hud() -> void:
	if infinite:
		_map_label.text = "World: Infinite"
	else:
		_map_label.text = "Map: %s" % map_name

# ── Infinite world: chunk streaming ────────────────────────────────────────

func _build_grass_blades_node() -> void:
	_grass = GrassBlades.new()
	_grass.name = "GrassBlades"
	add_child(_grass)

func _spawn_player_infinite() -> void:
	var px: float = 3.0 * IsoConst.TILE_SIZE
	var pz: float = 3.0 * IsoConst.TILE_SIZE
	if SaveManager.current_map == "infinite" and (SaveManager.player_x != 0.0 or SaveManager.player_z != 0.0):
		px = SaveManager.player_x
		pz = SaveManager.player_z
	_player = _create_player_node()
	_player.position = Vector3(px, get_terrain_height(px, pz) + 0.5, pz)
	_entity_root.add_child(_player)
	_camera.position = _player.position + Vector3(20, 20, 20)

# Returns the tile type at global tile coordinates (wtx, wtz).
# Used by ChunkRenderer during terrain height computation so hills blend
# seamlessly across chunk borders.
func get_tile_global(wtx: int, wtz: int) -> int:
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
	var cx: int = int(floor(float(wtx) / float(IsoConst.CHUNK_SIZE)))
	var cz: int = int(floor(float(wtz) / float(IsoConst.CHUNK_SIZE)))
	var key := Vector2i(cx, cz)
	if not _chunk_data_cache.has(key):
		_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk_data_only(cx, cz, WORLD_SEED)
	var lx: int = wtx - cx * IsoConst.CHUNK_SIZE
	var lz: int = wtz - cz * IsoConst.CHUNK_SIZE
	var chunk: RefCounted = _chunk_data_cache[key]
	return chunk.get_height(lx, lz)

# Compute terrain height at a world position using the same smoothstep
# algorithm as the mesh builder.  Used for entity placement and physics.
func get_terrain_height(wx: float, wz: float) -> float:
	var curve_r: float = HILL_RAMP_R if not infinite else 3.0
	var peak_h: float = HILL_PEAK_H
	var tile_check: int = int(ceil(curve_r / IsoConst.TILE_SIZE)) + 1
	var vtx: int = int(wx / IsoConst.TILE_SIZE)
	var vtz: int = int(wz / IsoConst.TILE_SIZE)
	var curve_r_sq: float = curve_r * curve_r
	var min_dist_sq: float = curve_r_sq
	for dtz in range(-tile_check, tile_check + 1):
		for dtx in range(-tile_check, tile_check + 1):
			var ttx: int = vtx + dtx
			var ttz: int = vtz + dtz
			var tile_type: int
			if infinite:
				tile_type = get_tile_global(ttx, ttz)
			else:
				tile_type = world_map.get_tile(ttx, ttz)
			if tile_type != IsoConst.TILE_HILL:
				continue
			var near_x: float = clamp(wx, float(ttx) * IsoConst.TILE_SIZE, float(ttx + 1) * IsoConst.TILE_SIZE)
			var near_z: float = clamp(wz, float(ttz) * IsoConst.TILE_SIZE, float(ttz + 1) * IsoConst.TILE_SIZE)
			var ddx: float = wx - near_x
			var ddz: float = wz - near_z
			var dist_sq: float = ddx * ddx + ddz * ddz
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
	var t: float = 1.0 - sqrt(min_dist_sq) / curve_r
	t = t * t * (3.0 - 2.0 * t)
	var base_h: float = peak_h * t

	# If standing on a wall tile, add the wall block height so entities
	# are placed on top of the block, not clipped inside it.
	var tile_at: int = get_tile_global(vtx, vtz) if infinite else world_map.get_tile(vtx, vtz)
	if tile_at == IsoConst.TILE_WALL:
		var wh: int = _get_height_global(vtx, vtz) if infinite else world_map.get_height(vtx, vtz)
		base_h += float(maxi(1, wh)) * WALL_FACE_H

	return base_h

# Returns false if the chunk AABB is definitely outside the camera frustum.
# Uses the standard separating-plane test: if all 8 corners of the chunk's
# bounding box are on the outside of any single frustum plane, it's culled.
func _chunk_in_frustum(cx: int, cz: int, frustum: Array[Plane]) -> bool:
	var ws: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var x0: float = float(cx) * ws
	var z0: float = float(cz) * ws
	var x1: float = x0 + ws
	var z1: float = z0 + ws
	# Y range: -1 (below flat ground) to 3 (above hill + wall peak)
	for plane: Plane in frustum:
		if (not plane.is_point_over(Vector3(x0, -1.0, z0)) and
			not plane.is_point_over(Vector3(x1, -1.0, z0)) and
			not plane.is_point_over(Vector3(x0, -1.0, z1)) and
			not plane.is_point_over(Vector3(x1, -1.0, z1)) and
			not plane.is_point_over(Vector3(x0,  3.0, z0)) and
			not plane.is_point_over(Vector3(x1,  3.0, z0)) and
			not plane.is_point_over(Vector3(x0,  3.0, z1)) and
			not plane.is_point_over(Vector3(x1,  3.0, z1))):
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
			if _chunk_renderers.has(key) or _chunk_build_queue.has(key):
				continue
			# Trim square to a circle (skip far corners of the grid)
			if dx * dx + dz * dz > LOAD_RADIUS * LOAD_RADIUS:
				continue
			# Always load the immediate 3×3 neighbourhood around the player
			if abs(dx) <= 1 and abs(dz) <= 1:
				_chunk_build_queue.append(key)
				continue
			# Load if visible in camera frustum (or no frustum available)
			if frustum.is_empty() or _chunk_in_frustum(key.x, key.y, frustum):
				_chunk_build_queue.append(key)
				continue
			# Load if inside the forward movement cone (~120° arc ahead)
			if look_dir.length_squared() > 0.1:
				var to_chunk := Vector2(float(dx), float(dz))
				if to_chunk.length_squared() > 0.0 and to_chunk.normalized().dot(look_dir) > 0.3:
					_chunk_build_queue.append(key)

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

	_last_player_chunk = player_chunk

# ── Tile-grid snapshot helpers ─────────────────────────────────────────────

# Ensure 3×3 neighbourhood of chunk key has tile-only data in the cache.
# Fast: only noise for 16×16 tiles each, no mesh work.
func _ensure_tile_data_around(key: Vector2i) -> void:
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
	tile_grid.resize(grid_w * grid_h)
	for gz in range(grid_h):
		for gx in range(grid_w):
			tile_grid[gz * grid_w + gx] = get_tile_global(grid_min_x + gx, grid_min_z + gz)
	return [tile_grid, grid_min_x, grid_min_z, grid_w]

# ── Threaded chunk building ────────────────────────────────────────────────

# Worker-thread task: does the heavy CPU work (height field, packed arrays,
# ArrayMesh, HeightMapShape3D) without touching the scene tree.
func _chunk_prepare_task(key: Vector2i, chunk_data: RefCounted,
		tile_grid: PackedInt32Array, grid_min_x: int, grid_min_z: int, grid_w: int) -> void:
	var terrain_res: Dictionary = ChunkRenderer.prepare_terrain(
			chunk_data, tile_grid, grid_min_x, grid_min_z, grid_w)
	_chunk_build_mutex.lock()
	_chunk_build_results.append({ "key": key, "chunk_data": chunk_data, "terrain_res": terrain_res })
	_chunk_build_mutex.unlock()

# Called every frame: kick off thread jobs for queued chunks up to MAX_CHUNK_JOBS.
func _kick_chunk_jobs() -> void:
	# Sort so nearest chunks are dispatched first (re-sort each call so
	# direction changes are reflected without waiting for _update_chunks).
	var pcx: int = _last_player_chunk.x
	var pcz: int = _last_player_chunk.y
	_chunk_build_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = (a.x - pcx) * (a.x - pcx) + (a.y - pcz) * (a.y - pcz)
		var db: int = (b.x - pcx) * (b.x - pcx) + (b.y - pcz) * (b.y - pcz)
		return da < db
	)

	var i: int = 0
	while i < _chunk_build_queue.size():
		if _chunk_data_pending.size() >= MAX_CHUNK_JOBS:
			break
		var key: Vector2i = _chunk_build_queue[i]
		if _chunk_renderers.has(key) or _chunk_data_pending.has(key):
			_chunk_build_queue.remove_at(i)
			continue
		if abs(key.x - pcx) > LOAD_RADIUS or abs(key.y - pcz) > LOAD_RADIUS:
			_chunk_build_queue.remove_at(i)
			continue

		# Ensure neighbour tile data exists (fast, sync) then snapshot for thread
		_ensure_tile_data_around(key)
		var snap := _snapshot_tile_grid_for(key)

		# Ensure full chunk data (entities) is ready before handing to thread
		if not _chunk_data_cache.has(key) or not _chunk_data_cache[key].has_entities:
			_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk(key.x, key.y, WORLD_SEED)
		var chunk_data: RefCounted = _chunk_data_cache[key]

		_chunk_data_pending[key] = true
		_chunk_build_queue.remove_at(i)
		WorkerThreadPool.add_task(_chunk_prepare_task.bind(
				key, chunk_data, snap[0], snap[1], snap[2], snap[3]))
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

	var renderer: ChunkRenderer = ChunkRenderer.new()
	renderer.name = "Chunk_%d_%d" % [key.x, key.y]
	add_child(renderer)
	renderer.build(chunk, key, self, _terrain_mat, result["terrain_res"])
	_chunk_renderers[key] = renderer

# Synchronous build used at startup so the world is ready before first frame.
func _build_chunk_sync(key: Vector2i) -> void:
	if _chunk_renderers.has(key):
		return
	_ensure_tile_data_around(key)
	var snap := _snapshot_tile_grid_for(key)
	if not _chunk_data_cache.has(key) or not _chunk_data_cache[key].has_entities:
		_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk(key.x, key.y, WORLD_SEED)
	var chunk: RefCounted = _chunk_data_cache[key]
	var terrain_res: Dictionary = ChunkRenderer.prepare_terrain(chunk, snap[0], snap[1], snap[2], snap[3])
	for c_data in chunk.chests:
		var cid: String = str(c_data.get("id", ""))
		_active_chest_data[cid] = c_data
	var renderer: ChunkRenderer = ChunkRenderer.new()
	renderer.name = "Chunk_%d_%d" % [key.x, key.y]
	add_child(renderer)
	renderer.build(chunk, key, self, _terrain_mat, terrain_res)
	_chunk_renderers[key] = renderer

# Called by ChunkRenderer after spawning an enemy
func register_enemy(eid: String, node: Node3D) -> void:
	_enemy_nodes[eid] = node

# Called by ChunkRenderer after spawning a chest
func register_chest(cid: String, node: Node3D, c_data: Dictionary) -> void:
	_chest_nodes[cid] = node
	_active_chest_data[cid] = c_data

# Find nearest active chest within range
func _find_nearby_enemy_infinite(px: float, pz: float, range_dist: float) -> Node3D:
	var range_sq: float = range_dist * range_dist
	for node: Node3D in _enemy_nodes.values():
		if not is_instance_valid(node):
			continue
		var dx: float = node.global_position.x - px
		var dz: float = node.global_position.z - pz
		if dx * dx + dz * dz <= range_sq:
			return node
	return null

func _find_nearby_chest_infinite(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	for d: Dictionary in _active_chest_data.values():
		if d.get("opened", false):
			continue
		var dx: float = float(d.get("x", 0.0)) - px
		var dz: float = float(d.get("z", 0.0)) - pz
		if dx * dx + dz * dz <= range_sq:
			return d
	return {}

# ── Named-map (bounded) path ───────────────────────────────────────────────

func _build_grass_blades() -> void:
	_grass = GrassBlades.new()
	_grass.name = "GrassBlades"
	add_child(_grass)
	_grass.build(world_map)

func _build_terrain() -> void:
	var nvx: int = WorldMap.MAP_WIDTH  * TERRAIN_VDENSITY + 1
	var nvz: int = WorldMap.MAP_HEIGHT * TERRAIN_VDENSITY + 1
	var step: float = IsoConst.TILE_SIZE / float(TERRAIN_VDENSITY)

	var hfield := _compute_terrain_heights(nvx, nvz, step)
	_build_terrain_mesh(hfield, nvx, nvz, step)
	_build_terrain_collision(hfield, nvx, nvz, step)

func _compute_terrain_heights(nvx: int, nvz: int, step: float) -> PackedFloat32Array:
	var field := PackedFloat32Array()
	field.resize(nvx * nvz)

	var tile_range: int = int(ceil(HILL_RAMP_R / IsoConst.TILE_SIZE)) + 1

	for iz in range(nvz):
		for ix in range(nvx):
			var wx: float = ix * step
			var wz: float = iz * step
			var vtx: int = int(wx / IsoConst.TILE_SIZE)
			var vtz: int = int(wz / IsoConst.TILE_SIZE)

			var h: float = 0.0
			for dtz in range(-tile_range, tile_range + 1):
				for dtx in range(-tile_range, tile_range + 1):
					var ttx: int = vtx + dtx
					var ttz: int = vtz + dtz
					if world_map.get_tile(ttx, ttz) != WorldMap.TILE_HILL:
						continue
					var near_x: float = clamp(wx, float(ttx) * IsoConst.TILE_SIZE, float(ttx + 1) * IsoConst.TILE_SIZE)
					var near_z: float = clamp(wz, float(ttz) * IsoConst.TILE_SIZE, float(ttz + 1) * IsoConst.TILE_SIZE)
					var dist: float = sqrt((wx - near_x) * (wx - near_x) + (wz - near_z) * (wz - near_z))
					if dist < HILL_RAMP_R:
						var t: float = 1.0 - dist / HILL_RAMP_R
						t = t * t * (3.0 - 2.0 * t)
						var contrib: float = HILL_PEAK_H * t
						if contrib > h:
							h = contrib
			field[iz * nvx + ix] = h
	return field

func _build_terrain_mesh(hfield: PackedFloat32Array, nvx: int, nvz: int, step: float) -> void:
	var total_verts: int = nvx * nvz
	var total_quads: int = (nvx - 1) * (nvz - 1)

	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs     := PackedVector2Array()
	var colors  := PackedColorArray()
	var indices := PackedInt32Array()

	verts.resize(total_verts)
	normals.resize(total_verts)
	uvs.resize(total_verts)
	colors.resize(total_verts)
	indices.resize(total_quads * 6)

	for iz in range(nvz):
		for ix in range(nvx):
			var i: int = iz * nvx + ix
			var x: float = ix * step
			var z: float = iz * step
			var h: float = hfield[i]
			verts[i] = Vector3(x, h, z)
			uvs[i]   = Vector2(x, z)
			var blend: float = clamp(h / HILL_PEAK_H, 0.0, 1.0)
			# Encode wall flag in COLOR.g so the terrain shader shows stone floor
			var tx: int = int(x / IsoConst.TILE_SIZE)
			var tz: int = int(z / IsoConst.TILE_SIZE)
			var is_wall: float = 1.0 if world_map.get_tile(tx, tz) == WorldMap.TILE_WALL else 0.0
			colors[i] = Color(blend, is_wall, 0.0, 1.0)

	for iz in range(nvz):
		for ix in range(nvx):
			var i: int = iz * nvx + ix
			var ix_l: int = max(ix - 1, 0)
			var ix_r: int = min(ix + 1, nvx - 1)
			var iz_d: int = max(iz - 1, 0)
			var iz_u: int = min(iz + 1, nvz - 1)
			var hL: float = hfield[iz   * nvx + ix_l]
			var hR: float = hfield[iz   * nvx + ix_r]
			var hD: float = hfield[iz_d * nvx + ix  ]
			var hU: float = hfield[iz_u * nvx + ix  ]
			var dx: float = (hR - hL) / (2.0 * step)
			var dz: float = (hU - hD) / (2.0 * step)
			normals[i] = Vector3(-dx, 1.0, -dz).normalized()

	var idx: int = 0
	for iz in range(nvz - 1):
		for ix in range(nvx - 1):
			var a: int = iz * nvx + ix
			var b: int = iz * nvx + (ix + 1)
			var c: int = (iz + 1) * nvx + ix
			var d: int = (iz + 1) * nvx + (ix + 1)
			indices[idx]     = a; indices[idx + 1] = c; indices[idx + 2] = b
			indices[idx + 3] = b; indices[idx + 4] = c; indices[idx + 5] = d
			idx += 6

	# ── Edge skirts: drop border vertices below ground to hide underside ──
	const SKIRT_Y: float = -0.5
	var skirt_count: int = (nvx + nvz) * 2
	var skirt_verts   := PackedVector3Array()
	var skirt_normals := PackedVector3Array()
	var skirt_uvs     := PackedVector2Array()
	var skirt_colors  := PackedColorArray()
	var skirt_indices := PackedInt32Array()
	skirt_verts.resize(skirt_count)
	skirt_normals.resize(skirt_count)
	skirt_uvs.resize(skirt_count)
	skirt_colors.resize(skirt_count)
	var skirt_seg: int = (nvx - 1) * 2 + (nvz - 1) * 2
	skirt_indices.resize(skirt_seg * 6)

	var si: int = 0
	var _edge_ids: Array[int] = []
	for ixx in range(nvx):
		for iz_edge in [0, nvz - 1]:
			var surf_i: int = iz_edge * nvx + ixx
			skirt_verts[si]   = Vector3(verts[surf_i].x, SKIRT_Y, verts[surf_i].z)
			skirt_normals[si] = normals[surf_i]
			skirt_uvs[si]     = uvs[surf_i]
			skirt_colors[si]  = colors[surf_i]
			_edge_ids.append(surf_i)
			_edge_ids.append(si)
			si += 1
	for izz in range(1, nvz - 1):
		for ix_edge in [0, nvx - 1]:
			var surf_i: int = izz * nvx + ix_edge
			skirt_verts[si]   = Vector3(verts[surf_i].x, SKIRT_Y, verts[surf_i].z)
			skirt_normals[si] = normals[surf_i]
			skirt_uvs[si]     = uvs[surf_i]
			skirt_colors[si]  = colors[surf_i]
			_edge_ids.append(surf_i)
			_edge_ids.append(si)
			si += 1

	var skirt_map: Dictionary = {}
	for ei in range(0, _edge_ids.size(), 2):
		skirt_map[_edge_ids[ei]] = _edge_ids[ei + 1]

	var sidx: int = 0
	for ixx in range(nvx - 1):
		var a: int = ixx; var b: int = ixx + 1
		var sa: int = total_verts + int(skirt_map[a])
		var sb: int = total_verts + int(skirt_map[b])
		skirt_indices[sidx] = a;  skirt_indices[sidx+1] = sa; skirt_indices[sidx+2] = b
		skirt_indices[sidx+3] = b; skirt_indices[sidx+4] = sa; skirt_indices[sidx+5] = sb
		sidx += 6
	for ixx in range(nvx - 1):
		var a: int = (nvz - 1) * nvx + ixx; var b: int = (nvz - 1) * nvx + ixx + 1
		var sa: int = total_verts + int(skirt_map[a])
		var sb: int = total_verts + int(skirt_map[b])
		skirt_indices[sidx] = a;  skirt_indices[sidx+1] = b;  skirt_indices[sidx+2] = sa
		skirt_indices[sidx+3] = b; skirt_indices[sidx+4] = sb; skirt_indices[sidx+5] = sa
		sidx += 6
	for izz in range(nvz - 1):
		var a: int = izz * nvx; var b: int = (izz + 1) * nvx
		var sa: int = total_verts + int(skirt_map[a])
		var sb: int = total_verts + int(skirt_map[b])
		skirt_indices[sidx] = a;  skirt_indices[sidx+1] = b;  skirt_indices[sidx+2] = sa
		skirt_indices[sidx+3] = b; skirt_indices[sidx+4] = sb; skirt_indices[sidx+5] = sa
		sidx += 6
	for izz in range(nvz - 1):
		var a: int = izz * nvx + nvx - 1; var b: int = (izz + 1) * nvx + nvx - 1
		var sa: int = total_verts + int(skirt_map[a])
		var sb: int = total_verts + int(skirt_map[b])
		skirt_indices[sidx] = a;  skirt_indices[sidx+1] = sa; skirt_indices[sidx+2] = b
		skirt_indices[sidx+3] = b; skirt_indices[sidx+4] = sa; skirt_indices[sidx+5] = sb
		sidx += 6

	verts.append_array(skirt_verts)
	normals.append_array(skirt_normals)
	uvs.append_array(skirt_uvs)
	colors.append_array(skirt_colors)
	indices.append_array(skirt_indices)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR]  = colors
	arrays[Mesh.ARRAY_INDEX]  = indices

	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.mesh = terrain_mesh
	mi.material_override = _make_terrain_material()
	_tile_meshes.add_child(mi)

func _make_terrain_material(_seed: int = 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _TerrainShader
	mat.set_shader_parameter("grass_texture",     _TexGrass)
	mat.set_shader_parameter("hill_side_texture", _TexHillSide)
	mat.set_shader_parameter("hill_texture",      _TexHillTop)
	mat.set_shader_parameter("wall_top_texture",  _TexWallTop)
	mat.set_shader_parameter("uv_scale", 0.5)
	return mat

static func _add_wall_side(
		verts: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, indices: PackedInt32Array,
		bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3,
		normal: Vector3, h: float) -> void:
	var i: int = verts.size()
	verts.append_array([bl, br, tr, tl])
	normals.append_array([normal, normal, normal, normal])
	uvs.append_array([Vector2(0.0, h), Vector2(1.0, h), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
	indices.append_array([i, i + 1, i + 2, i, i + 2, i + 3])

func _build_terrain_collision(hfield: PackedFloat32Array, nvx: int, nvz: int, _step: float) -> void:
	var hmap := HeightMapShape3D.new()
	hmap.map_width = nvx
	hmap.map_depth = nvz
	hmap.map_data  = hfield
	var col := CollisionShape3D.new()
	col.shape = hmap
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 2   # terrain layer
	body.collision_mask  = 0   # terrain doesn't need to detect others
	# HeightMapShape3D is centered on its own origin
	var map_world_x: float = WorldMap.MAP_WIDTH  * IsoConst.TILE_SIZE
	var map_world_z: float = WorldMap.MAP_HEIGHT * IsoConst.TILE_SIZE
	body.position = Vector3(map_world_x * 0.5, 0.0, map_world_z * 0.5)
	body.add_child(col)
	add_child(body)

func _build_walls() -> void:
	var left_mat := StandardMaterial3D.new()
	left_mat.albedo_texture = _TexWallLeft
	left_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	left_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var right_mat := StandardMaterial3D.new()
	right_mat.albedo_texture = _TexWallRight
	right_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	right_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_texture = _TexWallTop
	top_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	top_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var lv := PackedVector3Array()
	var ln := PackedVector3Array()
	var lu := PackedVector2Array()
	var li := PackedInt32Array()
	var rv := PackedVector3Array()
	var rn := PackedVector3Array()
	var ru := PackedVector2Array()
	var ri := PackedInt32Array()
	var tv := PackedVector3Array()
	var tn := PackedVector3Array()
	var tu := PackedVector2Array()
	var ti := PackedInt32Array()

	var wall_body := StaticBody3D.new()
	wall_body.name = "WallCollision"
	wall_body.collision_layer = 4
	wall_body.collision_mask  = 0

	for tz in range(WorldMap.MAP_HEIGHT):
		for tx in range(WorldMap.MAP_WIDTH):
			if world_map.get_tile(tx, tz) != WorldMap.TILE_WALL:
				continue
			var h: int = max(1, world_map.get_height(tx, tz))
			var top_y: float = float(h) * WALL_FACE_H
			var x0: float = float(tx) * IsoConst.TILE_SIZE
			var x1: float = x0 + IsoConst.TILE_SIZE
			var z0: float = float(tz) * IsoConst.TILE_SIZE
			var z1: float = z0 + IsoConst.TILE_SIZE

			# Top face
			var tbase: int = tv.size()
			tv.append_array([
				Vector3(x0, top_y, z0), Vector3(x1, top_y, z0),
				Vector3(x1, top_y, z1), Vector3(x0, top_y, z1)
			])
			tn.append_array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
			tu.append_array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
			ti.append_array([tbase, tbase + 1, tbase + 2, tbase, tbase + 2, tbase + 3])

			# South (+Z) = left side of iso block — only camera-facing side faces.
			var nb_h_s: int = 0
			if world_map.get_tile(tx, tz + 1) == WorldMap.TILE_WALL:
				nb_h_s = max(1, world_map.get_height(tx, tz + 1))
			if nb_h_s < h:
				var bot_s: float = float(nb_h_s) * WALL_FACE_H
				_add_wall_side(lv, ln, lu, li,
					Vector3(x0, bot_s, z1), Vector3(x1, bot_s, z1),
					Vector3(x1, top_y, z1), Vector3(x0, top_y, z1),
					Vector3(0.0, 0.0, 1.0), float(h - nb_h_s))

			# East (+X) = right side of iso block.
			var nb_h_e: int = 0
			if world_map.get_tile(tx + 1, tz) == WorldMap.TILE_WALL:
				nb_h_e = max(1, world_map.get_height(tx + 1, tz))
			if nb_h_e < h:
				var bot_e: float = float(nb_h_e) * WALL_FACE_H
				_add_wall_side(rv, rn, ru, ri,
					Vector3(x1, bot_e, z1), Vector3(x1, bot_e, z0),
					Vector3(x1, top_y, z0), Vector3(x1, top_y, z1),
					Vector3(1.0, 0.0, 0.0), float(h - nb_h_e))

			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(IsoConst.TILE_SIZE, top_y, IsoConst.TILE_SIZE)
			col.shape = box
			col.position = Vector3(x0 + IsoConst.TILE_SIZE * 0.5, top_y * 0.5, z0 + IsoConst.TILE_SIZE * 0.5)
			wall_body.add_child(col)

	if lv.is_empty() and rv.is_empty() and tv.is_empty():
		return

	var mesh := ArrayMesh.new()
	if not lv.is_empty():
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = lv
		arr[Mesh.ARRAY_NORMAL] = ln
		arr[Mesh.ARRAY_TEX_UV] = lu
		arr[Mesh.ARRAY_INDEX]  = li
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if not rv.is_empty():
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = rv
		arr[Mesh.ARRAY_NORMAL] = rn
		arr[Mesh.ARRAY_TEX_UV] = ru
		arr[Mesh.ARRAY_INDEX]  = ri
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if not tv.is_empty():
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = tv
		arr[Mesh.ARRAY_NORMAL] = tn
		arr[Mesh.ARRAY_TEX_UV] = tu
		arr[Mesh.ARRAY_INDEX]  = ti
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var surf: int = 0
	if not lv.is_empty():
		mi.set_surface_override_material(surf, left_mat)
		surf += 1
	if not rv.is_empty():
		mi.set_surface_override_material(surf, right_mat)
		surf += 1
	if not tv.is_empty():
		mi.set_surface_override_material(surf, top_mat)
	_wall_meshes.add_child(mi)
	_wall_meshes.add_child(wall_body)

func flush_save_position() -> void:
	if _player:
		var save_map: String = "infinite" if infinite else map_name
		SaveManager.update_position(save_map, _player.position.x, _player.position.z)

func _spawn_player() -> void:
	var px: float
	var pz: float

	if not target_door_id.is_empty():
		var door := world_map.find_door_by_id(target_door_id)
		if not door.is_empty():
			px = door["x"]
			pz = door["z"]
		else:
			px = _get_default_px()
			pz = _get_default_pz()
	elif SaveManager.current_map == map_name and (SaveManager.player_x != 0.0 or SaveManager.player_z != 0.0):
		px = SaveManager.player_x
		pz = SaveManager.player_z
	else:
		px = _get_default_px()
		pz = _get_default_pz()

	_player = _create_player_node()
	_player.position = Vector3(px, get_terrain_height(px, pz) + 0.5, pz)
	_entity_root.add_child(_player)
	_camera.position = _player.position + Vector3(20, 20, 20)

func _get_default_px() -> float:
	if world_map.has_player_spawn():
		return world_map.player_spawn_x * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	return 3.0 * IsoConst.TILE_SIZE

func _get_default_pz() -> float:
	if world_map.has_player_spawn():
		return world_map.player_spawn_z * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	return 3.0 * IsoConst.TILE_SIZE

func _create_player_node() -> CharacterBody3D:
	var p: CharacterBody3D = _PlayerScene.instantiate()
	p.add_to_group("player")
	return p

func _spawn_entities() -> void:
	for e_data in world_map.enemies:
		var eid: String = str(e_data.get("id", ""))
		if SaveManager.is_enemy_defeated(eid):
			continue
		if eid == SaveManager.in_battle_enemy_id:
			continue  # being fought right now — don't spawn a duplicate
		_spawn_enemy(e_data)
	for c_data in world_map.chests:
		var cid: String = str(c_data.get("id", ""))
		if SaveManager.is_chest_opened(cid):
			c_data["opened"] = true
		_spawn_chest(c_data)
	for d_data in world_map.doors:
		_spawn_door(d_data)

func _spawn_enemy(e_data: Dictionary) -> void:
	var node: Node3D = _EnemyScene.instantiate()
	var ey: float = get_terrain_height(float(e_data["x"]), float(e_data["z"])) + 0.5
	node.position = Vector3(e_data["x"], ey, e_data["z"])
	if node.has_method("init_from_data"):
		node.init_from_data(e_data)
	if node.has_method("set_player") and _player:
		node.set_player(_player)
	_entity_root.add_child(node)
	_enemy_nodes[e_data["id"]] = node

func _spawn_chest(c_data: Dictionary) -> void:
	var node: Node3D = _ChestScene.instantiate()
	var cy: float = get_terrain_height(float(c_data["x"]), float(c_data["z"])) + 0.25
	node.position = Vector3(c_data["x"], cy, c_data["z"])
	if node.has_method("init_from_data"):
		node.init_from_data(c_data)
	_entity_root.add_child(node)
	_chest_nodes[c_data["id"]] = node

func _spawn_door(d_data: Dictionary) -> void:
	var node: Node3D = _DoorScene.instantiate()
	var dy: float = get_terrain_height(float(d_data["x"]), float(d_data["z"])) + 0.75
	node.position = Vector3(d_data["x"], dy, d_data["z"])
	if node.has_method("init_from_data"):
		node.init_from_data(d_data)
	_entity_root.add_child(node)
	_door_nodes[d_data["id"]] = node

# ── Day / Night cycle ──────────────────────────────────────────────────────

func _update_day_night(delta: float) -> void:
	_time_of_day = fmod(_time_of_day + delta / day_duration, 1.0)

	# sun_angle: 0 at sunrise (t=0.25), PI/2 at noon (t=0.5), PI at sunset (t=0.75)
	var sun_angle: float = (_time_of_day - 0.25) * TAU
	_sun.rotation = Vector3(-sun_angle, 0.0, 0.0)
	_moon.rotation = Vector3(-(sun_angle + PI), 0.0, 0.0)

	# sin: 0 at horizons, 1 at noon, -1 at midnight
	var sun_h: float = sin(sun_angle)
	var t_day: float = clampf(sun_h * 2.0 + 0.1, 0.0, 1.0)
	var t_horizon: float = clampf(1.0 - abs(sun_h) * 5.0, 0.0, 1.0)

	# Sun: warm white at midday, orange at horizon, off at night
	_sun.light_energy = clampf(sun_h * 1.5, 0.0, 1.5)
	_sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.45, 0.1), t_horizon)

	# Moon: opposite hemisphere, cool blue
	var moon_h: float = -sun_h
	_moon.light_energy = clampf(moon_h * 0.35, 0.0, 0.35)

	# Sky colour: deep blue day → orange horizon → near-black night
	var sky: Color
	if sun_h >= 0.0:
		sky = Color(0.7, 0.3, 0.1).lerp(Color(0.25, 0.5, 0.85), clampf(sun_h * 3.0, 0.0, 1.0))
	else:
		sky = Color(0.02, 0.02, 0.08).lerp(Color(0.7, 0.3, 0.1), clampf((sun_h + 0.3) * 5.0, 0.0, 1.0))
	_world_env.environment.background_color = sky

	# Ambient: dark blue night → soft grey day
	_world_env.environment.ambient_light_color = Color(0.03, 0.04, 0.12).lerp(Color(0.4, 0.45, 0.5), t_day)
	_world_env.environment.ambient_light_energy = lerpf(0.15, 0.7, t_day)

# ── Per-frame update ───────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _player == null:
		return
	_camera.position = _player.position + Vector3(20, 20, 20)
	_day_night_timer += delta
	if _day_night_timer >= DAY_NIGHT_INTERVAL:
		_update_day_night(_day_night_timer)
		_day_night_timer = 0.0
	if _grass:
		_grass.update_player(_player.position, delta, _player.is_on_floor())

	if infinite:
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
					needs_update = true
					_last_move_dir = new_dir
		if needs_update:
			_update_chunks()
		# Dispatch thread jobs for queued chunks, commit completed results
		_kick_chunk_jobs()
		_commit_chunk_results()

	# Only update save position when player moves > 1 unit (not every frame)
	var cur_pos := Vector2(_player.position.x, _player.position.z)
	if cur_pos.distance_squared_to(_last_save_pos) > 1.0:
		_last_save_pos = cur_pos
		var save_map: String = "infinite" if infinite else map_name
		SaveManager.update_position(save_map, _player.position.x, _player.position.z)

	# Throttle interaction checks — no need to scan every frame
	_interact_timer += delta
	if _interact_timer >= INTERACT_INTERVAL:
		_interact_timer = 0.0
		_check_interactions()

func _check_interactions() -> void:
	var px: float = _player.position.x
	var pz: float = _player.position.z

	if infinite:
		var enemy := _find_nearby_enemy_infinite(px, pz, IsoConst.INTERACT_RANGE)
		var chest := _find_nearby_chest_infinite(px, pz, IsoConst.INTERACT_RANGE)
		if enemy != null or not chest.is_empty():
			_interact_label.show()
		else:
			_interact_label.hide()
	else:
		var door := world_map.find_nearby_door(px, pz, IsoConst.INTERACT_RANGE)
		var enemy := world_map.find_nearby_enemy(px, pz, IsoConst.INTERACT_RANGE)
		var chest := world_map.find_nearby_chest(px, pz, IsoConst.INTERACT_RANGE)
		if not door.is_empty() or not enemy.is_empty() or not chest.is_empty():
			_interact_label.show()
		else:
			_interact_label.hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_handle_interact()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		GameBus.inventory_requested.emit()
		get_viewport().set_input_as_handled()

func _handle_interact() -> void:
	if _player == null:
		return
	var px: float = _player.position.x
	var pz: float = _player.position.z

	if infinite:
		var enemy := _find_nearby_enemy_infinite(px, pz, IsoConst.INTERACT_RANGE)
		if enemy != null and enemy.has_method("engage"):
			enemy.engage()
			return
		var chest := _find_nearby_chest_infinite(px, pz, IsoConst.INTERACT_RANGE)
		if not chest.is_empty() and not chest.get("opened", false):
			chest["opened"] = true
			var cid: String = str(chest.get("id", ""))
			SaveManager.mark_chest_opened(cid)
			var node := _chest_nodes.get(cid) as Node3D
			if node and node.has_method("mark_opened"):
				node.mark_opened()
			var chest_pos := Vector3(float(chest.get("x", px)), get_terrain_height(float(chest.get("x", px)), float(chest.get("z", pz))) + 0.25, float(chest.get("z", pz)))
			_spawn_card_items(chest.get("card_ids", []), chest_pos)
		return

	# Named-map path
	var door := world_map.find_nearby_door(px, pz, IsoConst.INTERACT_RANGE)
	if not door.is_empty():
		var target_map: String = door.get("target_map", "")
		var tdoor: String = door.get("target_door_id", "")
		if target_map.is_empty():
			SceneManager.exit_map()
		else:
			SceneManager.enter_map(target_map, tdoor)
		return

	var nearby_enemy := world_map.find_nearby_enemy(px, pz, IsoConst.INTERACT_RANGE)
	if not nearby_enemy.is_empty():
		var eid: String = str(nearby_enemy.get("id", ""))
		var enode := _enemy_nodes.get(eid) as Node3D
		if enode and enode.has_method("engage"):
			enode.engage()
		return

	var chest := world_map.find_nearby_chest(px, pz, IsoConst.INTERACT_RANGE)
	if not chest.is_empty() and not chest.get("opened", false):
		chest["opened"] = true
		var cid: String = str(chest.get("id", ""))
		SaveManager.mark_chest_opened(cid)
		var node := _chest_nodes.get(chest["id"]) as Node3D
		if node and node.has_method("mark_opened"):
			node.mark_opened()
		var chest_pos := Vector3(float(chest.get("x", px)), get_terrain_height(float(chest.get("x", px)), float(chest.get("z", pz))) + 0.25, float(chest.get("z", pz)))
		_spawn_card_items(chest.get("card_ids", []), chest_pos)

# ── Card item spawning ──────────────────────────────────────────────────────

func _spawn_card_items(card_ids: Array, origin: Vector3) -> void:
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
