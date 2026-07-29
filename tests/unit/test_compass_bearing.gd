## Unit tests for CompassRibbon bearing math and its agreement with the camera.
extends "res://tests/framework/test_case.gd"

const CompassRibbon = preload("res://scenes/ui/CompassRibbon.gd")

const RIBBON_W: float = 400.0  # arbitrary fixed width for all tests
const CENTER: float = RIBBON_W * 0.5  # = 200.0

# Compass convention (matches the minimap and Player's WASD mapping):
#   North = −Z (bearing −90°), East = +X (0°), South = +Z (+90°), West = −X (180°)
# The isometric camera looks along (−1, 0, −1) = north-west, so NW is the centre.

func _x(deg: float) -> float:
	return CompassRibbon.bearing_to_ribbon_x(deg_to_rad(deg), RIBBON_W)

# ---------------------------------------------------------------------------
# The ribbon centre is the direction the camera actually looks
# ---------------------------------------------------------------------------

func test_camera_facing_is_at_center() -> void:
	assert_almost_eq(_x(CompassRibbon.FACING_BEARING_DEG), CENTER, 0.001,
		"The camera's facing bearing sits at the ribbon centre")

func test_northwest_is_at_center() -> void:
	# Camera forward (−1, 0, −1) → atan2(−1, −1) = −135° = north-west.
	assert_almost_eq(_x(-135.0), CENTER, 0.001, "NW (screen-up) is the ribbon centre")

## Guardrail: the ribbon centre is derived from the Camera3D transform baked into
## WorldScene.tscn.  Re-derive it here from the scene file itself so a camera
## re-bake can never silently leave the compass pointing somewhere else.
func test_center_matches_baked_camera_transform() -> void:
	var text: String = FileAccess.get_file_as_string("res://scenes/world/WorldScene.tscn")
	assert_ne(text, "", "WorldScene.tscn should be readable")
	var cam_idx: int = text.find("[node name=\"Camera3D\"")
	assert_gt(cam_idx, -1, "WorldScene.tscn should define a Camera3D node")
	var t_idx: int = text.find("transform = Transform3D(", cam_idx)
	assert_gt(t_idx, -1, "Camera3D should carry a baked transform")
	var open_paren: int = text.find("(", t_idx)
	var close_paren: int = text.find(")", open_paren)
	var nums: PackedStringArray = text.substr(
		open_paren + 1, close_paren - open_paren - 1).split(",")
	assert_eq(nums.size(), 12, "Transform3D literal should carry 12 numbers")
	# A serialised Transform3D lists the basis matrix by rows, so an axis vector
	# is strided by 3: basis.z (which the camera looks along, negated) is
	# components 2, 5, 8, and the origin is the last three.
	var fwd_x: float = -float(nums[2].strip_edges())
	var fwd_y: float = -float(nums[5].strip_edges())
	var fwd_z: float = -float(nums[8].strip_edges())
	assert_lt(fwd_y, 0.0, "Parsed camera forward must point downward (sanity check)")
	var facing_deg: float = rad_to_deg(atan2(fwd_z, fwd_x))
	assert_almost_eq(facing_deg, CompassRibbon.FACING_BEARING_DEG, 0.01,
		"CompassRibbon.FACING_BEARING_DEG must match the baked camera azimuth")

# ---------------------------------------------------------------------------
# Cardinals land where the player sees them
# ---------------------------------------------------------------------------

func test_north_is_right_of_center() -> void:
	# Facing NW, north is 45° clockwise → an eighth of the ribbon to the right.
	assert_almost_eq(_x(-90.0), CENTER + RIBBON_W * 0.125, 0.001,
		"North (−Z) sits right of centre")

func test_west_is_left_of_center() -> void:
	assert_almost_eq(_x(180.0), CENTER - RIBBON_W * 0.125, 0.001,
		"West (−X) sits left of centre")

func test_northeast_is_screen_right() -> void:
	# The camera's screen-right axis is (+1, 0, −1) = NE, a quarter turn from
	# forward, so it lands a quarter of the ribbon right of centre.
	assert_almost_eq(_x(-45.0), CENTER + RIBBON_W * 0.25, 0.001,
		"NE is screen-right, a quarter width right of centre")

func test_southwest_is_screen_left() -> void:
	assert_almost_eq(_x(135.0), CENTER - RIBBON_W * 0.25, 0.001,
		"SW is screen-left, a quarter width left of centre")

func test_east_and_south_straddle_the_edges() -> void:
	assert_almost_eq(_x(0.0), CENTER + RIBBON_W * 0.375, 0.001, "East is far right")
	assert_almost_eq(_x(90.0), CENTER - RIBBON_W * 0.375, 0.001, "South is far left")

func test_cardinals_are_evenly_spaced_in_screen_order() -> void:
	# Left → right the player should read SE, S, SW, W, NW, N, NE, E.
	var order: Array = [45.0, 90.0, 135.0, 180.0, -135.0, -90.0, -45.0, 0.0]
	var prev: float = -1.0
	for deg: float in order:
		var x: float = _x(deg)
		assert_gt(x, prev, "Cardinal %d° should be right of the previous one" % int(deg))
		prev = x

# ---------------------------------------------------------------------------
# Wrapping: the full width is used, nothing piles up on an edge
# ---------------------------------------------------------------------------

func test_directly_behind_lands_on_an_edge() -> void:
	# SE is 180° from the camera's facing — the far edge of the ribbon.
	var x: float = _x(45.0)
	assert_true(x <= 0.001 or x >= RIBBON_W - 0.001,
		"A target directly behind the camera lands on a ribbon edge")

func test_all_bearings_stay_inside_the_ribbon() -> void:
	for deg: int in range(-180, 181, 5):
		var x: float = _x(float(deg))
		assert_between(x, 0.0, RIBBON_W, "Bearing %d° should map inside the ribbon" % deg)

func test_bearings_either_side_of_center_are_distinct() -> void:
	# The old mapping clamped everything past +135°, collapsing a third of the
	# compass onto the right edge. Nothing may collapse now except true ±180°.
	assert_ne(_x(170.0), _x(-170.0), "Bearings either side of west stay distinct")
	assert_lt(_x(-140.0), _x(-130.0), "Bearings just past the centre stay ordered")

# ---------------------------------------------------------------------------
# compute_bearing: directional sanity checks
# ---------------------------------------------------------------------------

func test_compute_bearing_east() -> void:
	# Target directly east (+X from player)
	var b: float = CompassRibbon.compute_bearing(0.0, 0.0, 10.0, 0.0)
	assert_almost_eq(b, 0.0, 0.001, "Target at +X gives 0 rad bearing")

func test_compute_bearing_south() -> void:
	# Target at +Z from player — south under the game's convention
	var b: float = CompassRibbon.compute_bearing(0.0, 0.0, 0.0, 10.0)
	assert_almost_eq(b, PI * 0.5, 0.001, "Target at +Z gives π/2 bearing")

func test_compute_bearing_west() -> void:
	var b: float = CompassRibbon.compute_bearing(0.0, 0.0, -10.0, 0.0)
	assert_almost_eq(absf(b), PI, 0.001, "Target at −X gives ±π bearing")

func test_compute_bearing_north_maps_right_of_center() -> void:
	# End to end: a target due north of the player reads to the right of centre.
	var b: float = CompassRibbon.compute_bearing(0.0, 0.0, 0.0, -10.0)
	assert_gt(CompassRibbon.bearing_to_ribbon_x(b, RIBBON_W), CENTER,
		"A target due north renders right of centre")

# ---------------------------------------------------------------------------
# Caption shortening
# ---------------------------------------------------------------------------

func test_short_caption_untouched() -> void:
	assert_eq(CompassRibbon._shorten("Leave Madrian"), "Leave Madrian",
		"A caption that fits is drawn verbatim")

func test_long_caption_is_ellipsised() -> void:
	var long_label: String = "Speak with the Queen and Scargroth, then the King"
	var out: String = CompassRibbon._shorten(long_label)
	assert_true(out.ends_with("…"), "An over-long caption is ellipsised")
	assert_lte(out.length(), 34, "Ellipsised caption stays within the budget")
