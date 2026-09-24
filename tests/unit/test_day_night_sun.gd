## Unit tests for the tilted sun arc and golden-hour ramp (GID-129 / TID-485).
##
## The arc is baked against the iso camera: dawn shadows must run across the
## screen and the noon sun must never be straight overhead, or shadows vanish
## under objects. Nothing else fails if these drift, so pin them here.
extends "res://tests/framework/test_case.gd"

const DNC = preload("res://scenes/world/DayNightCycle.gd")

# The iso camera looks along (-1, -1, -1); its screen-right axis on the ground is (+1, 0, -1).
const _SCREEN_RIGHT := Vector3(0.70710678, 0.0, -0.70710678)


func test_sun_direction_is_unit_and_matches_night() -> void:
	for i: int in 24:
		var t: float = float(i) / 24.0 + 0.01
		var d: Vector3 = DNC.sun_direction(t)
		assert_almost_eq(d.length(), 1.0, 0.0001, "sun_direction(%f) not unit" % t)
		assert_eq(d.y < 0.0, DNC.is_night(t), "horizon crossing disagrees with is_night at %f" % t)

func test_noon_sun_is_not_overhead_and_leans_away_from_camera() -> void:
	var noon: Vector3 = DNC.sun_direction(0.5)
	assert_lt(noon.y, 0.95, "noon sun straight overhead — shadows hide under objects")
	assert_gt(noon.y, 0.7, "noon sun too low")
	# Sun toward the camera's forward (-1,0,-1) means shadows fall toward the viewer.
	assert_gt(noon.dot(Vector3(-1.0, 0.0, -1.0)), 0.0)

func test_dawn_and_dusk_shadows_run_across_the_screen() -> void:
	var dawn: Vector3 = DNC.sun_direction(0.25)
	var dusk: Vector3 = DNC.sun_direction(0.75)
	assert_almost_eq(dawn.y, 0.0, 0.0001)
	assert_gt(absf(dawn.dot(_SCREEN_RIGHT)), 0.95, "dawn sun not on the screen's horizontal axis")
	assert_almost_eq(dawn.dot(dusk), -1.0, 0.0001, "sunrise and sunset not opposite")

func test_light_basis_points_minus_z_along_travel() -> void:
	for i: int in 12:
		var d: Vector3 = DNC.sun_direction(float(i) / 12.0)
		var b: Basis = DNC.light_basis(-d)
		assert_true((-b.z).is_equal_approx(-d), "light -Z not along travel at step %d" % i)

func test_golden_hour_ramp_warms_toward_horizon() -> void:
	var prev_blue: float = -1.0
	for i: int in 11:
		var h: float = float(i) * 0.05
		var c: Color = DNC.sun_color_for(h)
		assert_gte(c.b, prev_blue, "sun colour not monotonically cooler as it rises (h=%f)" % h)
		prev_blue = c.b
	assert_true(DNC.sun_color_for(0.0).is_equal_approx(DNC.SUN_HORIZON_COLOR))
	assert_true(DNC.sun_color_for(1.0).is_equal_approx(DNC.SUN_DAY_COLOR))
	# Still visibly golden well above the horizon (the old ramp was white by sun_h 0.2).
	assert_lt(DNC.sun_color_for(0.2).b, 0.6)
