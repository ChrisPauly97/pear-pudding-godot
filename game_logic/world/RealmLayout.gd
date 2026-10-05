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
const _RiddleSpots = preload("res://game_logic/world/RiddleSpots.gd")
const _TownBuildings = preload("res://game_logic/world/TownBuildings.gd")
const _TownStreets = preload("res://game_logic/world/TownStreets.gd")

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
	"marsax_hold": {"crop": Rect2i(18, 22, 61, 57), "offset": Vector2i(-167, 100), "data": _MARSAX_HOLD},
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

## Madrian's debug shortcuts straight into far-off interiors; in the stitched
## realm you walk to Maykalene / Blancogov and use their own doors.
const DROPPED_DOORS: Array[String] = ["madrian:door_11", "madrian:door_13"]

## Overworld spawn tokens ride in SceneManager's door_stack (in place of a door
## id) so leaving an interior puts the player back where they went in.
const POS_TOKEN_PREFIX: String = "pos:"

## GID-153: each Pear Pudding riddle spot sits in a small natural glade. The
## spots count as reserved ground (flat, no trees, water, ruins or random
## spawns) but never reach 0, so no path tile marks them.
const LEGEND_SITE_PAD: float = 0.5

## Fixed overworld tiles for the story beats that used to spawn "a few tiles
## from the player" (TID-572): each sits on the road the story sends you along.
const STORY_SITES: Dictionary = {
	"madrian_south_road": Vector2i(13, 30),
	"wilderness_camp": Vector2i(17, 42),
	"isfig_road": Vector2i(80, 180),
	"scout_ambush": Vector2i(-114, 222),
}

static var _maps: Dictionary = {}  # town → WorldMap (built on first use)
static var _entity_cache: Dictionary = {}  # kind → Array[Dictionary]
static var _plans: Dictionary = {}  # town → TownBuildings.detect() result
static var _streets: Dictionary = {}  # town → TownStreets.plan() result

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
	return Vector3(IsoConst.tile_center(w.x), 0.0, IsoConst.tile_center(w.y))

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
	var t := IsoConst.world_to_tile(wx, wz)
	return town_at_tile(t.x, t.y)

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

## Distance (tiles) from a tile to the nearest town rectangle or road; 0 inside.
static func reserved_distance(wtx: int, wtz: int) -> float:
	var best: float = maxf(0.0, road_distance(float(wtx), float(wtz)) - ROAD_HALF_WIDTH)
	best = minf(best, legend_site_distance(wtx, wtz))
	for k: Variant in TOWNS.keys():
		var r: Rect2i = world_rect(str(k))
		var dx: int = maxi(0, maxi(r.position.x - wtx, wtx - (r.end.x - 1)))
		var dz: int = maxi(0, maxi(r.position.y - wtz, wtz - (r.end.y - 1)))
		best = minf(best, sqrt(float(dx * dx + dz * dz)))
		if best <= 0.0:
			return 0.0
	return best

static func legend_site_distance(wtx: int, wtz: int) -> float:
	var best: float = INF
	for spot: Dictionary in _RiddleSpots.SPOTS:
		var t: Vector2i = spot["tile"]
		best = minf(best, Vector2(wtx - t.x, wtz - t.y).length() + LEGEND_SITE_PAD)
	return best

## True when any tile of chunk (cx, cz), grown by BLEND_MARGIN, touches a town, road or legend glade.
static func chunk_touches_realm(cx: int, cz: int) -> bool:
	var cs: int = IsoConst.CHUNK_SIZE
	var m: int = int(ceil(BLEND_MARGIN))
	var area := Rect2i(cx * cs - m, cz * cs - m, cs + 2 * m, cs + 2 * m)
	for k: Variant in TOWNS.keys():
		if area.intersects(world_rect(str(k))):
			return true
	for spot: Dictionary in _RiddleSpots.SPOTS:
		if area.has_point(spot["tile"] as Vector2i):
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
		var tile: int = wm.get_tile(local.x, local.y)
		var raised: Dictionary = building_plan(town)["heights"]
		var levels: int = int(raised.get(local, 0))
		var streets: Dictionary = street_plan(town)["tiles"]
		if tile == IsoConst.TILE_GRASS and streets.has(local):
			tile = IsoConst.TILE_PATH
		return Vector2i(tile, levels if levels > 0 else wm.get_height(local.x, local.y))
	var d: float = reserved_distance(wtx, wtz)
	if d <= 0.0:
		return Vector2i(IsoConst.TILE_PATH, 0)
	if d >= BLEND_MARGIN:
		return Vector2i(noise_tile, noise_height)
	var h: int = int(floor(float(noise_height) * d / BLEND_MARGIN))
	if h <= 0:
		return Vector2i(IsoConst.TILE_GRASS, 0)
	return Vector2i(noise_tile, h)

## The town's building plan (TownBuildings.detect over its crop), built once.
static func building_plan(town: String) -> Dictionary:
	if _plans.has(town):
		var cached: Dictionary = _plans[town]
		return cached
	var wm: _WorldMap = town_map(town)
	var plan: Dictionary = {"heights": {}, "buildings": []}
	if wm != null:
		plan = _TownBuildings.detect(wm, crop_of(town))
	_plans[town] = plan
	return plan

## The town's street plan (TownStreets.plan), built once: trunks from each realm
## road that meets the town to its spawn square, lanes to every door.
static func street_plan(town: String) -> Dictionary:
	if _streets.has(town):
		var cached: Dictionary = _streets[town]
		return cached
	var wm: _WorldMap = town_map(town)
	var plan: Dictionary = {"tiles": {}, "lamps": [] as Array[Vector2i]}
	if wm != null:
		var crop: Rect2i = crop_of(town)
		var gates: Array[Vector2i] = []
		for road: Array in ROADS:
			for end: Vector2 in [road[0], road[road.size() - 1]]:
				var local: Vector2i = to_local_tile(town, Vector2i(roundi(end.x), roundi(end.y)))
				if crop.grow(2).has_point(local):
					gates.append(local.clamp(crop.position, crop.end - Vector2i.ONE))
		plan = _TownStreets.plan(wm, crop, hub_of(town), gates, building_plan(town)["buildings"])
	_streets[town] = plan
	return plan

## The town's square (local tile): its authored player spawn, else the crop centre.
static func hub_of(town: String) -> Vector2i:
	var crop: Rect2i = crop_of(town)
	var wm: _WorldMap = town_map(town)
	if wm != null:
		var spawn := Vector2i(wm.player_spawn_x, wm.player_spawn_z)
		if wm.has_player_spawn() and crop.has_point(spawn):
			return spawn
	return crop.get_center()

## Every street lamp in the stitched towns, as overworld tiles.
static func street_lamps_world() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for town: String in town_names():
		var lamps: Array[Vector2i] = []
		lamps.assign(street_plan(town)["lamps"])
		for l: Vector2i in lamps:
			out.append(l + offset_of(town))
	return out

## Every stitched building in overworld tiles: the TownBuildings dicts with
## "rect" and "doors" moved into the overworld and a "town" key added.
static func buildings_world() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for town: String in town_names():
		var off: Vector2i = offset_of(town)
		var list: Array = building_plan(town)["buildings"]
		for b: Dictionary in list:
			var moved: Dictionary = b.duplicate()
			var rect: Rect2i = b["rect"]
			moved["rect"] = Rect2i(rect.position + off, rect.size)
			var doors: Array[Vector2i] = []
			for d: Vector2i in b["doors"]:
				doors.append(d + off)
			moved["doors"] = doors
			moved["town"] = town
			out.append(moved)
	return out

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
	out.assign(_cached_entities(kind))
	return out

## The cached `entities(kind)` list itself — read-only, no copy. For hot paths
## (per-frame quest pointers, chunk generation); callers must not mutate it.
static func _cached_entities(kind: String) -> Array[Dictionary]:
	if _entity_cache.has(kind):
		return _entity_cache[kind]
	var out: Array[Dictionary] = []
	for town: String in town_names():
		var wm: _WorldMap = town_map(town)
		if wm == null:
			continue
		var shift: Vector2 = world_shift(town)
		var list: Array[Dictionary] = []
		list.assign(wm.get(kind))
		for e: Dictionary in list:
			if kind == "doors" and (OVERWORLD_TARGETS.has(str(e.get("target_map", "")))
					or DROPPED_DOORS.has("%s:%s" % [town, str(e.get("id", ""))])):
				continue
			if not crop_of(town).has_point(IsoConst.entity_tile(e)):
				continue
			var moved: Dictionary = _shift_entity(e, shift)
			moved["town"] = town
			# Every town numbers its townsfolk npc_1, npc_2…; WorldScene keys NPC
			# nodes by id, so generic ids get the town prefix. Named ones (duelists,
			# merchants, boards) are already unique and keep save state keyed on them.
			var eid: String = str(e.get("id", ""))
			if kind == "npcs" and eid.begins_with("npc_"):
				moved["id"] = "%s:%s" % [town, eid]
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
	for e: Dictionary in _cached_entities(kind):
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
	return Vector3(IsoConst.tile_center(t.x), 0.0, IsoConst.tile_center(t.y))

## The stitched door leading into `map_name` (an interior), or {}.
static func door_into(map_name: String) -> Dictionary:
	for d: Dictionary in _cached_entities("doors"):
		if str(d.get("target_map", "")) == map_name:
			return d
	return {}

## Where the player stands in the overworld after leaving interior `map_name`:
## one tile in front of (south of) the door that leads into it. null when no
## stitched door leads there.
static func return_pos_for(map_name: String) -> Variant:
	var d: Dictionary = door_into(map_name)
	if d.is_empty():
		return null
	return Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 0.0)) + IsoConst.TILE_SIZE)

static func pos_token(x: float, z: float) -> String:
	return "%s%.2f:%.2f" % [POS_TOKEN_PREFIX, x, z]

## Vector3 for a `pos:` token, or null for anything else (e.g. a door id).
static func parse_pos_token(token: String) -> Variant:
	if not token.begins_with(POS_TOKEN_PREFIX):
		return null
	var parts: PackedStringArray = token.substr(POS_TOKEN_PREFIX.length()).split(":")
	if parts.size() != 2 or not parts[0].is_valid_float() or not parts[1].is_valid_float():
		return null
	return Vector3(parts[0].to_float(), 0.0, parts[1].to_float())

## True for the map ids that are the overworld (where the towns are stitched).
static func is_overworld(map_name: String) -> bool:
	return map_name == "main" or map_name == "infinite"
