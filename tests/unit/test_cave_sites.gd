## GID-173 / TID-699: cave entrances placed in rocky chunks (CaveSites) + RuinGen extraction.
extends "res://tests/framework/test_case.gd"

const CaveSites = preload("res://game_logic/world/CaveSites.gd")
const RuinGen = preload("res://game_logic/world/RuinGen.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const ChunkData = preload("res://game_logic/world/ChunkData.gd")
const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")

const SEED: int = 42


func _caves_in(r: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cz: int in range(-r, r):
		for cx: int in range(-r, r):
			var c: ChunkData = InfiniteWorldGen.generate_chunk(cx, cz, SEED)
			for d: Dictionary in c.doors:
				if str(d.get("kind", "")) == "cave":
					var e: Dictionary = d.duplicate()
					e["cx"] = cx
					e["cz"] = cz
					e["biome"] = c.biome_id
					e["chunk"] = c
					out.append(e)
	return out


func test_caves_open_in_rocky_country_only() -> void:
	var caves: Array[Dictionary] = _caves_in(14)
	assert_gt(caves.size(), 3, "a handful of caves within 14 chunks")
	var ids: Dictionary = {}
	for cave: Dictionary in caves:
		var b: int = cave["biome"]
		assert_true(CaveSites.ONE_IN.has(b), "cave in a rocky biome (biome %d)" % b)
		assert_false(RealmLayout.chunk_touches_realm(int(cave["cx"]), int(cave["cz"])), "no cave by a town, road or river")
		assert_true(CaveSites.is_cave_map(str(cave["target_map"])), "leads into a cave map")
		assert_true(str(cave["target_map"]).begins_with("dungeon_"), "keeps the dungeon_ prefix every dungeon path checks")
		assert_eq(str(cave["target_door_id"]), "entrance")
		assert_false(ids.has(cave["id"]), "cave ids are unique")
		ids[cave["id"]] = true


func test_mouth_sits_at_the_foot_of_a_hill() -> void:
	for cave: Dictionary in _caves_in(10):
		var c: ChunkData = cave["chunk"]
		var f: Array = cave["facing"]
		var d := Vector2i(int(f[0]), int(f[1]))
		assert_true(d == Vector2i(1, 0) or d == Vector2i(0, 1), "opens toward the camera")
		var cs: int = IsoConst.CHUNK_SIZE
		var t: Vector2i = IsoConst.world_to_tile(float(cave["x"]), float(cave["z"])) \
				- Vector2i(int(cave["cx"]) * cs, int(cave["cz"]) * cs)
		assert_eq(c.get_tile(t.x, t.y), IsoConst.TILE_GRASS, "the approach is level grass")
		assert_eq(c.get_height(t.x, t.y), 0)
		assert_eq(c.get_tile(t.x - d.x, t.y - d.y), IsoConst.TILE_GRASS, "and so is the tile in front")
		assert_eq(c.get_tile(t.x + d.x, t.y + d.y), IsoConst.TILE_HILL, "the hill rises right behind the mouth")
		assert_gte(int(cave["face_height"]), CaveSites.MIN_PEAK)


func test_sites_are_deterministic_and_rare() -> void:
	var a: Array[Dictionary] = _caves_in(6)
	var b: Array[Dictionary] = _caves_in(6)
	assert_eq(a.size(), b.size(), "same world, same caves")
	for i: int in a.size():
		assert_eq(a[i]["target_map"], b[i]["target_map"])
	var chunk := ChunkData.new(0, 0)
	chunk.biome_id = BiomeDef.GRASSLANDS
	assert_true(CaveSites.site_for(chunk, 0, 0, 7).is_empty(), "no caves in the grasslands")


func test_ruin_gen_keeps_its_old_roll() -> void:
	var ruins: int = 0
	for cz: int in range(-12, 12):
		for cx: int in range(-12, 12):
			var cseed: int = InfiniteWorldGen._chunk_seed(cx, cz, SEED)
			if RuinGen.has_ruin(cx, cz, cseed):
				ruins += 1
				var c: ChunkData = InfiniteWorldGen.generate_chunk_data_only(cx, cz, SEED)
				var walls: int = 0
				for i: int in IsoConst.CHUNK_SIZE * IsoConst.CHUNK_SIZE:
					if c.get_tile(i % IsoConst.CHUNK_SIZE, i / IsoConst.CHUNK_SIZE) == IsoConst.TILE_WALL:
						walls += 1
				assert_gt(walls, 4, "ruin chunk (%d, %d) has its wall ring" % [cx, cz])
	assert_between(ruins, 60, 200, "about a third of the off-realm chunks hold a ruin (%d)" % ruins)


func test_cave_mouth_faces_the_approach() -> void:
	const CaveMouth = preload("res://scenes/world/entities/CaveMouth.gd")
	for f: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var m: Node3D = CaveMouth.make(f, 0.75)
		var into: Vector3 = m.basis * Vector3.FORWARD
		assert_almost_eq(into.x, float(f.x), 0.001, "local −Z runs into the hill (x) for %s" % str(f))
		assert_almost_eq(into.z, float(f.y), 0.001, "local −Z runs into the hill (z) for %s" % str(f))
		assert_almost_eq(m.position.y, -0.75, 0.001, "the arch stands on the ground, not at the door's height")
		assert_gt(Vector2(m.position.x, m.position.z).dot(Vector2(f)), 0.0, "set back toward the hill")
		var arch: MeshInstance3D = m.get_child(0) as MeshInstance3D
		assert_gt(arch.mesh.get_aabb().size.y, CaveMouth.OPEN_H, "an arch taller than the opening")
		m.free()


func test_cave_doors_and_names() -> void:
	const Door = preload("res://scenes/world/entities/Door.gd")
	const PlaceNames = preload("res://game_logic/PlaceNames.gd")
	var d: Door = Door.new()
	d.init_from_data({"target_map": "dungeon_cave_123", "kind": "cave", "facing": [1, 0], "x": 0.0, "z": 0.0})
	assert_true(d._is_cave, "a cave door")
	d.free()
	var title: String = PlaceNames.title("dungeon_cave_123")
	var cave_noun: bool = false
	for n: String in PlaceNames.CAVE_NOUNS:
		cave_noun = cave_noun or title.ends_with(" " + n)
	assert_true(cave_noun, "cave maps get a cave name (%s)" % title)
	assert_false(PlaceNames.title("dungeon_123").ends_with(" Cave"), "plain dungeons keep dungeon names")
