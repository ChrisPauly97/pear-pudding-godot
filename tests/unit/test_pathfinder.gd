## Unit tests for Pathfinder.gd (A* over Callable tile lookup).
extends "res://tests/framework/test_case.gd"

const Pathfinder = preload("res://game_logic/Pathfinder.gd")

# ---------------------------------------------------------------------------
# Tile lookup helpers
# ---------------------------------------------------------------------------

static func _all_grass(_x: int, _z: int) -> int:
	return IsoConst.TILE_GRASS

# Partial wall: x=2, z in [0..5]. Gap at z<0 allows a detour around it.
static func _wall_partial(x: int, z: int) -> int:
	if x == 2 and z >= 0 and z <= 5:
		return IsoConst.TILE_WALL
	return IsoConst.TILE_GRASS

# Completely inaccessible box: (5,5) is surrounded on all 4 cardinal sides by walls.
static func _walled_box(x: int, z: int) -> int:
	if (x == 4 and z == 5) or (x == 6 and z == 5):
		return IsoConst.TILE_WALL
	if (z == 4 and x == 5) or (z == 6 and x == 5):
		return IsoConst.TILE_WALL
	return IsoConst.TILE_GRASS

# ---------------------------------------------------------------------------
# Identity — from == to
# ---------------------------------------------------------------------------

func test_identity_returns_single_element() -> void:
	var path: Array[Vector2i] = Pathfinder.find_path(_all_grass, Vector2i(3, 3), Vector2i(3, 3), 64)
	assert_eq(path.size(), 1)
	assert_eq(path[0], Vector2i(3, 3))

# ---------------------------------------------------------------------------
# Straight path on open grass
# ---------------------------------------------------------------------------

func test_straight_path_has_correct_endpoints() -> void:
	var path: Array[Vector2i] = Pathfinder.find_path(_all_grass, Vector2i(0, 0), Vector2i(4, 0), 64)
	assert_false(path.is_empty(), "should find a path")
	assert_eq(path[0], Vector2i(0, 0))
	assert_eq(path[path.size() - 1], Vector2i(4, 0))

func test_straight_path_optimal_length() -> void:
	# After string-pull smoothing, a straight open path collapses to [start, dest]
	var path: Array[Vector2i] = Pathfinder.find_path(_all_grass, Vector2i(0, 0), Vector2i(4, 0), 64)
	assert_eq(path.size(), 2, "smoothed straight open path should have only start and dest")

func test_diagonal_path_optimal_length() -> void:
	# After string-pull smoothing, open diagonal path collapses to [start, dest]
	var path: Array[Vector2i] = Pathfinder.find_path(_all_grass, Vector2i(0, 0), Vector2i(4, 4), 64)
	assert_false(path.is_empty(), "should find a path")
	assert_eq(path[path.size() - 1], Vector2i(4, 4))
	assert_eq(path.size(), 2, "smoothed open diagonal path should have only start and dest")

# ---------------------------------------------------------------------------
# Path around a partial wall
# ---------------------------------------------------------------------------

func test_path_around_wall_reaches_destination() -> void:
	# Wall at x=2, z=0..5; detour via z=-1
	var path: Array[Vector2i] = Pathfinder.find_path(_wall_partial, Vector2i(0, 0), Vector2i(4, 0), 64)
	assert_false(path.is_empty(), "should find a detour around the wall")
	assert_eq(path[0], Vector2i(0, 0))
	assert_eq(path[path.size() - 1], Vector2i(4, 0))

func test_path_around_wall_avoids_blocked_tiles() -> void:
	var path: Array[Vector2i] = Pathfinder.find_path(_wall_partial, Vector2i(0, 0), Vector2i(4, 0), 64)
	for tile: Vector2i in path:
		if tile.x == 2:
			assert_false(tile.y >= 0 and tile.y <= 5,
				"path must not pass through the walled section (x=2, z=0..5)")

# ---------------------------------------------------------------------------
# Unreachable destination
# ---------------------------------------------------------------------------

func test_unreachable_wall_destination() -> void:
	# Destination tile itself is a wall.
	var path: Array[Vector2i] = Pathfinder.find_path(_wall_partial, Vector2i(0, 0), Vector2i(2, 2), 64)
	assert_true(path.is_empty(), "wall tile destination should be rejected immediately")

func test_unreachable_surrounded_by_walls() -> void:
	# (5,5) surrounded by 4 adjacent wall tiles.
	var path: Array[Vector2i] = Pathfinder.find_path(_walled_box, Vector2i(0, 0), Vector2i(5, 5), 64)
	assert_true(path.is_empty(), "destination surrounded by walls should be unreachable")

# ---------------------------------------------------------------------------
# Max-radius bound
# ---------------------------------------------------------------------------

func test_max_radius_blocks_far_goal() -> void:
	var path: Array[Vector2i] = Pathfinder.find_path(_all_grass, Vector2i(0, 0), Vector2i(100, 0), 10)
	assert_true(path.is_empty(), "goal beyond max_radius should be unreachable")

func test_max_radius_allows_near_goal() -> void:
	var path: Array[Vector2i] = Pathfinder.find_path(_all_grass, Vector2i(0, 0), Vector2i(5, 0), 10)
	assert_false(path.is_empty(), "goal within max_radius should be found")
	assert_eq(path[path.size() - 1], Vector2i(5, 0))

# ---------------------------------------------------------------------------
# Smoothed path correctness — endpoints match and no waypoint is a wall tile
# ---------------------------------------------------------------------------

func test_open_path_steps_are_adjacent() -> void:
	# After smoothing, intermediate tiles are skipped; verify endpoints and tile validity.
	var path: Array[Vector2i] = Pathfinder.find_path(_all_grass, Vector2i(0, 0), Vector2i(6, 4), 64)
	assert_false(path.is_empty(), "should find a path")
	assert_eq(path[0], Vector2i(0, 0), "first waypoint must be start")
	assert_eq(path[path.size() - 1], Vector2i(6, 4), "last waypoint must be dest")
	for wp: Vector2i in path:
		assert_true(_all_grass(wp.x, wp.y) != IsoConst.TILE_WALL, "no waypoint may land on a wall")

func test_detour_path_steps_are_adjacent() -> void:
	# After smoothing, verify endpoints and no waypoint on a wall tile.
	var path: Array[Vector2i] = Pathfinder.find_path(_wall_partial, Vector2i(0, 0), Vector2i(4, 0), 64)
	assert_false(path.is_empty(), "detour path must not be empty")
	assert_eq(path[0], Vector2i(0, 0), "first waypoint must be start")
	assert_eq(path[path.size() - 1], Vector2i(4, 0), "last waypoint must be dest")
	for wp: Vector2i in path:
		assert_false(wp.x == 2 and wp.y >= 0 and wp.y <= 5,
			"no waypoint may land on the wall column")

# ---------------------------------------------------------------------------
# String-pull smoothing — new tests
# ---------------------------------------------------------------------------

func test_open_diagonal_path_is_direct() -> void:
	# Open diagonal: (0,0)→(4,4) should collapse to just [start, dest] after smoothing.
	var path: Array[Vector2i] = Pathfinder.find_path(_all_grass, Vector2i(0, 0), Vector2i(4, 4), 64)
	assert_false(path.is_empty(), "should find a path")
	assert_eq(path.size(), 2, "open diagonal should be [start, dest] after smoothing")
	assert_eq(path[0], Vector2i(0, 0))
	assert_eq(path[1], Vector2i(4, 4))

func test_smoothed_path_around_wall_reaches_dest() -> void:
	# Wall detour: endpoints correct, no waypoint on the wall column.
	var path: Array[Vector2i] = Pathfinder.find_path(_wall_partial, Vector2i(0, 0), Vector2i(4, 0), 64)
	assert_false(path.is_empty(), "should find a detour path")
	assert_eq(path[0], Vector2i(0, 0), "first waypoint must be start")
	assert_eq(path[path.size() - 1], Vector2i(4, 0), "last waypoint must be dest")
	for wp: Vector2i in path:
		assert_false(_wall_partial(wp.x, wp.y) == IsoConst.TILE_WALL,
			"no smoothed waypoint may land on a wall tile")
