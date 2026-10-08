## Streams and ponds in the infinite world (GID-134 / TID-524).
##
## Visual, wadeable water: a stream is a thin band of low-frequency noise near
## zero (like a ley line), a pond is a blob of a second noise. The intensity is
## baked per terrain vertex into UV2.y by ChunkRenderer, so the shader draws
## exactly what the CPU side (grass, props, footstep splashes) keeps clear of.
## Water only lies on level walkable grass — the shader masks walls, hills and
## paths — and only in biomes that have it.
extends RefCounted

const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _Coast = preload("res://game_logic/world/Coast.gd")
const _Rivers = preload("res://game_logic/world/Rivers.gd")

const STREAM_FREQUENCY: float = 0.011
const STREAM_WIDTH: float = 0.045     # |noise| below this is in the stream
const POND_FREQUENCY: float = 0.035
const POND_LEVEL: float = 0.52        # noise above this is pond
const STREAM_SEED_OFFSET: int = 771133
const POND_SEED_OFFSET: int = 193771
## Biomes with water: grasslands, forest, mountains (no desert/scorched streams).
const WATER_BIOMES: Array[int] = [0, 1, 4]
## Intensity above which a spot counts as "in the water" (grass, props, splashes).
const WET_LEVEL: float = 0.3
## Keep water this far (world units) from structure tiles, fading over DRY_FADE.
## The sum must stay ≤ ChunkRenderer.TILE_CHECK tiles minus half a tile (5 u), so
## both chunks sharing a border see the same structure tiles: no water seams.
const DRY_RADIUS: float = 2.5
const DRY_FADE: float = 2.5
## Water fades in over this many tiles from a stitched town or road (GID-138).
const REALM_DRY_TILES: float = 4.0

## Flow (TID-642): gradient sample step (world units), the gradient magnitude
## that maps to speed 1, and the speed clamp. Narrow streams run faster.
const FLOW_EPS: float = 0.5
const FLOW_TYPICAL_GRADIENT: float = 0.026  # median in streams (seed 42 sample)
const FLOW_MIN_SPEED: float = 0.5
const FLOW_MAX_SPEED: float = 2.0

## Water-edge props (TID-643): reeds on the bank band straddling the drawn
## shoreline (~0.24), lily pads on still deep water; chance per tile.
const REED_MIN: float = 0.14
const REED_MAX: float = 0.3
const REED_CHANCE: float = 0.45
const LILY_MIN: float = 0.6
const LILY_CHANCE: float = 0.3
## Rocks break the surface in fast river water (GID-172): water band, minimum current, chance.
const ROCK_MIN: float = 0.36
const ROCK_MAX: float = 0.6
const ROCK_FLOW: float = 1.2
const ROCK_CHANCE: float = 0.12
## Lily pads (and river rocks) sit at the lowered water surface, not the bank height.
const LILY_SINK: float = 0.18

## A chunk tile farther than this (tiles) from the chunk's centre tile can't
## exist; used to prove a whole chunk sits beyond the realm dry fade (TID-673).
const CHUNK_REACH_TILES: float = 13.0

static var _stream: FastNoiseLite = null
static var _pond: FastNoiseLite = null
static var _seed: int = -1
static var _mutex := Mutex.new()

## Structure clearance for one chunk (GID-164 / TID-673): the dry points bucketed
## into DRY_RADIUS + DRY_FADE cells, so a lookup scans the 3×3 cells around a
## point instead of every point — exact, since anything farther fades to 1.
## `realm_clear` is true when the whole chunk is provably beyond the stitched
## towns' / roads' dry fade, so `intensity` can skip `reserved_distance`.
class DryGrid:
	var cells: Dictionary = {}  # Vector2i -> PackedVector2Array
	var realm_clear: bool = false

	func _init(points: PackedVector2Array = PackedVector2Array()) -> void:
		var cell: float = DRY_RADIUS + DRY_FADE
		for q: Vector2 in points:
			var k := Vector2i(floori(q.x / cell), floori(q.y / cell))
			var arr: PackedVector2Array = cells.get(k, PackedVector2Array())
			arr.append(q)
			cells[k] = arr

	## Same value as `WaterMath.structure_fade` over the original points.
	func fade(wx: float, wz: float) -> float:
		if cells.is_empty():
			return 1.0
		var reach: float = DRY_RADIUS + DRY_FADE
		var p := Vector2(wx, wz)
		var cx: int = floori(wx / reach)
		var cz: int = floori(wz / reach)
		var best: float = INF
		for dz: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var k := Vector2i(cx + dx, cz + dz)
				if not cells.has(k):
					continue
				var arr: PackedVector2Array = cells[k]
				for q: Vector2 in arr:
					best = minf(best, p.distance_squared_to(q))
		if best >= reach * reach:
			return 1.0
		return smoothstep(DRY_RADIUS, reach, sqrt(best))


## The water context for chunk (cx, cz): bucketed dry points plus the
## realm-clear proof (reserved distance is 1-Lipschitz over tiles, and the
## realm fade is flat 1 past REALM_DRY_TILES).
static func chunk_context(points: PackedVector2Array, cx: int, cz: int) -> DryGrid:
	var g := DryGrid.new(points)
	var half: int = IsoConst.CHUNK_SIZE / 2
	var d: float = RealmLayout.reserved_distance(cx * IsoConst.CHUNK_SIZE + half, cz * IsoConst.CHUNK_SIZE + half,
			false)
	g.realm_clear = d > REALM_DRY_TILES + CHUNK_REACH_TILES
	return g




static func biome_has_water(biome_id: int) -> bool:
	return WATER_BIOMES.has(biome_id)


## 0 (dry) .. 1 (middle of a stream or pond, a river, or out at sea) at world (wx, wz).
static func intensity(wx: float, wz: float, world_seed: int, realm_clear: bool = false) -> float:
	return maxf(_inland(wx, wz, world_seed, realm_clear), sea_at(wx, wz))


## The eastern sea (GID-171) and the rivers (GID-172): never faded by towns, roads or
## structures — the quay meets the sea, and a road crosses a river at a ford.
static func sea_at(wx: float, wz: float) -> float:
	return maxf(_Coast.sea_water(wx, wz, IsoConst.TILE_SIZE), _Rivers.water(wx, wz))


## Streams and ponds only.
static func _inland(wx: float, wz: float, world_seed: int, realm_clear: bool) -> float:
	_ensure(world_seed)
	var s: float = absf(_stream.get_noise_2d(wx, wz))
	var stream: float = clampf(1.0 - s / STREAM_WIDTH, 0.0, 1.0)
	var p: float = _pond.get_noise_2d(wx, wz)
	var pond: float = clampf((p - POND_LEVEL) / 0.12, 0.0, 1.0)
	var w: float = maxf(stream, pond)
	if w <= 0.0:
		return 0.0
	if realm_clear:
		return w
	# Stitched story towns and their roads stay dry (GID-138).
	var ts: float = IsoConst.TILE_SIZE
	var d: float = RealmLayout.reserved_distance(int(floor(wx / ts)), int(floor(wz / ts)), false)
	return w * smoothstep(1.0, REALM_DRY_TILES, d)


## Water fades out near structures (ruins, roads, doors): 0 within
## DRY_RADIUS of the nearest point, 1 beyond DRY_RADIUS + DRY_FADE.
static func structure_fade(wx: float, wz: float, dry_points: PackedVector2Array) -> float:
	if dry_points.is_empty():
		return 1.0
	var p := Vector2(wx, wz)
	var best: float = INF
	for q: Vector2 in dry_points:
		best = minf(best, p.distance_squared_to(q))
	return smoothstep(DRY_RADIUS, DRY_RADIUS + DRY_FADE, sqrt(best))


static func is_wet(wx: float, wz: float, world_seed: int) -> bool:
	return intensity(wx, wz, world_seed) > WET_LEVEL


## Water after keeping clear of structures (what the terrain actually draws).
## `dry` null = no structures nearby. Dry ground skips the clearance scan (TID-673).
static func water_at(wx: float, wz: float, world_seed: int, dry: DryGrid) -> float:
	var clear: bool = dry != null and dry.realm_clear
	var sea: float = sea_at(wx, wz)
	var w: float = _inland(wx, wz, world_seed, clear)
	if w <= 0.0 or dry == null:
		return maxf(w, sea)
	return maxf(w * dry.fade(wx, wz), sea)


static func wet_at(wx: float, wz: float, world_seed: int, dry: DryGrid) -> bool:
	if sea_at(wx, wz) > _Coast.SHORE_WATER - 0.04:
		return true  # grass and props stop right at the sea's (and rivers') drawn shoreline
	var clear: bool = dry != null and dry.realm_clear
	var w: float = _inland(wx, wz, world_seed, clear)
	if w <= WET_LEVEL:
		return false  # the fade only lowers it
	return dry == null or w * dry.fade(wx, wz) > WET_LEVEL


## Stream current at (wx, wz) (TID-642): unit direction along the stream
## scaled by speed, zero in ponds and on dry ground. The stream is the
## zero contour of the stream noise, so the direction is the noise gradient
## turned 90°; the gradient is continuous across the contour, so the current
## keeps one orientation along the whole stream and across chunk borders.
## A steep gradient means a narrow stream, which runs faster.
static func flow_at(wx: float, wz: float, world_seed: int) -> Vector2:
	if _Rivers.water(wx, wz) > 0.0:
		return _Rivers.flow(wx, wz)  # a river carries its own current (GID-172)
	if _Coast.sea_water(wx, wz, IsoConst.TILE_SIZE) > 0.0:
		return Vector2.ZERO  # the sea is still water; no stream current across it
	_ensure(world_seed)
	var n: float = _stream.get_noise_2d(wx, wz)
	var stream: float = clampf(1.0 - absf(n) / STREAM_WIDTH, 0.0, 1.0)
	if stream <= 0.0:
		return Vector2.ZERO
	var pond: float = clampf((_pond.get_noise_2d(wx, wz) - POND_LEVEL) / 0.12, 0.0, 1.0)
	if pond >= stream:
		return Vector2.ZERO  # still water where a pond takes over
	var gx: float = (_stream.get_noise_2d(wx + FLOW_EPS, wz)
			- _stream.get_noise_2d(wx - FLOW_EPS, wz)) / (2.0 * FLOW_EPS)
	var gz: float = (_stream.get_noise_2d(wx, wz + FLOW_EPS)
			- _stream.get_noise_2d(wx, wz - FLOW_EPS)) / (2.0 * FLOW_EPS)
	var g := Vector2(gx, gz)
	var mag: float = g.length()
	if mag < 0.000001:
		return Vector2.ZERO
	var speed: float = clampf(mag / FLOW_TYPICAL_GRADIENT, FLOW_MIN_SPEED, FLOW_MAX_SPEED)
	return Vector2(-g.y, g.x) / mag * speed


## Water-edge dressing (TID-643) for one spot: "reed" on a bank (water just
## below the wet line), "river_rock" in fast shallow-to-mid water (GID-172),
## "lily_pad" on still, deep pond water, else "". `roll`
## is the caller's deterministic 0..1 hash for this spot.
static func edge_prop(water: float, flow: Vector2, roll: float) -> String:
	if water > REED_MIN and water < REED_MAX:
		return "reed" if roll < REED_CHANCE else ""
	if water > ROCK_MIN and water < ROCK_MAX and flow.length() > ROCK_FLOW:
		return "river_rock" if roll < ROCK_CHANCE else ""
	if water > LILY_MIN and flow == Vector2.ZERO:
		return "lily_pad" if roll < LILY_CHANCE else ""
	return ""


## Reeds and lily pads are freshwater: none along the sea's sand and quay (GID-171).
static func edge_prop_ok(_key: String, wx: float, wz: float) -> bool:
	var ts: float = IsoConst.TILE_SIZE
	return _Coast.sea_water(wx, wz, ts) <= 0.0 and _Coast.depth(wx / ts, wz / ts) < -1.0


static func _ensure(world_seed: int) -> void:
	if _seed == world_seed and _stream != null:
		return
	# Chunk builds run on worker threads; build the pair once per seed.
	_mutex.lock()
	if _seed != world_seed or _stream == null:
		var st := FastNoiseLite.new()
		st.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		st.seed = world_seed + STREAM_SEED_OFFSET
		st.frequency = STREAM_FREQUENCY
		var pd := FastNoiseLite.new()
		pd.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		pd.seed = world_seed + POND_SEED_OFFSET
		pd.frequency = POND_FREQUENCY
		_stream = st
		_pond = pd
		_seed = world_seed
	_mutex.unlock()
