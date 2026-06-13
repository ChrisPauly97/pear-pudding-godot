## Unit tests for WeatherManager.
##
## WeatherManager is an autoload Node — the runner initialises it via --path .
## Tests manipulate it directly via the WeatherManager singleton path.
extends "res://tests/framework/test_case.gd"

func get_suite_name() -> String:
	return "WeatherManager"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _reset() -> void:
	WeatherManager.current_weather = ""
	WeatherManager.current_duration = 0.0
	WeatherManager._current_biome = -1
	WeatherManager._initialized = false
	WeatherManager._biome_rngs = {}
	WeatherManager._save_timer = 0.0
	SaveManager.weather = {}
	SaveManager.current_map = "main"
	SaveManager.world_seed = 42

# ---------------------------------------------------------------------------
# _pick_weather
# ---------------------------------------------------------------------------

func test_pick_weather_returns_string_for_valid_biome() -> void:
	_reset()
	WeatherManager.on_world_entered()
	var w: String = WeatherManager._pick_weather(0)
	assert_true(w is String)

func test_pick_weather_returns_empty_for_invalid_biome() -> void:
	_reset()
	WeatherManager.on_world_entered()
	var w: String = WeatherManager._pick_weather(99)
	assert_eq(w, "")

func test_pick_weather_grasslands_valid_ids() -> void:
	_reset()
	WeatherManager.on_world_entered()
	var valid: Array[String] = ["", "rain", "heavy_rain"]
	for _i in range(20):
		var w: String = WeatherManager._pick_weather(0)
		assert_true(valid.has(w), "unexpected weather id: %s" % w)

func test_pick_weather_desert_valid_ids() -> void:
	_reset()
	WeatherManager.on_world_entered()
	var valid: Array[String] = ["", "sandstorm", "dust_devil"]
	for _i in range(20):
		var w: String = WeatherManager._pick_weather(2)
		assert_true(valid.has(w), "unexpected weather id: %s" % w)

# ---------------------------------------------------------------------------
# _change_weather
# ---------------------------------------------------------------------------

func test_change_weather_emits_signal() -> void:
	_reset()
	WeatherManager.on_world_entered()
	WeatherManager._current_biome = 0
	var received: Array[String] = []
	GameBus.weather_changed.connect(func(wid: String, _d: float) -> void: received.append(wid))
	WeatherManager._change_weather()
	GameBus.weather_changed.disconnect(GameBus.weather_changed.get_connections()[-1]["callable"])
	assert_eq(received.size(), 1)

func test_change_weather_sets_positive_duration() -> void:
	_reset()
	WeatherManager.on_world_entered()
	WeatherManager._current_biome = 4  # MOUNTAINS
	WeatherManager._change_weather()
	assert_gt(WeatherManager.current_duration, 0.0)

# ---------------------------------------------------------------------------
# set_biome
# ---------------------------------------------------------------------------

func test_set_biome_same_biome_no_reset() -> void:
	_reset()
	WeatherManager.on_world_entered()
	WeatherManager._current_biome = 1
	WeatherManager.current_duration = 200.0
	WeatherManager.set_biome(1)
	assert_eq(WeatherManager.current_duration, 200.0)

func test_set_biome_new_biome_resets_duration() -> void:
	_reset()
	WeatherManager.on_world_entered()
	WeatherManager._current_biome = 0
	WeatherManager.current_duration = 200.0
	WeatherManager.set_biome(3)
	assert_eq(WeatherManager.current_duration, 0.0)

# ---------------------------------------------------------------------------
# on_world_entered save restore
# ---------------------------------------------------------------------------

func test_on_world_entered_restores_from_save() -> void:
	_reset()
	SaveManager.weather = {"id": "rain", "duration": 77.5, "biome_id": 1}
	WeatherManager.on_world_entered()
	assert_eq(WeatherManager.current_weather, "rain")
	assert_eq(WeatherManager.current_duration, 77.5)
	assert_eq(WeatherManager._current_biome, 1)

func test_on_world_entered_defaults_duration_when_zero() -> void:
	_reset()
	SaveManager.weather = {"id": "", "duration": 0.0, "biome_id": 0}
	WeatherManager.on_world_entered()
	assert_gt(WeatherManager.current_duration, 0.0)

# ---------------------------------------------------------------------------
# _sync_to_save
# ---------------------------------------------------------------------------

func test_sync_to_save_writes_correct_fields() -> void:
	_reset()
	WeatherManager.on_world_entered()
	WeatherManager.current_weather = "snow"
	WeatherManager.current_duration = 88.0
	WeatherManager._current_biome = 4
	WeatherManager._sync_to_save()
	assert_eq(str(SaveManager.weather.get("id", "")), "snow")
	assert_eq(float(SaveManager.weather.get("duration", 0.0)), 88.0)
	assert_eq(int(SaveManager.weather.get("biome_id", -1)), 4)

# ---------------------------------------------------------------------------
# World-only gating
# ---------------------------------------------------------------------------

func test_process_does_not_tick_outside_infinite_world() -> void:
	_reset()
	WeatherManager.on_world_entered()
	WeatherManager._current_biome = 0
	WeatherManager.current_duration = 10.0
	WeatherManager.current_weather = ""
	SaveManager.current_map = "dungeon_123"
	var received: int = 0
	GameBus.weather_changed.connect(func(_w: String, _d: float) -> void: received += 1)
	# Manually call _process with enough delta to expire the timer
	WeatherManager._process(20.0)
	GameBus.weather_changed.disconnect(GameBus.weather_changed.get_connections()[-1]["callable"])
	assert_eq(received, 0, "weather_changed should not fire outside infinite world")
	# duration should NOT have changed (we didn't tick)
	assert_eq(WeatherManager.current_duration, 10.0)

func test_process_ticks_in_infinite_world() -> void:
	_reset()
	WeatherManager.on_world_entered()
	WeatherManager._current_biome = 0
	WeatherManager.current_duration = 5.0
	SaveManager.current_map = "main"
	WeatherManager._process(6.0)
	# duration went negative → _change_weather was called → duration reset to positive
	assert_gt(WeatherManager.current_duration, 0.0)
