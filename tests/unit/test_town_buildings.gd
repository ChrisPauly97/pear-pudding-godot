## Unit tests for TownBuildings — town wall rings raised into buildings.
extends "res://tests/framework/test_case.gd"

const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const TownBuildings = preload("res://game_logic/world/TownBuildings.gd")
const _WorldMap = preload("res://game_logic/world/WorldMap.gd")
const BuildingMesh = preload("res://game_logic/world/BuildingMesh.gd")

func _map(rows: Array[String]) -> _WorldMap:
	var wm := _WorldMap.new("t", true)
	for z: int in range(rows.size()):
		for x: int in range(rows[z].length()):
			if rows[z][x] == "#":
				wm.set_tile(x, z, IsoConst.TILE_WALL)
	return wm

func test_ring_with_gap_is_a_house_with_a_door() -> void:
	var wm := _map([".......", ".#####.", ".#...#.", ".#...#.", ".##.##.", "......."])
	var plan: Dictionary = TownBuildings.detect(wm, Rect2i(0, 0, 7, 6))
	var list: Array = plan["buildings"]
	assert_eq(list.size(), 1, "one building")
	var b: Dictionary = list[0]
	assert_eq(b["kind"], TownBuildings.KIND_HOUSE)
	assert_eq(b["rect"], Rect2i(1, 1, 5, 4))
	var doors: Array = b["doors"]
	assert_eq(doors, [Vector2i(3, 4)], "the gap is the doorway")
	var heights: Dictionary = plan["heights"]
	assert_eq(int(heights.get(Vector2i(1, 1), 0)), TownBuildings.HOUSE_LEVELS)

func test_solid_block_is_a_tower_and_fence_is_left_alone() -> void:
	var wm := _map(["###.......", "###.......", "###.......", "..........", "....######"])
	var plan: Dictionary = TownBuildings.detect(wm, Rect2i(0, 0, 10, 5))
	var list: Array = plan["buildings"]
	assert_eq(list.size(), 1)
	var b: Dictionary = list[0]
	assert_eq(b["kind"], TownBuildings.KIND_TOWER)
	var heights: Dictionary = plan["heights"]
	assert_false(heights.has(Vector2i(5, 4)), "a 1-thick fence keeps its authored height")

func test_long_town_wall_is_a_rampart_not_a_building() -> void:
	var rows: Array[String] = []
	var line: String = "#".repeat(30)
	rows.append(line)
	rows.append("#" + ".".repeat(28) + "#")
	rows.append(line)
	var plan: Dictionary = TownBuildings.detect(_map(rows), Rect2i(0, 0, 30, 3))
	var list: Array = plan["buildings"]
	assert_eq(list.size(), 0)
	var heights: Dictionary = plan["heights"]
	assert_eq(int(heights.get(Vector2i(0, 0), 0)), TownBuildings.RAMPART_LEVELS)

func test_every_town_has_buildings_and_stamp_raises_them() -> void:
	var all: Array[Dictionary] = RealmLayout.buildings_world()
	for town: String in RealmLayout.town_names():
		var n: int = 0
		for b: Dictionary in all:
			if b["town"] == town:
				n += 1
				var r: Rect2i = b["rect"]
				assert_true(RealmLayout.world_rect(town).encloses(r), "%s building inside town" % town)
		assert_gt(n, 0, "%s has buildings" % town)
	var first: Dictionary = all[0]
	var corner: Vector2i = (first["rect"] as Rect2i).position
	var st: Vector2i = RealmLayout.stamp_tile(corner.x, corner.y, IsoConst.TILE_GRASS, 0)
	assert_eq(st.x, IsoConst.TILE_WALL)
	assert_eq(st.y, int(first["levels"]), "stamped wall carries the building height")

func test_split_walls_and_stubs_still_make_rooms() -> void:
	# Maykalene's twin rooms: the left room's top-right corner is open and its
	# east wall is a separate component; the right room's top wall pokes a stub
	# over the alley between them. Both still come out as their own rooms.
	var wm := _map([
		"............",
		".####.#####.",
		".#...#.#...#",
		".#...#.#...#",
		".##.##.##.##",
		"............",
	])
	var plan: Dictionary = TownBuildings.detect(wm, Rect2i(0, 0, 12, 6))
	var rects: Array[Rect2i] = []
	for b: Dictionary in plan["buildings"]:
		rects.append(b["rect"])
	assert_eq(rects, [Rect2i(1, 1, 5, 4), Rect2i(7, 1, 5, 4)] as Array[Rect2i])

func test_meshes_build_for_every_town_building() -> void:
	for b: Dictionary in RealmLayout.buildings_world():
		var roof: ArrayMesh = BuildingMesh.build_roof(b)
		assert_eq(roof.get_surface_count(), 1, "roof for %s" % str(b["rect"]))
		var aabb: AABB = roof.get_aabb()
		assert_gt(aabb.end.y, BuildingMesh.wall_top(b), "roof rises above the walls")
		var trim: ArrayMesh = BuildingMesh.build_trim(b)
		assert_true(trim.get_surface_count() >= 1, "trim for %s" % str(b["rect"]))
