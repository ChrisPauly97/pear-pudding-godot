## GID-172 / TID-694: the overworld rivers (Rivers) and their hooks.
extends "res://tests/framework/test_case.gd"

const Rivers = preload("res://game_logic/world/Rivers.gd")
const Coast = preload("res://game_logic/world/Coast.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const StarterZone = preload("res://game_logic/world/StarterZone.gd")
const RiddleSpots = preload("res://game_logic/world/RiddleSpots.gd")
const WaterMath = preload("res://game_logic/world/WaterMath.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")


func test_every_river_runs_into_the_sea() -> void:
	for c: int in range(Rivers.COURSES.size()):
		var line: PackedVector2Array = Rivers.centreline(c)
		assert_gt(line.size(), 20, "course %d has a smoothed centreline" % c)
		var mouth: Vector2 = line[line.size() - 1]
		assert_gt(Coast.depth(mouth.x, mouth.y), 3.0, "course %d ends out in the sea" % c)
		var src: Vector2 = line[0]
		assert_lt(Coast.depth(src.x, src.y), -50.0, "course %d rises far inland" % c)


func test_rivers_keep_off_story_places() -> void:
	for c: int in range(Rivers.COURSES.size()):
		for p: Vector2 in Rivers.centreline(c):
			for town: String in RealmLayout.town_names():
				var r := Rect2(RealmLayout.world_rect(town))
				var dx: float = maxf(0.0, maxf(r.position.x - p.x, p.x - r.end.x))
				var dz: float = maxf(0.0, maxf(r.position.y - p.y, p.y - r.end.y))
				assert_gt(sqrt(dx * dx + dz * dz) - Rivers.HW_MOUTH, 3.0, "river %d keeps clear of %s" % [c, town])
			for camp: Dictionary in StarterZone.CAMPS:
				var t: Vector2i = camp["tile"]
				assert_gt(p.distance_to(Vector2(t)) - Rivers.HW_MOUTH, StarterZone.CAMP_CLEAR_RADIUS,
					"river %d keeps out of camp %s" % [c, str(camp["id"])])
			for spot: Dictionary in RiddleSpots.SPOTS:
				var t: Vector2i = spot["tile"]
				assert_gt(p.distance_to(Vector2(t)) - Rivers.HW_MOUTH, 3.0, "river %d misses %s" % [c, str(spot["id"])])
			for site: Variant in RealmLayout.STORY_SITES.values():
				var t: Vector2i = site
				assert_gt(p.distance_to(Vector2(t)) - Rivers.HW_MOUTH, 3.0, "river %d misses site %s" % [c, str(t)])


func test_narrow_at_the_source_deep_downstream() -> void:
	for c: int in range(Rivers.COURSES.size()):
		var line: PackedVector2Array = Rivers.centreline(c)
		var src: Vector2 = line[2]
		var low: Vector2 = line[line.size() - 15]
		assert_lt(Rivers.depth(src.x, src.y), Coast.WADE_DEPTH, "course %d is wadeable at its source" % c)
		assert_gt(Rivers.depth(low.x, low.y), Coast.WADE_DEPTH, "course %d runs deep downstream" % c)
		assert_gt(Rivers.water(low.x * IsoConst.TILE_SIZE, low.y * IsoConst.TILE_SIZE), 0.6, "deep water draws deep")
	assert_eq(Rivers.depth(-500.0, -500.0), -INF, "no river far from every course")
	assert_eq(Rivers.water(-1000.0, -1000.0), 0.0)


func test_road_crossing_is_a_ford() -> void:
	var fords: PackedVector2Array = Rivers.fords()
	assert_eq(fords.size(), 1, "the west river crosses the Madrian–Maykalene road once")
	for f: Vector2 in fords:
		assert_lt(RealmLayout.road_distance(f.x, f.y), 0.01, "the ford lies on a road")
		for dz: int in range(-5, 6):
			assert_lt(Rivers.depth(f.x, f.y + float(dz)), Coast.WADE_DEPTH, "the road fords the river (dz %d)" % dz)
			var t := Vector2i(floori(f.x), floori(f.y) + dz)
			if RealmLayout.road_distance(float(t.x) + 0.5, float(t.y) + 0.5) <= RealmLayout.ROAD_HALF_WIDTH:
				assert_eq(RealmLayout.stamp_tile(t.x, t.y, IsoConst.TILE_HILL, 3).x, IsoConst.TILE_PATH,
					"the road stays paved across the ford")


func test_depth_and_flow_are_continuous() -> void:
	var line: PackedVector2Array = Rivers.centreline(0)
	var mid: Vector2 = line[line.size() / 2]
	var prev: float = Rivers.depth(mid.x - 6.0, mid.y)
	for k: int in range(1, 121):
		var x: float = mid.x - 6.0 + float(k) * 0.1
		var d: float = Rivers.depth(x, mid.y)
		assert_lt(absf(d - prev), 0.2, "depth has no step at x %.1f" % x)
		prev = d
	var ts: float = IsoConst.TILE_SIZE
	var f: Vector2 = Rivers.flow(mid.x * ts, mid.y * ts)
	assert_gt(f.length(), 0.5, "the river runs")
	var down: Vector2 = line[line.size() / 2 + 3] - mid
	assert_gt(f.dot(down), 0.0, "the current runs downstream")
	assert_eq(WaterMath.flow_at(mid.x * ts, mid.y * ts, 42), f, "WaterMath reports the river current")


func test_water_math_and_realm_include_rivers() -> void:
	var line: PackedVector2Array = Rivers.centreline(2)
	var p: Vector2 = line[line.size() / 2]
	var ts: float = IsoConst.TILE_SIZE
	assert_gt(WaterMath.intensity(p.x * ts, p.y * ts, 42), 0.5, "river water shows in WaterMath")
	assert_true(WaterMath.wet_at(p.x * ts, p.y * ts, 42, null), "grass keeps off the river")
	var t := Vector2i(floori(p.x), floori(p.y))
	assert_eq(RealmLayout.reserved_distance(t.x, t.y), Rivers.RIVER_PAD, "the river bed is reserved, not paved")
	assert_gt(RealmLayout.reserved_distance(t.x, t.y, false), 20.0, "the stream fade ignores rivers")
	assert_eq(RealmLayout.stamp_tile(t.x, t.y, IsoConst.TILE_HILL, 4), Vector2i(IsoConst.TILE_GRASS, 0),
		"the river bed is level grass")
	var cs: int = IsoConst.CHUNK_SIZE
	assert_true(RealmLayout.chunk_touches_realm(floori(p.x / cs), floori(p.y / cs)), "river chunks are realm chunks")


func test_biomes_follow_the_rivers() -> void:
	var cs: int = IsoConst.CHUNK_SIZE
	for c: int in range(Rivers.COURSES.size()):
		var line: PackedVector2Array = Rivers.centreline(c)
		var src: Vector2 = line[0]
		assert_eq(InfiniteWorldGen.biome_for_chunk(floori(src.x / cs), floori(src.y / cs), 42), BiomeDef.MOUNTAINS,
			"course %d rises in the mountains" % c)
		for seed: int in [1, 42, 9001]:
			for k: int in range(0, line.size(), 4):
				var q: Vector2 = line[k]
				var b: int = InfiniteWorldGen.biome_for_chunk(floori(q.x / cs), floori(q.y / cs), seed)
				assert_true(WaterMath.biome_has_water(b), "course %d draws its water at %s (seed %d)" % [c, str(q), seed])


func test_lookups_are_cheap() -> void:
	var line: PackedVector2Array = Rivers.centreline(1)
	var p: Vector2 = line[line.size() / 2] * IsoConst.TILE_SIZE
	var t0: int = Time.get_ticks_usec()
	for k: int in range(2000):
		Rivers.water(p.x + float(k % 40), p.y + float(k / 40))
	var per: float = float(Time.get_ticks_usec() - t0) / 2000.0
	assert_lt(per, 20.0, "a river water lookup stays cheap (%.1f µs)" % per)
