## Rivers — the overworld's three rivers, from the mountains down to the eastern sea (GID-172 / TID-694).
##
## Fixed realm geography, like the roads (RealmLayout.ROADS) and the sea (Coast): each
## river is a hand-routed control polyline in overworld tiles, smoothed (Catmull-Rom) and
## given a gentle sine meander once, then bucketed so a lookup scans one small cell.
## A river is narrow and wadeable at its mountain source and widens downstream into a
## deep channel (≥ Coast.WADE_DEPTH) with shallow banks; where a road crosses it the
## water is held shallow (a ford).
##
## Everything that needs a river asks this script:
##   - RealmLayout counts it as reserved ground (level valley, no trees / ruins / spawns),
##   - WaterMath folds `water()` / `flow()` into the terrain water and current,
##   - InfiniteWorldGen makes the sources mountains and the river's chunks water biomes.
##
## Pure static logic, no autoloads: it runs on the chunk worker threads. The tables are
## built once (`warm()`, called from InfiniteWorldGen.warm) and read-only afterwards.
extends RefCounted

const IsoConst = preload("res://autoloads/IsoConst.gd")  # usable before autoloads register (-s runs)
const _Coast = preload("res://game_logic/world/Coast.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")  # cyclic, fine
const _WaterMath = preload("res://game_logic/world/WaterMath.gd")  # cyclic, fine
const _BiomeDef = preload("res://game_logic/world/BiomeDef.gd")

## Control points (overworld tiles), source first; the last point lies inside the sea.
## `wiggle` scales the meander (default 1) where a course threads between story places.
const COURSES: Array[Dictionary] = [
	# From the northern peaks south into the bay's north shore.
	{"id": "north", "points": [Vector2(150, -150), Vector2(170, -110), Vector2(150, -70), Vector2(165, -30),
		Vector2(145, 10), Vector2(150, 35), Vector2(152, 56)]},
	# From the western heights east, between Madrian and Maykalene (fording their road), into the bay.
	{"id": "west", "points": [Vector2(-235, 15), Vector2(-200, 35), Vector2(-160, 42), Vector2(-120, 58),
		Vector2(-80, 54), Vector2(-45, 56), Vector2(-15, 56), Vector2(13, 56), Vector2(30, 57),
		Vector2(45, 58), Vector2(56, 58), Vector2(68, 63)], "wiggle": 0.5},
	# From the southern range north into the bay's south shore.
	{"id": "south", "points": [Vector2(250, 335), Vector2(225, 295), Vector2(235, 250), Vector2(210, 210),
		Vector2(205, 175), Vector2(195, 150), Vector2(190, 130)]},
]

## Spacing (tiles) of the smoothed centreline.
const STEP: float = 2.0
## Meander: two sines along the course (amplitude tiles, frequency per tile), faded to
## nothing over MEANDER_FADE tiles at both ends so the source and mouth stay put.
const MEANDER_AMP: float = 2.5
const MEANDER_FREQ: float = 0.07
const MEANDER_AMP2: float = 1.0
const MEANDER_FREQ2: float = 0.19
const MEANDER_FADE: float = 30.0
## Half-width (tiles, centreline to bank) at the source and at the mouth.
const HW_SOURCE: float = 1.0
const HW_MOUTH: float = 4.0
## Current speed (WaterMath.flow_at units) at the source and at the mouth.
const FLOW_SOURCE: float = 1.8
const FLOW_MOUTH: float = 0.7
## Water intensity at the bank and its rise per tile of depth (same bands as the sea).
const BANK_WATER: float = 0.3
const WATER_PER_TILE: float = 0.12
## Fords: within FORD_INNER tiles of a road crossing the water is at most FORD_DEPTH
## deep, deepening by FORD_SLOPE per tile beyond.
const FORD_DEPTH: float = 0.8
const FORD_INNER: float = 3.0
const FORD_SLOPE: float = 0.6
## Reserved distance inside the river (like Coast.SEA_PAD): above 0 so it is never paved.
const RIVER_PAD: float = 0.5
## Lookups are exact within REACH tiles of the centreline (≥ HW_MOUTH + RealmLayout.BLEND_MARGIN).
const REACH: float = 13.0
## Bucket cell size (tiles).
const CELL: int = 8
## The water / current lookups only need the centreline within this many tiles (bank + the 0.6-tile
## shoreline fade), so they scan a second, sparser bucket table.
const NEAR: float = HW_MOUTH + 1.0
## Chunks whose centre lies within this many tiles of a source are mountains.
const SOURCE_RADIUS: float = 40.0
static var _pts := PackedVector2Array()   # centreline points, every course back to back
static var _ts := PackedFloat32Array()    # 0 at a source .. 1 at the mouth, per point
static var _segs := PackedInt32Array()    # segment i joins _pts[i] → _pts[i + 1]
static var _cells: Dictionary = {}        # Vector2i → PackedInt32Array of segment starts within REACH
static var _near_cells: Dictionary = {}   # the same within NEAR
static var _fords := PackedVector2Array()
static var _sources := PackedVector2Array()
static var _course_counts := PackedInt32Array()  # centreline points per course
static var _built: bool = false
static var _mutex := Mutex.new()


## Builds the tables on the calling thread (before any chunk worker reads them). The build is
## mutex-guarded anyway, and RealmLayout.warm() triggers it through its first stamp_tile.
static func warm() -> void:
	_ensure()


## The biome of chunk (cx, cz) given its noise biome `b` (InfiniteWorldGen.biome_for_chunk): a river rises
## in the mountains, and the chunks it runs through are water biomes (grasslands if dry) so its water draws.
static func biome_for(cx: int, cz: int, b: int) -> int:
	if source_chunk(cx, cz):
		return _BiomeDef.MOUNTAINS
	if not _WaterMath.biome_has_water(b) and touches_chunk(cx, cz, 0.0):
		return _BiomeDef.GRASSLANDS
	return b


## RealmLayout reserved distance of the water: the sea (Coast) or a river, whichever is nearer.
static func water_reserved(wtx: int, wtz: int) -> float:
	return minf(_Coast.reserved_distance(wtx, wtz), reserved_distance(wtx, wtz))


## Signed depth (tiles) at continuous tile coords: > 0 in the water (centre = half-width), < 0 on the
## bank side; -INF farther than REACH from every river.
static func depth(px: float, pz: float) -> float:
	_ensure()
	return _depth_of(Vector2(px, pz), _nearest(Vector2(px, pz), _cells, REACH))


static func _depth_of(p: Vector2, n: Vector3) -> float:
	if n.x == INF:
		return -INF
	var d: float = half_width(n.y) - n.x
	if d <= 0.0 or _fords.is_empty():
		return d
	for f: Vector2 in _fords:
		d = minf(d, FORD_DEPTH + maxf(0.0, p.distance_to(f) - FORD_INNER) * FORD_SLOPE)
	return d


static func tile_depth(wtx: int, wtz: int) -> float:
	return depth(float(wtx) + 0.5, float(wtz) + 0.5)


## Too deep to wade.
static func is_deep(wtx: int, wtz: int) -> bool:
	return tile_depth(wtx, wtz) >= _Coast.WADE_DEPTH


## Any river water at all.
static func is_river(wtx: int, wtz: int) -> bool:
	return tile_depth(wtx, wtz) > 0.0


## Bank-to-bank half-width at fraction `t` of the way from source (0) to mouth (1).
static func half_width(t: float) -> float:
	return lerpf(HW_SOURCE, HW_MOUTH, pow(clampf(t, 0.0, 1.0), 0.8))


## Water intensity (WaterMath / terrain UV2.y) at world position (wx, wz).
static func water(wx: float, wz: float) -> float:
	_ensure()
	var ts: float = IsoConst.TILE_SIZE
	var p := Vector2(wx / ts, wz / ts)
	var d: float = _depth_of(p, _nearest(p, _near_cells, NEAR))
	if d < -0.6:
		return 0.0
	return clampf(BANK_WATER + d * WATER_PER_TILE, 0.0, 1.0)


## Current at world position (wx, wz): downstream unit direction × speed; zero out of the water.
static func flow(wx: float, wz: float) -> Vector2:
	_ensure()
	var ts: float = IsoConst.TILE_SIZE
	var n: Vector3 = _nearest(Vector2(wx / ts, wz / ts), _near_cells, NEAR)
	if n.x == INF or half_width(n.y) - n.x < -0.6:
		return Vector2.ZERO
	var i: int = int(n.z)
	var dir: Vector2 = (_pts[i + 1] - _pts[i]).normalized()
	return dir * lerpf(FLOW_SOURCE, FLOW_MOUTH, n.y)


## RealmLayout reserved distance: RIVER_PAD in the water (level, never paved), else the distance
## to the bank (at least RIVER_PAD, so the bank is never paved either); INF beyond REACH.
static func reserved_distance(wtx: int, wtz: int) -> float:
	var d: float = tile_depth(wtx, wtz)
	if d == -INF:
		return INF
	return maxf(RIVER_PAD, -d)


## True when any tile of chunk (cx, cz) can lie within `margin` tiles of a river bank (conservative).
static func touches_chunk(cx: int, cz: int, margin: float) -> bool:
	_ensure()
	var cs: int = IsoConst.CHUNK_SIZE
	var half: float = float(cs) * 0.5
	var centre := Vector2(float(cx * cs) + half, float(cz * cs) + half)
	var seen: Dictionary = {}
	for z: int in range(floori(float(cz * cs) / CELL), floori(float(cz * cs + cs - 1) / CELL) + 1):
		for x: int in range(floori(float(cx * cs) / CELL), floori(float(cx * cs + cs - 1) / CELL) + 1):
			var segs: PackedInt32Array = _cells.get(Vector2i(x, z), PackedInt32Array())
			for i: int in segs:
				if seen.has(i):
					continue
				seen[i] = true
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(centre, _pts[i], _pts[i + 1])
				if centre.distance_to(q) - half * 1.4143 <= margin + HW_MOUTH:
					return true
	return false


## True when chunk (cx, cz)'s centre lies within SOURCE_RADIUS of a river's source.
static func source_chunk(cx: int, cz: int) -> bool:
	_ensure()
	var cs: int = IsoConst.CHUNK_SIZE
	var centre := Vector2(float(cx * cs) + float(cs) * 0.5, float(cz * cs) + float(cs) * 0.5)
	for s: Vector2 in _sources:
		if centre.distance_to(s) <= SOURCE_RADIUS:
			return true
	return false


## The smoothed centreline of course `idx` (tiles), source first.
static func centreline(idx: int) -> PackedVector2Array:
	_ensure()
	var out := PackedVector2Array()
	var start: int = 0
	for c: int in range(idx):
		start += _course_len(c)
	for i: int in range(start, start + _course_len(idx)):
		out.append(_pts[i])
	return out


## Road crossings (tiles), where the river is a ford.
static func fords() -> PackedVector2Array:
	_ensure()
	return _fords


## (distance, t, segment start) of the centreline nearest to p, or (INF, 0, -1) beyond `reach`
## (`cells` must bucket every segment within `reach` of each cell).
static func _nearest(p: Vector2, cells: Dictionary, reach: float) -> Vector3:
	var segs: PackedInt32Array = cells.get(Vector2i(floori(p.x / CELL), floori(p.y / CELL)), PackedInt32Array())
	var best: float = INF
	var best_t: float = 0.0
	var best_i: int = -1
	for i: int in segs:
		var a: Vector2 = _pts[i]
		var ab: Vector2 = _pts[i + 1] - a
		var len2: float = ab.length_squared()
		var u: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
		var dd: float = p.distance_squared_to(a + ab * u)
		if dd < best:
			best = dd
			best_t = lerpf(_ts[i], _ts[i + 1], u)
			best_i = i
	if best_i < 0 or best > reach * reach:
		return Vector3(INF, 0.0, -1.0)
	return Vector3(sqrt(best), best_t, float(best_i))


static func _course_len(idx: int) -> int:
	return int(_course_counts[idx])



static func _ensure() -> void:
	if _built:
		return
	_mutex.lock()
	if not _built:
		_build()
		_built = true
	_mutex.unlock()


static func _build() -> void:
	var pts := PackedVector2Array()
	var ts := PackedFloat32Array()
	var segs := PackedInt32Array()
	var counts := PackedInt32Array()
	var sources := PackedVector2Array()
	for ci: int in range(COURSES.size()):
		var ctrl: Array = COURSES[ci]["points"]
		var wiggle: float = float(COURSES[ci].get("wiggle", 1.0))
		var line: PackedVector2Array = _meander(_smooth(ctrl), float(ci) * 2.3, wiggle)
		var total: float = 0.0
		var acc := PackedFloat32Array()
		for k: int in range(line.size()):
			if k > 0:
				total += line[k].distance_to(line[k - 1])
			acc.append(total)
		var base: int = pts.size()
		for k: int in range(line.size()):
			pts.append(line[k])
			ts.append(acc[k] / maxf(total, 0.001))
			if k < line.size() - 1:
				segs.append(base + k)
		counts.append(line.size())
		sources.append(line[0])
	var cells: Dictionary = _bucket(pts, segs, REACH)
	var near_cells: Dictionary = _bucket(pts, segs, NEAR)
	var fords := PackedVector2Array()
	for road: Array in _RealmLayout.ROADS:
		for r: int in range(road.size() - 1):
			var ra: Vector2 = road[r]
			var rb: Vector2 = road[r + 1]
			for i: int in segs:
				var hit: Variant = Geometry2D.segment_intersects_segment(ra, rb, pts[i], pts[i + 1])
				if hit != null:
					fords.append(hit as Vector2)
	_pts = pts
	_ts = ts
	_segs = segs
	_cells = cells
	_near_cells = near_cells
	_fords = fords
	_sources = sources
	_course_counts = counts


## Segment starts per CELL bucket, for every segment that comes within `reach` of the cell.
static func _bucket(pts: PackedVector2Array, segs: PackedInt32Array, reach: float) -> Dictionary:
	var cells: Dictionary = {}
	var half := Vector2(CELL, CELL) * 0.5
	var cell_r: float = half.length()
	for i: int in segs:
		var bb := Rect2(pts[i], Vector2.ZERO).expand(pts[i + 1]).grow(reach)
		for z: int in range(floori(bb.position.y / CELL), floori(bb.end.y / CELL) + 1):
			for x: int in range(floori(bb.position.x / CELL), floori(bb.end.x / CELL) + 1):
				var c := Vector2(x * CELL, z * CELL) + half
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(c, pts[i], pts[i + 1])
				if c.distance_to(q) > reach + cell_r:
					continue
				var k := Vector2i(x, z)
				var arr: PackedInt32Array = cells.get(k, PackedInt32Array())
				arr.append(i)
				cells[k] = arr
	return cells


## Catmull-Rom through the control points, sampled about every STEP tiles.
static func _smooth(ctrl: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = ctrl.size()
	for i: int in range(n - 1):
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, n - 1)]
		var steps: int = maxi(1, ceili(p1.distance_to(p2) / STEP))
		for s: int in range(steps):
			var t: float = float(s) / float(steps)
			var t2: float = t * t
			var t3: float = t2 * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[n - 1] as Vector2)
	return out


## Sideways sine wobble along the line, faded out at both ends.
static func _meander(line: PackedVector2Array, phase: float, wiggle: float) -> PackedVector2Array:
	var total: float = 0.0
	for k: int in range(1, line.size()):
		total += line[k].distance_to(line[k - 1])
	var out := PackedVector2Array()
	var s: float = 0.0
	for k: int in range(line.size()):
		if k > 0:
			s += line[k].distance_to(line[k - 1])
		var tangent: Vector2 = (line[mini(k + 1, line.size() - 1)] - line[maxi(k - 1, 0)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var env: float = clampf(s / MEANDER_FADE, 0.0, 1.0) * clampf((total - s) / MEANDER_FADE, 0.0, 1.0)
		var off: float = (MEANDER_AMP * sin(s * MEANDER_FREQ + phase)
				+ MEANDER_AMP2 * sin(s * MEANDER_FREQ2 + phase * 1.7)) * env * wiggle
		out.append(line[k] + normal * off)
	return out
