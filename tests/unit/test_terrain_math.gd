## Unit tests for TerrainMath.
##
## TerrainMath is a pure-static RefCounted utility. All methods except
## spawn_entity() are Node-free and fully unit-testable.
## spawn_entity() is excluded — it instantiates PackedScene nodes.
extends "res://tests/framework/test_case.gd"

const TerrainMath = preload("res://game_logic/TerrainMath.gd")

# ---------------------------------------------------------------------------
# Tile-lookup helpers (Callable-compatible free functions)
# ---------------------------------------------------------------------------

static func _tile_all_grass(_x: int, _z: int) -> int:
	return IsoConst.TILE_GRASS

static func _height_all_zero(_x: int, _z: int) -> int:
	return 0

# Single hill tile at (5, 5) with height level 3
static func _tile_single_hill(x: int, z: int) -> int:
	if x == 5 and z == 5:
		return IsoConst.TILE_HILL
	return IsoConst.TILE_GRASS

static func _height_single_hill(x: int, z: int) -> int:
	if x == 5 and z == 5:
		return 3
	return 0

# Single wall tile at (5, 5) with height level 2
static func _tile_single_wall(x: int, z: int) -> int:
	if x == 5 and z == 5:
		return IsoConst.TILE_WALL
	return IsoConst.TILE_GRASS

static func _height_single_wall(x: int, z: int) -> int:
	if x == 5 and z == 5:
		return 2
	return 0


# ---------------------------------------------------------------------------
# get_height_at — flat world
# ---------------------------------------------------------------------------

func test_get_height_at_returns_zero_on_flat_grass() -> void:
	var h: float = TerrainMath.get_height_at(
		10.0, 10.0,
		_tile_all_grass, _height_all_zero,
		4.0, 2.0)
	assert_almost_eq(h, 0.0)


func test_get_height_at_returns_zero_far_from_hill() -> void:
	# Query 50 world units away from the hill at tile (5,5)
	var tile_size: float = IsoConst.TILE_SIZE
	var far_x: float = 50.0 * tile_size
	var h: float = TerrainMath.get_height_at(
		far_x, far_x,
		_tile_single_hill, _height_single_hill,
		4.0, 2.0)
	assert_almost_eq(h, 0.0)


func test_get_height_at_returns_positive_at_hill_center() -> void:
	# Query at the exact centre of the hill tile (5, 5)
	var tile_size: float = IsoConst.TILE_SIZE
	var cx: float = (5.0 + 0.5) * tile_size
	var cz: float = (5.0 + 0.5) * tile_size
	var h: float = TerrainMath.get_height_at(
		cx, cz,
		_tile_single_hill, _height_single_hill,
		4.0, 2.0)
	assert_gt(h, 0.0, "height at hill centre should be > 0")


func test_get_height_at_returns_positive_near_wall() -> void:
	var tile_size: float = IsoConst.TILE_SIZE
	var cx: float = (5.0 + 0.5) * tile_size
	var cz: float = (5.0 + 0.5) * tile_size
	var h: float = TerrainMath.get_height_at(
		cx, cz,
		_tile_single_wall, _height_single_wall,
		4.0, 2.0)
	assert_gt(h, 0.0, "height at wall should be > 0")


# ---------------------------------------------------------------------------
# compute_height_field — size and content
# ---------------------------------------------------------------------------

func test_compute_height_field_size_is_nvx_times_nvz() -> void:
	var nvx: int = 5
	var nvz: int = 7
	var hfield: PackedFloat32Array = TerrainMath.compute_height_field(
		_tile_all_grass, _height_all_zero,
		0.0, 0.0, nvx, nvz, IsoConst.TILE_SIZE, 4.0, 2.0)
	assert_eq(hfield.size(), nvx * nvz)


func test_compute_height_field_all_zero_on_flat_grass() -> void:
	var hfield: PackedFloat32Array = TerrainMath.compute_height_field(
		_tile_all_grass, _height_all_zero,
		0.0, 0.0, 8, 8, IsoConst.TILE_SIZE, 4.0, 2.0)
	for i in range(hfield.size()):
		if hfield[i] != 0.0:
			assert_almost_eq(hfield[i], 0.0, 0.001, "expected 0 at index %d" % i)
			return


func test_compute_height_field_elevated_near_hill() -> void:
	# Grid origin at tile (4,4), hill at (5,5); nearest vertex should be elevated
	var tile_size: float = IsoConst.TILE_SIZE
	var origin_x: float = 4.0 * tile_size
	var origin_z: float = 4.0 * tile_size
	var hfield: PackedFloat32Array = TerrainMath.compute_height_field(
		_tile_single_hill, _height_single_hill,
		origin_x, origin_z, 5, 5, tile_size, 4.0, 2.0)
	var has_elevated := false
	for i in range(hfield.size()):
		if hfield[i] > 0.001:
			has_elevated = true
			break
	assert_true(has_elevated, "expected at least one elevated vertex near the hill")


func test_compute_height_field_elevated_near_wall() -> void:
	var tile_size: float = IsoConst.TILE_SIZE
	var origin_x: float = 4.0 * tile_size
	var origin_z: float = 4.0 * tile_size
	var hfield: PackedFloat32Array = TerrainMath.compute_height_field(
		_tile_single_wall, _height_single_wall,
		origin_x, origin_z, 5, 5, tile_size, 4.0, 2.0)
	var has_elevated := false
	for i in range(hfield.size()):
		if hfield[i] > 0.001:
			has_elevated = true
			break
	assert_true(has_elevated, "expected at least one elevated vertex near the wall")


func test_compute_height_field_values_are_non_negative() -> void:
	var hfield: PackedFloat32Array = TerrainMath.compute_height_field(
		_tile_single_hill, _height_single_hill,
		0.0, 0.0, 16, 16, IsoConst.TILE_SIZE, 4.0, 2.0)
	for i in range(hfield.size()):
		if hfield[i] < 0.0:
			_fail("negative height %f at index %d" % [hfield[i], i])
			return


# ---------------------------------------------------------------------------
# build_terrain_mesh
# ---------------------------------------------------------------------------

func _flat_hfield(nvx: int, nvz: int) -> PackedFloat32Array:
	var h := PackedFloat32Array()
	h.resize(nvx * nvz)
	h.fill(0.0)
	return h


func test_build_terrain_mesh_returns_dict() -> void:
	var nvx: int = 4
	var nvz: int = 4
	var result: Dictionary = TerrainMath.build_terrain_mesh(
		_flat_hfield(nvx, nvz),
		_tile_all_grass,
		0.0, 0.0, nvx, nvz, IsoConst.TILE_SIZE, 2.0)
	assert_true(result is Dictionary)


func test_build_terrain_mesh_has_mesh_key() -> void:
	var nvx: int = 4
	var nvz: int = 4
	var result: Dictionary = TerrainMath.build_terrain_mesh(
		_flat_hfield(nvx, nvz),
		_tile_all_grass,
		0.0, 0.0, nvx, nvz, IsoConst.TILE_SIZE, 2.0)
	assert_true(result.has("mesh"), "result missing 'mesh' key")


func test_build_terrain_mesh_has_hmap_key() -> void:
	var nvx: int = 4
	var nvz: int = 4
	var result: Dictionary = TerrainMath.build_terrain_mesh(
		_flat_hfield(nvx, nvz),
		_tile_all_grass,
		0.0, 0.0, nvx, nvz, IsoConst.TILE_SIZE, 2.0)
	assert_true(result.has("hmap"), "result missing 'hmap' key")


func test_build_terrain_mesh_mesh_is_array_mesh() -> void:
	var nvx: int = 4
	var nvz: int = 4
	var result: Dictionary = TerrainMath.build_terrain_mesh(
		_flat_hfield(nvx, nvz),
		_tile_all_grass,
		0.0, 0.0, nvx, nvz, IsoConst.TILE_SIZE, 2.0)
	assert_true(result["mesh"] is ArrayMesh, "mesh should be ArrayMesh")


func test_build_terrain_mesh_hmap_dimensions_match() -> void:
	var nvx: int = 6
	var nvz: int = 8
	var result: Dictionary = TerrainMath.build_terrain_mesh(
		_flat_hfield(nvx, nvz),
		_tile_all_grass,
		0.0, 0.0, nvx, nvz, IsoConst.TILE_SIZE, 2.0)
	var hmap: HeightMapShape3D = result["hmap"] as HeightMapShape3D
	assert_eq(hmap.map_width, nvx)
	assert_eq(hmap.map_depth, nvz)


func test_build_terrain_mesh_hmap_data_matches_input() -> void:
	var nvx: int = 3
	var nvz: int = 3
	var hfield := _flat_hfield(nvx, nvz)
	hfield[4] = 1.5  # centre point
	var result: Dictionary = TerrainMath.build_terrain_mesh(
		hfield, _tile_all_grass,
		0.0, 0.0, nvx, nvz, IsoConst.TILE_SIZE, 2.0)
	var hmap: HeightMapShape3D = result["hmap"] as HeightMapShape3D
	assert_almost_eq(hmap.map_data[4], 1.5, 0.001)
