extends Node3D

const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const ChunkRenderer    = preload("res://scenes/world/ChunkRenderer.gd")
const GrassBlades      = preload("res://scenes/world/GrassBlades.gd")

## Emitted when the player enters a new chunk; world scene updates music/ambience/save.
signal player_chunk_changed(chunk: Vector2i, biome_id: int)
## Emitted after a chunk is committed (visual + entities live). World scene registers
## landmark data that ChunkRenderer cannot register itself (no scene node).
signal chunk_committed(key: Vector2i, chunk_data: RefCounted)
## Emitted just before a chunk renderer is torn down. World scene cleans up entity
## nodes and active-data dictionaries.
signal chunk_unloading(key: Vector2i, chunk_data: RefCounted)

# ── Constants ──────────────────────────────────────────────────────────────────
const LOAD_RADIUS:        int = 6
const UNLOAD_RADIUS:      int = 7
const CACHE_EVICT_RADIUS: int = 10
const MAX_CHUNK_JOBS:     int = 4

# ── Chunk lifecycle state ──────────────────────────────────────────────────────
var _chunk_data_cache: Dictionary = {}        # Vector2i -> ChunkData (RefCounted)
var _chunk_renderers: Dictionary = {}         # Vector2i -> ChunkRenderer
var _chunk_data_pending: Dictionary = {}      # Vector2i -> true (job in flight)
var _chunk_build_results: Array[Dictionary] = []
var _chunk_build_mutex: Mutex = Mutex.new()
var _chunk_task_ids: Array[int] = []
var _chunk_task_id_map: Dictionary = {}       # Vector2i -> task_id
var _chunk_queued: Dictionary = {}            # Vector2i -> true (O(1) membership)
var _chunk_queue_dirty: bool = false
var _pending_physics: Array[Node3D] = []
var _chunk_build_queue: Array[Vector2i] = []
var _last_player_chunk: Vector2i = Vector2i(-9999, -9999)

# Direction-change throttle for re-triggering chunk updates mid-turn
var _last_move_dir: Vector2 = Vector2.ZERO
var _last_dir_update_time: float = -999.0

# ── Config (set via setup()) ───────────────────────────────────────────────────
var _world_seed: int = 42
var _is_infinite: bool = false
var _world_map: RefCounted = null     # WorldMap; null for infinite worlds
var _terrain_mat: ShaderMaterial = null
var _world_scene: Node3D = null       # WorldScene; passed to ChunkRenderer.build_visual

# ── Public API ─────────────────────────────────────────────────────────────────

## Must be called once from WorldScene._ready() before any other method.
func setup(world_seed: int, is_infinite: bool, world_map: RefCounted,
		terrain_mat: ShaderMaterial, world_scene: Node3D) -> void:
	_world_seed = world_seed
	_is_infinite = is_infinite
	_world_map = world_map
	_terrain_mat = terrain_mat
	_world_scene = world_scene

## Infinite-world startup: update chunks around player_pos, then sync-build the
## inner 5×5 ring; the remaining queued chunks stream in via process_streaming().
func build_initial_infinite(player_pos: Vector3) -> void:
	_update_chunks(player_pos, [], Vector2.ZERO)
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

## Named-map startup: sync-build every chunk and record last player chunk.
func build_all_named_map(max_cx: int, max_cz: int, player_pos: Vector3) -> void:
	for cz in range(max_cz):
		for cx in range(max_cx):
			_build_chunk_sync(Vector2i(cx, cz))
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	_last_player_chunk = Vector2i(
		int(floor(player_pos.x / chunk_world)),
		int(floor(player_pos.z / chunk_world)))

## Full per-frame entry point for infinite worlds. Decides whether to re-scan
## (player moved or turned significantly), then kicks jobs, commits results, and
## drains one deferred physics build.
func process_streaming(player_pos: Vector3, player_vel: Vector3, camera_frustum: Array[Plane]) -> void:
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var pcx: int = int(floor(player_pos.x / chunk_world))
	var pcz: int = int(floor(player_pos.z / chunk_world))
	var needs_update: bool = Vector2i(pcx, pcz) != _last_player_chunk
	if not needs_update:
		var vel_xz: Vector2 = Vector2(player_vel.x, player_vel.z)
		if vel_xz.length_squared() > 0.25:
			var new_dir: Vector2 = vel_xz.normalized()
			if new_dir.dot(_last_move_dir) < 0.7:
				var now: float = Time.get_ticks_msec() * 0.001
				if now - _last_dir_update_time >= 0.5:
					needs_update = true
					_last_move_dir = new_dir
					_last_dir_update_time = now
	if needs_update:
		var vel_xz: Vector2 = Vector2(player_vel.x, player_vel.z)
		var look_dir: Vector2 = vel_xz.normalized() if vel_xz.length_squared() > 0.25 else Vector2.ZERO
		_update_chunks(player_pos, camera_frustum, look_dir)
	_kick_chunk_jobs()
	_commit_chunk_results()
	if not _pending_physics.is_empty():
		var r: ChunkRenderer = _pending_physics.pop_front() as ChunkRenderer
		if is_instance_valid(r):
			r.build_physics()

## Returns the chunk coordinate the player was last seen in.
func get_last_player_chunk() -> Vector2i:
	return _last_player_chunk

## Returns the last tracked movement direction (XZ plane), used by WorldScene for
## directional actions such as ghost phase.
func get_last_move_dir() -> Vector2:
	return _last_move_dir

## True if chunk data for key is cached (may be tile-only or full with entities).
func has_chunk_data(key: Vector2i) -> bool:
	return _chunk_data_cache.has(key)

## Returns the ChunkData ref for key, or null if not cached.
func get_chunk_data(key: Vector2i) -> RefCounted:
	return _chunk_data_cache.get(key) as RefCounted

## Returns the tile type at global tile coordinates (wtx, wtz).
## Generates tile-only data if the chunk is not yet cached.
func get_tile_global(wtx: int, wtz: int) -> int:
	if not _is_infinite:
		return _world_map.get_tile(wtx, wtz)
	var cx: int = int(floor(float(wtx) / float(IsoConst.CHUNK_SIZE)))
	var cz: int = int(floor(float(wtz) / float(IsoConst.CHUNK_SIZE)))
	var key := Vector2i(cx, cz)
	if not _chunk_data_cache.has(key):
		_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk_data_only(cx, cz, _world_seed)
	var lx: int = wtx - cx * IsoConst.CHUNK_SIZE
	var lz: int = wtz - cz * IsoConst.CHUNK_SIZE
	var chunk: RefCounted = _chunk_data_cache[key]
	return chunk.get_tile(lx, lz)

## Returns the height value at global tile coordinates (wtx, wtz).
func get_height_global(wtx: int, wtz: int) -> int:
	if not _is_infinite:
		return _world_map.get_height(wtx, wtz)
	var cx: int = int(floor(float(wtx) / float(IsoConst.CHUNK_SIZE)))
	var cz: int = int(floor(float(wtz) / float(IsoConst.CHUNK_SIZE)))
	var key := Vector2i(cx, cz)
	if not _chunk_data_cache.has(key):
		_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk_data_only(cx, cz, _world_seed)
	var lx: int = wtx - cx * IsoConst.CHUNK_SIZE
	var lz: int = wtz - cz * IsoConst.CHUNK_SIZE
	var chunk: RefCounted = _chunk_data_cache[key]
	return chunk.get_height(lx, lz)

## Builds the packed tile-grid snapshot needed by ChunkRenderer.prepare_terrain().
## Returns [tile_grid, height_grid, grid_min_x, grid_min_z, grid_w].
func snapshot_tile_grid_for(key: Vector2i) -> Array:
	const TILE_CHECK: int = ChunkRenderer.TILE_CHECK
	var chunk_origin_x: float = float(key.x * IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var chunk_origin_z: float = float(key.y * IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var base_tx: int = int(chunk_origin_x / IsoConst.TILE_SIZE)
	var base_tz: int = int(chunk_origin_z / IsoConst.TILE_SIZE)
	var grid_min_x: int = base_tx - TILE_CHECK
	var grid_min_z: int = base_tz - TILE_CHECK
	var grid_w: int = IsoConst.CHUNK_SIZE + TILE_CHECK * 2 + 1
	var grid_h: int = IsoConst.CHUNK_SIZE + TILE_CHECK * 2 + 1
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
			height_grid[idx] = get_height_global(wtx, wtz)
	return [tile_grid, height_grid, grid_min_x, grid_min_z, grid_w]

## Rebuilds terrain meshes in the 3×3 chunk neighbourhood of tile (tx, tz).
## Called after map-editor tile edits.
func rebuild_terrain_around_tile(tx: int, tz: int) -> void:
	var cx: int = int(floor(float(tx) / float(IsoConst.CHUNK_SIZE)))
	var cz: int = int(floor(float(tz) / float(IsoConst.CHUNK_SIZE)))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			var renderer: ChunkRenderer = _chunk_renderers.get(key) as ChunkRenderer
			if renderer == null:
				continue
			var snap := snapshot_tile_grid_for(key)
			renderer.rebuild_terrain(snap, _world_seed)

## Iterates all active renderers. callback receives (key: Vector2i, renderer: ChunkRenderer).
func for_each_renderer(callback: Callable) -> void:
	for raw_key in _chunk_renderers:
		var key: Vector2i = raw_key
		var cr: ChunkRenderer = _chunk_renderers[key] as ChunkRenderer
		if cr != null:
			callback.call(key, cr)

## Called from WorldScene._exit_tree() to drain in-flight thread tasks before
## the GDScript instance is freed.
func exit_cleanup() -> void:
	for task_id: int in _chunk_task_ids:
		WorkerThreadPool.wait_for_task_completion(task_id)
	_chunk_task_ids.clear()

# ── Internal ───────────────────────────────────────────────────────────────────

func _chunk_in_frustum(cx: int, cz: int, frustum: Array[Plane]) -> bool:
	var ws: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var x0: float = float(cx) * ws
	var z0: float = float(cz) * ws
	var x1: float = x0 + ws
	var z1: float = z0 + ws
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

func _ensure_tile_data_around(key: Vector2i) -> void:
	if not _is_infinite:
		return
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var nkey := Vector2i(key.x + dx, key.y + dz)
			if not _chunk_data_cache.has(nkey):
				_chunk_data_cache[nkey] = InfiniteWorldGen.generate_chunk_data_only(nkey.x, nkey.y, _world_seed)

func _update_chunks(player_pos: Vector3, camera_frustum: Array[Plane], look_dir: Vector2) -> void:
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var pcx: int = int(floor(player_pos.x / chunk_world))
	var pcz: int = int(floor(player_pos.z / chunk_world))
	var player_chunk := Vector2i(pcx, pcz)

	if _is_infinite:
		var new_biome: int = InfiniteWorldGen.biome_for_chunk(pcx, pcz, _world_seed)
		if new_biome != _last_biome:
			_last_biome = new_biome
			player_chunk_changed.emit(player_chunk, new_biome)

	for dz in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var key := Vector2i(pcx + dx, pcz + dz)
			if _chunk_renderers.has(key) or _chunk_queued.has(key):
				continue
			if dx * dx + dz * dz > LOAD_RADIUS * LOAD_RADIUS:
				continue
			if abs(dx) <= 1 and abs(dz) <= 1:
				_chunk_build_queue.append(key)
				_chunk_queued[key] = true
				continue
			if camera_frustum.is_empty() or _chunk_in_frustum(key.x, key.y, camera_frustum):
				_chunk_build_queue.append(key)
				_chunk_queued[key] = true
				continue
			if look_dir.length_squared() > 0.1:
				var to_chunk := Vector2(float(dx), float(dz))
				if to_chunk.length_squared() > 0.0 and to_chunk.normalized().dot(look_dir) > 0.3:
					_chunk_build_queue.append(key)
					_chunk_queued[key] = true

	_chunk_queue_dirty = true

	var keys_to_remove: Array[Vector2i] = []
	for raw_key in _chunk_renderers:
		var typed_key: Vector2i = raw_key
		if abs(typed_key.x - pcx) > UNLOAD_RADIUS or abs(typed_key.y - pcz) > UNLOAD_RADIUS:
			keys_to_remove.append(typed_key)

	for key in keys_to_remove:
		var renderer: ChunkRenderer = _chunk_renderers[key]
		var chunk: RefCounted = _chunk_data_cache.get(key) as RefCounted
		if chunk != null:
			chunk_unloading.emit(key, chunk)
		renderer.teardown()
		_chunk_renderers.erase(key)
		var grass_node: GrassBlades = _world_scene.get("_grass") as GrassBlades if _world_scene != null else null
		if grass_node:
			grass_node.remove_chunk(key)

	var cache_keys_to_remove: Array[Vector2i] = []
	for raw_key in _chunk_data_cache:
		var typed_key: Vector2i = raw_key
		if abs(typed_key.x - pcx) > CACHE_EVICT_RADIUS or abs(typed_key.y - pcz) > CACHE_EVICT_RADIUS:
			cache_keys_to_remove.append(typed_key)
	for key in cache_keys_to_remove:
		_chunk_data_cache.erase(key)

	_last_player_chunk = player_chunk

# Track last-seen biome to detect changes inside _update_chunks.
var _last_biome: int = -1

func _chunk_prepare_task(key: Vector2i, chunk_data: RefCounted,
		tile_grid: PackedInt32Array, height_grid: PackedInt32Array,
		grid_min_x: int, grid_min_z: int, grid_w: int, p_world_seed: int) -> void:
	var terrain_res: Dictionary = ChunkRenderer.prepare_terrain(
			chunk_data, tile_grid, height_grid, grid_min_x, grid_min_z, grid_w, p_world_seed)
	_chunk_build_mutex.lock()
	_chunk_build_results.append({ "key": key, "chunk_data": chunk_data, "terrain_res": terrain_res })
	_chunk_build_mutex.unlock()

func _kick_chunk_jobs() -> void:
	var pcx: int = _last_player_chunk.x
	var pcz: int = _last_player_chunk.y
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

		_ensure_tile_data_around(key)
		var snap := snapshot_tile_grid_for(key)

		if not _chunk_data_cache.has(key) or not _chunk_data_cache[key].has_entities:
			if _is_infinite:
				_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk(key.x, key.y, _world_seed)
			else:
				_chunk_data_cache[key] = _world_map.get_chunk_data(key.x, key.y)
		var chunk_data: RefCounted = _chunk_data_cache[key]

		_chunk_data_pending[key] = true
		_chunk_build_queue.remove_at(i)
		_chunk_queued.erase(key)
		var task_id: int = WorkerThreadPool.add_task(_chunk_prepare_task.bind(
				key, chunk_data, snap[0], snap[1], snap[2], snap[3], snap[4], _world_seed))
		_chunk_task_ids.append(task_id)
		_chunk_task_id_map[key] = task_id

func _commit_chunk_results() -> void:
	_chunk_build_mutex.lock()
	if _chunk_build_results.is_empty():
		_chunk_build_mutex.unlock()
		return
	var result: Dictionary = _chunk_build_results.pop_front()
	_chunk_build_mutex.unlock()

	var key: Vector2i = result["key"]
	_chunk_data_pending.erase(key)
	if _chunk_task_id_map.has(key):
		var done_id: int = _chunk_task_id_map[key]
		WorkerThreadPool.wait_for_task_completion(done_id)
		_chunk_task_ids.erase(done_id)
		_chunk_task_id_map.erase(key)

	if _chunk_renderers.has(key):
		return
	if abs(key.x - _last_player_chunk.x) > LOAD_RADIUS or abs(key.y - _last_player_chunk.y) > LOAD_RADIUS:
		return

	var chunk: RefCounted = result["chunk_data"]
	var renderer: ChunkRenderer = ChunkRenderer.new()
	renderer.name = "Chunk_%d_%d" % [key.x, key.y]
	add_child(renderer)
	renderer.build_visual(chunk, key, _world_scene, _terrain_mat, result["terrain_res"])
	_chunk_renderers[key] = renderer
	_pending_physics.append(renderer)
	chunk_committed.emit(key, chunk)

func _build_chunk_sync(key: Vector2i) -> void:
	if _chunk_renderers.has(key):
		return
	_ensure_tile_data_around(key)
	var snap := snapshot_tile_grid_for(key)
	if not _chunk_data_cache.has(key) or not _chunk_data_cache[key].has_entities:
		if _is_infinite:
			_chunk_data_cache[key] = InfiniteWorldGen.generate_chunk(key.x, key.y, _world_seed)
		else:
			_chunk_data_cache[key] = _world_map.get_chunk_data(key.x, key.y)
	var chunk: RefCounted = _chunk_data_cache[key]
	var terrain_res: Dictionary = ChunkRenderer.prepare_terrain(chunk, snap[0], snap[1], snap[2], snap[3], snap[4], _world_seed)
	var renderer: ChunkRenderer = ChunkRenderer.new()
	renderer.name = "Chunk_%d_%d" % [key.x, key.y]
	add_child(renderer)
	renderer.build_visual(chunk, key, _world_scene, _terrain_mat, terrain_res)
	renderer.build_physics()
	_chunk_renderers[key] = renderer
	_chunk_queued.erase(key)
	chunk_committed.emit(key, chunk)
