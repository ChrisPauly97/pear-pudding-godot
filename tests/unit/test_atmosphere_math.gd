## Unit tests for the fake-volumetric atmosphere rules (GID-130).
extends "res://tests/framework/test_case.gd"

const AM = preload("res://game_logic/AtmosphereMath.gd")
const DNC = preload("res://scenes/world/DayNightCycle.gd")
const WeatherLook = preload("res://game_logic/WeatherLook.gd")


func test_height_fog_is_thickest_at_dawn_and_thin_at_midday() -> void:
	var night: float = AM.height_fog_density(-0.8, 1.0)
	var dawn: float = AM.height_fog_density(0.02, 1.0)
	var midday: float = AM.height_fog_density(0.9, 1.0)
	assert_gt(dawn, night, "dawn mist should beat night")
	assert_gt(night, midday, "night should beat midday")
	assert_almost_eq(midday, AM.HEIGHT_FOG_MIDDAY, 0.0001)

func test_height_fog_scales_with_weather_and_stays_capped() -> void:
	assert_almost_eq(AM.height_fog_density(0.9, 0.0), 0.0)
	assert_gt(AM.height_fog_density(-0.8, 2.0), AM.height_fog_density(-0.8, 1.0))
	for id: Variant in WeatherLook.OVERRIDES:
		var mult: float = float(WeatherLook.look_for(str(id))["height_fog"])
		for h: float in [-1.0, -0.2, 0.0, 0.02, 0.2, 0.6, 1.0]:
			assert_between(AM.height_fog_density(h, mult), 0.0, AM.HEIGHT_FOG_MAX)

func test_day_night_cycle_height_fog_toggle() -> void:
	var dnc := DNC.new()
	var sun := DirectionalLight3D.new()
	var moon := DirectionalLight3D.new()
	var env := Environment.new()
	env.fog_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	dnc.setup(sun, moon, we, false, 600.0, 0.0)  # midnight
	dnc.set_weather("", true)
	assert_almost_eq(env.fog_height_density, 0.0, 0.00001, "off by default")
	dnc.set_height_fog(true)
	assert_almost_eq(env.fog_height, AM.HEIGHT_FOG_TOP)
	var clear: float = env.fog_height_density
	assert_gt(clear, 0.0)
	dnc.set_weather("rain", true)
	assert_gt(env.fog_height_density, clear, "rain thickens the mist")
	dnc.set_height_fog(false)
	assert_almost_eq(env.fog_height_density, 0.0, 0.00001)
	dnc.free()
	sun.free()
	moon.free()
	we.free()

func test_shaft_anchors_are_world_anchored_and_nearest_first() -> void:
	var a: Array[Vector3] = AM.shaft_anchors(Vector2(10.0, -4.0), 8)
	assert_eq(a.size(), 8)
	assert_eq(AM.shaft_anchors(Vector2(10.0, -4.0), 0).size(), 0)
	for i: int in range(1, a.size()):
		assert_true(Vector2(a[i].x, a[i].y).distance_to(Vector2(10, -4))
				>= Vector2(a[i - 1].x, a[i - 1].y).distance_to(Vector2(10, -4)) - 0.0001, "sorted by distance")
	# A small step keeps the nearest shafts where they were (no sliding with the player).
	var b: Array[Vector3] = AM.shaft_anchors(Vector2(10.5, -4.2), 8)
	var shared: int = 0
	for p: Vector3 in b:
		if a.has(p):
			shared += 1
	assert_gte(shared, 6)
	for p: Vector3 in a:
		assert_between(p.z, 0.0, 1.0)

func test_shaft_axis_is_steep_and_unit() -> void:
	var low_sun := Vector3(0.95, 0.05, -0.3)
	var ax: Vector3 = AM.shaft_axis(low_sun)
	assert_almost_eq(ax.length(), 1.0, 0.0001)
	assert_gte(ax.y, AM.SHAFT_MIN_AXIS_Y - 0.0001)
	assert_gt(ax.x, 0.0, "leans toward the sun")
	assert_eq(AM.shaft_axis(Vector3.UP), Vector3.UP)
