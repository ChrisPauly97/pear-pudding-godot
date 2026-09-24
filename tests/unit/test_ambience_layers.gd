## Unit tests for layered ambience + music ducking (GID-129 / TID-490).
##
## Covers the pure selection rules in AmbienceLayers (weather id → loop key,
## day/night hysteresis, wildlife per biome, indoor maps), the synthesized
## fallback loops, and the music-duck levels.
extends "res://tests/framework/test_case.gd"

const AmbienceLayers = preload("res://game_logic/AmbienceLayers.gd")
const AmbienceGen = preload("res://game_logic/AmbienceGen.gd")

const _ALL_WEATHER: Array[String] = [
	"", "rain", "heavy_rain", "sandstorm", "dust_devil", "ash_fall", "volcanic", "snow", "blizzard",
]


func test_weather_layer_mapping() -> void:
	assert_eq(AmbienceLayers.weather_layer(""), "")
	assert_eq(AmbienceLayers.weather_layer("rain"), "rain")
	assert_eq(AmbienceLayers.weather_layer("heavy_rain"), "heavy_rain")
	assert_eq(AmbienceLayers.weather_layer("sandstorm"), "sandstorm")
	assert_eq(AmbienceLayers.weather_layer("dust_devil"), "wind")
	assert_eq(AmbienceLayers.weather_layer("snow"), "wind")
	assert_eq(AmbienceLayers.weather_layer("blizzard"), "wind")
	assert_eq(AmbienceLayers.weather_layer("ash_fall"), "crackle")
	assert_eq(AmbienceLayers.weather_layer("volcanic"), "crackle")
	assert_eq(AmbienceLayers.weather_layer("not_weather"), "")


func test_every_weather_key_has_a_path_and_gain() -> void:
	for w: String in _ALL_WEATHER:
		var key: String = AmbienceLayers.weather_layer(w)
		if w.is_empty():
			assert_eq(AmbienceLayers.weather_gain(w), 0.0)
			continue
		assert_true(AmbienceLayers.LAYER_PATHS.has(key), "weather '%s' layer '%s' needs a path" % [w, key])
		assert_gt(AmbienceLayers.weather_gain(w), 0.0, "weather '%s' must be audible" % w)
	assert_gt(AmbienceLayers.weather_gain("blizzard"), AmbienceLayers.weather_gain("snow"))


func test_every_weather_manager_id_is_mapped() -> void:
	for biome_id: int in WeatherManager._BIOME_TABLES:
		var table: Array = WeatherManager._BIOME_TABLES[biome_id]
		for row: Dictionary in table:
			var id: String = str(row.get("id", ""))
			if id.is_empty():
				continue
			assert_false(AmbienceLayers.weather_layer(id).is_empty(), "weather '%s' has no layer" % id)


func test_day_night_hysteresis() -> void:
	# Noon / midnight are unambiguous.
	assert_true(AmbienceLayers.next_is_day(0.5, false))
	assert_false(AmbienceLayers.next_is_day(0.0, true))
	# Just past sunset (sun height slightly negative): day holds, night holds.
	var dusk: float = 0.75 + 0.005
	assert_true(AmbienceLayers.next_is_day(dusk, true), "day must not flip inside the band")
	assert_false(AmbienceLayers.next_is_day(dusk, false))
	# Just after sunrise: night holds until the sun clears the band.
	var dawn: float = 0.25 + 0.005
	assert_false(AmbienceLayers.next_is_day(dawn, false), "night must not flip inside the band")
	assert_true(AmbienceLayers.next_is_day(dawn, true))


func test_time_layer_per_biome() -> void:
	assert_eq(AmbienceLayers.time_layer(0, true, ""), "birds")
	assert_eq(AmbienceLayers.time_layer(0, false, ""), "crickets")
	assert_eq(AmbienceLayers.time_layer(1, false, ""), "owls")
	assert_eq(AmbienceLayers.time_layer(2, true, ""), "")
	assert_eq(AmbienceLayers.time_layer(3, false, ""), "")
	assert_eq(AmbienceLayers.time_layer(-1, true, ""), "", "no biome → no wildlife")
	assert_eq(AmbienceLayers.time_layer(0, true, "rain"), "", "birds hush under weather")
	assert_eq(AmbienceLayers.time_layer(0, false, "rain"), "crickets")


func test_indoor_maps_mute_wildlife() -> void:
	assert_true(AmbienceLayers.named_map_is_outdoors("madrian"))
	assert_false(AmbienceLayers.named_map_is_outdoors("player_home"))
	assert_false(AmbienceLayers.named_map_is_outdoors("guildhall"))
	assert_false(AmbienceLayers.named_map_is_outdoors("dungeon_3_1234"))
	assert_false(AmbienceLayers.named_map_is_outdoors("spire_floor_2"))


func test_synth_layers_loop() -> void:
	for key: String in AmbienceLayers.all_layer_keys():
		var stream: AudioStreamWAV = AmbienceGen.get_layer(key)
		assert_not_null(stream, "layer '%s' must synthesize" % key)
		assert_gt(stream.data.size(), 0, "layer '%s' must have PCM data" % key)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "layer '%s' must loop" % key)
	var first: AudioStreamWAV = AmbienceGen.get_layer("rain")
	assert_true(first == AmbienceGen.get_layer("rain"), "layers are cached")


func test_music_duck_levels() -> void:
	assert_eq(AmbienceLayers.music_duck(false, false), 1.0)
	assert_eq(AmbienceLayers.music_duck(true, false), AmbienceLayers.DUCK_DIALOGUE)
	assert_eq(AmbienceLayers.music_duck(false, true), AmbienceLayers.DUCK_NARRATION)
	assert_eq(AmbienceLayers.music_duck(true, true), AmbienceLayers.DUCK_DIALOGUE, "dialogue wins")
	assert_lt(AmbienceLayers.DUCK_DIALOGUE, 1.0)
