## Unit tests for the fake-volumetric atmosphere rules (GID-130).
extends "res://tests/framework/test_case.gd"

const AM = preload("res://game_logic/AtmosphereMath.gd")
const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
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


func test_depth_fog_follows_height_fog_curve() -> void:
	assert_almost_eq(AM.depth_fog_density(0.9, 0.0), 0.0)
	assert_gt(AM.depth_fog_density(0.02, 1.0), AM.depth_fog_density(0.9, 1.0))
	assert_lte(AM.depth_fog_density(0.02, 5.0), AM.DEPTH_FOG_MAX_ALPHA + 0.0001)

func test_terrain_rain_global_tracks_raining_now() -> void:
	assert_true(ProjectSettings.has_setting("shader_globals/terrain_rain"))
	var dnc := DNC.new()
	var sun := DirectionalLight3D.new()
	var moon := DirectionalLight3D.new()
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	dnc.setup(sun, moon, we, false, 600.0, 0.5)
	dnc.set_weather("heavy_rain", true)
	dnc.tick(0.1)
	# The headless dummy renderer stores no globals; check the value written.
	assert_almost_eq(dnc._cached_rain, 1.0, 0.05)
	dnc.set_weather("", true)
	dnc.tick(0.1)
	assert_almost_eq(dnc._cached_rain, 0.0, 0.05,
			"ripples stop with the rain even while the ground stays wet")
	dnc.free()
	sun.free()
	moon.free()
	we.free()


func test_cloud_shadows_by_day_only_and_fade_under_overcast() -> void:
	assert_almost_eq(AM.cloud_shadow_strength(-0.3, 0.0), 0.0, 0.0001, "no cloud shadows at night")
	assert_almost_eq(AM.cloud_shadow_strength(0.8, 0.0), AM.CLOUD_SHADOW_MAX, 0.0001)
	assert_lt(AM.cloud_shadow_strength(0.8, 0.9), AM.cloud_shadow_strength(0.8, 0.0) * 0.5,
		"a fully overcast sky has no distinct cloud shadows")


func test_biome_grade_eases_instead_of_snapping() -> void:
	var nodes: Array = _make_dnc_grade()
	var dnc: DNC = nodes[0]
	var env: Environment = (nodes[3] as WorldEnvironment).environment
	dnc.set_biome_grade(0, true)
	var meadow: Color = dnc.mood()
	assert_almost_eq(env.adjustment_saturation, float(BiomeDef.ADJ_PARAMS[0]["saturation"]), 0.001)
	dnc.set_biome_grade(3)
	dnc.tick(0.1)
	assert_true(dnc.mood() != meadow and dnc.mood() != (BiomeDef.ADJ_PARAMS[3]["mood"] as Color),
		"mid-blend mood sits between the two biomes")
	for i in 200:
		dnc.tick(0.1)
	assert_true(dnc.mood().is_equal_approx(BiomeDef.ADJ_PARAMS[3]["mood"] as Color), "blend settles")
	assert_almost_eq(env.adjustment_saturation, float(BiomeDef.ADJ_PARAMS[3]["saturation"]), 0.01)
	_free_nodes(nodes)


func _make_dnc_grade() -> Array:
	var dnc := DNC.new()
	var sun := DirectionalLight3D.new()
	var moon := DirectionalLight3D.new()
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	dnc.setup(sun, moon, we, true, 600.0, 0.4)
	dnc.set_weather("", true)
	return [dnc, sun, moon, we]


func _free_nodes(nodes: Array) -> void:
	for n: Variant in nodes:
		(n as Node).free()
