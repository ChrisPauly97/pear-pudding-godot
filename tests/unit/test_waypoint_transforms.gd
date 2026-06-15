## Unit tests for MapViewTransforms coordinate helpers.
extends "res://tests/framework/test_case.gd"

const MapViewTransforms = preload("res://scenes/ui/MapViewTransforms.gd")

# Test parameters that mirror a typical in-game setup.
# panel occupies a 600×600 pixel square starting at (100, 50).
const PANEL_X: float = 100.0
const PANEL_Y: float = 50.0
const PANEL_SIZE: float = 600.0
const TILE_SIZE: float = 1.0   # world_to_panel_coords uses IsoConst.TILE_SIZE; use 1.0 for simplicity

# ---------------------------------------------------------------------------
# world_to_panel_coords
# ---------------------------------------------------------------------------

func test_world_origin_maps_to_panel_origin() -> void:
	var px: Vector2 = MapViewTransforms.world_to_panel_coords(
		0.0, 0.0, PANEL_X, PANEL_Y, PANEL_SIZE, TILE_SIZE)
	assert_almost_eq(px.x, PANEL_X, 0.001, "world 0,0 should map to panel top-left x")
	assert_almost_eq(px.y, PANEL_Y, 0.001, "world 0,0 should map to panel top-left y")

func test_world_centre_maps_to_panel_centre() -> void:
	# Tile 50,50 in a 100×100 map = centre of the map.
	var px: Vector2 = MapViewTransforms.world_to_panel_coords(
		50.0, 50.0, PANEL_X, PANEL_Y, PANEL_SIZE, TILE_SIZE)
	assert_almost_eq(px.x, PANEL_X + PANEL_SIZE * 0.5, 0.001, "tile 50 in x → panel centre x")
	assert_almost_eq(px.y, PANEL_Y + PANEL_SIZE * 0.5, 0.001, "tile 50 in z → panel centre y")

func test_world_far_corner_maps_to_panel_bottom_right() -> void:
	# Tile 100,100 should map to the bottom-right corner of the panel.
	var px: Vector2 = MapViewTransforms.world_to_panel_coords(
		100.0, 100.0, PANEL_X, PANEL_Y, PANEL_SIZE, TILE_SIZE)
	assert_almost_eq(px.x, PANEL_X + PANEL_SIZE, 0.001, "tile 100 in x → panel right edge")
	assert_almost_eq(px.y, PANEL_Y + PANEL_SIZE, 0.001, "tile 100 in z → panel bottom edge")

# ---------------------------------------------------------------------------
# panel_to_world_coords
# ---------------------------------------------------------------------------

func test_panel_origin_maps_to_world_origin() -> void:
	var wp: Vector3 = MapViewTransforms.panel_to_world_coords(
		PANEL_X, PANEL_Y, PANEL_X, PANEL_Y, PANEL_SIZE, TILE_SIZE)
	assert_almost_eq(wp.x, 0.0, 0.001, "panel top-left → world x 0")
	assert_almost_eq(wp.z, 0.0, 0.001, "panel top-left → world z 0")

func test_panel_centre_maps_to_world_centre() -> void:
	var wp: Vector3 = MapViewTransforms.panel_to_world_coords(
		PANEL_X + PANEL_SIZE * 0.5, PANEL_Y + PANEL_SIZE * 0.5,
		PANEL_X, PANEL_Y, PANEL_SIZE, TILE_SIZE)
	assert_almost_eq(wp.x, 50.0, 0.001, "panel centre → world x 50")
	assert_almost_eq(wp.z, 50.0, 0.001, "panel centre → world z 50")

# ---------------------------------------------------------------------------
# Round-trip: panel → world → panel
# ---------------------------------------------------------------------------

func test_round_trip_centre() -> void:
	var screen_x: float = PANEL_X + PANEL_SIZE * 0.5
	var screen_y: float = PANEL_Y + PANEL_SIZE * 0.5
	var world: Vector3 = MapViewTransforms.panel_to_world_coords(
		screen_x, screen_y, PANEL_X, PANEL_Y, PANEL_SIZE, TILE_SIZE)
	var back: Vector2 = MapViewTransforms.world_to_panel_coords(
		world.x, world.z, PANEL_X, PANEL_Y, PANEL_SIZE, TILE_SIZE)
	assert_almost_eq(back.x, screen_x, 0.01, "round-trip centre x")
	assert_almost_eq(back.y, screen_y, 0.01, "round-trip centre y")

func test_round_trip_arbitrary_point() -> void:
	var screen_x: float = PANEL_X + PANEL_SIZE * 0.37
	var screen_y: float = PANEL_Y + PANEL_SIZE * 0.72
	var world: Vector3 = MapViewTransforms.panel_to_world_coords(
		screen_x, screen_y, PANEL_X, PANEL_Y, PANEL_SIZE, TILE_SIZE)
	var back: Vector2 = MapViewTransforms.world_to_panel_coords(
		world.x, world.z, PANEL_X, PANEL_Y, PANEL_SIZE, TILE_SIZE)
	assert_almost_eq(back.x, screen_x, 0.01, "round-trip arbitrary x")
	assert_almost_eq(back.y, screen_y, 0.01, "round-trip arbitrary y")

# ---------------------------------------------------------------------------
# Edge / out-of-bounds behaviour (documents expected, not guarded)
# ---------------------------------------------------------------------------

func test_off_panel_negative_gives_negative_world_coords() -> void:
	# A pixel 10px to the left of panel_x gives a negative tile coordinate.
	var wp: Vector3 = MapViewTransforms.panel_to_world_coords(
		PANEL_X - 10.0, PANEL_Y, PANEL_X, PANEL_Y, PANEL_SIZE, TILE_SIZE)
	assert_lt(wp.x, 0.0, "off-panel left → negative world x")
