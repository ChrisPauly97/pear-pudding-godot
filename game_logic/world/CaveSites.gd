## Cave entrances in the infinite overworld (GID-173 / TID-699).
##
## Some chunks in rocky country get a cave mouth at the foot of their highest hill: a door entity
## on the first level tile below the peak (walking toward the camera), facing up into the hill, whose target is a
## cave-themed procedural dungeon (`dungeon_cave_<seed>` — the `dungeon_` prefix keeps every
## existing dungeon path working; DungeonGen picks the cave layout from the name). Caves are the
## way underground; ruins are scenery (TID-702).
##
## Pure static logic (runs on the chunk worker threads); deterministic per world seed.
extends RefCounted

const IsoConst = preload("res://autoloads/IsoConst.gd")  # usable before autoloads register (-s runs)
const _ChunkData = preload("res://game_logic/world/ChunkData.gd")
const _BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _RuinGen = preload("res://game_logic/world/RuinGen.gd")

## One chunk in N gets a cave, per biome (absent = never).
const ONE_IN: Dictionary = {_BiomeDef.MOUNTAINS: 5, _BiomeDef.SCORCHED: 7, _BiomeDef.FOREST: 16}
## The hill the cave runs into must peak at least this many levels high.
const MIN_PEAK: int = 1
## Keep the mouth this many tiles inside the chunk, so the approach tiles are in it too.
const EDGE_MARGIN: int = 2
const MAP_PREFIX: String = "dungeon_cave_"
## Into-the-hill directions tried. Only +X and +Z: the iso camera looks along (−1, −1, −1), so a
## mouth facing those ways opens toward the viewer (one facing −X / −Z would show the hill's back).
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]


## Adds chunk (cx, cz)'s cave entrance to its doors, if it has one. Call after the tiles,
## ruin and landmark are in (`chunk_seed` = InfiniteWorldGen's per-chunk seed).
static func add_to(chunk: _ChunkData, p_cx: int, p_cz: int, chunk_seed: int) -> void:
	var site: Dictionary = site_for(chunk, p_cx, p_cz, chunk_seed)
	if not site.is_empty():
		chunk.doors.append(site)


## The cave door dict for this chunk, or {}: `id`, `x`, `z` (world, the approach tile's centre),
## `target_map`, `target_door_id`, `kind` "cave", `facing` [dx, dz] (into the hill), `face_height`.
static func site_for(chunk: _ChunkData, p_cx: int, p_cz: int, chunk_seed: int) -> Dictionary:
	var n: int = int(ONE_IN.get(chunk.biome_id, 0))
	if n <= 0:
		return {}
	var h: int = absi((chunk_seed * 2654435761) ^ 0x5CA7E) & 0x7FFFFFFF
	if h % n != 0:
		return {}
	if not chunk.landmarks.is_empty() or _RuinGen.has_ruin(p_cx, p_cz, chunk_seed):
		return {}
	if _RealmLayout.chunk_touches_realm(p_cx, p_cz):
		return {}
	for peak: Vector2i in _peaks(chunk):
		for d: Vector2i in DIRS:
			var mouth: Vector2i = _foot_below(chunk, peak, d)
			if mouth.x >= 0:
				return _door(chunk, p_cx, p_cz, chunk_seed, peak, mouth, d)
	return {}


static func _door(chunk: _ChunkData, p_cx: int, p_cz: int, chunk_seed: int, peak: Vector2i,
		mouth: Vector2i, d: Vector2i) -> Dictionary:
	var cs: int = IsoConst.CHUNK_SIZE
	var cave_seed: int = absi(chunk_seed ^ (mouth.x * 7919 + mouth.y * 104729)) & 0x7FFFFFFF
	return {
		"id": "cave_%d_%d" % [p_cx, p_cz],
		"x": IsoConst.tile_center(p_cx * cs + mouth.x),
		"z": IsoConst.tile_center(p_cz * cs + mouth.y),
		"target_map": MAP_PREFIX + str(cave_seed),
		"target_door_id": "entrance",
		"kind": "cave",
		"facing": [d.x, d.y],
		"face_height": chunk.get_height(peak.x, peak.y),
	}


## True when map `map_name` is a cave interior.
static func is_cave_map(map_name: String) -> bool:
	return map_name.begins_with(MAP_PREFIX)


## The chunk's hill tiles at least MIN_PEAK high, tallest first (scan order on a tie).
static func _peaks(chunk: _ChunkData) -> Array[Vector2i]:
	var cs: int = IsoConst.CHUNK_SIZE
	var out: Array[Vector2i] = []
	for z: int in range(cs):
		for x: int in range(cs):
			if chunk.get_tile(x, z) == IsoConst.TILE_HILL and chunk.get_height(x, z) >= MIN_PEAK:
				out.append(Vector2i(x, z))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ha: int = chunk.get_height(a.x, a.y)
		var hb: int = chunk.get_height(b.x, b.y)
		return ha > hb or (ha == hb and a.y * cs + a.x < b.y * cs + b.x))
	return out


## Walking down from `peak` against `d` (toward the camera): the first level grass tile, if the walk
## stays on hill until it, has level grass behind it too, and both lie EDGE_MARGIN inside the chunk;
## else (-1, -1). That tile is the cave approach, facing `d` up into the hill.
static func _foot_below(chunk: _ChunkData, peak: Vector2i, d: Vector2i) -> Vector2i:
	var cs: int = IsoConst.CHUNK_SIZE
	var t: Vector2i = peak - d
	while t.x >= EDGE_MARGIN and t.y >= EDGE_MARGIN and t.x < cs - EDGE_MARGIN and t.y < cs - EDGE_MARGIN:
		var tile: int = chunk.get_tile(t.x, t.y)
		if tile == IsoConst.TILE_GRASS and chunk.get_height(t.x, t.y) == 0:
			var back: Vector2i = t - d
			if back.x < EDGE_MARGIN or back.y < EDGE_MARGIN:
				return Vector2i(-1, -1)
			if chunk.get_tile(back.x, back.y) != IsoConst.TILE_GRASS or chunk.get_height(back.x, back.y) != 0:
				return Vector2i(-1, -1)
			return t
		if tile != IsoConst.TILE_HILL:
			return Vector2i(-1, -1)
		t -= d
	return Vector2i(-1, -1)
