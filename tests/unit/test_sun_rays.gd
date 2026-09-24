## Unit tests for sun rays (GID-129 / TID-488).
##
## The shafts only show up on screen, so pin the rules (SunRayMath), the
## WeatherLook dampening and SunRaysFx's mode handling here.
extends "res://tests/framework/test_case.gd"

const SunRayMath = preload("res://game_logic/SunRayMath.gd")
const WeatherLook = preload("res://game_logic/WeatherLook.gd")
const GQ = preload("res://game_logic/GraphicsQuality.gd")
const DNC = preload("res://scenes/world/DayNightCycle.gd")
const SunRaysFx = preload("res://scenes/world/SunRaysFx.gd")

const DAWN := 0.27
const DUSK := 0.73
const NOON := 0.5
const MIDNIGHT := 0.0

# WorldScene.tscn's iso camera basis (looks along −(1,1,1)).
const CAM_BASIS := Basis(Vector3(0.707107, 0.0, -0.707107), Vector3(-0.408248, 0.816497, -0.408248),
	Vector3(0.57735, 0.57735, 0.57735))


func _sun_h(tod: float) -> float:
	return sin((tod - 0.25) * TAU)


func test_rays_belong_to_a_low_sun() -> void:
	assert_almost_eq(SunRayMath.strength(_sun_h(MIDNIGHT), 1.0), 0.0, 0.0001, "no rays at night")
	assert_almost_eq(SunRayMath.strength(-0.05, 1.0), 0.0, 0.0001, "no rays below the horizon")
	assert_almost_eq(SunRayMath.strength(_sun_h(NOON), 1.0), 0.0, 0.0001, "midday never hazes")
	assert_gt(SunRayMath.strength(_sun_h(DAWN), 1.0), 0.7, "dawn rays near full")
	assert_gt(SunRayMath.strength(_sun_h(DUSK), 1.0), 0.7, "dusk rays near full")
	assert_gt(SunRayMath.strength(0.1, 1.0), SunRayMath.strength(0.45, 1.0), "strongest near the horizon")
	assert_almost_eq(SunRayMath.strength(0.1, 0.5), SunRayMath.strength(0.1, 1.0) * 0.5, 0.0001)
	var t: float = 0.0
	while t < 1.0:
		var s: float = SunRayMath.strength(_sun_h(t), 1.0)
		assert_true(s >= 0.0 and s <= 1.0, "strength %f at %f" % [s, t])
		t += 0.01


func test_weather_dampens_rays() -> void:
	assert_almost_eq(float(WeatherLook.look_for("")["sun_rays"]), 1.0)
	for id: String in WeatherLook.OVERRIDES:
		var m: float = float(WeatherLook.look_for(id)["sun_rays"])
		assert_true(m >= 0.0 and m < 1.0, "%s should dampen rays (%f)" % [id, m])
	assert_lt(float(WeatherLook.look_for("heavy_rain")["sun_rays"]), float(WeatherLook.look_for("rain")["sun_rays"]))
	assert_lt(float(WeatherLook.look_for("blizzard")["sun_rays"]), float(WeatherLook.look_for("snow")["sun_rays"]))
	assert_almost_eq(float(WeatherLook.look_for("heavy_rain")["sun_rays"]), 0.0, 0.0001, "storms kill rays")


func test_rays_stream_from_the_sun_side_of_the_screen() -> void:
	var dawn: Vector3 = SunRayMath.screen_direction(DNC.sun_direction(DAWN), CAM_BASIS)
	var dusk: Vector3 = SunRayMath.screen_direction(DNC.sun_direction(DUSK), CAM_BASIS)
	var morning: Vector3 = SunRayMath.screen_direction(DNC.sun_direction(0.35), CAM_BASIS)
	assert_gt(dawn.x, 0.9, "NE dawn sun streams from screen-right")
	assert_lt(dusk.x, -0.9, "SW dusk sun streams from screen-left")
	assert_lt(morning.y, 0.0, "a higher sun leans toward the top of the screen")
	assert_almost_eq(dawn.z, 1.0, 0.0001, "a low sun lies fully across the screen")
	for d: Vector3 in [dawn, dusk, morning]:
		var uv: Vector2 = SunRayMath.source_uv(Vector2(d.x, d.y), 16.0 / 9.0)
		var off: bool = uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0
		assert_true(off, "virtual source %s sits just off-screen" % uv)
		assert_true(uv.x > -0.2 and uv.x < 1.2 and uv.y > -0.2 and uv.y < 1.2, "…but not far off (%s)" % uv)


func test_volumetric_density_off_at_zero_strength() -> void:
	assert_almost_eq(SunRayMath.volumetric_density(0.0), 0.0)
	assert_almost_eq(SunRayMath.volumetric_density(SunRayMath.MIN_STRENGTH * 0.5), 0.0)
	assert_almost_eq(SunRayMath.volumetric_density(1.0), SunRayMath.VOLUMETRIC_MAX_DENSITY)
	assert_lt(SunRayMath.VOLUMETRIC_MAX_DENSITY, 0.03, "keep the fog thin")


func _make_fx(tod: float) -> Array:
	var dnc := DNC.new()
	var sun := DirectionalLight3D.new()
	var moon := DirectionalLight3D.new()
	var env := Environment.new()
	env.fog_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	dnc.setup(sun, moon, we, false, 600.0, tod)
	var cam := Camera3D.new()
	cam.basis = CAM_BASIS
	var fx := SunRaysFx.new()
	fx.setup(cam, sun, moon, env, dnc)
	return [fx, dnc, sun, moon, we, cam, env]


func _free_all(nodes: Array) -> void:
	for n: Variant in nodes:
		if n is Node:
			(n as Node).free()


func test_screen_mode_shows_at_dawn_and_hides_at_noon() -> void:
	var nodes: Array = _make_fx(DAWN)
	var fx: SunRaysFx = nodes[0]
	var dnc: DNC = nodes[1]
	fx.set_mode(GQ.SUN_RAYS_OFF)
	assert_false(fx.is_screen_pass_visible(), "Low draws nothing")
	fx.set_mode(GQ.SUN_RAYS_SCREEN)
	assert_true(fx.is_screen_pass_visible())
	assert_gt(fx.screen_strength(), 0.5)
	dnc.set_time_of_day(NOON)
	fx.refresh()
	assert_false(fx.is_screen_pass_visible(), "hidden (and free) at midday")
	dnc.set_time_of_day(DUSK)
	dnc.set_weather("heavy_rain", true)
	fx.refresh()
	assert_false(fx.is_screen_pass_visible(), "storms kill the rays")
	dnc.set_weather("", true)
	fx.refresh()
	assert_true(fx.is_screen_pass_visible())
	fx.set_mode(GQ.SUN_RAYS_OFF)
	assert_false(fx.is_screen_pass_visible())
	_free_all(nodes)


func test_volumetric_mode_drives_fog() -> void:
	var nodes: Array = _make_fx(DAWN)
	var fx: SunRaysFx = nodes[0]
	var dnc: DNC = nodes[1]
	var sun: DirectionalLight3D = nodes[2]
	var moon: DirectionalLight3D = nodes[3]
	var env: Environment = nodes[6]
	fx.set_mode(GQ.SUN_RAYS_VOLUMETRIC)
	assert_true(env.volumetric_fog_enabled)
	assert_gt(env.volumetric_fog_density, 0.0)
	assert_almost_eq(env.volumetric_fog_ambient_inject, 0.0, 0.0001, "only the sun lights the fog")
	assert_almost_eq(moon.light_volumetric_fog_energy, 0.0, 0.0001)
	assert_gt(sun.light_volumetric_fog_energy, 0.0)
	assert_lt(fx.screen_strength(), fx.strength(), "screen pass is lighter alongside the fog")
	assert_true(fx.is_screen_pass_visible())
	dnc.set_time_of_day(NOON)
	fx.refresh()
	assert_false(env.volumetric_fog_enabled, "no fog at midday")
	dnc.set_time_of_day(DAWN)
	fx.refresh()
	assert_true(env.volumetric_fog_enabled)
	fx.set_mode(GQ.SUN_RAYS_SCREEN)
	assert_false(env.volumetric_fog_enabled, "leaving High turns the fog off")
	_free_all(nodes)


func test_high_enables_volumetric_fog_only_on_forward_plus() -> void:
	assert_true(bool(GQ.knobs_for(GQ.HIGH, "forward_plus")["volumetric_fog"]))
	assert_false(bool(GQ.knobs_for(GQ.HIGH, "mobile")["volumetric_fog"]))
	assert_eq(int(GQ.knobs_for(GQ.MEDIUM, "mobile")["sun_rays"]), GQ.SUN_RAYS_SCREEN)
	assert_eq(int(GQ.knobs_for(GQ.LOW, "forward_plus")["sun_rays"]), GQ.SUN_RAYS_OFF)
