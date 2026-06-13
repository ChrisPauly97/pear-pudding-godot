## Unit tests for WeatherParticles factory and GrassBlades wind integration.
## These tests exercise the pure GDScript logic without requiring the full scene tree.
extends "res://tests/framework/test_case.gd"

const WeatherParticles = preload("res://scenes/world/WeatherParticles.gd")
const GrassBlades = preload("res://scenes/world/GrassBlades.gd")

func get_suite_name() -> String:
	return "WeatherVisuals"

# ---------------------------------------------------------------------------
# WeatherParticles.make
# ---------------------------------------------------------------------------

func test_make_returns_null_for_empty_weather() -> void:
	var node := WeatherParticles.make("")
	assert_eq(node, null)

func test_make_returns_gpu_particles_for_rain() -> void:
	var node: GPUParticles3D = WeatherParticles.make("rain") as GPUParticles3D
	assert_true(node != null, "rain should return a GPUParticles3D")
	if node != null:
		node.queue_free()

func test_make_rain_heavy_positive_amount() -> void:
	var node: GPUParticles3D = WeatherParticles.make("heavy_rain") as GPUParticles3D
	assert_true(node != null)
	if node != null:
		assert_gt(node.amount, 0)
		node.queue_free()

func test_make_sandstorm_positive_amount() -> void:
	var node: GPUParticles3D = WeatherParticles.make("sandstorm") as GPUParticles3D
	assert_true(node != null)
	if node != null:
		assert_gt(node.amount, 0)
		node.queue_free()

func test_make_snow_positive_amount() -> void:
	var node: GPUParticles3D = WeatherParticles.make("snow") as GPUParticles3D
	assert_true(node != null)
	if node != null:
		assert_gt(node.amount, 0)
		node.queue_free()

func test_make_blizzard_positive_amount() -> void:
	var node: GPUParticles3D = WeatherParticles.make("blizzard") as GPUParticles3D
	assert_true(node != null)
	if node != null:
		assert_gt(node.amount, 0)
		node.queue_free()

func test_make_ash_fall_positive_amount() -> void:
	var node: GPUParticles3D = WeatherParticles.make("ash_fall") as GPUParticles3D
	assert_true(node != null)
	if node != null:
		assert_gt(node.amount, 0)
		node.queue_free()

func test_make_unknown_weather_returns_null() -> void:
	var node := WeatherParticles.make("nonexistent_weather_xyz")
	assert_eq(node, null)

# ---------------------------------------------------------------------------
# WeatherParticles.get_wind_direction
# ---------------------------------------------------------------------------

func test_wind_direction_zero_for_clear() -> void:
	var d: Vector2 = WeatherParticles.get_wind_direction("")
	assert_eq(d, Vector2.ZERO)

func test_wind_direction_nonzero_for_rain() -> void:
	var d: Vector2 = WeatherParticles.get_wind_direction("rain")
	assert_true(d.length() > 0.0)

func test_wind_direction_nonzero_for_sandstorm() -> void:
	var d: Vector2 = WeatherParticles.get_wind_direction("sandstorm")
	assert_true(d.length() > 0.0)

func test_wind_direction_sandstorm_is_strongest() -> void:
	# Sandstorm should have stronger X component than rain
	var rain_d: Vector2 = WeatherParticles.get_wind_direction("rain")
	var storm_d: Vector2 = WeatherParticles.get_wind_direction("sandstorm")
	# Sandstorm dir has x=1.0 normalized, rain has x=0.2 normalized — sandstorm x is higher
	assert_true(storm_d.x > rain_d.x)

# ---------------------------------------------------------------------------
# WeatherParticles.get_screen_tint
# ---------------------------------------------------------------------------

func test_screen_tint_white_for_clear() -> void:
	var t: Color = WeatherParticles.get_screen_tint("")
	assert_eq(t, Color(1.0, 1.0, 1.0))

func test_screen_tint_blue_tinted_for_rain() -> void:
	var t: Color = WeatherParticles.get_screen_tint("rain")
	# Rain tint has more blue than red
	assert_true(t.b > t.r)

func test_screen_tint_warm_for_sandstorm() -> void:
	var t: Color = WeatherParticles.get_screen_tint("sandstorm")
	# Sandy tint: red >= blue
	assert_true(t.r >= t.b)
