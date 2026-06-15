## Unit tests for CompassRibbon bearing math (pure static functions).
extends "res://tests/framework/test_case.gd"

const CompassRibbon = preload("res://scenes/ui/CompassRibbon.gd")

const CENTER: float = 200.0
const WIDTH: float = 400.0
const HALF: float = 200.0
const EPS: float = 0.01

# ---------------------------------------------------------------------------
# bearing_to_ribbon_x — cardinal directions
# ---------------------------------------------------------------------------

func test_ne_direction_at_ribbon_center() -> void:
	# NE iso-right direction: bearing = -PI/4
	var rx: float = CompassRibbon.bearing_to_ribbon_x(-PI / 4.0, CENTER, WIDTH)
	assert_true(abs(rx - CENTER) < EPS, "NE should be at ribbon center")

func test_sw_direction_at_left_edge() -> void:
	# SW = bearing 3PI/4 wraps to left edge (offset = -PI)
	var rx: float = CompassRibbon.bearing_to_ribbon_x(3.0 * PI / 4.0, CENTER, WIDTH)
	assert_true(abs(rx - 0.0) < EPS, "SW should be at left edge (x=0)")

func test_n_direction_left_of_center() -> void:
	# N = bearing -PI/2 → offset = -PI/4 → CENTER - WIDTH/8
	var rx: float = CompassRibbon.bearing_to_ribbon_x(-PI / 2.0, CENTER, WIDTH)
	var expected: float = CENTER - WIDTH / 8.0  # 150.0
	assert_true(abs(rx - expected) < EPS, "N should be at CENTER - WIDTH/8")

func test_e_direction_right_of_center() -> void:
	# E = bearing 0 → offset = PI/4 → CENTER + WIDTH/8
	var rx: float = CompassRibbon.bearing_to_ribbon_x(0.0, CENTER, WIDTH)
	var expected: float = CENTER + WIDTH / 8.0  # 250.0
	assert_true(abs(rx - expected) < EPS, "E should be at CENTER + WIDTH/8")

func test_s_direction_further_right() -> void:
	# S = bearing PI/2 → offset = 3PI/4 → CENTER + 3*WIDTH/8
	var rx: float = CompassRibbon.bearing_to_ribbon_x(PI / 2.0, CENTER, WIDTH)
	var expected: float = CENTER + 3.0 * WIDTH / 8.0  # 350.0
	assert_true(abs(rx - expected) < EPS, "S should be at CENTER + 3*WIDTH/8")

func test_w_direction_further_left() -> void:
	# W = bearing PI → offset = -3PI/4 → CENTER - 3*WIDTH/8
	var rx: float = CompassRibbon.bearing_to_ribbon_x(PI, CENTER, WIDTH)
	var expected: float = CENTER - 3.0 * WIDTH / 8.0  # 50.0
	assert_true(abs(rx - expected) < EPS, "W should be at CENTER - 3*WIDTH/8")

func test_nsew_equally_spaced() -> void:
	# N, E, W, S are each WIDTH/4 apart
	var rn: float = CompassRibbon.bearing_to_ribbon_x(-PI / 2.0, CENTER, WIDTH)
	var re: float = CompassRibbon.bearing_to_ribbon_x(0.0, CENTER, WIDTH)
	var rs: float = CompassRibbon.bearing_to_ribbon_x(PI / 2.0, CENTER, WIDTH)
	var rw: float = CompassRibbon.bearing_to_ribbon_x(PI, CENTER, WIDTH)
	var step: float = WIDTH / 4.0
	assert_true(abs(re - rn - step) < EPS, "E - N should equal WIDTH/4")
	assert_true(abs(rs - re - step) < EPS, "S - E should equal WIDTH/4")
	assert_true(abs(rw - rn + step) < EPS, "W = N - WIDTH/4 (W is further left)")

# ---------------------------------------------------------------------------
# compute_marker_ribbon_x — marker positioning and off-map clamping
# ---------------------------------------------------------------------------

func test_marker_east_of_player_right_of_center() -> void:
	var player: Vector3 = Vector3(0.0, 0.0, 0.0)
	var target: Vector3 = Vector3(10.0, 0.0, 0.0)  # East (+X)
	var rx: float = CompassRibbon.compute_marker_ribbon_x(player, target, CENTER, WIDTH, false)
	assert_true(rx > CENTER, "East target should appear right of ribbon center")

func test_marker_north_of_player_left_of_center() -> void:
	var player: Vector3 = Vector3(0.0, 0.0, 0.0)
	var target: Vector3 = Vector3(0.0, 0.0, -10.0)  # North (-Z)
	var rx: float = CompassRibbon.compute_marker_ribbon_x(player, target, CENTER, WIDTH, false)
	assert_true(rx < CENTER, "North target should appear left of ribbon center")

func test_marker_at_same_position_returns_center() -> void:
	var pos: Vector3 = Vector3(5.0, 0.0, 5.0)
	var rx: float = CompassRibbon.compute_marker_ribbon_x(pos, pos, CENTER, WIDTH, false)
	assert_eq(rx, CENTER, "Same position should return ribbon center")

func test_off_map_marker_east_clamps_to_right_edge() -> void:
	var player: Vector3 = Vector3(0.0, 0.0, 0.0)
	var target: Vector3 = Vector3(100.0, 0.0, 0.0)  # East = right of center
	var rx: float = CompassRibbon.compute_marker_ribbon_x(player, target, CENTER, WIDTH, true)
	assert_eq(rx, WIDTH, "Off-map east marker should clamp to right edge")

func test_off_map_marker_north_clamps_to_left_edge() -> void:
	var player: Vector3 = Vector3(0.0, 0.0, 0.0)
	var target: Vector3 = Vector3(0.0, 0.0, -100.0)  # North = left of center
	var rx: float = CompassRibbon.compute_marker_ribbon_x(player, target, CENTER, WIDTH, true)
	assert_eq(rx, 0.0, "Off-map north marker should clamp to left edge")
