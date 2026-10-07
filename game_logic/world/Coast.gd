## Coast — the eastern sea that Maykalene's waterfront looks out on (GID-171).
##
## A bay of open water east of Maykalene, defined by a coastline polygon in
## overworld tiles. Everything that needs the sea asks this script:
##   - RealmLayout counts it as reserved ground (flat, no trees / ruins / spawns),
##   - WaterMath folds `sea_water()` into the stream/pond intensity, so the
##     terrain shader draws it with the same pixel water and shoreline,
##   - the Coastline world module keeps the hero out of deep water and builds the
##     pier, the quay edge and the moored boats.
##
## Pure static logic, no autoloads: it runs on the chunk worker threads.
extends RefCounted

## Coastline (overworld tiles), clockwise from Maykalene's quay. Its west edge is
## the town's east crop edge (local x 80 = world 43), so the quay meets the water.
const SHORE: Array[Vector2] = [
	Vector2(43, 69), Vector2(47, 62), Vector2(58, 56), Vector2(74, 52), Vector2(96, 49),
	Vector2(130, 46), Vector2(170, 43), Vector2(215, 49), Vector2(250, 61), Vector2(262, 95),
	Vector2(250, 130), Vector2(215, 146), Vector2(175, 140), Vector2(140, 130), Vector2(110, 124),
	Vector2(84, 119), Vector2(62, 116), Vector2(48, 117), Vector2(43, 112),
]
## SHORE's bounding box (a const, so worker threads never build shared state; test_coast checks it).
const BOUNDS := Rect2(43, 43, 219, 103)
## Hills fade to level ground over this many tiles of shore (RealmLayout.BLEND_MARGIN).
const BLEND_MARGIN: float = 8.0
## Tiles of water before it gets too deep to wade.
const WADE_DEPTH: float = 1.5
## Reserved distance inside the sea (like a legend glade's pad): above 0 so the
## sea floor is never paved, small enough that hills flatten to level ground.
const SEA_PAD: float = 0.5
## Water intensity at the shoreline and its rise per tile of depth (the terrain
## shader draws water above 0.24, so it starts right at the sand: shallow, mid, deep bands).
const SHORE_WATER: float = 0.3
const WATER_PER_TILE: float = 0.12
## The coastline wobbles by up to this many tiles, except along the quay.
const WOBBLE: float = 1.6

## Sand between the sea and the grass on the wild coast: this many tiles plus up to
## BEACH_WOBBLE more (stamped as path tiles, so the terrain draws them sandy).
const BEACH_WIDTH: float = 2.0
const BEACH_WOBBLE: float = 1.4
## Past this many tiles from BOUNDS, depth() skips the exact shore distance (nothing reads
## closer than the beach + BLEND_MARGIN from the water).
const FAR: float = 16.0

## Piers: walkable plank decks over the water (overworld tile rects). The first is
## Maykalene's T-pier off the quay; the last is the fishing jetty off the north-east beach.
const PIERS: Array[Rect2i] = [Rect2i(43, 92, 7, 2), Rect2i(50, 88, 2, 10), Rect2i(80, 49, 2, 10)]
## Iron lamps on the piers (overworld tiles; lit at night like the town street lamps).
const PIER_LAMPS: Array[Vector2i] = [Vector2i(46, 92), Vector2i(51, 88), Vector2i(51, 97), Vector2i(81, 57)]
## Moored boats: kind, overworld tile (its berth), facing (+1 / -1 flips the sprite),
## `berth` (tiles: a boat tied up beside a pier opens the railing within that reach),
## and its voyages: `route` (waypoints from the berth out to open sea, past the edge
## of the view), `trips` per day and `phase` (share of a trip, so they don't all sail
## at once). A boat with no route stays at anchor.
const BOATS: Array[Dictionary] = [
	{"kind": "cog", "tile": Vector2(53.9, 92.6), "flip": 1, "berth": 2.2, "trips": 1, "phase": 0.15,
		"route": [Vector2(58.0, 92.6), Vector2(75.0, 94.0), Vector2(112.0, 96.0)]},
	{"kind": "rowboat", "tile": Vector2(51.0, 87.3), "flip": 1, "berth": 1.6, "trips": 2, "phase": 0.55,
		"route": [Vector2(51.0, 84.5), Vector2(56.0, 83.5), Vector2(78.0, 86.0), Vector2(104.0, 84.0)]},
	{"kind": "rowboat", "tile": Vector2(50.6, 98.6), "flip": -1, "berth": 1.6, "trips": 2, "phase": 0.3,
		"route": [Vector2(50.6, 101.0), Vector2(56.0, 103.0), Vector2(80.0, 106.0), Vector2(106.0, 108.0)]},
	{"kind": "rowboat", "tile": Vector2(45.5, 91.2), "flip": 1, "berth": 1.6, "trips": 2, "phase": 0.8,
		"route": [Vector2(45.5, 89.5), Vector2(48.0, 86.5), Vector2(53.0, 85.5), Vector2(78.0, 88.0),
			Vector2(105.0, 88.0)]},
	{"kind": "rowboat", "tile": Vector2(46.5, 94.8), "flip": -1, "berth": 1.6, "trips": 2, "phase": 0.05,
		"route": [Vector2(46.5, 96.5), Vector2(49.0, 99.0), Vector2(54.0, 100.5), Vector2(80.0, 104.0),
			Vector2(105.0, 106.0)]},
	{"kind": "cog", "tile": Vector2(64.0, 101.0), "flip": -1, "berth": 0.0},
	{"kind": "rowboat", "tile": Vector2(81.0, 59.6), "flip": 1, "berth": 1.6, "trips": 2, "phase": 0.65,
		"route": [Vector2(81.0, 62.0), Vector2(85.0, 66.0), Vector2(100.0, 72.0), Vector2(122.0, 75.0)]},
]
## Tiles per second under sail or oar, and the share of each trip spent tied up.
const SAIL_SPEED: float = 1.6
const DOCKED_SHARE: float = 0.5
## A rowboat pulled up on the north-east beach (overworld tile).
const BEACHED_BOAT := Vector2(68.5, 51.5)
## Beach clutter is scattered over tiles west of this (tiles) — near Maykalene.
const BEACH_CLUTTER_MAX_X: int = 130

## SHORE as a packed array, built once when the script loads (read-only after).
static var _shore_packed := PackedVector2Array(SHORE)


## Signed depth in tiles at overworld tile point (px, pz): > 0 at sea, < 0 on land.
static func depth(px: float, pz: float) -> float:
	var p := Vector2(px, pz)
	var bb: Rect2 = BOUNDS
	if not bb.grow(FAR).has_point(p):
		# Beyond every consumer's reach (beach, blend margin): the box distance is close enough.
		return -maxf(maxf(bb.position.x - px, px - bb.end.x), maxf(bb.position.y - pz, pz - bb.end.y))
	var best: float = INF
	for i: int in range(SHORE.size()):
		var a: Vector2 = SHORE[i]
		var b: Vector2 = SHORE[(i + 1) % SHORE.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	var s: float = best if Geometry2D.is_point_in_polygon(p, _shore_packed) else -best
	# A natural ragged coast away from the town; the quay (x < 46) stays straight.
	var w: float = clampf((px - 46.0) / 8.0, 0.0, 1.0) * WOBBLE
	return s + w * (0.6 * sin(px * 0.21 + pz * 0.13) + 0.4 * sin(pz * 0.37 - px * 0.11))


## Depth at a tile's centre.
static func tile_depth(wtx: int, wtz: int) -> float:
	return depth(float(wtx) + 0.5, float(wtz) + 0.5)


static func on_pier(wtx: int, wtz: int) -> bool:
	for r: Rect2i in PIERS:
		if r.has_point(Vector2i(wtx, wtz)):
			return true
	return false


## Where boat `b` is at clock time `t` (seconds into the day; a day is `day_seconds`):
## {"pos": Vector2 tiles, "dir": Vector2 heading (zero when still), "away": bool (out of
## sight at sea)}. A pure function of the clock, whole trips per day, so co-op peers see
## the same boats and a day wrap never jumps: tied up, sail out along the route, away,
## sail back in.
static func boat_at(b: Dictionary, t: float, day_seconds: float) -> Dictionary:
	var home: Vector2 = b["tile"]
	var route: Array = b.get("route", [])
	var still: Dictionary = {"pos": home, "dir": Vector2.ZERO, "away": false}
	if route.is_empty() or day_seconds <= 0.0:
		return still
	var pts: Array[Vector2] = [home]
	pts.assign([home] + route)
	var length: float = 0.0
	for i: int in range(pts.size() - 1):
		length += pts[i].distance_to(pts[i + 1])
	var period: float = day_seconds / float(maxi(1, int(b.get("trips", 1))))
	var local: float = fposmod(t + period * float(b.get("phase", 0.0)), period)
	var sail: float = minf(length / SAIL_SPEED, period * (1.0 - DOCKED_SHARE) * 0.5)
	var docked: float = period * DOCKED_SHARE
	if local < docked:
		return still
	if local < docked + sail:
		return _along(pts, length * (local - docked) / sail, 1.0)
	if local < period - sail:
		return {"pos": pts[pts.size() - 1], "dir": Vector2.ZERO, "away": true}
	return _along(pts, length * (period - local) / sail, -1.0)


## The point `dist` tiles along polyline `pts`, heading forward (sign 1) or back (-1).
static func _along(pts: Array[Vector2], dist: float, sign: float) -> Dictionary:
	var left: float = dist
	for i: int in range(pts.size() - 1):
		var seg: float = pts[i].distance_to(pts[i + 1])
		if left <= seg or i == pts.size() - 2:
			var dir: Vector2 = (pts[i + 1] - pts[i]).normalized()
			return {"pos": pts[i].lerp(pts[i + 1], clampf(left / maxf(seg, 0.001), 0.0, 1.0)),
				"dir": dir * sign, "away": false}
		left -= seg
	return {"pos": pts[0], "dir": Vector2.ZERO, "away": false}


## True when the railing along `tile`'s `dir` edge of pier `r` is left open: the
## pier's far ends (its short sides) and a gangway beside every berthed boat.
static func rail_open(r: Rect2i, tile: Vector2i, dir: Vector2i) -> bool:
	var along_x: bool = r.size.x >= r.size.y
	if (along_x and dir.y == 0) or (not along_x and dir.x == 0):
		return true
	var mid := Vector2(tile) + Vector2(0.5, 0.5) + Vector2(dir) * 0.5
	for b: Dictionary in BOATS:
		if mid.distance_to(b["tile"] as Vector2) <= float(b["berth"]):
			return true
	return false


## Too deep to wade (and not a pier plank).
static func is_deep(wtx: int, wtz: int) -> bool:
	return tile_depth(wtx, wtz) >= WADE_DEPTH and not on_pier(wtx, wtz)


## Any water at all (spawns keep off it).
static func is_sea(wtx: int, wtz: int) -> bool:
	return tile_depth(wtx, wtz) > 0.0


## RealmLayout reserved distance: SEA_PAD at sea (level, never paved), 0 on the beach
## (stamped as sandy path), else the distance to the back of the beach.
static func reserved_distance(wtx: int, wtz: int) -> float:
	var d: float = tile_depth(wtx, wtz)
	if d > 0.0:
		return SEA_PAD
	return maxf(0.0, -d - beach_width(wtx, wtz))


## How far (tiles) the sand runs up from the waterline at this tile.
static func beach_width(wtx: int, wtz: int) -> float:
	return BEACH_WIDTH + BEACH_WOBBLE * (0.5 + 0.5 * sin(float(wtx) * 0.17 - float(wtz) * 0.23))


static func is_beach(wtx: int, wtz: int) -> bool:
	var d: float = tile_depth(wtx, wtz)
	return d <= 0.0 and -d <= beach_width(wtx, wtz)


## Water intensity (WaterMath / terrain UV2.y) at world position (wx, wz).
static func sea_water(wx: float, wz: float, tile_size: float) -> float:
	var d: float = depth(wx / tile_size, wz / tile_size)
	if d < -0.6:
		return 0.0
	return clampf(SHORE_WATER + d * WATER_PER_TILE, 0.0, 1.0)


## True when any tile of the `area` rect (tiles) can be within `margin` tiles of the sea or its beach.
static func touches(area: Rect2i, margin: float) -> bool:
	var a := Rect2(Vector2(area.position), Vector2(area.size))
	return BOUNDS.grow(WOBBLE + BEACH_WIDTH + BEACH_WOBBLE + margin + 1.0).intersects(a)


## True when chunk (cx, cz) can lie within the blend margin of the sea.
static func touches_chunk(cx: int, cz: int) -> bool:
	var cs: int = IsoConst.CHUNK_SIZE
	return touches(Rect2i(cx * cs, cz * cs, cs, cs), BLEND_MARGIN)


## Nearest tile to (wtx, wtz) that is dry land, walking back toward the origin.
static func to_land(wtx: int, wtz: int) -> Vector2i:
	var p := Vector2(wtx, wtz)
	var step: Vector2 = -p.normalized() if p.length() > 0.0 else Vector2.ZERO
	for i: int in range(400):
		var t := Vector2i(roundi(p.x), roundi(p.y))
		if not is_sea(t.x, t.y) and tile_depth(t.x, t.y) < -1.0:
			return t
		p += step
	return Vector2i(wtx, wtz)
