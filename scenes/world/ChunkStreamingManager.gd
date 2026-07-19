extends Node3D

const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const ChunkRenderer    = preload("res://scenes/world/ChunkRenderer.gd")
const GrassBlades      = preload("res://scenes/world/GrassBlades.gd")
const TerrainMath      = preload("res://game_logic/TerrainMath.gd")

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
# Kicking a job does main-thread prep (3×3 neighbour tile gen, 529-tile
# snapshot, entity generation) — cap how many kicks land on one frame so a
# chunk-boundary crossing doesn't stack up to 4 preps in a single frame.
# Workers still saturate within 2 frames.
const MAX_KICKS_PER_FRAME: int = 2

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
var _chunk_build_queue: Array[Vector2i] = []
var _last_player_chunk: Vector2i = Vector2i(-9999, -9999)
# Renderers whose visual is live but physics build is deferred to a later
# frame (ChunkRenderer phase 2) — drained one per frame by process_streaming.
var _physics_pending: Array[ChunkRenderer] = []

# Direction-change throttle for re-triggering chunk updates mid-turn
var _last_move_dir: Vector2 = Vector2.ZERO
var _last_dir_update_time: float = -999.0

# ── Height-query grid cache (GID-121 / TID-460) ────────────────────────────────
# Packed tile/height snapshot answering steady-state get_height_world() calls via
# direct array indexing instead of ~49 Callable → Dictionary lookups per query.
# Infinite worlds: covers the player's chunk ±1, refreshed on chunk crossing.
# Named maps: covers the whole map + margin, built once at setup.
var _hq_tiles: PackedInt32Array = PackedInt32Array()
var _hq_heights: PackedInt32Array = PackedInt32Array()
var _hq_min_x: int = 0
var _hq_min_z: int = 0
var _hq_w: int = 0                       # 0 = cache not built
var _hq_center: Vector2i = Vector2i(-9999, -9999)  # player chunk the window is centred on
# Point queries scan tiles vtx±_hq_tc — must match TerrainMath.get_height_at.
var _hq_tc: int = int(ceil(IsoConst.HILL_CURVE_R / IsoConst.TILE_SIZE)) + 1

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
	if not _is_infinite:
		# Named maps never change size — snapshot the whole map (plus margin) once.
		_refresh_height_query_grid()

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
	_drain_deferred_physics()
	_commit_chunk_results()

## Build physics for at most one committed chunk per frame. Splitting the
## heightmap-collision + wall-box creation off the commit frame halves the
## worst-case frame cost of a chunk landing (ChunkRenderer phase 1/2 design).
func _drain_deferred_physics() -> void:
	while not _physics_pending.is_empty():
		var renderer: ChunkRenderer = _physics_pending.pop_front()
		if is_instance_valid(renderer) and not renderer.is_queued_for_deletion():
			renderer.build_physics()
			return

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
	var grid_min_x: int = key.x * IsoConst.CHUNK_SIZE - TILE_CHECK
	var grid_min_z: int = key.y * IsoConst.CHUNK_SIZE - TILE_CHECK
	var grid_w: int = IsoConst.CHUNK_SIZE + TILE_CHECK * 2 + 1
	var snap: Array = _snapshot_region(grid_min_x, grid_min_z, grid_w, grid_w)
	return [snap[0], snap[1], grid_min_x, grid_min_z, grid_w]

## Copies the w×h tile/height region starting at global tile (min_tx, min_tz) into
## packed arrays. Infinite path: block-copies straight out of each covered
## ChunkData's PackedInt32Arrays — one cache lookup per chunk instead of two global
## lookups (float div + Vector2i + Dictionary + dynamic call) per tile, which made
## the old per-tile loop a per-kick main-thread hitch (GID-121 / TID-459).
## Missing chunks are generated tile-only into the cache, exactly like
## get_tile_global. Returns [tile_grid: PackedInt32Array, height_grid: PackedInt32Array].
func _snapshot_region(min_tx: int, min_tz: int, w: int, h: int) -> Array:
	var tile_grid := PackedInt32Array()
	var height_grid := PackedInt32Array()
	tile_grid.resize(w * h)
	height_grid.resize(w * h)

	if not _is_infinite:
		# Named maps: startup-only path; call the WorldMap accessors directly
		# (nested-Array storage, no packed source to block-copy from).
		for gz in range(h):
			var row: int = gz * w
			var wtz: int = min_tz + gz
			for gx in range(w):
				tile_grid[row + gx] = _world_map.get_tile(min_tx + gx, wtz)
				height_grid[row + gx] = _world_map.get_height(min_tx + gx, wtz)
		return [tile_grid, height_grid]

	var cs: int = IsoConst.CHUNK_SIZE
	var cx0: int = int(floor(float(min_tx) / float(cs)))
	var cz0: int = int(floor(float(min_tz) / float(cs)))
	var cx1: int = int(floor(float(min_tx + w - 1) / float(cs)))
	var cz1: int = int(floor(float(min_tz + h - 1) / float(cs)))
	for ccz in range(cz0, cz1 + 1):
		for ccx in range(cx0, cx1 + 1):
			var ckey := Vector2i(ccx, ccz)
			if not _chunk_data_cache.has(ckey):
				_chunk_data_cache[ckey] = InfiniteWorldGen.generate_chunk_data_only(ccx, ccz, _world_seed)
			var chunk: RefCounted = _chunk_data_cache[ckey]
			var src_tiles: PackedInt32Array = chunk.tiles
			var src_heights: PackedInt32Array = chunk.heights
			# Overlap of this chunk's tile range with the requested region,
			# in chunk-local coordinates.
			var lx0: int = maxi(min_tx - ccx * cs, 0)
			var lz0: int = maxi(min_tz - ccz * cs, 0)
			var lx1: int = mini(min_tx + w - ccx * cs, cs)
			var lz1: int = mini(min_tz + h - ccz * cs, cs)
			for lz in range(lz0, lz1):
				var src_row: int = lz * cs
				var dst_row: int = (ccz * cs + lz - min_tz) * w + (ccx * cs - min_tx)
				for lx in range(lx0, lx1):
					tile_grid[dst_row + lx] = src_tiles[src_row + lx]
					height_grid[dst_row + lx] = src_heights[src_row + lx]
	return [tile_grid, height_grid]

## Rebuilds the height-query grid cache. Infinite worlds: player chunk ±1.
## Named maps: whole map + a TILE_CHECK margin (out-of-bounds cells read through
## WorldMap.get_tile/get_height, which return TILE_WALL/1 — the same fallbacks
## TerrainMath.get_height_at_grid uses, so results are identical everywhere).
func _refresh_height_query_grid() -> void:
	if _is_infinite:
		if _last_player_chunk == Vector2i(-9999, -9999):
			return
		var cs: int = IsoConst.CHUNK_SIZE
		_hq_min_x = (_last_player_chunk.x - 1) * cs
		_hq_min_z = (_last_player_chunk.y - 1) * cs
		_hq_w = cs * 3
		_hq_center = _last_player_chunk
	else:
		if _world_map == null:
			return
		var tc: int = ChunkRenderer.TILE_CHECK
		var side: int = maxi(int(_world_map.MAP_WIDTH), int(_world_map.MAP_HEIGHT)) + tc * 2
		_hq_min_x = -tc
		_hq_min_z = -tc
		_hq_w = side
	var snap: Array = _snapshot_region(_hq_min_x, _hq_min_z, _hq_w, _hq_w)
	_hq_tiles = snap[0]
	_hq_heights = snap[1]

## Terrain height at a world position. Fast path: direct packed-grid indexing when
## the query's 7×7 tile neighbourhood fits inside the cached grid (always true for
## steady-state queries near the player / anywhere on a named map). Falls back to
## the Callable path — identical results, just slower — for far-away queries such
## as entity placement during chunk commits.
func get_height_world(wx: float, wz: float) -> float:
	if _hq_w > 0:
		var vtx: int = floori(wx / IsoConst.TILE_SIZE)
		var vtz: int = floori(wz / IsoConst.TILE_SIZE)
		if vtx - _hq_tc >= _hq_min_x and vtx + _hq_tc < _hq_min_x + _hq_w \
				and vtz - _hq_tc >= _hq_min_z and vtz + _hq_tc < _hq_min_z + _hq_w:
			return TerrainMath.get_height_at_grid(wx, wz, _hq_tiles, _hq_heights,
					_hq_min_x, _hq_min_z, _hq_w,
					IsoConst.HILL_CURVE_R, IsoConst.HILL_PEAK_H)
	if _is_infinite:
		return TerrainMath.get_height_at(wx, wz, get_tile_global, get_height_global,
				IsoConst.HILL_CURVE_R, IsoConst.HILL_PEAK_H)
	return TerrainMath.get_height_at(wx, wz, _world_map.get_tile, _world_map.get_height,
			IsoConst.HILL_CURVE_R, IsoConst.HILL_PEAK_H)

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
	# Tile data changed — the height-query cache may now be stale.
	_refresh_height_query_grid()

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
	if _is_infinite and _hq_center != player_chunk:
		_refresh_height_query_grid()

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
	var kicked: int = 0
	while i < _chunk_build_queue.size():
		if _chunk_data_pending.size() >= MAX_CHUNK_JOBS or kicked >= MAX_KICKS_PER_FRAME:
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
		kicked += 1

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
	# Physics is deferred to a later frame (_drain_deferred_physics) — the
	# WorldScene software floor covers the gap if the player outruns it.
	_physics_pending.append(renderer)
	_chunk_renderers[key] = renderer
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
