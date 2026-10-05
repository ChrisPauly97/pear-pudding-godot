## TownStreets — paved streets and street-lamp spots inside the stitched towns.
##
## Town maps are authored as open grass with houses dotted about. This lays a
## street network over that grass so the towns read as places people walk:
##
##   trunk — from every town gate (where a realm road meets the town) to the
##           town's player spawn (its square), TRUNK_RADIUS tiles each side;
##   lane  — from every reachable door (house doorway gaps and door entities)
##           to the nearest street already laid, one tile wide.
##
## Each route is a breadth-first search outward from the network, walked back
## from the anchor preferring to keep its heading, so streets run straight with
## few turns. Lamps stand beside the streets every LAMP_SPACING steps, on grass,
## clear of doors and townsfolk. Pure static logic (no scene tree): RealmLayout
## asks it for tiles while generating chunks, tests check the plan directly.
extends RefCounted

const _WorldMap = preload("res://game_logic/world/WorldMap.gd")

const TRUNK_RADIUS: int = 1
## Steps along a street between lamps, and the least gap (tiles) between two lamps.
const LAMP_SPACING: int = 7
const LAMP_MIN_GAP: float = 5.0
## Routes longer than this (tiles) are not laid: the anchor is cut off.
const MAX_ROUTE: int = 90

const _DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Plans the streets of `wm` inside `crop` (local tiles). `gates` are local tiles
## where roads enter, `hub` the tile every gate leads to, `buildings` the
## TownBuildings plan's list. Returns {"tiles": {Vector2i local → true},
## "lamps": Array[Vector2i] local}.
static func plan(wm: _WorldMap, crop: Rect2i, hub: Vector2i, gates: Array[Vector2i],
		buildings: Array) -> Dictionary:
	var interior: Dictionary = {}
	var anchors: Array[Vector2i] = []
	for b: Dictionary in buildings:
		var rect: Rect2i = b["rect"]
		var inner: Rect2i = rect.grow(-1)
		for z: int in range(inner.position.y, inner.end.y):
			for x: int in range(inner.position.x, inner.end.x):
				interior[Vector2i(x, z)] = true
		for d: Vector2i in b["doors"]:
			anchors.append(d)
	var occupied: Dictionary = _entity_tiles(wm)
	for v: Variant in wm.doors:
		var door: Dictionary = v
		var t := _entity_tile(door)
		if not interior.has(t):
			anchors.append(t)
	var open := func(t: Vector2i) -> bool:
		return crop.has_point(t) and not interior.has(t) and _is_ground(wm.get_tile(t.x, t.y))
	var tiles: Dictionary = {}
	var routes: Array[Dictionary] = []
	var start: Vector2i = _nearest_open(hub, open)
	if start.x == -1:
		return {"tiles": tiles, "lamps": [] as Array[Vector2i]}
	tiles[start] = true
	anchors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - start).length_squared() < (b - start).length_squared())
	for g: Vector2i in gates:
		_lay(_route(_nearest_open(g, open), tiles, open), TRUNK_RADIUS, tiles, open, routes)
	for a: Vector2i in anchors:
		_lay(_route(_nearest_open(a, open), tiles, open), 0, tiles, open, routes)
	var grass := func(t: Vector2i) -> bool:
		return bool(open.call(t)) and wm.get_tile(t.x, t.y) == IsoConst.TILE_GRASS
	return {"tiles": tiles, "lamps": _place_lamps(routes, tiles, occupied, grass)}

## Paths, walls and hills stay as authored; only grass is paved.
static func _is_ground(tile: int) -> bool:
	return tile == IsoConst.TILE_GRASS or tile == IsoConst.TILE_PATH

static func _entity_tile(e: Dictionary) -> Vector2i:
	return Vector2i(floori(float(e.get("x", 0.0)) / IsoConst.TILE_SIZE),
			floori(float(e.get("z", 0.0)) / IsoConst.TILE_SIZE))

## Tiles townsfolk, doors and props stand on — no lamp goes on or beside them.
static func _entity_tiles(wm: _WorldMap) -> Dictionary:
	var out: Dictionary = {}
	for list: Array in [wm.doors, wm.npcs, wm.chests, wm.scrolls, wm.shrines, wm.waystones, wm.enemies]:
		for v: Variant in list:
			var e: Dictionary = v
			out[_entity_tile(e)] = true
	return out

## `t` if it is open, else the nearest open tile within 2, else (-1, -1).
static func _nearest_open(t: Vector2i, open: Callable) -> Vector2i:
	for r: int in range(3):
		for dz: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				var c := t + Vector2i(dx, dz)
				if bool(open.call(c)):
					return c
	return Vector2i(-1, -1)

## The tiles from `from` to the nearest street tile (exclusive), in walking
## order, or [] when there is none in reach. A BFS from the anchor gives each
## tile its distance; the walk back from the hit keeps its heading while that
## still descends, so routes come out straight.
static func _route(from: Vector2i, tiles: Dictionary, open: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if from.x == -1 or tiles.has(from):
		return out
	var dist: Dictionary = {from: 0}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	var hit := Vector2i(-1, -1)
	while head < queue.size() and hit.x == -1:
		var cur: Vector2i = queue[head]
		head += 1
		var d: int = dist[cur]
		if d >= MAX_ROUTE:
			break
		for dir: Vector2i in _DIRS:
			var n: Vector2i = cur + dir
			if dist.has(n) or not bool(open.call(n)):
				continue
			dist[n] = d + 1
			if tiles.has(n):
				hit = n
				break
			queue.append(n)
	if hit.x == -1:
		return out
	var cur: Vector2i = hit
	var heading := Vector2i.ZERO
	while cur != from:
		var cd: int = dist[cur]
		var step := Vector2i.ZERO
		if heading != Vector2i.ZERO and int(dist.get(cur + heading, -1)) == cd - 1:
			step = heading
		else:
			for dir: Vector2i in _DIRS:
				if int(dist.get(cur + dir, -1)) == cd - 1:
					step = dir
					break
		heading = step
		cur += step
		out.push_front(cur)
	return out

static func _lay(route: Array[Vector2i], radius: int, tiles: Dictionary, open: Callable,
		routes: Array[Dictionary]) -> void:
	if route.is_empty():
		return
	for t: Vector2i in route:
		for dz: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var c := t + Vector2i(dx, dz)
				if bool(open.call(c)):
					tiles[c] = true
	routes.append({"route": route, "radius": radius})

## Lamps alternate sides every LAMP_SPACING steps along each route.
static func _place_lamps(routes: Array[Dictionary], tiles: Dictionary, occupied: Dictionary,
		open: Callable) -> Array[Vector2i]:
	var lamps: Array[Vector2i] = []
	for r: Dictionary in routes:
		var route: Array[Vector2i] = []
		route.assign(r["route"])
		var off: int = int(r["radius"]) + 1
		var side: int = 1
		for i: int in range(LAMP_SPACING / 2, route.size(), LAMP_SPACING):
			var a: Vector2i = route[maxi(i - 1, 0)]
			var b: Vector2i = route[mini(i + 1, route.size() - 1)]
			var along: Vector2i = (b - a).sign()
			var perp := Vector2i(-along.y, along.x)
			if perp == Vector2i.ZERO:
				continue
			for s: int in [side, -side]:
				var c: Vector2i = route[i] + perp * off * s
				if _lamp_ok(c, lamps, tiles, occupied, open):
					lamps.append(c)
					break
			side = -side
	return lamps

static func _lamp_ok(c: Vector2i, lamps: Array[Vector2i], tiles: Dictionary, occupied: Dictionary,
		open: Callable) -> bool:
	if tiles.has(c) or not bool(open.call(c)):
		return false
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if occupied.has(c + Vector2i(dx, dz)):
				return false
	for l: Vector2i in lamps:
		if Vector2(l - c).length() < LAMP_MIN_GAP:
			return false
	return true
