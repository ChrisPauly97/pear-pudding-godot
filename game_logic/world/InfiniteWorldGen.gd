extends RefCounted

const CHUNK_SIZE: int = 16
const TILE_SIZE: float = 2.0

# Noise thresholds: value is noise mapped to [0, 1]
const WALL_THRESHOLD: float = 0.60
const HILL_THRESHOLD: float = 0.56

# Per-chunk noise frequency
const NOISE_FREQ: float = 0.08

# Cached noise object — same seed & frequency every call, no need to re-create
static var _cached_noise: FastNoiseLite
static var _cached_noise_seed: int = -1

static func _get_noise(world_seed: int) -> FastNoiseLite:
	if _cached_noise != null and _cached_noise_seed == world_seed:
		return _cached_noise
	_cached_noise = FastNoiseLite.new()
	_cached_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_cached_noise.seed = world_seed
	_cached_noise.frequency = NOISE_FREQ
	_cached_noise_seed = world_seed
	return _cached_noise

static func _chunk_seed(p_cx: int, p_cz: int, world_seed: int) -> int:
	return (p_cx * 73856093) ^ (p_cz * 19349663) ^ world_seed

# Generate full chunk with entities
static func generate_chunk(p_cx: int, p_cz: int, world_seed: int) -> RefCounted:
	var chunk := _gen_tile_data(p_cx, p_cz, world_seed)
	_gen_ruins(chunk, p_cx, p_cz, world_seed)
	_gen_entities(chunk, p_cx, p_cz, world_seed)
	chunk.is_generated = true
	chunk.has_entities = true
	return chunk

# Generate tile/height data only (no entities) — used for border ring
static func generate_chunk_data_only(p_cx: int, p_cz: int, world_seed: int) -> RefCounted:
	var chunk := _gen_tile_data(p_cx, p_cz, world_seed)
	_gen_ruins(chunk, p_cx, p_cz, world_seed)
	chunk.is_generated = true
	return chunk

static func _gen_tile_data(p_cx: int, p_cz: int, world_seed: int) -> RefCounted:
	const ChunkData = preload("res://game_logic/world/ChunkData.gd")
	var chunk: ChunkData = ChunkData.new(p_cx, p_cz)

	var noise: FastNoiseLite = _get_noise(world_seed)

	for lz in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var wtx: int = p_cx * CHUNK_SIZE + lx
			var wtz: int = p_cz * CHUNK_SIZE + lz
			# noise returns [-1, 1] — remap to [0, 1]
			var n: float = noise.get_noise_2d(float(wtx), float(wtz))
			var v: float = (n + 1.0) * 0.5

			# Walls no longer spawned from noise — ruins are stamped in _gen_ruins instead
			if v >= HILL_THRESHOLD:
				chunk.set_tile(lx, lz, IsoConst.TILE_HILL)
				# Power-curve distribution: most hills short, rare tall mountains
				# Clamp to [0,1] — noise above WALL_THRESHOLD would overflow without this
				var hill_factor: float = clamp((v - HILL_THRESHOLD) / (WALL_THRESHOLD - HILL_THRESHOLD), 0.0, 1.0)
				var hill_h: int = 1 + int(pow(hill_factor, 2.5) * 4.0)
				chunk.set_height(lx, lz, hill_h)
			else:
				chunk.set_tile(lx, lz, IsoConst.TILE_GRASS)
				chunk.set_height(lx, lz, 0)

	return chunk

static func _gen_ruins(chunk: RefCounted, p_cx: int, p_cz: int, world_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(p_cx, p_cz, world_seed) + 2

	# ~33% chance of a ruin per chunk
	if rng.randi_range(0, 2) != 0:
		return

	# Inner size: 3x3 to 6x6 tiles; outer includes the wall ring
	var inner_w: int = rng.randi_range(3, 6)
	var inner_h: int = rng.randi_range(3, 6)
	var outer_w: int = inner_w + 2
	var outer_h: int = inner_h + 2

	# Ensure the structure fits with a margin from chunk edges
	const MARGIN: int = 2
	if outer_w + MARGIN * 2 > CHUNK_SIZE or outer_h + MARGIN * 2 > CHUNK_SIZE:
		return

	var sx: int = rng.randi_range(MARGIN, CHUNK_SIZE - outer_w - MARGIN)
	var sz: int = rng.randi_range(MARGIN, CHUNK_SIZE - outer_h - MARGIN)

	# Wall heights: base 4–6 levels, corner towers get an extra 1–3 on top
	var base_h: int = rng.randi_range(4, 6)
	var corner_bonus: int = rng.randi_range(1, 3)

	# Pick 1–2 door openings on the perimeter (not at corners)
	var doors: Array[Vector2i] = []
	var possible_doors: Array[Vector2i] = []
	for i in range(1, outer_w - 1):
		possible_doors.append(Vector2i(sx + i, sz))
		possible_doors.append(Vector2i(sx + i, sz + outer_h - 1))
	for i in range(1, outer_h - 1):
		possible_doors.append(Vector2i(sx, sz + i))
		possible_doors.append(Vector2i(sx + outer_w - 1, sz + i))
	var door_count: int = rng.randi_range(1, 2)
	for _d in range(door_count):
		if possible_doors.is_empty():
			break
		var door_idx: int = rng.randi_range(0, possible_doors.size() - 1)
		doors.append(possible_doors[door_idx])
		possible_doors.remove_at(door_idx)

	# Stamp the ruin — perimeter walls, flat interior floor
	for lx in range(outer_w):
		for lz in range(outer_h):
			var tx: int = sx + lx
			var tz: int = sz + lz
			var on_perimeter: bool = lx == 0 or lx == outer_w - 1 or lz == 0 or lz == outer_h - 1

			if not on_perimeter:
				# Interior: clear to flat grass so the floor is walkable
				chunk.set_tile(tx, tz, IsoConst.TILE_GRASS)
				chunk.set_height(tx, tz, 0)
				continue

			var pos: Vector2i = Vector2i(tx, tz)
			if pos in doors:
				# Door opening — leave as grass
				chunk.set_tile(tx, tz, IsoConst.TILE_GRASS)
				chunk.set_height(tx, tz, 0)
				continue

			var is_corner: bool = (lx == 0 or lx == outer_w - 1) and (lz == 0 or lz == outer_h - 1)
			if is_corner:
				# Corner towers are always intact and slightly taller
				chunk.set_tile(tx, tz, IsoConst.TILE_WALL)
				chunk.set_height(tx, tz, base_h + corner_bonus)
			else:
				# 80% of wall segments remain; the rest have crumbled
				if rng.randf() < 0.80:
					var wall_h: int = base_h + rng.randi_range(-1, 1)
					chunk.set_tile(tx, tz, IsoConst.TILE_WALL)
					chunk.set_height(tx, tz, maxi(2, wall_h))
				else:
					chunk.set_tile(tx, tz, IsoConst.TILE_GRASS)
					chunk.set_height(tx, tz, 0)

static func _gen_entities(chunk: RefCounted, p_cx: int, p_cz: int, world_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(p_cx, p_cz, world_seed) + 1

	# Collect GRASS tiles not adjacent to walls
	var grass_tiles: Array[Vector2i] = []
	for lz in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			if chunk.get_tile(lx, lz) != IsoConst.TILE_GRASS:
				continue
			var adj_wall: bool = false
			for nb in [Vector2i(lx+1, lz), Vector2i(lx-1, lz), Vector2i(lx, lz+1), Vector2i(lx, lz-1)]:
				var t: int = chunk.get_tile(nb.x, nb.y)
				if t == IsoConst.TILE_WALL:
					adj_wall = true
					break
			if not adj_wall:
				grass_tiles.append(Vector2i(lx, lz))

	if grass_tiles.is_empty():
		return

	# 0–2 enemies per chunk, type scaled by Manhattan distance from origin
	var enemy_count: int = rng.randi_range(0, 2)
	var uid_base: String = "e_%d_%d_" % [p_cx, p_cz]
	var chunk_dist: int = abs(p_cx) + abs(p_cz)
	var etype: String = EnemyRegistry.type_for_chunk_dist(chunk_dist)
	for i in range(enemy_count):
		var idx: int = rng.randi_range(0, grass_tiles.size() - 1)
		var tile: Vector2i = grass_tiles[idx]
		var wx: float = float(p_cx * CHUNK_SIZE + tile.x) * TILE_SIZE + TILE_SIZE * 0.5
		var wz: float = float(p_cz * CHUNK_SIZE + tile.y) * TILE_SIZE + TILE_SIZE * 0.5
		chunk.enemies.append({
			"id": uid_base + str(i),
			"x": wx, "z": wz,
			"alive": true, "tracking": true,
			"enemy_type": etype,
			"enemy_deck": EnemyRegistry.get_deck(etype),
		})

	# 0–1 chest per chunk
	if rng.randi_range(0, 2) == 0 and grass_tiles.size() > enemy_count:
		var idx: int = rng.randi_range(0, grass_tiles.size() - 1)
		var tile: Vector2i = grass_tiles[idx]
		var wx: float = float(p_cx * CHUNK_SIZE + tile.x) * TILE_SIZE + TILE_SIZE * 0.5
		var wz: float = float(p_cz * CHUNK_SIZE + tile.y) * TILE_SIZE + TILE_SIZE * 0.5
		var card_ids: Array[String] = ["ghost", "skeleton", "zombie", "ghoul"]
		var cid: String = card_ids[rng.randi_range(0, card_ids.size() - 1)]
		chunk.chests.append({
			"id": "c_%d_%d_0" % [p_cx, p_cz],
			"x": wx, "z": wz,
			"card_ids": [cid],
			"opened": false
		})
