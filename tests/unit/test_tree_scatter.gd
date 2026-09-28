## Tree groves (TreeScatter): trees grow on open ground, keep clear of ruins
## and entities, and every tree key has sprites.
extends "res://tests/framework/test_case.gd"

const _TreeScatter = preload("res://game_logic/world/TreeScatter.gd")
const _ChunkData = preload("res://game_logic/world/ChunkData.gd")
const _BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")


func _trees(biome: int, cx: int, cz: int, lookup: Callable, cd: _ChunkData = null) -> Array[Vector3]:
	if cd == null:
		cd = _ChunkData.new(cx, cz)
	cd.biome_id = biome
	var n: int = IsoConst.CHUNK_SIZE + 1
	var hfield := PackedFloat32Array()
	hfield.resize(n * n)
	var out: Array[Vector3] = []
	var res: Dictionary = _TreeScatter.compute(cd, lookup, hfield, cd.origin_world(), n, 777)
	for key: String in res.keys():
		assert_true(_TreeScatter.is_tree_key(key), "%s is a tree key" % key)
		for p: Vector3 in res[key]:
			out.append(p)
	return out


func _forest_count(lookup: Callable) -> int:
	var total: int = 0
	for i in range(8):
		total += _trees(_BiomeDef.FOREST, 40 + i, -30, lookup).size()
	return total


func test_forest_chunks_grow_trees() -> void:
	var grass := func(_tx: int, _tz: int) -> int: return IsoConst.TILE_GRASS
	assert_gt(_forest_count(grass), 20, "a run of forest chunks grows trees")


func test_no_trees_on_or_beside_walls() -> void:
	var walls := func(_tx: int, _tz: int) -> int: return IsoConst.TILE_WALL
	assert_eq(_forest_count(walls), 0, "ruin walls grow no trees")
	# Every other column a wall: no tile has eight open neighbours.
	var striped := func(tx: int, _tz: int) -> int:
		return IsoConst.TILE_WALL if tx % 2 == 0 else IsoConst.TILE_GRASS
	assert_eq(_forest_count(striped), 0, "trees keep a tile clear of walls")


func test_trees_keep_clear_of_entities() -> void:
	var grass := func(_tx: int, _tz: int) -> int: return IsoConst.TILE_GRASS
	var cd := _ChunkData.new(41, -30)
	var o: Vector3 = cd.origin_world()
	var span: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	for gz in range(0, 8):
		for gx in range(0, 8):
			cd.chests.append({"x": o.x + gx * span / 8.0, "z": o.z + gz * span / 8.0})
	for p: Vector3 in _trees(_BiomeDef.FOREST, 41, -30, grass, cd):
		for c: Dictionary in cd.chests:
			var d: float = Vector2(o.x + p.x, o.z + p.z).distance_to(Vector2(float(c["x"]), float(c["z"])))
			assert_true(d >= _TreeScatter.ENTITY_CLEARANCE, "tree clear of chest")


func test_every_tree_key_has_sprites() -> void:
	assert_eq(_BiomeDef.TREE_SETS.size(), _BiomeDef.PARAMS.size(), "one tree set per biome")
	assert_eq(_BiomeDef.TREE_GROVE_CHANCE.size(), _BiomeDef.PARAMS.size(), "grove chance per biome")
	assert_eq(_BiomeDef.TREE_LONE_CHANCE.size(), _BiomeDef.PARAMS.size(), "lone chance per biome")
	for set_arr: Array in _BiomeDef.TREE_SETS:
		for key: String in set_arr:
			assert_gt(_SpriteRegistry.prop_variants(key).size(), 1, "%s has sprite variants" % key)
