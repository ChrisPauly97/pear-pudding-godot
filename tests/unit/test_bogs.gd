## GID-174: bogs (WaterMath.bog_at / bog_in) and their gameplay hooks.
extends "res://tests/framework/test_case.gd"

const WaterMath = preload("res://game_logic/world/WaterMath.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const Rivers = preload("res://game_logic/world/Rivers.gd")
const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")

const SEED: int = 42


## A bog spot in a bog biome near the origin (world units), or Vector2.INF.
func _bog_spot(min_bog: float) -> Vector2:
	for z: int in range(-300, 300, 2):
		for x: int in range(-300, 300, 2):
			var wx: float = float(x) * 2.0 + 1.0
			var wz: float = float(z) * 2.0 + 1.0
			var b: int = InfiniteWorldGen.biome_for_chunk(floori(float(x) / 16.0), floori(float(z) / 16.0), SEED)
			if WaterMath.bog_in(b, wx, wz, SEED) > min_bog:
				return Vector2(wx, wz)
	return Vector2.INF


func test_bogs_cover_a_little_of_the_lowlands() -> void:
	var n: int = 0
	var bog: int = 0
	for z: int in range(-300, 300, 4):
		for x: int in range(-300, 300, 4):
			var b: int = InfiniteWorldGen.biome_for_chunk(floori(float(x) / 16.0), floori(float(z) / 16.0), SEED)
			if not WaterMath.biome_has_bog(b):
				continue
			n += 1
			if WaterMath.bog_in(b, float(x) * 2.0 + 1.0, float(z) * 2.0 + 1.0, SEED) > 0.3:
				bog += 1
	var share: float = float(bog) / float(maxi(1, n))
	assert_between(share, 0.03, 0.12, "bogs cover %.1f%% of grassland and forest" % (share * 100.0))


func test_bogs_only_in_the_lowland_biomes() -> void:
	var p: Vector2 = _bog_spot(0.5)
	assert_ne(p, Vector2.INF, "found a bog")
	assert_gt(WaterMath.bog_in(BiomeDef.FOREST, p.x, p.y, SEED), 0.5)
	assert_gt(WaterMath.bog_in(BiomeDef.GRASSLANDS, p.x, p.y, SEED), 0.5)
	for b: int in [BiomeDef.DESERT, BiomeDef.SCORCHED, BiomeDef.MOUNTAINS]:
		assert_eq(WaterMath.bog_in(b, p.x, p.y, SEED), 0.0, "no bog in biome %d" % b)
	assert_eq(WaterMath.bog_at(p.x, p.y, SEED), WaterMath.bog_at(p.x, p.y, SEED), "deterministic")


func test_bogs_keep_off_towns_roads_and_rivers() -> void:
	var ts: float = IsoConst.TILE_SIZE
	for town: String in RealmLayout.town_names():
		var r: Rect2i = RealmLayout.world_rect(town)
		for z: int in range(r.position.y, r.end.y, 4):
			for x: int in range(r.position.x, r.end.x, 4):
				assert_eq(WaterMath.bog_at((float(x) + 0.5) * ts, (float(z) + 0.5) * ts, SEED), 0.0,
					"no bog in %s at (%d, %d)" % [town, x, z])
	for c: int in Rivers.COURSES.size():
		var line: PackedVector2Array = Rivers.centreline(c)
		for k: int in range(0, line.size(), 3):
			assert_eq(WaterMath.bog_at(line[k].x * ts, line[k].y * ts, SEED), 0.0, "no bog in river %d" % c)
	for road: Array in RealmLayout.ROADS:
		var a: Vector2 = road[0]
		assert_eq(WaterMath.bog_at(a.x * ts, a.y * ts, SEED), 0.0, "no bog on a road")
