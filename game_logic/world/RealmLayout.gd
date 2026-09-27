## RealmLayout — where the outdoor story towns sit in the overworld (GID-138).
##
## The five outdoor towns are still authored as 100×100 named maps
## (`assets/maps/<town>.tres`), but they are no longer entered by door: each is
## cropped to the part it actually uses and stamped into the infinite overworld
## (`main`) at a fixed tile offset, joined by roads. The player walks from town
## to town with no transition. Interiors (temple, mansion, home, guildhall,
## dungeons) stay door-entered named maps.
##
##   world tile = local tile + TOWNS[town].offset
##
## Pure static logic — no autoloads — so chunk generation, tests and every
## "where is this story place" caller share one table.
extends RefCounted

const _WorldMap = preload("res://game_logic/world/WorldMap.gd")

const _MADRIAN := preload("res://assets/maps/madrian.tres")
const _MAYKALENE := preload("res://assets/maps/maykalene.tres")
const _BLANCOGOV := preload("res://assets/maps/blancogov.tres")
const _LARIK := preload("res://assets/maps/larik.tres")
const _MARSAX_HOLD := preload("res://assets/maps/marsax_hold.tres")

## crop: the part of the 100×100 source map (local tiles) that is stamped.
## offset: added to a local tile to get its overworld tile.
## Story order runs Madrian → south to Maykalene → south-east to Blancogov →
## west to Larik → north to Marsax Hold.
const TOWNS: Dictionary = {
	"madrian": {"crop": Rect2i(4, 4, 91, 56), "offset": Vector2i(-37, -33), "data": _MADRIAN},
	"maykalene": {"crop": Rect2i(3, 0, 80, 100), "offset": Vector2i(-37, 66), "data": _MAYKALENE},
	"blancogov": {"crop": Rect2i(0, 2, 100, 98), "offset": Vector2i(43, 222), "data": _BLANCOGOV},
	"larik": {"crop": Rect2i(33, 35, 33, 29), "offset": Vector2i(-167, 232), "data": _LARIK},
	"marsax_hold": {"crop": Rect2i(22, 22, 57, 57), "offset": Vector2i(-167, 100), "data": _MARSAX_HOLD},
}

## Road polylines in overworld tiles. Each starts/ends at a town gate.
const ROADS: Array = [
	# Madrian's south fence gap (local 50,45) → Maykalene's north road (local 50,0).
	[Vector2(13, 12), Vector2(13, 66)],
	# Maykalene's east side (local 82,48) → Blancogov's north gate (local 50,2).
	[Vector2(45, 114), Vector2(70, 160), Vector2(93, 200), Vector2(93, 224)],
	# Blancogov's west side (local 0,50) → Larik's east side (local 65,50).
	[Vector2(43, 272), Vector2(-20, 282), Vector2(-102, 282)],
	# Larik's north side (local 50,35) → Marsax Hold's south gate (local 50,78).
	[Vector2(-117, 267), Vector2(-117, 178)],
]

## Road tiles within this distance of a polyline are paved.
const ROAD_HALF_WIDTH: float = 1.0
## Hills fade to level ground over this many tiles around towns and roads.
const BLEND_MARGIN: float = 8.0

## Doors whose target is now part of the overworld are dropped when a town is
## stamped (the old town-to-town and town-to-overworld exits).
const OVERWORLD_TARGETS: Array[String] = [
	"", "main", "infinite", "madrian", "maykalene", "blancogov", "larik", "marsax_hold",
]

## Fixed overworld tiles for the story beats that used to spawn "a few tiles
## from the player" (TID-572): each sits on the road the story sends you along.
const STORY_SITES: Dictionary = {
	"wilderness_camp": Vector2i(17, 42),
	"isfig_road": Vector2i(80, 180),
	"scout_ambush": Vector2i(-114, 222),
}

static var _maps: Dictionary = {}  # town → WorldMap (built on first use)
static var _entity_cache: Dictionary = {}  # kind → Array[Dictionary]

static func town_names() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in TOWNS.keys():
		out.append(str(k))
	return out

static func is_stitched(map_name: String) -> bool:
	return TOWNS.has(map_name)

static func offset_of(town: String) -> Vector2i:
	var t: Dictionary = TOWNS.get(town, {})
	var off: Vector2i = t.get("offset", Vector2i.ZERO)
	return off

static func crop_of(town: String) -> Rect2i:
	var t: Dictionary = TOWNS.get(town, {})
	var crop: Rect2i = t.get("crop", Rect2i())
	return crop

## Overworld-tile rectangle a town occupies.
static func world_rect(town: String) -> Rect2i:
	var crop: Rect2i = crop_of(town)
	return Rect2i(crop.position + offset_of(town), crop.size)

static func to_world_tile(town: String, local: Vector2i) -> Vector2i:
	return local + offset_of(town)

static func to_local_tile(town: String, world: Vector2i) -> Vector2i:
	return world - offset_of(town)

## World-space position (tile centre) of a town-local tile.
static func to_world_pos(town: String, local: Vector2i) -> Vector3:
	var w: Vector2i = to_world_tile(town, local)
	return Vector3((float(w.x) + 0.5) * IsoConst.TILE_SIZE, 0.0, (float(w.y) + 0.5) * IsoConst.TILE_SIZE)

## World-unit shift that moves a town-local world position into the overworld.
static func world_shift(town: String) -> Vector2:
	var off: Vector2i = offset_of(town)
	return Vector2(float(off.x) * IsoConst.TILE_SIZE, float(off.y) * IsoConst.TILE_SIZE)

## The stitched town containing overworld tile (wtx, wtz), or "".
static func town_at_tile(wtx: int, wtz: int) -> String:
	for k: Variant in TOWNS.keys():
		var town: String = str(k)
		if world_rect(town).has_point(Vector2i(wtx, wtz)):
			return town
	return ""

static func town_at_world(wx: float, wz: float) -> String:
	return town_at_tile(int(floor(wx / IsoConst.TILE_SIZE)), int(floor(wz / IsoConst.TILE_SIZE)))

## Distance (tiles) from a point to the nearest road centreline.
static func road_distance(px: float, pz: float) -> float:
	var best: float = INF
	var p := Vector2(px, pz)
	for road: Array in ROADS:
		for i: int in range(road.size() - 1):
			var a: Vector2 = road[i]
			var b: Vector2 = road[i + 1]
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
			best = minf(best, p.distance_to(q))
	return best

static func is_road_tile(wtx: int, wtz: int) -> bool:
	return road_distance(float(wtx), float(wtz)) <= ROAD_HALF_WIDTH

## Distance (tiles) from a tile to the nearest town rectangle or road; 0 inside.
static func reserved_distance(wtx: int, wtz: int) -> float:
	var best: float = maxf(0.0, road_distance(float(wtx), float(wtz)) - ROAD_HALF_WIDTH)
	for k: Variant in TOWNS.keys():
		var r: Rect2i = world_rect(str(k))
		var dx: int = maxi(0, maxi(r.position.x - wtx, wtx - (r.end.x - 1)))
		var dz: int = maxi(0, maxi(r.position.y - wtz, wtz - (r.end.y - 1)))
		best = minf(best, sqrt(float(dx * dx + dz * dz)))
		if best <= 0.0:
			return 0.0
	return best

## True when any tile of chunk (cx, cz), grown by BLEND_MARGIN, touches a town or road.
static func chunk_touches_realm(cx: int, cz: int) -> bool:
	var cs: int = IsoConst.CHUNK_SIZE
	var m: int = int(ceil(BLEND_MARGIN))
	var area := Rect2i(cx * cs - m, cz * cs - m, cs + 2 * m, cs + 2 * m)
	for k: Variant in TOWNS.keys():
		if area.intersects(world_rect(str(k))):
			return true
	var half: float = float(cs) * 0.5
	var centre := Vector2(float(cx * cs) + half, float(cz * cs) + half)
	# A chunk's farthest tile is half·√2 from its centre.
	return road_distance(centre.x, centre.y) <= half * 1.4143 + float(m) + ROAD_HALF_WIDTH

## True when chunk (cx, cz) overlaps a town rectangle itself (not just the margin).
static func chunk_in_town(cx: int, cz: int) -> bool:
	var cs: int = IsoConst.CHUNK_SIZE
	var area := Rect2i(cx * cs, cz * cs, cs, cs)
	for k: Variant in TOWNS.keys():
		if area.intersects(world_rect(str(k))):
			return true
	return false

## The town's authored map as runtime dicts (local coordinates), loaded once.
static func town_map(town: String) -> _WorldMap:
	if _maps.has(town):
		var cached: _WorldMap = _maps[town]
		return cached
	var t: Dictionary = TOWNS.get(town, {})
	var data: Resource = t.get("data", null)
	if data == null:
		return null
	var wm := _WorldMap.new(town, true)
	wm.load_from_resource(data)
	_maps[town] = wm
	return wm

## (tile type, height) the realm dictates for an overworld tile: the town's own
## tile inside a town, paved road on a road, and the generated (`noise_*`) terrain
## elsewhere — its height faded towards 0 across the blend margin.
static func stamp_tile(wtx: int, wtz: int, noise_tile: int, noise_height: int) -> Vector2i:
	var town: String = town_at_tile(wtx, wtz)
	if town != "":
		var wm: _WorldMap = town_map(town)
		var local: Vector2i = to_local_tile(town, Vector2i(wtx, wtz))
		return Vector2i(wm.get_tile(local.x, local.y), wm.get_height(local.x, local.y))
	var d: float = reserved_distance(wtx, wtz)
	if d <= 0.0:
		return Vector2i(IsoConst.TILE_PATH, 0)
	if d >= BLEND_MARGIN:
		return Vector2i(noise_tile, noise_height)
	var h: int = int(floor(float(noise_height) * d / BLEND_MARGIN))
	if h <= 0:
		return Vector2i(IsoConst.TILE_GRASS, 0)
	return Vector2i(noise_tile, h)

## Moves a town-local entity dict into the overworld (returns a copy).
static func _shift_entity(e: Dictionary, shift: Vector2) -> Dictionary:
	var out: Dictionary = e.duplicate()
	out["x"] = float(e.get("x", 0.0)) + shift.x
	out["z"] = float(e.get("z", 0.0)) + shift.y
	return out

## Every stitched entity of `kind` ("enemies", "chests", "doors", "npcs",
## "scrolls", "shrines", "waystones") in overworld coordinates. Ids are kept, so
## per-entity save state (opened chests, read scrolls, defeated enemies) carries
## over from the old named maps. Doors leading to a place that is now overworld
## are dropped.
static func entities(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _entity_cache.has(kind):
		out.assign(_entity_cache[kind])
		return out
	for town: String in town_names():
		var wm: _WorldMap = town_map(town)
		if wm == null:
			continue
		var shift: Vector2 = world_shift(town)
		var list: Array[Dictionary] = []
		list.assign(wm.get(kind))
		for e: Dictionary in list:
			if kind == "doors" and OVERWORLD_TARGETS.has(str(e.get("target_map", ""))):
				continue
			var tx: int = int(floor(float(e.get("x", 0.0)) / IsoConst.TILE_SIZE))
			var tz: int = int(floor(float(e.get("z", 0.0)) / IsoConst.TILE_SIZE))
			if not crop_of(town).has_point(Vector2i(tx, tz)):
				continue
			var moved: Dictionary = _shift_entity(e, shift)
			moved["town"] = town
			out.append(moved)
	_entity_cache[kind] = out
	return out

## Entities of `kind` whose position falls inside chunk (cx, cz).
static func entities_in_chunk(kind: String, cx: int, cz: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not chunk_in_town(cx, cz):
		return out
	var span: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var x0: float = float(cx) * span
	var z0: float = float(cz) * span
	for e: Dictionary in entities(kind):
		# Chunk data is mutated at runtime (e.g. chests get "opened"), so hand out copies.
		var ex: float = float(e.get("x", 0.0))
		var ez: float = float(e.get("z", 0.0))
		if ex >= x0 and ex < x0 + span and ez >= z0 and ez < z0 + span:
			out.append(e.duplicate())
	return out

## Overworld spawn position of a town's authored player spawn (world units).
static func spawn_pos(town: String) -> Vector3:
	var wm: _WorldMap = town_map(town)
	if wm == null:
		return Vector3.ZERO
	return to_world_pos(town, Vector2i(wm.player_spawn_x, wm.player_spawn_z))

## World position of a story site from STORY_SITES (tile centre).
static func site_pos(site: String) -> Vector3:
	var t: Vector2i = STORY_SITES.get(site, Vector2i.ZERO)
	return Vector3((float(t.x) + 0.5) * IsoConst.TILE_SIZE, 0.0, (float(t.y) + 0.5) * IsoConst.TILE_SIZE)
