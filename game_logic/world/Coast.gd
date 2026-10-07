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
## shader draws water above 0.24: shallow, then mid, then deep bands).
const SHORE_WATER: float = 0.24
const WATER_PER_TILE: float = 0.12
## The coastline wobbles by up to this many tiles, except along the quay.
const WOBBLE: float = 1.6

## West of this (tiles) the shore is Maykalene's straight dressed quay.
const QUAY_END_X: float = 50.0

## Piers: walkable plank decks over the water (overworld tile rects).
const PIERS: Array[Rect2i] = [Rect2i(43, 92, 7, 2), Rect2i(50, 88, 2, 10)]
## Moored boats: kind, overworld tile, facing (+1 / -1 flips the sprite).
const BOATS: Array[Dictionary] = [
	{"kind": "cog", "tile": Vector2(55.5, 86.0), "flip": 1},
	{"kind": "rowboat", "tile": Vector2(47.5, 95.2), "flip": -1},
	{"kind": "rowboat", "tile": Vector2(46.0, 89.8), "flip": 1},
	{"kind": "cog", "tile": Vector2(64.0, 101.0), "flip": -1},
]

## SHORE as a packed array, built once when the script loads (read-only after).
static var _shore_packed := PackedVector2Array(SHORE)


## Signed depth in tiles at overworld tile point (px, pz): > 0 at sea, < 0 on land.
static func depth(px: float, pz: float) -> float:
	var p := Vector2(px, pz)
	var bb: Rect2 = BOUNDS
	if not bb.grow(WOBBLE + 1.0).has_point(p):
		return -(maxf(0.0, maxf(bb.position.x - px, px - bb.end.x))
				+ maxf(0.0, maxf(bb.position.y - pz, pz - bb.end.y)) + WOBBLE + 1.0)
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


## Too deep to wade (and not a pier plank).
static func is_deep(wtx: int, wtz: int) -> bool:
	return tile_depth(wtx, wtz) >= WADE_DEPTH and not on_pier(wtx, wtz)


## Any water at all (spawns keep off it).
static func is_sea(wtx: int, wtz: int) -> bool:
	return tile_depth(wtx, wtz) > 0.0


## RealmLayout reserved distance: distance to the shore outside, SEA_PAD inside.
static func reserved_distance(wtx: int, wtz: int) -> float:
	return maxf(SEA_PAD, -tile_depth(wtx, wtz))


## Water intensity (WaterMath / terrain UV2.y) at world position (wx, wz).
static func sea_water(wx: float, wz: float, tile_size: float) -> float:
	var d: float = depth(wx / tile_size, wz / tile_size)
	if d < -0.6:
		return 0.0
	return clampf(SHORE_WATER + d * WATER_PER_TILE, 0.0, 1.0)


## True when any tile of the `area` rect (tiles) can be within `margin` tiles of the sea.
static func touches(area: Rect2i, margin: float) -> bool:
	var a := Rect2(Vector2(area.position), Vector2(area.size))
	return BOUNDS.grow(WOBBLE + margin + 1.0).intersects(a)


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
