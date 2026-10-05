## TownBuildings — reads building footprints out of a town's wall tiles.
##
## Town maps author a house as a ring of 1-high wall tiles with a gap for the
## door. This finds those footprints so the overworld can raise them into real
## buildings:
##
##   house — an enclosed room up to MAX_SPAN tiles a side: HOUSE_LEVELS tall, gabled roof
##   tower — a solid wall block of that size: TOWER_LEVELS tall, pyramid roof
##   rampart — a wall component longer than MAX_SPAN (town walls): RAMPART_LEVELS tall
##   fence — thinner than 3 tiles: left as authored
##
## Pure static logic (no scene tree), so chunk generation can ask for wall
## heights from a worker thread and tests can check the plan directly.
extends RefCounted

const _WorldMap = preload("res://game_logic/world/WorldMap.gd")

const KIND_HOUSE: String = "house"
const KIND_TOWER: String = "tower"

const HOUSE_LEVELS: int = 3
const TOWER_LEVELS: int = 4
const RAMPART_LEVELS: int = 2
## Longest side (tiles) a component may have and still count as a building.
const MAX_SPAN: int = 20
## Share of a footprint's border that must be wall for it to read as a building.
const MIN_BORDER_COVER: float = 0.6

## Plans the buildings of `wm` inside `crop` (local tiles).
## Returns {"heights": {Vector2i local → wall levels}, "buildings": Array[Dictionary]}
## where each building is {"rect": Rect2i, "kind": String, "levels": int,
## "doors": Array[Vector2i]} in local tiles.
##
## Houses are found from the inside: open tiles are flood-filled with doorway
## gaps (a gap with wall on both sides) treated as closed, and every small region
## that never reaches the crop edge is a room. That copes with rooms whose walls
## are split across components or that share a wall with a neighbour.
static func detect(wm: _WorldMap, crop: Rect2i) -> Dictionary:
	var heights: Dictionary = {}
	var buildings: Array[Dictionary] = []
	var seen: Dictionary = {}
	# Walls first: ramparts and towers come from wall components.
	for tz: int in range(crop.position.y, crop.end.y):
		for tx: int in range(crop.position.x, crop.end.x):
			var start := Vector2i(tx, tz)
			if seen.has(start) or not _is_wall(wm, start, crop):
				continue
			var comp: Array[Vector2i] = _flood(start, seen, func(t: Vector2i) -> bool:
				return _is_wall(wm, t, crop))
			var rect: Rect2i = _bounds(comp)
			if mini(rect.size.x, rect.size.y) < 3:
				continue  # a fence or a stub: left as authored
			if maxi(rect.size.x, rect.size.y) > MAX_SPAN:
				for t: Vector2i in comp:
					heights[t] = RAMPART_LEVELS
			elif comp.size() == rect.size.x * rect.size.y:
				buildings.append({"rect": rect, "kind": KIND_TOWER, "levels": TOWER_LEVELS,
					"doors": [] as Array[Vector2i]})
	# Then rooms, from their enclosed floor.
	var open_seen: Dictionary = {}
	for tz: int in range(crop.position.y, crop.end.y):
		for tx: int in range(crop.position.x, crop.end.x):
			var start := Vector2i(tx, tz)
			if open_seen.has(start) or _is_closed(wm, start, crop):
				continue
			var region: Array[Vector2i] = _flood(start, open_seen, func(t: Vector2i) -> bool:
				return crop.has_point(t) and not _is_closed(wm, t, crop))
			var house: Dictionary = _room(wm, region, crop)
			if not house.is_empty():
				buildings.append(house)
	for b: Dictionary in buildings:
		var rect: Rect2i = b["rect"]
		var levels: int = b["levels"]
		for z: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var t := Vector2i(x, z)
				if _is_wall(wm, t, crop):
					heights[t] = maxi(levels, int(heights.get(t, 0)))
	return {"heights": heights, "buildings": buildings}

## A house dict for an enclosed floor region, or {} when it is not a room.
static func _room(wm: _WorldMap, region: Array[Vector2i], crop: Rect2i) -> Dictionary:
	var floor_rect: Rect2i = _bounds(region)
	var rect: Rect2i = floor_rect.grow(1)
	if not crop.encloses(rect):
		return {}  # runs out to the edge of the town: open ground, not a room
	if mini(rect.size.x, rect.size.y) < 3 or maxi(rect.size.x, rect.size.y) > MAX_SPAN:
		return {}
	var border: int = 0
	var covered: int = 0
	var doors: Array[Vector2i] = []
	for t: Vector2i in border_tiles(rect):
		border += 1
		if _is_wall(wm, t, crop):
			covered += 1
		elif not _is_corner(rect, t):
			doors.append(t)
	if float(covered) / float(border) < MIN_BORDER_COVER:
		return {}
	return {"rect": rect, "kind": KIND_HOUSE, "levels": HOUSE_LEVELS, "doors": doors}

static func _is_wall(wm: _WorldMap, t: Vector2i, crop: Rect2i) -> bool:
	if not crop.has_point(t):
		return false
	var tile: int = wm.get_tile(t.x, t.y)
	return tile == IsoConst.TILE_WALL or tile == IsoConst.TILE_CRACKED

## A wall, or a one-tile gap between two walls (a doorway, for room finding).
static func _is_closed(wm: _WorldMap, t: Vector2i, crop: Rect2i) -> bool:
	if _is_wall(wm, t, crop):
		return true
	var we: bool = _is_wall(wm, t + Vector2i(-1, 0), crop) and _is_wall(wm, t + Vector2i(1, 0), crop)
	var ns: bool = _is_wall(wm, t + Vector2i(0, -1), crop) and _is_wall(wm, t + Vector2i(0, 1), crop)
	return we or ns

static func _flood(start: Vector2i, seen: Dictionary, inside: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var stack: Array[Vector2i] = [start]
	seen[start] = true
	while not stack.is_empty():
		var t: Vector2i = stack.pop_back()
		out.append(t)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + d
			if not seen.has(n) and inside.call(n):
				seen[n] = true
				stack.append(n)
	return out

static func _bounds(tiles: Array[Vector2i]) -> Rect2i:
	var lo: Vector2i = tiles[0]
	var hi: Vector2i = tiles[0]
	for t: Vector2i in tiles:
		lo = lo.min(t)
		hi = hi.max(t)
	return Rect2i(lo, hi - lo + Vector2i.ONE)

## The tiles on a rectangle's outer ring, each once.
static func border_tiles(rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x: int in range(rect.position.x, rect.end.x):
		out.append(Vector2i(x, rect.position.y))
		out.append(Vector2i(x, rect.end.y - 1))
	for z: int in range(rect.position.y + 1, rect.end.y - 1):
		out.append(Vector2i(rect.position.x, z))
		out.append(Vector2i(rect.end.x - 1, z))
	return out

static func _is_corner(rect: Rect2i, t: Vector2i) -> bool:
	var on_x: bool = t.x == rect.position.x or t.x == rect.end.x - 1
	var on_z: bool = t.y == rect.position.y or t.y == rect.end.y - 1
	return on_x and on_z
