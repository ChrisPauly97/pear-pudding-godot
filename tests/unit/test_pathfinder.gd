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
	# Manhattan distance = 4; optimal path visits 5 tiles
	var path: Array[Vector2i] = Pathfinder.find_path(_all_grass, Vector2i(0, 0), Vector2i(4, 0), 64)
	assert_eq(path.size(), 5, "straight 4-tile path should have 5 nodes")

func test_diagonal_path_optimal_length() -> void:
	# (0,0) → (4,4): Manhattan = 8 → 9 tiles
	var path: Array[Vector2i] = Pathfinder.find_path(_all_grass, Vector2i(0, 0), Vector2i(4, 4), 64)
	assert_false(path.is_empty(), "should find a path")
	assert_eq(path[path.size() - 1], Vector2i(4, 4))
	assert_eq(path.size(), 9, "diagonal 4+4 path should have 9 nodes")

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
# Connectivity — every step in path is 4-directionally adjacent
# ---------------------------------------------------------------------------

func test_open_path_steps_are_adjacent() -> void:
	var path: Array[Vector2i] = Pathfinder.find_path(_all_grass, Vector2i(0, 0), Vector2i(6, 4), 64)
	assert_false(path.is_empty(), "should find a path")
	for i in range(1, path.size()):
		var prev: Vector2i = path[i - 1]
		var curr: Vector2i = path[i]
		var dist: int = abs(curr.x - prev.x) + abs(curr.y - prev.y)
		assert_eq(dist, 1, "consecutive tiles must be 4-directionally adjacent")

func test_detour_path_steps_are_adjacent() -> void:
	var path: Array[Vector2i] = Pathfinder.find_path(_wall_partial, Vector2i(0, 0), Vector2i(4, 0), 64)
	for i in range(1, path.size()):
		var prev: Vector2i = path[i - 1]
		var curr: Vector2i = path[i]
		var dist: int = abs(curr.x - prev.x) + abs(curr.y - prev.y)
		assert_eq(dist, 1, "detour steps must be 4-directionally adjacent")
