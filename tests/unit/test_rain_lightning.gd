## Unit tests for rain wetness and storm lightning (GID-129 / TID-487).
##
## Wetness and flashes only show up on screen, so pin the rules (Lightning.gd),
## the look table entries, and DayNightCycle's application of both here.
extends "res://tests/framework/test_case.gd"

const Lightning = preload("res://game_logic/Lightning.gd")
const WeatherLook = preload("res://game_logic/WeatherLook.gd")
const DNC = preload("res://scenes/world/DayNightCycle.gd")
const SfxGen = preload("res://game_logic/SfxGen.gd")


func _make_dnc() -> Array:
	var dnc := DNC.new()
	var sun := DirectionalLight3D.new()
	var moon := DirectionalLight3D.new()
	var env := Environment.new()
	env.fog_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	dnc.setup(sun, moon, we, false, 600.0, 0.5)
	return [dnc, sun, moon, we]


func _free_all(nodes: Array) -> void:
	for n: Variant in nodes:
		(n as Node).free()


func test_rain_looks_wet_and_storms_flash() -> void:
	assert_almost_eq(float(WeatherLook.look_for("")["wetness"]), 0.0)
	assert_almost_eq(float(WeatherLook.look_for("")["lightning"]), 0.0)
	var rain: float = float(WeatherLook.look_for("rain")["wetness"])
	var heavy: float = float(WeatherLook.look_for("heavy_rain")["wetness"])
	assert_gt(rain, 0.0)
	assert_gt(heavy, rain, "heavy rain soaks harder than rain")
	assert_true(heavy <= 1.0)
	assert_gt(float(WeatherLook.look_for("heavy_rain")["lightning"]), 0.0)
	assert_gt(float(WeatherLook.look_for("volcanic")["lightning"]), 0.0)
	var red: Color = WeatherLook.look_for("volcanic")["lightning_color"]
	assert_gt(red.r, red.b, "volcanic lightning is red-tinted")
	for id: String in ["rain", "snow", "sandstorm", "blizzard"]:
		assert_almost_eq(float(WeatherLook.look_for(id)["lightning"]), 0.0, 0.0001, "%s must not flash" % id)


func test_wetness_soaks_fast_and_dries_slowly() -> void:
	var w: float = Lightning.step_wetness(0.0, 1.0, Lightning.WET_SECONDS * 0.5)
	assert_almost_eq(w, 0.5, 0.001)
	assert_almost_eq(Lightning.step_wetness(0.9, 1.0, 100.0), 1.0, 0.0001, "never overshoots")
	var d: float = Lightning.step_wetness(1.0, 0.0, Lightning.WET_SECONDS * 0.5)
	assert_gt(d, 0.8, "drying is much slower than soaking")
	assert_almost_eq(Lightning.step_wetness(1.0, 0.0, Lightning.DRY_SECONDS), 0.0, 0.0001)
	assert_gt(Lightning.DRY_SECONDS, Lightning.WET_SECONDS * 2.0)


func test_strike_timing_and_envelope() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 200:
		var full: float = Lightning.next_interval(rng, 1.0)
		assert_true(full >= Lightning.MIN_INTERVAL and full <= Lightning.MAX_INTERVAL, "interval %f" % full)
		var delay: float = Lightning.thunder_delay(rng)
		assert_true(delay >= Lightning.MIN_THUNDER_DELAY and delay <= Lightning.MAX_THUNDER_DELAY)
	assert_gt(Lightning.thunder_pitch(Lightning.MIN_THUNDER_DELAY),
		Lightning.thunder_pitch(Lightning.MAX_THUNDER_DELAY), "distant thunder is lower")
	assert_almost_eq(Lightning.flash_envelope(-0.1), 0.0)
	assert_almost_eq(Lightning.flash_envelope(0.03), 1.0, 0.001)
	assert_almost_eq(Lightning.flash_envelope(Lightning.FLASH_SECONDS), 0.0)
	var peak: float = 0.0
	var t: float = 0.0
	while t < Lightning.FLASH_SECONDS:
		var f: float = Lightning.flash_envelope(t)
		assert_true(f >= 0.0 and f <= 1.0)
		peak = maxf(peak, f)
		t += 0.01
	assert_almost_eq(peak, 1.0, 0.05)


func test_day_night_cycle_wetness_follows_rain() -> void:
	var nodes: Array = _make_dnc()
	var dnc: DNC = nodes[0]
	dnc.set_weather("heavy_rain")  # first id after setup: already raining → starts wet
	assert_almost_eq(dnc.wetness(), 1.0, 0.0001)
	dnc.set_weather("")
	dnc.tick(Lightning.DRY_SECONDS * 0.5)
	assert_almost_eq(dnc.wetness(), 0.5, 0.01)
	dnc.tick(Lightning.DRY_SECONDS)
	assert_almost_eq(dnc.wetness(), 0.0, 0.0001)
	dnc.set_weather("rain")
	dnc.tick(1.0)
	assert_gt(dnc.wetness(), 0.0, "later rain soaks in gradually")
	assert_lt(dnc.wetness(), 0.6)
	_free_all(nodes)


func test_lightning_flashes_and_thunders() -> void:
	var nodes: Array = _make_dnc()
	var dnc: DNC = nodes[0]
	var env: Environment = (nodes[3] as WorldEnvironment).environment
	dnc.set_weather("heavy_rain", true)
	var base_ambient: float = env.ambient_light_energy
	var pitches: Array[float] = []
	dnc.thunder_rumbled.connect(func(p: float) -> void: pitches.append(p))
	dnc.strike_lightning()
	dnc.tick(0.03)
	assert_gt(dnc.flash_level(), 0.5)
	assert_gt(env.ambient_light_energy, base_ambient + 0.5, "flash brightens ambient light")
	dnc.tick(Lightning.FLASH_SECONDS)
	assert_almost_eq(dnc.flash_level(), 0.0)
	assert_almost_eq(env.ambient_light_energy, base_ambient, 0.0001, "flash fully fades")
	dnc.tick(Lightning.MAX_THUNDER_DELAY)
	assert_eq(pitches.size(), 1, "one thunder per strike")

	# Reduce flashing: no flash, thunder still arrives.
	dnc.flashing_allowed = func() -> bool: return false
	dnc.strike_lightning()
	dnc.tick(0.03)
	assert_almost_eq(dnc.flash_level(), 0.0)
	assert_almost_eq(env.ambient_light_energy, base_ambient, 0.0001)
	dnc.tick(Lightning.MAX_THUNDER_DELAY)
	assert_eq(pitches.size(), 2)

	# A storm keeps striking on its own: within two max intervals at least one strike.
	dnc.flashing_allowed = Callable()
	var t: float = 0.0
	while t < Lightning.MAX_INTERVAL * 2.0 + Lightning.MAX_THUNDER_DELAY:
		dnc.tick(0.25)
		t += 0.25
	assert_gt(pitches.size(), 2, "heavy rain schedules strikes")
	_free_all(nodes)


func test_clear_weather_never_strikes() -> void:
	var nodes: Array = _make_dnc()
	var dnc: DNC = nodes[0]
	dnc.set_weather("rain", true)
	var count: Array[int] = [0]
	dnc.thunder_rumbled.connect(func(_p: float) -> void: count[0] += 1)
	var t: float = 0.0
	while t < 120.0:
		dnc.tick(0.5)
		t += 0.5
	assert_eq(count[0], 0)
	_free_all(nodes)


func test_thunder_has_a_synth_fallback() -> void:
	assert_true(SfxGen.all_keys().has("thunder"))
	var stream: AudioStreamWAV = SfxGen.get_sfx("thunder")
	assert_gt(stream.data.size(), SfxGen.MIX_RATE * 2, "thunder rolls for over a second")
