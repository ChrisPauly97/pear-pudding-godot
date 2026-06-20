extends RefCounted

# Super-region is SUPER_SIZE × SUPER_SIZE chunks; each super-region may have one Blight Heart.
const SUPER_SIZE: int = 12
# Approximately 1 in HEART_DENSITY super-regions gets a heart (~33 %).
const HEART_DENSITY: int = 3
# Spread parameters — pure function of days_elapsed.
const INITIAL_RADIUS: float = 2.0   # chunks blighted on day 0
const SPREAD_RATE: float = 0.5      # additional chunks per day
const MAX_RADIUS: float = 10.0      # cap — blight never covers the whole map
# Safe zone: no hearts within this Manhattan distance of origin (matches InfiniteWorldGen.SAFE_ZONE_DIST).
const SAFE_CHUNK_RADIUS: int = 6

# Returns the super-region coordinates (sx, sz) that contain chunk (cx, cz).
static func _super_for_chunk(cx: int, cz: int) -> Vector2i:
	return Vector2i(
		int(floor(float(cx) / float(SUPER_SIZE))),
		int(floor(float(cz) / float(SUPER_SIZE))))

# Positive hash of (sx, sz, world_seed).
static func _hash_super(sx: int, sz: int, world_seed: int) -> int:
	return ((sx * 73856093) ^ (sz * 19349663) ^ world_seed) & 0x7FFFFFFF

# Returns the heart Dictionary for super-region (sx, sz), or {} if none.
# Public so InfiniteWorldGen can use it to decide whether to spawn the entity.
static func get_heart_for_super(sx: int, sz: int, world_seed: int) -> Dictionary:
	var h: int = _hash_super(sx, sz, world_seed)
	if h % HEART_DENSITY != 0:
		return {}
	# Deterministically pick a chunk within the super-region for the heart.
	var rng_h: int = ((sx * 49979693) ^ (sz * 86028121) ^ (world_seed + 1)) & 0x7FFFFFFF
	var heart_lx: int = (rng_h >> 4) % SUPER_SIZE
	var heart_lz: int = (rng_h >> 8) % SUPER_SIZE
	var heart_cx: int = sx * SUPER_SIZE + heart_lx
	var heart_cz: int = sz * SUPER_SIZE + heart_lz
	# Skip super-regions that place the heart inside the origin safe zone.
	if (abs(heart_cx) + abs(heart_cz)) <= SAFE_CHUNK_RADIUS:
		return {}
	return {
		"id": "heart_%d_%d" % [sx, sz],
		"cx": heart_cx,
		"cz": heart_cz,
	}

# Returns the heart Dictionary for the chunk that hosts a heart, or {} if chunk (cx, cz)
# is not itself the heart chunk.
static func get_heart_at_chunk(cx: int, cz: int, world_seed: int) -> Dictionary:
	var sv: Vector2i = _super_for_chunk(cx, cz)
	var heart: Dictionary = get_heart_for_super(sv.x, sv.y, world_seed)
	if heart.is_empty():
		return {}
	if int(heart.get("cx", -999)) == cx and int(heart.get("cz", -999)) == cz:
		return heart
	return {}

# Collects all active (uncleansed) hearts whose blight radius could reach chunk (cx, cz).
static func _get_hearts_in_range(cx: int, cz: int, world_seed: int, cleansed_hearts: Array) -> Array[Dictionary]:
	var hearts: Array[Dictionary] = []
	var qsx: int = int(floor(float(cx) / float(SUPER_SIZE)))
	var qsz: int = int(floor(float(cz) / float(SUPER_SIZE)))
	# How many super-regions away can a heart still reach this chunk at MAX_RADIUS?
	var search_r: int = int(ceil(MAX_RADIUS / float(SUPER_SIZE))) + 1
	for sx in range(qsx - search_r, qsx + search_r + 1):
		for sz in range(qsz - search_r, qsz + search_r + 1):
			var heart: Dictionary = get_heart_for_super(sx, sz, world_seed)
			if heart.is_empty():
				continue
			var hid: String = str(heart.get("id", ""))
			if cleansed_hearts.has(hid):
				continue
			hearts.append(heart)
	return hearts

# Current blight radius in chunk units.
static func blighted_radius(days_elapsed: int) -> float:
	return minf(INITIAL_RADIUS + float(days_elapsed) * SPREAD_RATE, MAX_RADIUS)

# Returns true if chunk (cx, cz) is within any active heart's blight radius.
static func is_blighted(cx: int, cz: int, world_seed: int, days_elapsed: int, cleansed_hearts: Array) -> bool:
	var radius: float = blighted_radius(days_elapsed)
	for h: Dictionary in _get_hearts_in_range(cx, cz, world_seed, cleansed_hearts):
		var hcx: int = int(h.get("cx", 0))
		var hcz: int = int(h.get("cz", 0))
		var dx: int = cx - hcx
		var dz: int = cz - hcz
		var dist: float = sqrt(float(dx * dx + dz * dz))
		if dist < radius:
			return true
	return false

# Returns 0–1: how deeply blighted is chunk (cx, cz)?
# 1.0 at the heart, 0.0 at or beyond the radius edge.
static func blight_intensity(cx: int, cz: int, world_seed: int, days_elapsed: int, cleansed_hearts: Array) -> float:
	var radius: float = blighted_radius(days_elapsed)
	if radius <= 0.0:
		return 0.0
	var min_dist: float = INF
	for h: Dictionary in _get_hearts_in_range(cx, cz, world_seed, cleansed_hearts):
		var hcx: int = int(h.get("cx", 0))
		var hcz: int = int(h.get("cz", 0))
		var dx: int = cx - hcx
		var dz: int = cz - hcz
		var dist: float = sqrt(float(dx * dx + dz * dz))
		if dist < min_dist:
			min_dist = dist
	if min_dist >= radius:
		return 0.0
	return clampf(1.0 - min_dist / radius, 0.0, 1.0)

# Returns the nearest uncleansed heart's info dict (with added "distance" key) or {}.
static func get_nearest_heart(cx: int, cz: int, world_seed: int, cleansed_hearts: Array) -> Dictionary:
	var min_dist: float = INF
	var nearest: Dictionary = {}
	for h: Dictionary in _get_hearts_in_range(cx, cz, world_seed, cleansed_hearts):
		var hcx: int = int(h.get("cx", 0))
		var hcz: int = int(h.get("cz", 0))
		var dx: int = cx - hcx
		var dz: int = cz - hcz
		var dist: float = sqrt(float(dx * dx + dz * dz))
		if dist < min_dist:
			min_dist = dist
			nearest = h.duplicate()
			nearest["distance"] = dist
	return nearest
