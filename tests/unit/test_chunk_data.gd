## Unit tests for ChunkData.
##
## ChunkData is a pure RefCounted data container — no scene-tree dependencies.
extends "res://tests/framework/test_case.gd"

const ChunkData = preload("res://game_logic/world/ChunkData.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _chunk(cx: int = 0, cz: int = 0) -> ChunkData:
	return ChunkData.new(cx, cz)


# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func test_cx_stored_on_init() -> void:
	assert_eq(_chunk(3, 7).cx, 3)


func test_cz_stored_on_init() -> void:
	assert_eq(_chunk(3, 7).cz, 7)


func test_negative_coords_stored() -> void:
	var c := _chunk(-2, -5)
	assert_eq(c.cx, -2)
	assert_eq(c.cz, -5)


func test_tiles_have_correct_size() -> void:
	assert_eq(_chunk().tiles.size(), IsoConst.CHUNK_SIZE * IsoConst.CHUNK_SIZE)


func test_heights_have_correct_size() -> void:
	assert_eq(_chunk().heights.size(), IsoConst.CHUNK_SIZE * IsoConst.CHUNK_SIZE)


func test_all_tiles_initialised_to_grass() -> void:
	var c := _chunk()
	for i in range(c.tiles.size()):
		if c.tiles[i] != IsoConst.TILE_GRASS:
			assert_eq(c.tiles[i], IsoConst.TILE_GRASS, "tile %d was not TILE_GRASS" % i)
			return


func test_all_heights_initialised_to_zero() -> void:
	var c := _chunk()
	for i in range(c.heights.size()):
		if c.heights[i] != 0:
			assert_eq(c.heights[i], 0, "height %d was not 0" % i)
			return


func test_enemies_list_starts_empty() -> void:
	assert_eq(_chunk().enemies.size(), 0)


func test_chests_list_starts_empty() -> void:
	assert_eq(_chunk().chests.size(), 0)


func test_is_generated_starts_false() -> void:
	assert_false(_chunk().is_generated)


func test_has_entities_starts_false() -> void:
	assert_false(_chunk().has_entities)


# ---------------------------------------------------------------------------
# get_tile / set_tile
# ---------------------------------------------------------------------------

func test_get_tile_returns_grass_for_uninitialised_cell() -> void:
	assert_eq(_chunk().get_tile(0, 0), IsoConst.TILE_GRASS)


func test_set_and_get_tile_round_trip() -> void:
	var c := _chunk()
	c.set_tile(4, 7, IsoConst.TILE_WALL)
	assert_eq(c.get_tile(4, 7), IsoConst.TILE_WALL)


func test_set_tile_does_not_affect_adjacent_cells() -> void:
	var c := _chunk()
	c.set_tile(4, 7, IsoConst.TILE_WALL)
	assert_eq(c.get_tile(5, 7), IsoConst.TILE_GRASS)
	assert_eq(c.get_tile(4, 8), IsoConst.TILE_GRASS)


func test_get_tile_returns_grass_for_negative_x() -> void:
	assert_eq(_chunk().get_tile(-1, 0), IsoConst.TILE_GRASS)


func test_get_tile_returns_grass_for_negative_z() -> void:
	assert_eq(_chunk().get_tile(0, -1), IsoConst.TILE_GRASS)


func test_get_tile_returns_grass_for_x_out_of_bounds() -> void:
	assert_eq(_chunk().get_tile(IsoConst.CHUNK_SIZE, 0), IsoConst.TILE_GRASS)


func test_get_tile_returns_grass_for_z_out_of_bounds() -> void:
	assert_eq(_chunk().get_tile(0, IsoConst.CHUNK_SIZE), IsoConst.TILE_GRASS)


func test_set_tile_ignores_out_of_bounds_without_crash() -> void:
	var c := _chunk()
	c.set_tile(-1, 0, IsoConst.TILE_WALL)   # must not crash
	c.set_tile(0, -1, IsoConst.TILE_WALL)
	c.set_tile(IsoConst.CHUNK_SIZE, 0, IsoConst.TILE_WALL)
	c.set_tile(0, IsoConst.CHUNK_SIZE, IsoConst.TILE_WALL)
	assert_eq(c.get_tile(0, 0), IsoConst.TILE_GRASS)  # unchanged


# ---------------------------------------------------------------------------
# get_height / set_height
# ---------------------------------------------------------------------------

func test_get_height_returns_one_for_out_of_bounds_negative() -> void:
	assert_eq(_chunk().get_height(-1, 0), 1)


func test_get_height_returns_one_for_out_of_bounds_positive() -> void:
	assert_eq(_chunk().get_height(IsoConst.CHUNK_SIZE, 0), 1)


func test_set_and_get_height_round_trip() -> void:
	var c := _chunk()
	c.set_height(3, 9, 5)
	assert_eq(c.get_height(3, 9), 5)


func test_set_height_does_not_affect_adjacent_cells() -> void:
	var c := _chunk()
	c.set_height(3, 9, 5)
	assert_eq(c.get_height(4, 9), 0)
	assert_eq(c.get_height(3, 10), 0)


func test_set_height_ignores_out_of_bounds_without_crash() -> void:
	var c := _chunk()
	c.set_height(-1, 0, 3)  # must not crash
	c.set_height(0, IsoConst.CHUNK_SIZE, 3)
	assert_eq(c.get_height(0, 0), 0)  # unchanged


# ---------------------------------------------------------------------------
# origin_world
# ---------------------------------------------------------------------------

func test_origin_world_at_0_0() -> void:
	var o: Vector3 = _chunk(0, 0).origin_world()
	assert_almost_eq(o.x, 0.0)
	assert_almost_eq(o.y, 0.0)
	assert_almost_eq(o.z, 0.0)


func test_origin_world_at_1_0() -> void:
	var expected_x: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var o: Vector3 = _chunk(1, 0).origin_world()
	assert_almost_eq(o.x, expected_x)
	assert_almost_eq(o.z, 0.0)


func test_origin_world_at_0_1() -> void:
	var expected_z: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var o: Vector3 = _chunk(0, 1).origin_world()
	assert_almost_eq(o.x, 0.0)
	assert_almost_eq(o.z, expected_z)


func test_origin_world_negative_chunk() -> void:
	var expected_x: float = -float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var o: Vector3 = _chunk(-1, 0).origin_world()
	assert_almost_eq(o.x, expected_x)
