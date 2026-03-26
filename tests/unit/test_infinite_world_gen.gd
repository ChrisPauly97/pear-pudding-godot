## Unit tests for InfiniteWorldGen.
##
## InfiniteWorldGen is a pure-static RefCounted utility — all generation is
## deterministic given the same (cx, cz, seed) triple. No scene-tree needed.
extends "res://tests/framework/test_case.gd"

const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const ChunkData        = preload("res://game_logic/world/ChunkData.gd")

const SEED: int = 12345

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _gen(cx: int = 0, cz: int = 0, world_seed: int = SEED) -> ChunkData:
	return InfiniteWorldGen.generate_chunk(cx, cz, world_seed) as ChunkData


func _gen_data_only(cx: int = 0, cz: int = 0, world_seed: int = SEED) -> ChunkData:
	return InfiniteWorldGen.generate_chunk_data_only(cx, cz, world_seed) as ChunkData


# ---------------------------------------------------------------------------
# Basic return values
# ---------------------------------------------------------------------------

func test_generate_chunk_returns_non_null() -> void:
	assert_not_null(_gen())


func test_generate_chunk_returns_chunk_data() -> void:
	var c := _gen()
	assert_not_null(c)
	assert_eq(c.cx, 0)


func test_generate_chunk_sets_is_generated() -> void:
	assert_true(_gen().is_generated)


func test_generate_chunk_sets_has_entities() -> void:
	assert_true(_gen().has_entities)


func test_generate_chunk_data_only_sets_is_generated() -> void:
	assert_true(_gen_data_only().is_generated)


func test_generate_chunk_data_only_does_not_set_has_entities() -> void:
	assert_false(_gen_data_only().has_entities)


func test_generate_chunk_data_only_has_no_enemies() -> void:
	assert_eq(_gen_data_only().enemies.size(), 0)


func test_generate_chunk_data_only_has_no_chests() -> void:
	assert_eq(_gen_data_only().chests.size(), 0)


func test_cx_cz_set_correctly_for_non_origin_chunk() -> void:
	var c := _gen(3, -2)
	assert_eq(c.cx, 3)
	assert_eq(c.cz, -2)


# ---------------------------------------------------------------------------
# Tile validity
# ---------------------------------------------------------------------------

func test_all_tiles_are_valid_types() -> void:
	var c := _gen()
	var valid := [IsoConst.TILE_GRASS, IsoConst.TILE_WALL, IsoConst.TILE_HILL]
	for i in range(c.tiles.size()):
		var t: int = c.tiles[i]
		if not (t in valid):
			_fail("tile %d has invalid type %d" % [i, t])
			return


func test_hill_tiles_have_nonzero_height() -> void:
	# Try a few chunks to find a hill; if none found in any, the test is vacuous.
	for cx in range(-2, 3):
		for cz in range(-2, 3):
			var c := _gen(cx, cz)
			for lz in range(ChunkData.CHUNK_SIZE):
				for lx in range(ChunkData.CHUNK_SIZE):
					if c.get_tile(lx, lz) == IsoConst.TILE_HILL:
						assert_gt(c.get_height(lx, lz), 0,
							"hill tile at (%d,%d) has zero height" % [lx, lz])


func test_grass_tiles_have_zero_height() -> void:
	var c := _gen()
	for lz in range(ChunkData.CHUNK_SIZE):
		for lx in range(ChunkData.CHUNK_SIZE):
			if c.get_tile(lx, lz) == IsoConst.TILE_GRASS:
				assert_eq(c.get_height(lx, lz), 0,
					"grass tile at (%d,%d) has non-zero height" % [lx, lz])


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

func test_generate_chunk_is_deterministic() -> void:
	var c1 := _gen(5, 3, 99)
	var c2 := _gen(5, 3, 99)
	for i in range(c1.tiles.size()):
		if c1.tiles[i] != c2.tiles[i]:
			_fail("tiles differ at index %d: %d vs %d" % [i, c1.tiles[i], c2.tiles[i]])
			return


func test_different_seeds_produce_different_tiles() -> void:
	var c1 := _gen(0, 0, 111)
	var c2 := _gen(0, 0, 222)
	# Almost certain to differ with different seeds; if they somehow match that
	# is a collision and not a test failure in the strict sense, so we just warn.
	var differ := false
	for i in range(c1.tiles.size()):
		if c1.tiles[i] != c2.tiles[i]:
			differ = true
			break
	assert_true(differ, "expected different seeds to produce different tiles")


func test_different_positions_produce_different_tiles() -> void:
	var c1 := _gen(0, 0, SEED)
	var c2 := _gen(1, 0, SEED)
	var differ := false
	for i in range(c1.tiles.size()):
		if c1.tiles[i] != c2.tiles[i]:
			differ = true
			break
	assert_true(differ, "expected different chunk positions to produce different tiles")


# ---------------------------------------------------------------------------
# Entity generation
# ---------------------------------------------------------------------------

func test_enemy_count_is_at_most_two() -> void:
	for cx in range(-3, 4):
		for cz in range(-3, 4):
			var c := _gen(cx, cz)
			assert_lte(c.enemies.size(), 2,
				"chunk (%d,%d) has more than 2 enemies" % [cx, cz])


func test_chest_count_is_at_most_one() -> void:
	for cx in range(-3, 4):
		for cz in range(-3, 4):
			var c := _gen(cx, cz)
			assert_lte(c.chests.size(), 1,
				"chunk (%d,%d) has more than 1 chest" % [cx, cz])


func test_enemy_dict_has_required_keys() -> void:
	# Scan several chunks to find at least one enemy to validate.
	var found := false
	for cx in range(-5, 6):
		for cz in range(-5, 6):
			var c := _gen(cx, cz)
			for e_data in c.enemies:
				found = true
				assert_true(e_data.has("id"),         "enemy missing 'id'")
				assert_true(e_data.has("x"),          "enemy missing 'x'")
				assert_true(e_data.has("z"),          "enemy missing 'z'")
				assert_true(e_data.has("alive"),      "enemy missing 'alive'")
				assert_true(e_data.has("enemy_type"), "enemy missing 'enemy_type'")
				assert_true(e_data.has("enemy_deck"), "enemy missing 'enemy_deck'")
				break
		if found:
			break
	if not found:
		pending("no enemies found in scanned chunks — increase scan range")


func test_enemy_ids_are_unique_within_chunk() -> void:
	for cx in range(-3, 4):
		for cz in range(-3, 4):
			var c := _gen(cx, cz)
			var seen: Array[String] = []
			for e_data in c.enemies:
				var eid: String = str(e_data.get("id", ""))
				assert_does_not_have(seen, eid,
					"duplicate enemy id '%s' in chunk (%d,%d)" % [eid, cx, cz])
				seen.append(eid)


func test_chest_dict_has_required_keys() -> void:
	var found := false
	for cx in range(-5, 6):
		for cz in range(-5, 6):
			var c := _gen(cx, cz)
			for chest in c.chests:
				found = true
				assert_true(chest.has("id"),       "chest missing 'id'")
				assert_true(chest.has("x"),        "chest missing 'x'")
				assert_true(chest.has("z"),        "chest missing 'z'")
				assert_true(chest.has("card_ids"), "chest missing 'card_ids'")
				assert_true(chest.has("opened"),   "chest missing 'opened'")
				break
		if found:
			break
	if not found:
		pending("no chests found in scanned chunks — increase scan range")
