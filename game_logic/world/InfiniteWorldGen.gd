extends RefCounted

const ChunkData = preload("res://game_logic/world/ChunkData.gd")
const BiomeDef  = preload("res://game_logic/world/BiomeDef.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

const CHUNK_SIZE: int = 16
const TILE_SIZE: float = 2.0

# Base noise frequency — biome freq_scale multiplies the sampling coordinates
const NOISE_FREQ: float = 0.08

# Low-frequency biome noise (large-scale regions)
const BIOME_NOISE_FREQ: float = 0.015
# Chunks within this Manhattan distance of origin are always Grasslands
const SAFE_ZONE_DIST: int = 5

# ── Terrain noise (cached per seed) ────────────────────────────────────────
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

# ── Biome noise (cached per seed, separate from terrain noise) ─────────────
static var _biome_noise: FastNoiseLite
static var _biome_noise_seed: int = -1

# When >= 0, overrides the safe-zone biome so the player starts in the chosen biome.
# Set by WorldScene._ready() from SaveManager.starting_biome before any chunks are generated.
static var forced_start_biome: int = -1

static func _get_biome_noise(world_seed: int) -> FastNoiseLite:
	if _biome_noise != null and _biome_noise_seed == world_seed:
		return _biome_noise
	_biome_noise = FastNoiseLite.new()
	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_biome_noise.seed = world_seed + 999983
	_biome_noise.frequency = BIOME_NOISE_FREQ
	_biome_noise_seed = world_seed
	return _biome_noise

# Returns the biome ID for a given chunk coordinate.
static func biome_for_chunk(p_cx: int, p_cz: int, world_seed: int) -> int:
	var dist: int = abs(p_cx) + abs(p_cz)
	if dist <= SAFE_ZONE_DIST:
		# Respect biome selection: use forced_start_biome if set, else default to Grasslands.
		return forced_start_biome if forced_start_biome >= 0 else BiomeDef.GRASSLANDS
	var n: float = _get_biome_noise(world_seed).get_noise_2d(float(p_cx), float(p_cz))
	var v: float = (n + 1.0) * 0.5   # remap [-1,1] → [0,1]
	return int(v * float(BiomeDef.COUNT)) % BiomeDef.COUNT

static func _chunk_seed(p_cx: int, p_cz: int, world_seed: int) -> int:
	return (p_cx * 73856093) ^ (p_cz * 19349663) ^ world_seed

# ── Landmark placement ─────────────────────────────────────────────────────
# ~1 in LANDMARK_RARITY chunks hosts a mega-landmark (colossus, spire, etc.)
const LANDMARK_RARITY: int = 50
# Skip landmark placement within this Manhattan radius of origin (safe zone)
const LANDMARK_SAFE_DIST: int = 3
# Footprint half-size (tiles): landmark reserves a (2*FP+1) × (2*FP+1) area
const LANDMARK_FP: int = 2

# Biome → variant name (one per biome; deterministic from biome id)
const LANDMARK_VARIANTS: Array[String] = [
	"obelisk_ring",       # GRASSLANDS
	"stone_head",         # FOREST
	"kneeling_colossus",  # DESERT
	"shattered_spire",    # SCORCHED
	"broken_arch",        # MOUNTAINS
]

# Returns the landmark data dict for this chunk, or {} if none.
# Pure function — identical inputs always produce identical output.
static func landmark_for_chunk(p_cx: int, p_cz: int, world_seed: int) -> Dictionary:
	# Skip safe zone
	var dist: int = abs(p_cx) + abs(p_cz)
	if dist <= LANDMARK_SAFE_DIST:
		return {}
	# Independent hash so we never disturb existing RNG streams
	var h: int = (p_cx * 16769023) ^ (p_cz * 6972593) ^ world_seed
	h = h & 0x7FFFFFFF
	# Rarity gate
	if h % LANDMARK_RARITY != 7:
		return {}
	# Skip ruin chunks — replicate _gen_ruins RNG check (mask to 31-bit for portability)
	var ruin_rng := RandomNumberGenerator.new()
	ruin_rng.seed = (_chunk_seed(p_cx, p_cz, world_seed) + 2) & 0x7FFFFFFF
	if ruin_rng.randi_range(0, 2) == 0:
		return {}
	# Determine variant from biome
	var biome: int = biome_for_chunk(p_cx, p_cz, world_seed)
	var variant: String = LANDMARK_VARIANTS[biome % LANDMARK_VARIANTS.size()]
	var lid: String = "landmark_%d_%d" % [p_cx, p_cz]
	# Centre tile of chunk
	var tx: int = CHUNK_SIZE / 2
	var tz: int = CHUNK_SIZE / 2
	var wx: float = float(p_cx * CHUNK_SIZE + tx) * TILE_SIZE + TILE_SIZE * 0.5
	var wz: float = float(p_cz * CHUNK_SIZE + tz) * TILE_SIZE + TILE_SIZE * 0.5
	return {
		"id": lid,
		"variant": variant,
		"biome": biome,
		"tx": tx,
		"tz": tz,
		"x": wx,
		"z": wz,
		"cx": p_cx,
		"cz": p_cz,
	}

static func _gen_landmarks(chunk: RefCounted, p_cx: int, p_cz: int, world_seed: int) -> void:
	var data: Dictionary = landmark_for_chunk(p_cx, p_cz, world_seed)
	if data.is_empty():
		return
	var tx: int = int(data["tx"])
	var tz: int = int(data["tz"])
	# Stamp footprint tiles to TILE_GRASS so terrain is flat under the structure
	for dz: int in range(-LANDMARK_FP, LANDMARK_FP + 1):
		for dx: int in range(-LANDMARK_FP, LANDMARK_FP + 1):
			var ltx: int = tx + dx
			var ltz: int = tz + dz
			chunk.set_tile(ltx, ltz, IsoConst.TILE_GRASS)
			chunk.set_height(ltx, ltz, 0)
	chunk.landmarks.append(data)

# Approximately 1 in SCROLL_CHUNK_RARITY chunks gets an infinite-world scroll.
const SCROLL_CHUNK_RARITY: int = 200

# Returns the scroll_id to place in this chunk, or "" if none.
# Deterministic: same cx/cz/world_seed always produces the same result.
static func get_chunk_scroll_id(p_cx: int, p_cz: int, world_seed: int) -> String:
	var h: int = _chunk_seed(p_cx, p_cz, world_seed)
	h = h & 0x7FFFFFFF  # ensure positive
	if h % SCROLL_CHUNK_RARITY != 0:
		return ""
	var eligible: Array[String] = ["scroll_martarquas_survivors"]
	return eligible[h % eligible.size()]

# Generate full chunk with entities
static func generate_chunk(p_cx: int, p_cz: int, world_seed: int) -> RefCounted:
	var chunk := _gen_tile_data(p_cx, p_cz, world_seed)
	_gen_ruins(chunk, p_cx, p_cz, world_seed)
	_gen_landmarks(chunk, p_cx, p_cz, world_seed)
	_gen_entities(chunk, p_cx, p_cz, world_seed)
	chunk.is_generated = true
	chunk.has_entities = true
	return chunk

# Generate tile/height data only (no entities) — used for border ring
static func generate_chunk_data_only(p_cx: int, p_cz: int, world_seed: int) -> RefCounted:
	var chunk := _gen_tile_data(p_cx, p_cz, world_seed)
	_gen_ruins(chunk, p_cx, p_cz, world_seed)
	_gen_landmarks(chunk, p_cx, p_cz, world_seed)
	chunk.is_generated = true
	return chunk

static func _gen_tile_data(p_cx: int, p_cz: int, world_seed: int) -> RefCounted:
	var chunk: ChunkData = ChunkData.new(p_cx, p_cz)

	var biome: int = biome_for_chunk(p_cx, p_cz, world_seed)
	chunk.biome_id = biome
	var params: Dictionary = BiomeDef.PARAMS[biome]
	var hill_thresh: float = params["hill_thresh"]
	var max_hill_h: int = params["max_hill_h"]
	var freq_scale: float = params["freq_scale"]

	var noise: FastNoiseLite = _get_noise(world_seed)

	for lz in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var wtx: int = p_cx * CHUNK_SIZE + lx
			var wtz: int = p_cz * CHUNK_SIZE + lz
			# Scale coordinates to simulate frequency variation per biome without mutating shared noise
			var n: float = noise.get_noise_2d(float(wtx) * freq_scale, float(wtz) * freq_scale)
			var v: float = (n + 1.0) * 0.5   # remap [-1,1] → [0,1]

			if v >= hill_thresh:
				chunk.set_tile(lx, lz, IsoConst.TILE_HILL)
				# Power-curve: most hills short, rare tall peaks up to max_hill_h
				var hill_factor: float = clamp((v - hill_thresh) / (1.0 - hill_thresh), 0.0, 1.0)
				var hill_h: int = 1 + int(pow(hill_factor, 2.5) * float(max_hill_h - 1))
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

	# Register each wall opening as a door entity pointing to a procedural dungeon
	for door_pos in doors:
		var wx: float = float(p_cx * CHUNK_SIZE + door_pos.x) * TILE_SIZE + TILE_SIZE * 0.5
		var wz: float = float(p_cz * CHUNK_SIZE + door_pos.y) * TILE_SIZE + TILE_SIZE * 0.5
		var dungeon_seed: int = abs(_chunk_seed(p_cx, p_cz, world_seed) ^ (door_pos.x * 1000003 + door_pos.y * 999983))
		chunk.doors.append({
			"id": "door_%d_%d_%d_%d" % [p_cx, p_cz, door_pos.x, door_pos.y],
			"x": wx,
			"z": wz,
			"target_map": "dungeon_%d" % dungeon_seed,
			"target_door_id": "entrance",
		})

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

	var biome: int = biome_for_chunk(p_cx, p_cz, world_seed)
	var chunk_dist: int = abs(p_cx) + abs(p_cz)
	var etype: String = EnemyRegistry.type_for_biome(biome, chunk_dist)

	# 0–2 enemies per chunk
	var enemy_count: int = rng.randi_range(0, 2)
	var uid_base: String = "e_%d_%d_" % [p_cx, p_cz]
	for i in range(enemy_count):
		var idx: int = rng.randi_range(0, grass_tiles.size() - 1)
		var tile: Vector2i = grass_tiles[idx]
		var wx: float = float(p_cx * CHUNK_SIZE + tile.x) * TILE_SIZE + TILE_SIZE * 0.5
		var wz: float = float(p_cz * CHUNK_SIZE + tile.y) * TILE_SIZE + TILE_SIZE * 0.5
		chunk.enemies.append({
			"id": uid_base + str(i),
			"x": wx, "z": wz,
			"alive": true, "tracking": EnemyRegistry.is_tracking(etype),
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

	# 0–1 NPC per chunk (~25% chance), dialogue chosen per biome
	if rng.randi_range(0, 3) == 0 and grass_tiles.size() > 0:
		var idx: int = rng.randi_range(0, grass_tiles.size() - 1)
		var tile: Vector2i = grass_tiles[idx]
		var wx: float = float(p_cx * CHUNK_SIZE + tile.x) * TILE_SIZE + TILE_SIZE * 0.5
		var wz: float = float(p_cz * CHUNK_SIZE + tile.y) * TILE_SIZE + TILE_SIZE * 0.5
		var lines: Array = BiomeDef.NPC_LINES[biome]
		var dialogue: String = lines[rng.randi_range(0, lines.size() - 1)]
		chunk.npcs.append({
			"id": "n_%d_%d_0" % [p_cx, p_cz],
			"x": wx, "z": wz,
			"dialogue": dialogue,
		})

	# 0–1 Merchant per chunk (~5% chance) — grasslands and forest biomes only
	if (biome == BiomeDef.GRASSLANDS or biome == BiomeDef.FOREST) \
			and rng.randi_range(0, 19) == 0 and grass_tiles.size() > 0:
		var idx: int = rng.randi_range(0, grass_tiles.size() - 1)
		var tile: Vector2i = grass_tiles[idx]
		var wx: float = float(p_cx * CHUNK_SIZE + tile.x) * TILE_SIZE + TILE_SIZE * 0.5
		var wz: float = float(p_cz * CHUNK_SIZE + tile.y) * TILE_SIZE + TILE_SIZE * 0.5
		chunk.npcs.append({
			"id": "m_%d_%d_0" % [p_cx, p_cz],
			"x": wx, "z": wz,
			"dialogue": "Welcome, traveller! Browse my wares.",
			"npc_type": "merchant",
		})

	# 0–1 Burial mound per chunk (~10% chance) — skeleton dig cantrip target
	var mound_rng := RandomNumberGenerator.new()
	mound_rng.seed = _chunk_seed(p_cx, p_cz, world_seed) + 13
	if mound_rng.randi_range(0, 9) == 0 and grass_tiles.size() > 0:
		var idx: int = mound_rng.randi_range(0, grass_tiles.size() - 1)
		var tile: Vector2i = grass_tiles[idx]
		var wx: float = float(p_cx * CHUNK_SIZE + tile.x) * TILE_SIZE + TILE_SIZE * 0.5
		var wz: float = float(p_cz * CHUNK_SIZE + tile.y) * TILE_SIZE + TILE_SIZE * 0.5
		chunk.burial_mounds.append({
			"id": "mound_%d_%d_0" % [p_cx, p_cz],
			"x": wx, "z": wz,
		})

	# 0–1 Waystone per ~40 chunks (2.5% chance) on a walkable grass tile
	var waystone_rng := RandomNumberGenerator.new()
	waystone_rng.seed = _chunk_seed(p_cx, p_cz, world_seed) + 7
	if waystone_rng.randi_range(0, 39) == 0 and grass_tiles.size() > 0:
		var idx: int = waystone_rng.randi_range(0, grass_tiles.size() - 1)
		var tile: Vector2i = grass_tiles[idx]
		var wtx: int = p_cx * CHUNK_SIZE + tile.x
		var wtz: int = p_cz * CHUNK_SIZE + tile.y
		var wx: float = float(wtx) * TILE_SIZE + TILE_SIZE * 0.5
		var wz: float = float(wtz) * TILE_SIZE + TILE_SIZE * 0.5
		chunk.waystones.append({
			"id": "world:%d:%d" % [wtx, wtz],
			"x": wx, "z": wz,
			"label": "Waystone (%d, %d)" % [wtx, wtz],
			"active": false,
		})
