## Unit tests for EnvSync — encode/decode round-trip and weather roll math.
extends "res://tests/framework/test_case.gd"

const EnvSync = preload("res://game_logic/net/EnvSync.gd")


# ---------------------------------------------------------------------------
# encode / decode round-trip
# ---------------------------------------------------------------------------

func test_encode_decode_preserves_time_of_day() -> void:
	var d: Dictionary = EnvSync.decode(EnvSync.encode(0.65, 3, "rain"))
	assert_almost_eq(float(d["time_of_day"]), 0.65)


func test_encode_decode_preserves_days_elapsed() -> void:
	var d: Dictionary = EnvSync.decode(EnvSync.encode(0.1, 12, ""))
	assert_eq(int(d["days_elapsed"]), 12)


func test_encode_decode_preserves_weather_id() -> void:
	var d: Dictionary = EnvSync.decode(EnvSync.encode(0.1, 0, "heavy_rain"))
	assert_eq(str(d["weather_id"]), "heavy_rain")


func test_encode_returns_three_elements() -> void:
	assert_eq(EnvSync.encode(0.4, 0, "").size(), 3)


func test_decode_returns_all_keys() -> void:
	var d: Dictionary = EnvSync.decode(EnvSync.encode(0.4, 0, ""))
	assert_true(d.has("time_of_day"), "missing key time_of_day")
	assert_true(d.has("days_elapsed"), "missing key days_elapsed")
	assert_true(d.has("weather_id"), "missing key weather_id")


func test_decode_empty_payload_uses_defaults() -> void:
	var d: Dictionary = EnvSync.decode([])
	assert_almost_eq(float(d["time_of_day"]), 0.4)
	assert_eq(int(d["days_elapsed"]), 0)
	assert_eq(str(d["weather_id"]), "")


func test_decode_short_payload_defaults_weather() -> void:
	# A 2-element payload (pre-weather) must still decode, weather defaulting to "".
	var d: Dictionary = EnvSync.decode([0.5, 4])
	assert_almost_eq(float(d["time_of_day"]), 0.5)
	assert_eq(int(d["days_elapsed"]), 4)
	assert_eq(str(d["weather_id"]), "")


# ---------------------------------------------------------------------------
# roll_weather / roll_duration
# ---------------------------------------------------------------------------

func test_roll_weather_is_deterministic_for_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 777
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 777
	assert_eq(EnvSync.roll_weather(rng_a), EnvSync.roll_weather(rng_b))


func test_roll_weather_returns_known_id() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var known: Array[String] = ["", "rain", "heavy_rain"]
	for _i in range(20):
		assert_true(known.has(EnvSync.roll_weather(rng)), "unexpected weather id")


func test_roll_duration_positive() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var dur: float = EnvSync.roll_duration(rng, "rain")
	assert_gt(dur, 0.0)


func test_roll_duration_unknown_weather_falls_back() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var dur: float = EnvSync.roll_duration(rng, "nonexistent_weather")
	assert_gte(dur, 120.0)
	assert_lte(dur, 300.0)
