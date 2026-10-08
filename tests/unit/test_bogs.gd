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


func test_custom0_carries_flow_and_bog() -> void:
	const TerrainChannels = preload("res://game_logic/TerrainChannels.gd")
	var flow := PackedVector2Array([Vector2(1, 2), Vector2(3, 4)])
	var bog := PackedFloat32Array([0.25, 0.75])
	var both: Dictionary = TerrainChannels.custom0(flow, bog, 2, 3)
	assert_eq(int(both["fmt"]), Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	assert_eq(both["data"], PackedFloat32Array([1, 2, 0.25, 3, 4, 0.75, 0, 0, 0]), "xy flow, z bog; skirts dry")
	var flow_only: Dictionary = TerrainChannels.custom0(flow, PackedFloat32Array(), 2, 2)
	assert_eq(int(flow_only["fmt"]), Mesh.ARRAY_CUSTOM_RG_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT, "old RG layout")
	assert_true(TerrainChannels.custom0(PackedVector2Array(), bog, 2, 2).is_empty(), "no flow field, no CUSTOM0")


func test_a_bog_chunk_bakes_peat_reeds_and_dead_trees() -> void:
	const ChunkRenderer = preload("res://scenes/world/ChunkRenderer.gd")
	const ChunkData = preload("res://game_logic/world/ChunkData.gd")
	var p: Vector2 = _bog_spot(0.85)
	assert_ne(p, Vector2.INF, "found a deep bog")
	var cs: int = IsoConst.CHUNK_SIZE
	var cx: int = floori(p.x / (float(cs) * IsoConst.TILE_SIZE))
	var cz: int = floori(p.y / (float(cs) * IsoConst.TILE_SIZE))
	var cd := ChunkData.new(cx, cz)
	cd.biome_id = BiomeDef.FOREST
	var gw: int = cs + 6
	var grid := PackedInt32Array()
	grid.resize(gw * gw)
	grid.fill(IsoConst.TILE_GRASS)
	var hgrid := PackedInt32Array()
	hgrid.resize(gw * gw)
	var res: Dictionary = ChunkRenderer.prepare_terrain(cd, grid, hgrid, cx * cs - 3, cz * cs - 3, gw, SEED)
	var mesh: ArrayMesh = res["mesh"]
	var fmt: int = mesh.surface_get_format(0)
	assert_eq((fmt >> Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) & Mesh.ARRAY_FORMAT_CUSTOM_MASK, Mesh.ARRAY_CUSTOM_RGB_FLOAT,
		"bog rides CUSTOM0.z")
	var custom: PackedFloat32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]
	var deep: int = 0
	for i: int in range(2, custom.size(), 3):
		if custom[i] > WaterMath.BOG_POOL:
			deep += 1
	assert_gt(deep, 10, "the chunk has bog pool vertices")
	var props: Dictionary = res["props"]
	var trees: Array = props.get("tree_oak", []) + props.get("tree_pine", [])
	for t: Variant in trees:
		var lp: Vector3 = t
		var wp := Vector2(cd.origin_world().x + lp.x, cd.origin_world().z + lp.z)
		assert_lt(WaterMath.bog_at(wp.x, wp.y, SEED), WaterMath.BOG_DEAD_TREES, "no living tree in the bog")
	assert_gt((props.get("reed", []) as Array).size() + (props.get("tree_dead", []) as Array).size(), 0,
		"reeds or dead trees dress the bog")
	assert_eq(WaterMath.bog_prop(0.4, 0.1), "reed")
	assert_eq(WaterMath.bog_prop(0.8, 0.1), "", "no reeds out in the pool")


func test_bog_critters_and_hags() -> void:
	const CritterDef = preload("res://game_logic/world/CritterDef.gd")
	assert_true(CritterDef.visible_now("frog", true) and CritterDef.visible_now("frog", false), "frogs day and night")
	assert_false(CritterDef.visible_now("wisp", true), "will-o'-wisps hide by day")
	assert_true(CritterDef.visible_now("wisp", false), "and drift at night")
	assert_false(CritterDef.visible_now("butterfly", false), "day_only still works")
	for r: int in 20:
		assert_eq(CritterDef.species_for_bog(true, r), "frog", "only frogs by day")
	var night: Dictionary = {}
	for r: int in 20:
		night[CritterDef.species_for_bog(false, r)] = true
	assert_true(night.has("wisp") and night.has("frog"), "frogs and wisps at night")
	assert_true(CritterDef.fits("frog", BiomeDef.DESERT, false, true), "bog critters fit in a bog")
	assert_false(CritterDef.fits("frog", BiomeDef.GRASSLANDS, false, false), "but not out of one")
	assert_eq((CritterDef.FRAMES["wisp"] as Array).size(), 2, "wisp sprite frames")
	var p: Vector2 = _bog_spot(0.6)
	assert_eq(InfiniteWorldGen.enemy_type_at("wolf_pack", BiomeDef.FOREST, p.x, p.y, SEED), "bog_hag",
		"a wild enemy spawning in a bog is a bog hag")
	assert_eq(InfiniteWorldGen.enemy_type_at("cactus_worm", BiomeDef.DESERT, p.x, p.y, SEED), "cactus_worm",
		"no bog, no hag")
