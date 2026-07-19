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


func test_get_height_at_returns_zero_on_wall_tile() -> void:
	# Walls are flat in the terrain mesh (y=0); their height comes from the
	# wall face mesh's side quads and top cap, not the height field.
	var tile_size: float = IsoConst.TILE_SIZE
	var cx: float = (5.0 + 0.5) * tile_size
	var cz: float = (5.0 + 0.5) * tile_size
	var h: float = TerrainMath.get_height_at(
		cx, cz,
		_tile_single_wall, _height_single_wall,
		4.0, 2.0)
	assert_almost_eq(h, 0.0, 0.001, "terrain height at wall should be 0 (wall geometry is in wall face mesh)")


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


func test_compute_height_field_flat_on_wall_tiles() -> void:
	# Wall tiles must be flat (y=0) in the terrain mesh — their geometry comes
	# from build_wall_face_mesh (side quads + top cap), not the height field.
	var tile_size: float = IsoConst.TILE_SIZE
	var origin_x: float = 4.0 * tile_size
	var origin_z: float = 4.0 * tile_size
	var hfield: PackedFloat32Array = TerrainMath.compute_height_field(
		_tile_single_wall, _height_single_wall,
		origin_x, origin_z, 5, 5, tile_size, 4.0, 2.0)
	for i in range(hfield.size()):
		if hfield[i] > 0.001:
			_fail("expected all-zero height field for wall-only world at index %d (got %f)" % [i, hfield[i]])
			return


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


# ---------------------------------------------------------------------------
# Packed-grid fast paths (GID-121) — must match the Callable variants exactly
# ---------------------------------------------------------------------------

const _PG_W: int = 12  # packed test grid is _PG_W × _PG_W, origin tile (0,0)

# Mixed terrain: hill at (5,5) h=3, wall at (2,8), cracked wall at (9,3) h=2.
func _make_packed_grids() -> Array:
	var tile_grid := PackedInt32Array()
	var height_grid := PackedInt32Array()
	tile_grid.resize(_PG_W * _PG_W)
	height_grid.resize(_PG_W * _PG_W)
	tile_grid.fill(IsoConst.TILE_GRASS)
	height_grid.fill(0)
	tile_grid[5 * _PG_W + 5] = IsoConst.TILE_HILL
	height_grid[5 * _PG_W + 5] = 3
	tile_grid[8 * _PG_W + 2] = IsoConst.TILE_WALL
	tile_grid[3 * _PG_W + 9] = IsoConst.TILE_CRACKED
	height_grid[3 * _PG_W + 9] = 2
	return [tile_grid, height_grid]

# Callable lookups over the same data, with the same out-of-range fallbacks the
# packed variants use (tile → TILE_WALL, height → 1).
func _packed_tile_lookup(grids: Array) -> Callable:
	var tile_grid: PackedInt32Array = grids[0]
	return func(x: int, z: int) -> int:
		if x < 0 or x >= _PG_W or z < 0 or z >= _PG_W:
			return IsoConst.TILE_WALL
		return tile_grid[z * _PG_W + x]

func _packed_height_lookup(grids: Array) -> Callable:
	var height_grid: PackedInt32Array = grids[1]
	return func(x: int, z: int) -> int:
		if x < 0 or x >= _PG_W or z < 0 or z >= _PG_W:
			return 1
		return height_grid[z * _PG_W + x]


func test_compute_height_field_grid_matches_callable_variant() -> void:
	var grids: Array = _make_packed_grids()
	var tile_size: float = IsoConst.TILE_SIZE
	var origin_x: float = 3.0 * tile_size
	var origin_z: float = 3.0 * tile_size
	var nvx: int = 9
	var nvz: int = 9
	var step: float = tile_size * 0.5
	var expected: PackedFloat32Array = TerrainMath.compute_height_field(
		_packed_tile_lookup(grids), _packed_height_lookup(grids),
		origin_x, origin_z, nvx, nvz, step,
		IsoConst.HILL_CURVE_R, IsoConst.HILL_PEAK_H)
	var actual: PackedFloat32Array = TerrainMath.compute_height_field_grid(
		grids[0], grids[1], 0, 0, _PG_W,
		origin_x, origin_z, nvx, nvz, step,
		IsoConst.HILL_CURVE_R, IsoConst.HILL_PEAK_H)
	assert_eq(actual.size(), expected.size())
	for i in range(expected.size()):
		if absf(actual[i] - expected[i]) > 0.0001:
			_fail("height field mismatch at index %d: grid=%f callable=%f" % [i, actual[i], expected[i]])
			return


func test_get_height_at_grid_matches_callable_variant() -> void:
	var grids: Array = _make_packed_grids()
	var tile_size: float = IsoConst.TILE_SIZE
	# Hill centre, hill skirt, near-wall (suppression), plain grass, grid edge.
	var probes: Array[Vector2] = [
		Vector2(5.5, 5.5), Vector2(6.5, 6.0), Vector2(3.2, 7.8),
		Vector2(1.0, 1.0), Vector2(10.9, 10.9), Vector2(4.0, 5.0),
	]
	for p in probes:
		var wx: float = p.x * tile_size
		var wz: float = p.y * tile_size
		var expected: float = TerrainMath.get_height_at(
			wx, wz, _packed_tile_lookup(grids), _packed_height_lookup(grids),
			IsoConst.HILL_CURVE_R, IsoConst.HILL_PEAK_H)
		var actual: float = TerrainMath.get_height_at_grid(
			wx, wz, grids[0], grids[1], 0, 0, _PG_W,
			IsoConst.HILL_CURVE_R, IsoConst.HILL_PEAK_H)
		assert_almost_eq(actual, expected, 0.0001,
			"point query mismatch at tile (%.1f, %.1f)" % [p.x, p.y])
