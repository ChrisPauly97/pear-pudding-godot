## Unit tests for the per-weather atmosphere look (GID-129 / TID-486).
##
## Weather reshapes fog, sky, sun, shadows and grass wind through WeatherLook +
## DayNightCycle. A missing key or a runaway fog multiplier would only show up
## on screen, so pin the table's shape and the applied result here.
extends "res://tests/framework/test_case.gd"

const WeatherLook = preload("res://game_logic/WeatherLook.gd")
const DNC = preload("res://scenes/world/DayNightCycle.gd")
const EnvSync = preload("res://game_logic/net/EnvSync.gd")

# Every id WeatherManager's biome tables can roll (WeatherManager is an
# autoload script, so it isn't preloaded here).
const _WEATHER_IDS: Array[String] = [
	"rain", "heavy_rain", "sandstorm", "dust_devil", "ash_fall", "volcanic", "snow", "blizzard"]
# Light → heavy pairs: the heavy one must be darker, foggier and windier.
const _PAIRS: Array = [
	["rain", "heavy_rain"], ["dust_devil", "sandstorm"], ["ash_fall", "volcanic"], ["snow", "blizzard"]]


func test_every_weather_has_a_look_with_every_key() -> void:
	for id: String in _WEATHER_IDS:
		assert_true(WeatherLook.OVERRIDES.has(id), "no WeatherLook override for '%s'" % id)
	for id: Variant in WeatherLook.OVERRIDES:
		var over: Dictionary = WeatherLook.OVERRIDES[id]
		for key: Variant in over:
			assert_true(WeatherLook.CLEAR.has(key), "'%s' override key '%s' has no CLEAR default" % [id, key])
		assert_eq(WeatherLook.look_for(str(id)).size(), WeatherLook.CLEAR.size())

func test_coop_weather_ids_have_looks() -> void:
	for id: Variant in EnvSync._DURATIONS:
		var s: String = str(id)
		if s != "":
			assert_true(WeatherLook.OVERRIDES.has(s), "co-op weather '%s' has no look" % s)

func test_clear_and_unknown_are_neutral() -> void:
	for id: String in ["", "nonexistent_weather_xyz"]:
		var look: Dictionary = WeatherLook.look_for(id)
		assert_eq(look["tint"], Color(1.0, 1.0, 1.0))
		assert_almost_eq(float(look["fog_density_mult"]), 1.0)
		assert_almost_eq(float(look["sun_energy_mult"]), 1.0)
		assert_almost_eq(float(look["shadow_opacity_mult"]), 1.0)
		assert_almost_eq(float(look["wind_scale"]), 1.0)
		assert_almost_eq(float(look["sky_overcast"]), 0.0)
		assert_almost_eq((look["wind_direction"] as Vector2).length(), 1.0, 0.001)

func test_look_for_returns_a_copy() -> void:
	var look: Dictionary = WeatherLook.look_for("rain")
	look["fog_density_mult"] = 99.0
	assert_almost_eq(float(WeatherLook.look_for("rain")["fog_density_mult"]), 1.6)
	assert_almost_eq(float(WeatherLook.CLEAR["fog_density_mult"]), 1.0)

func test_values_stay_in_readable_ranges() -> void:
	for id: String in _WEATHER_IDS:
		var look: Dictionary = WeatherLook.look_for(id)
		var fog: float = float(look["fog_density_mult"])
		assert_true(fog >= 1.0 and fog <= WeatherLook.MAX_FOG_DENSITY_MULT, "%s fog mult %f" % [id, fog])
		var sun: float = float(look["sun_energy_mult"])
		assert_true(sun > 0.0 and sun < 1.0, "%s must dim the sun" % id)
		var sh: float = float(look["shadow_opacity_mult"])
		assert_true(sh > 0.0 and sh <= 1.0, "%s shadow mult %f" % [id, sh])
		assert_almost_eq((look["wind_direction"] as Vector2).length(), 1.0, 0.001, "%s wind dir not unit" % id)
		for key: String in ["fog_color_weight", "sky_overcast"]:
			var v: float = float(look[key])
			assert_true(v >= 0.0 and v <= 1.0, "%s %s out of 0..1" % [id, key])

func test_heavy_weather_is_harsher_than_its_light_variant() -> void:
	for pair: Array in _PAIRS:
		var light: Dictionary = WeatherLook.look_for(str(pair[0]))
		var heavy: Dictionary = WeatherLook.look_for(str(pair[1]))
		var msg: String = "%s vs %s" % [pair[0], pair[1]]
		assert_gt(float(heavy["fog_density_mult"]), float(light["fog_density_mult"]), msg)
		assert_lt(float(heavy["sun_energy_mult"]), float(light["sun_energy_mult"]), msg)
		assert_true(float(heavy["wind_scale"]) >= float(light["wind_scale"]), msg)

func test_blend_endpoints_and_midpoint() -> void:
	var a: Dictionary = WeatherLook.look_for("")
	var b: Dictionary = WeatherLook.look_for("heavy_rain")
	for key: Variant in WeatherLook.CLEAR:
		assert_eq(str(WeatherLook.blend(a, b, 0.0)[key]), str(a[key]), "t=0 %s" % key)
		assert_eq(str(WeatherLook.blend(a, b, 1.0)[key]), str(b[key]), "t=1 %s" % key)
	var mid: Dictionary = WeatherLook.blend(a, b, 0.5)
	assert_almost_eq(float(mid["fog_density_mult"]), (1.0 + 2.2) * 0.5, 0.0001)
	var tint: Color = mid["tint"]
	assert_almost_eq(tint.r, 0.85, 0.0001)
	assert_eq(mid.size(), WeatherLook.CLEAR.size())

func test_day_night_cycle_applies_weather() -> void:
	var dnc := DNC.new()
	var sun := DirectionalLight3D.new()
	var moon := DirectionalLight3D.new()
	sun.shadow_opacity = 0.2
	var env := Environment.new()
	env.fog_enabled = true
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	dnc.setup(sun, moon, we, false, 600.0, 0.5)  # noon
	dnc.set_weather("", true)
	var clear_energy: float = sun.light_energy
	assert_gt(clear_energy, 0.5)
	assert_almost_eq(env.fog_density, 0.004, 0.00001)
	assert_almost_eq(sun.shadow_opacity, 0.2, 0.0001)

	dnc.set_weather("heavy_rain", true)
	assert_almost_eq(sun.light_energy, clear_energy * 0.35, 0.001)
	assert_almost_eq(env.fog_density, 0.004 * 2.2, 0.00001)
	assert_almost_eq(sun.shadow_opacity, 0.2 * 0.2, 0.0001)

	# A non-instant change blends over WEATHER_BLEND_SECONDS from the current look.
	dnc.set_weather("")
	dnc.tick(DNC.WEATHER_BLEND_SECONDS * 0.5)
	assert_true(env.fog_density < 0.004 * 2.2 and env.fog_density > 0.004, "mid-blend fog")
	dnc.tick(DNC.WEATHER_BLEND_SECONDS)
	assert_almost_eq(env.fog_density, 0.004, 0.00001)
	var look: Dictionary = dnc.weather_look()
	assert_almost_eq(float(look["sun_energy_mult"]), 1.0)

	dnc.free()
	sun.free()
	moon.free()
	we.free()
