extends RefCounted

const CHUNK_SIZE: int = 16
const TILE_SIZE: float = 2.0

# Noise thresholds: value is noise mapped to [0, 1]
const WALL_THRESHOLD: float = 0.60
const HILL_THRESHOLD: float = 0.40

# Per-chunk noise frequency
const NOISE_FREQ: float = 0.08

static func _chunk_seed(p_cx: int, p_cz: int, world_seed: int) -> int:
	return (p_cx * 73856093) ^ (p_cz * 19349663) ^ world_seed

# Generate full chunk with entities
static func generate_chunk(p_cx: int, p_cz: int, world_seed: int) -> RefCounted:
	var chunk := _gen_tile_data(p_cx, p_cz, world_seed)
	_gen_entities(chunk, p_cx, p_cz, world_seed)
	chunk.is_generated = true
	return chunk

# Generate tile/height data only (no entities) — used for border ring
static func generate_chunk_data_only(p_cx: int, p_cz: int, world_seed: int) -> RefCounted:
	var chunk := _gen_tile_data(p_cx, p_cz, world_seed)
	chunk.is_generated = true
	return chunk

static func _gen_tile_data(p_cx: int, p_cz: int, world_seed: int) -> RefCounted:
	const ChunkData = preload("res://game_logic/world/ChunkData.gd")
	var chunk: ChunkData = ChunkData.new(p_cx, p_cz)

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Use world_seed directly so the noise field is continuous across all chunks.
	# Per-chunk seeds broke continuity, causing abrupt terrain transitions at borders.
	noise.seed = world_seed
	noise.frequency = NOISE_FREQ

	for lz in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var wtx: int = p_cx * CHUNK_SIZE + lx
			var wtz: int = p_cz * CHUNK_SIZE + lz
			# noise returns [-1, 1] — remap to [0, 1]
			var n: float = noise.get_noise_2d(float(wtx), float(wtz))
			var v: float = (n + 1.0) * 0.5

			if v >= WALL_THRESHOLD:
				chunk.set_tile(lx, lz, IsoConst.TILE_WALL)
				var wh: int = 1 + int(v * 2.0)
				chunk.set_height(lx, lz, wh)
			elif v >= HILL_THRESHOLD:
				chunk.set_tile(lx, lz, IsoConst.TILE_HILL)
				chunk.set_height(lx, lz, 1)
			else:
				chunk.set_tile(lx, lz, IsoConst.TILE_GRASS)
				chunk.set_height(lx, lz, 0)

	return chunk

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
