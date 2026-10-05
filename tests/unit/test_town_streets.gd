## Unit tests for TownStreets — paved streets and street lamps inside the towns (GID-155).
extends "res://tests/framework/test_case.gd"

const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const TownBuildings = preload("res://game_logic/world/TownBuildings.gd")
const TownStreets = preload("res://game_logic/world/TownStreets.gd")
const StreetLampMesh = preload("res://game_logic/world/StreetLampMesh.gd")
const NLM = preload("res://game_logic/NightLightMath.gd")
const _WorldMap = preload("res://game_logic/world/WorldMap.gd")

func _map(rows: Array[String]) -> _WorldMap:
	var wm := _WorldMap.new("t", true)
	for z: int in range(rows.size()):
		for x: int in range(rows[z].length()):
			if rows[z][x] == "#":
				wm.set_tile(x, z, IsoConst.TILE_WALL)
	return wm

func _connected(tiles: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	var seen: Dictionary = {a: true}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		if cur == b:
			return true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if tiles.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return false

func test_gate_and_door_join_the_hub_without_entering_houses() -> void:
	var rows: Array[String] = []
	for z: int in range(30):
		rows.append(".".repeat(30))
	rows[10] = "..........#####..............."
	rows[11] = "..........#...#..............."
	rows[12] = "..........#...#..............."
	rows[13] = "..........##.##..............."
	var wm := _map(rows)
	var crop := Rect2i(0, 0, 30, 30)
	var buildings: Array = TownBuildings.detect(wm, crop)["buildings"]
	assert_eq(buildings.size(), 1, "one house")
	var hub := Vector2i(20, 20)
	var gate := Vector2i(2, 28)
	var plan: Dictionary = TownStreets.plan(wm, crop, hub, [gate] as Array[Vector2i], buildings)
	var tiles: Dictionary = plan["tiles"]
	assert_true(_connected(tiles, gate, hub), "gate street reaches the square")
	assert_true(_connected(tiles, Vector2i(12, 13), hub), "the doorway joins the streets")
	assert_false(tiles.has(Vector2i(12, 12)), "house floor stays unpaved")
	for t: Variant in tiles.keys():
		var tile: Vector2i = t
		assert_ne(wm.get_tile(tile.x, tile.y), IsoConst.TILE_WALL, "no street through a wall")

func test_every_town_has_streets_and_lamps_beside_them() -> void:
	for town: String in RealmLayout.town_names():
		var plan: Dictionary = RealmLayout.street_plan(town)
		var tiles: Dictionary = plan["tiles"]
		var lamps: Array[Vector2i] = []
		lamps.assign(plan["lamps"])
		assert_gt(tiles.size(), 0, "%s has streets" % town)
		assert_gt(lamps.size(), 0, "%s has street lamps" % town)
		var wm: _WorldMap = RealmLayout.town_map(town)
		for l: Vector2i in lamps:
			assert_false(tiles.has(l), "%s lamp stands beside the street, not on it" % town)
			assert_eq(wm.get_tile(l.x, l.y), IsoConst.TILE_GRASS, "%s lamp on grass" % town)
			var near: bool = false
			for dz: int in range(-2, 3):
				for dx: int in range(-2, 3):
					near = near or tiles.has(l + Vector2i(dx, dz))
			assert_true(near, "%s lamp is next to a street" % town)

func test_stamp_paves_street_tiles() -> void:
	var town: String = "madrian"
	var tiles: Dictionary = RealmLayout.street_plan(town)["tiles"]
	var wm: _WorldMap = RealmLayout.town_map(town)
	var checked: int = 0
	for t: Variant in tiles.keys():
		var local: Vector2i = t
		if wm.get_tile(local.x, local.y) != IsoConst.TILE_GRASS:
			continue
		var w: Vector2i = RealmLayout.to_world_tile(town, local)
		assert_eq(RealmLayout.stamp_tile(w.x, w.y, IsoConst.TILE_HILL, 3).x, IsoConst.TILE_PATH)
		checked += 1
		if checked >= 5:
			break
	assert_gt(checked, 0, "found grass street tiles to check")
	assert_eq(RealmLayout.street_lamps_world().size() > 0, true)

func test_lamp_mesh_and_light_style() -> void:
	var mesh: ArrayMesh = StreetLampMesh.mesh()
	assert_eq(mesh.get_surface_count(), 2, "iron + glass surfaces")
	assert_gt(mesh.get_aabb().size.y, StreetLampMesh.LIGHT_HEIGHT, "lamp is taller than its light")
	assert_true(NLM.STYLES.has("street_lamp"))
	var st: Dictionary = NLM.STYLES["street_lamp"]
	assert_almost_eq(float(st["height"]), StreetLampMesh.LIGHT_HEIGHT, 0.01, "light sits in the lantern")
