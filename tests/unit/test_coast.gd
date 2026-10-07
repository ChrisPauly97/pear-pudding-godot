## GID-171: the eastern sea off Maykalene's quay (Coast).
extends "res://tests/framework/test_case.gd"

const Coast = preload("res://game_logic/world/Coast.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const StarterZone = preload("res://game_logic/world/StarterZone.gd")
const RiddleSpots = preload("res://game_logic/world/RiddleSpots.gd")
const WaterMath = preload("res://game_logic/world/WaterMath.gd")
const TreasureGen = preload("res://game_logic/world/TreasureGen.gd")


func test_bounds_match_the_shore() -> void:
	var r := Rect2(Coast.SHORE[0], Vector2.ZERO)
	for p: Vector2 in Coast.SHORE:
		r = r.expand(p)
	assert_eq(Coast.BOUNDS, r, "BOUNDS is SHORE's bounding box")
	assert_eq(Coast.BLEND_MARGIN, RealmLayout.BLEND_MARGIN)


func test_quay_meets_the_water() -> void:
	var town: Rect2i = RealmLayout.world_rect("maykalene")
	for z: int in range(75, 108):
		var quay := Vector2i(town.end.x - 1, z)
		assert_eq(RealmLayout.town_at_tile(quay.x, quay.y), "maykalene", "quay tile %s is in town" % str(quay))
		assert_false(Coast.is_sea(quay.x, quay.y), "the quay is dry")
		assert_true(Coast.is_sea(quay.x + 1, quay.y), "water right off the quay at z %d" % z)
		assert_true(Coast.is_deep(quay.x + 3, quay.y) or Coast.on_pier(quay.x + 3, quay.y),
			"deep water a few tiles out at z %d" % z)


func test_story_places_are_dry() -> void:
	for town: String in RealmLayout.town_names():
		var r: Rect2i = RealmLayout.world_rect(town)
		for z: int in range(r.position.y, r.end.y, 3):
			for x: int in range(r.position.x, r.end.x, 3):
				assert_false(Coast.is_sea(x, z), "%s tile (%d, %d) is not under the sea" % [town, x, z])
	for road: Array in RealmLayout.ROADS:
		for i: int in range(road.size() - 1):
			var a: Vector2 = road[i]
			var b: Vector2 = road[i + 1]
			for k: int in range(21):
				var p: Vector2 = a.lerp(b, float(k) / 20.0)
				assert_lt(Coast.depth(p.x, p.y), -3.0, "road point %s keeps off the shore" % str(p))
	for site: Variant in RealmLayout.STORY_SITES.values():
		var t: Vector2i = site
		assert_lt(Coast.tile_depth(t.x, t.y), -3.0, "story site %s is dry" % str(t))
	for camp: Dictionary in StarterZone.CAMPS:
		var t: Vector2i = camp["tile"]
		assert_lt(Coast.tile_depth(t.x, t.y), -6.0, "camp %s is dry" % str(camp["id"]))
	for spot: Dictionary in RiddleSpots.SPOTS:
		var t: Vector2i = spot["tile"]
		assert_lt(Coast.tile_depth(t.x, t.y), -6.0, "riddle spot %s is dry" % str(spot["id"]))


func test_piers_reach_from_the_quay_and_boats_float() -> void:
	for r: Rect2i in Coast.PIERS:
		for z: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				assert_false(Coast.is_deep(x, z), "pier plank (%d, %d) is walkable" % [x, z])
	var root: Rect2i = Coast.PIERS[0]
	assert_eq(RealmLayout.town_at_tile(root.position.x - 1, root.position.y), "maykalene", "the pier starts at the quay")
	for b: Dictionary in Coast.BOATS:
		var t: Vector2 = b["tile"]
		assert_gt(Coast.depth(t.x, t.y), Coast.WADE_DEPTH, "%s moored in deep water" % str(b["kind"]))


func test_sea_is_flat_reserved_water() -> void:
	var t := Vector2i(120, 90)
	assert_gt(Coast.tile_depth(t.x, t.y), 10.0, "open sea")
	assert_eq(RealmLayout.stamp_tile(t.x, t.y, IsoConst.TILE_HILL, 4), Vector2i(IsoConst.TILE_GRASS, 0),
		"sea floor is level")
	assert_gt(RealmLayout.reserved_distance(t.x, t.y), 0.0, "never paved")
	var w: float = WaterMath.intensity(IsoConst.tile_center(t.x), IsoConst.tile_center(t.y), 42)
	assert_gt(w, 0.69, "deep-water band")
	assert_eq(WaterMath.flow_at(IsoConst.tile_center(t.x), IsoConst.tile_center(t.y), 42), Vector2.ZERO, "still water")
	assert_eq(WaterMath.intensity(IsoConst.tile_center(0), IsoConst.tile_center(0), 42) > 0.9, false, "origin is not sea")


func test_treasure_never_under_the_sea() -> void:
	for counter: int in range(60):
		var site: Vector2i = TreasureGen.get_dig_site(42, counter)
		assert_false(Coast.is_sea(site.x, site.y), "dig site %d %s is on land" % [counter, str(site)])
