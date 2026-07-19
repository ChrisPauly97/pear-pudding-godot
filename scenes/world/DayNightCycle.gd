extends Node

# Manages day/night time advancement, sun/moon lighting, sky color,
# and ambient light. Emits signals on day wrap, night start, and dawn.

signal day_passed
signal night_started
signal dawn_arrived

const _GrassBlades = preload("res://scenes/world/GrassBlades.gd")

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _world_env: WorldEnvironment
var _is_infinite: bool
var _day_duration: float = 600.0

var _time_of_day: float = 0.4
var _timer: float = 0.0
const INTERVAL: float = 0.5  # update lighting at 2 Hz

# Cached values — skip GPU writes when unchanged
var _cached_sun_energy: float = -1.0
var _cached_sun_color: Color = Color.BLACK
var _cached_moon_energy: float = -1.0
var _cached_sky_color: Color = Color.BLACK
var _cached_ambient_color: Color = Color.BLACK
var _cached_ambient_energy: float = -1.0
var _cached_grass_tint: Color = Color.BLACK

var _prev_was_night: bool = false
var _sky_mat: ProceduralSkyMaterial = null

func _get_sky_mat() -> ProceduralSkyMaterial:
	if _sky_mat != null:
		return _sky_mat
	if _world_env == null:
		return null
	var env: Environment = _world_env.environment
	if env == null:
		return null
	var s: Sky = env.sky as Sky
	if s == null:
		return null
	_sky_mat = s.sky_material as ProceduralSkyMaterial
	return _sky_mat

static func is_night(time_of_day: float) -> bool:
	return sin((time_of_day - 0.25) * TAU) < 0.0

func setup(sun: DirectionalLight3D, moon: DirectionalLight3D,
		world_env: WorldEnvironment, is_infinite: bool,
		day_duration: float, initial_time: float) -> void:
	_sun = sun
	_moon = moon
	_world_env = world_env
	_is_infinite = is_infinite
	_day_duration = day_duration
	_time_of_day = initial_time
	_prev_was_night = is_night(_time_of_day)
	# Register before the first _apply_lighting write — grass chunks may not
	# have initialised the shared grass globals yet at this point.
	_GrassBlades._ensure_global_param(
		"grass_day_tint", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ONE)

func get_time_of_day() -> float:
	return _time_of_day

func set_time_of_day(v: float) -> void:
	_time_of_day = v

func is_night_now() -> bool:
	return is_night(_time_of_day)

func invalidate_ambient_cache() -> void:
	_cached_ambient_color = Color.BLACK

func tick(delta: float, weather_tint: Color) -> void:
	_timer += delta
	if _timer < INTERVAL:
		return
	_advance(_timer, weather_tint)
	_timer = 0.0

func _advance(elapsed: float, weather_tint: Color) -> void:
	var prev_time: float = _time_of_day
	_time_of_day = fmod(_time_of_day + elapsed / _day_duration, 1.0)
	if _time_of_day < prev_time:
		day_passed.emit()

	if _is_infinite:
		var now_night: bool = is_night(_time_of_day)
		if now_night and not _prev_was_night:
			night_started.emit()
		elif not now_night and _prev_was_night:
			dawn_arrived.emit()
		_prev_was_night = now_night

	_apply_lighting(weather_tint)

func _apply_lighting(weather_tint: Color) -> void:
	var sun_angle: float = (_time_of_day - 0.25) * TAU
	_sun.rotation = Vector3(-sun_angle, 0.0, 0.0)
	_moon.rotation = Vector3(-(sun_angle + PI), 0.0, 0.0)

	var sun_h: float = sin(sun_angle)
	var t_day: float = clampf(sun_h * 2.0 + 0.1, 0.0, 1.0)
	var t_horizon: float = clampf(1.0 - abs(sun_h) * 5.0, 0.0, 1.0)

	# Cap below 1.5: sun + ambient + fill light stack multiplicatively on albedo;
	# 1.5 pushed midday terrain past 2.5x albedo and over the glow threshold.
	var sun_energy: float = clampf(sun_h * 1.5, 0.0, 1.1)
	var sun_color: Color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.45, 0.1), t_horizon)

	if not is_equal_approx(sun_energy, _cached_sun_energy):
		_sun.light_energy = sun_energy
		# A zero-energy light still costs per-pixel shading work — hide it.
		_sun.visible = sun_energy > 0.001
		_cached_sun_energy = sun_energy
	if not sun_color.is_equal_approx(_cached_sun_color):
		_sun.light_color = sun_color
		_cached_sun_color = sun_color

	var moon_h: float = -sun_h
	var moon_energy: float = clampf(moon_h * 0.35, 0.0, 0.35)
	if not is_equal_approx(moon_energy, _cached_moon_energy):
		_moon.light_energy = moon_energy
		_moon.visible = moon_energy > 0.001
		_cached_moon_energy = moon_energy

	var sky: Color
	if sun_h >= 0.0:
		sky = Color(0.7, 0.3, 0.1).lerp(Color(0.25, 0.5, 0.85), clampf(sun_h * 3.0, 0.0, 1.0))
	else:
		sky = Color(0.02, 0.02, 0.08).lerp(Color(0.7, 0.3, 0.1), clampf((sun_h + 0.3) * 5.0, 0.0, 1.0))
	if not sky.is_equal_approx(_cached_sky_color):
		_cached_sky_color = sky
		var sm: ProceduralSkyMaterial = _get_sky_mat()
		if sm != null:
			sm.sky_top_color         = sky.darkened(0.55)
			sm.sky_horizon_color     = sky
			sm.ground_horizon_color  = sky.darkened(0.25)
		if _world_env.environment.fog_enabled:
			_world_env.environment.fog_light_color = sky.lerp(Color(0.20, 0.20, 0.22), 0.25)

	var base_ambient: Color = Color(0.10, 0.10, 0.15).lerp(Color(0.65, 0.63, 0.60), t_day)
	var ambient_color: Color = Color(
		base_ambient.r * weather_tint.r,
		base_ambient.g * weather_tint.g,
		base_ambient.b * weather_tint.b)
	var ambient_energy: float = lerpf(0.35, 0.7, t_day)
	if not ambient_color.is_equal_approx(_cached_ambient_color):
		_world_env.environment.ambient_light_color = ambient_color
		_cached_ambient_color = ambient_color
	if not is_equal_approx(ambient_energy, _cached_ambient_energy):
		_world_env.environment.ambient_light_energy = ambient_energy
		_cached_ambient_energy = ambient_energy

	# Approximate the lit-grass brightness for the unshaded grass shaders:
	# ambient + most of the sun's contribution + a lift from the moon at night.
	# Capped at 1.25 so daytime grass stays vivid without crossing the bloom
	# threshold once multiplied by the authored blade colors.
	var grass_tint: Color = Color(
		minf(1.25, ambient_color.r * ambient_energy + sun_color.r * sun_energy * 0.85 + moon_energy * 0.5),
		minf(1.25, ambient_color.g * ambient_energy + sun_color.g * sun_energy * 0.85 + moon_energy * 0.5),
		minf(1.25, ambient_color.b * ambient_energy + sun_color.b * sun_energy * 0.85 + moon_energy * 0.6))
	if not grass_tint.is_equal_approx(_cached_grass_tint):
		_cached_grass_tint = grass_tint
		RenderingServer.global_shader_parameter_set(
			"grass_day_tint", Vector3(grass_tint.r, grass_tint.g, grass_tint.b))
