extends Node

# Manages day/night time advancement, sun/moon lighting, sky color,
# and ambient light. Emits signals on day wrap, night start, and dawn.

signal day_passed
signal night_started
signal dawn_arrived

const _GrassBlades = preload("res://scenes/world/GrassBlades.gd")
const _WeatherLook = preload("res://game_logic/WeatherLook.gd")
const INTERVAL: float = 0.5  # update lighting at 2 Hz

# Sun arc (TID-485). The old sun swung about the X axis alone: it rose due
# south, passed straight overhead (no visible shadows at noon) and its dawn
# shadows ran along the iso camera's depth axis, where objects hide them.
# The arc now rises in the NE and sets in the SW, so dawn/dusk shadows stretch
# sideways across the screen, and the noon sun leans NOON_TILT away from the
# camera (toward NW, screen-up) so midday shadows fall toward the viewer.
const SUN_RISE_DIR := Vector3(0.70710678, 0.0, -0.70710678)   # NE (−Z is north)
const SUN_NOON_LEAN := Vector3(-0.70710678, 0.0, -0.70710678)  # NW, the camera's forward
const NOON_TILT: float = 0.52359878  # 30°

# Golden-hour ramp: warm day white → gold → deep low-energy orange at the horizon.
const SUN_DAY_COLOR := Color(1.0, 0.95, 0.85)
const SUN_GOLDEN_COLOR := Color(1.0, 0.74, 0.42)
const SUN_HORIZON_COLOR := Color(0.95, 0.40, 0.14)
const GOLDEN_BAND: float = 0.45  # sun height (sin of arc angle) below which it warms

# Weather look (TID-486): seconds a weather change takes to blend fog, sun,
# sky, shadows and grass wind from the current look to the new one.
const WEATHER_BLEND_SECONDS: float = 4.0

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _world_env: WorldEnvironment
var _is_infinite: bool
var _day_duration: float = 600.0

var _time_of_day: float = 0.4
var _timer: float = 0.0

# Cached values — skip GPU writes when unchanged
var _cached_sun_energy: float = -1.0
var _cached_sun_color: Color = Color.BLACK
var _cached_moon_energy: float = -1.0
var _cached_sky_color: Color = Color.BLACK
var _cached_ambient_color: Color = Color.BLACK
var _cached_ambient_energy: float = -1.0
var _cached_grass_tint: Color = Color.BLACK
var _cached_sun_dir: Vector3 = Vector3.ZERO
var _cached_fog_color: Color = Color.BLACK
var _cached_fog_density: float = -1.0
var _cached_shadow_opacity: float = -1.0
var _cached_wind_scale: float = -1.0
var _cached_wind_lean: float = -1.0

# Weather look blend: `_look` is what is applied, blending `_look_from` → `_look_to`.
var _look: Dictionary = _WeatherLook.look_for("")
var _look_from: Dictionary = _look
var _look_to: Dictionary = _look
var _look_t: float = 1.0
# Clear-weather values the look multiplies, captured at setup.
var _base_fog_density: float = 0.004
var _base_shadow_opacity: float = 1.0

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

## Unit vector from the world toward the sun. Its height has the sign of
## `sin(arc angle)`, so it crosses the horizon exactly when `is_night` switches.
static func sun_direction(time_of_day: float) -> Vector3:
	var a: float = (time_of_day - 0.25) * TAU
	var up_axis: Vector3 = Vector3.UP * cos(NOON_TILT) + SUN_NOON_LEAN * sin(NOON_TILT)
	return (SUN_RISE_DIR * cos(a) + up_axis * sin(a)).normalized()

## A light basis whose −Z points along `travel` (the direction light travels).
static func light_basis(travel: Vector3) -> Basis:
	var up: Vector3 = Vector3.UP if absf(travel.normalized().y) < 0.999 else Vector3.FORWARD
	return Basis.looking_at(travel, up)

## Sun colour for a sun height `sun_h` (sin of the arc angle). Three stops so
## the warm light lingers through a golden hour instead of snapping to orange
## only in the last moments before the horizon.
static func sun_color_for(sun_h: float) -> Color:
	var t: float = clampf(sun_h / GOLDEN_BAND, 0.0, 1.0)
	if t < 0.4:
		return SUN_HORIZON_COLOR.lerp(SUN_GOLDEN_COLOR, smoothstep(0.0, 0.4, t))
	return SUN_GOLDEN_COLOR.lerp(SUN_DAY_COLOR, smoothstep(0.4, 1.0, t))

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
	_GrassBlades._ensure_global_param("grass_wind_scale", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)
	_GrassBlades._ensure_global_param("grass_wind_lean", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	if _world_env != null and _world_env.environment != null:
		_base_fog_density = _world_env.environment.fog_density
	if _sun != null:
		_base_shadow_opacity = _sun.shadow_opacity

func get_time_of_day() -> float:
	return _time_of_day

func set_time_of_day(v: float) -> void:
	_time_of_day = v

func is_night_now() -> bool:
	return is_night(_time_of_day)

## Starts blending toward `weather_id`'s WeatherLook ("" = clear). Co-op
## clients reach this through the host-synced weather id, so no extra sync.
func set_weather(weather_id: String, instant: bool = false) -> void:
	_look_from = _look
	_look_to = _WeatherLook.look_for(weather_id)
	_look_t = 0.0
	if instant:
		_look_t = 1.0
		_look = _look_to
		_apply_lighting()

## The weather look currently applied (mid-blend while a change is in progress).
func weather_look() -> Dictionary:
	return _look

func tick(delta: float) -> void:
	# Weather blends per frame (called from WorldScene._process); the caches
	# keep unchanged values from being rewritten.
	if _look_t < 1.0:
		_look_t = minf(_look_t + delta / WEATHER_BLEND_SECONDS, 1.0)
		_look = _WeatherLook.blend(_look_from, _look_to, smoothstep(0.0, 1.0, _look_t))
		_apply_lighting()
	_timer += delta
	if _timer < INTERVAL:
		return
	_advance(_timer)
	_timer = 0.0

func _advance(elapsed: float) -> void:
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

	_apply_lighting()

func _apply_lighting() -> void:
	var weather_tint: Color = _look["tint"] as Color
	var light_mult: float = float(_look["sun_energy_mult"])
	var env: Environment = _world_env.environment
	var sun_angle: float = (_time_of_day - 0.25) * TAU
	var sun_dir: Vector3 = sun_direction(_time_of_day)
	if not sun_dir.is_equal_approx(_cached_sun_dir):
		_sun.basis = light_basis(-sun_dir)
		# The moon sits opposite the sun, so at night its light travels along sun_dir.
		_moon.basis = light_basis(sun_dir)
		_cached_sun_dir = sun_dir

	var sun_h: float = sin(sun_angle)
	var t_day: float = clampf(sun_h * 2.0 + 0.1, 0.0, 1.0)

	# Cap below 1.5: sun + ambient + fill light stack multiplicatively on albedo;
	# 1.5 pushed midday terrain past 2.5x albedo and over the glow threshold.
	var sun_energy: float = clampf(sun_h * 1.5, 0.0, 1.1) * light_mult
	var sun_color: Color = sun_color_for(sun_h)

	if not is_equal_approx(sun_energy, _cached_sun_energy):
		_sun.light_energy = sun_energy
		# A zero-energy light still costs per-pixel shading work — hide it.
		_sun.visible = sun_energy > 0.001
		_cached_sun_energy = sun_energy
	if not sun_color.is_equal_approx(_cached_sun_color):
		_sun.light_color = sun_color
		_cached_sun_color = sun_color
	var shadow_opacity: float = _base_shadow_opacity * float(_look["shadow_opacity_mult"])
	if not is_equal_approx(shadow_opacity, _cached_shadow_opacity):
		_sun.shadow_opacity = shadow_opacity
		_cached_shadow_opacity = shadow_opacity

	var moon_h: float = -sun_h
	var moon_energy: float = clampf(moon_h * 0.35, 0.0, 0.35) * light_mult
	if not is_equal_approx(moon_energy, _cached_moon_energy):
		_moon.light_energy = moon_energy
		_moon.visible = moon_energy > 0.001
		_cached_moon_energy = moon_energy

	var sky: Color
	if sun_h >= 0.0:
		sky = Color(0.7, 0.3, 0.1).lerp(Color(0.25, 0.5, 0.85), clampf(sun_h * 3.0, 0.0, 1.0))
	else:
		sky = Color(0.02, 0.02, 0.08).lerp(Color(0.7, 0.3, 0.1), clampf((sun_h + 0.3) * 5.0, 0.0, 1.0))
	# Overcast greys the sky toward the weather's fog colour, dimmed by the day curve
	# so a stormy night stays dark.
	var weather_fog: Color = _look["fog_color"] as Color
	var overcast_col: Color = weather_fog * lerpf(0.15, 1.0, t_day)
	overcast_col.a = 1.0
	sky = sky.lerp(overcast_col, float(_look["sky_overcast"]))
	if not sky.is_equal_approx(_cached_sky_color):
		_cached_sky_color = sky
		var sm: ProceduralSkyMaterial = _get_sky_mat()
		if sm != null:
			sm.sky_top_color         = sky.darkened(0.55)
			sm.sky_horizon_color     = sky
			sm.ground_horizon_color  = sky.darkened(0.25)
	var fog_col: Color = sky.lerp(Color(0.20, 0.20, 0.22), 0.25).lerp(
		overcast_col, float(_look["fog_color_weight"]))
	if env.fog_enabled and not fog_col.is_equal_approx(_cached_fog_color):
		env.fog_light_color = fog_col
		_cached_fog_color = fog_col
	var fog_mult: float = minf(float(_look["fog_density_mult"]), _WeatherLook.MAX_FOG_DENSITY_MULT)
	var fog_density: float = _base_fog_density * fog_mult
	if not is_equal_approx(fog_density, _cached_fog_density):
		env.fog_density = fog_density
		_cached_fog_density = fog_density

	var base_ambient: Color = Color(0.10, 0.10, 0.15).lerp(Color(0.65, 0.63, 0.60), t_day)
	var ambient_color: Color = Color(
		base_ambient.r * weather_tint.r,
		base_ambient.g * weather_tint.g,
		base_ambient.b * weather_tint.b)
	var ambient_energy: float = lerpf(0.35, 0.7, t_day)
	if not ambient_color.is_equal_approx(_cached_ambient_color):
		env.ambient_light_color = ambient_color
		_cached_ambient_color = ambient_color
	if not is_equal_approx(ambient_energy, _cached_ambient_energy):
		env.ambient_light_energy = ambient_energy
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

	var wind_scale: float = float(_look["wind_scale"])
	if not is_equal_approx(wind_scale, _cached_wind_scale):
		_cached_wind_scale = wind_scale
		RenderingServer.global_shader_parameter_set("grass_wind_scale", wind_scale)
	var wind_lean: float = float(_look["wind_lean"])
	if not is_equal_approx(wind_lean, _cached_wind_lean):
		_cached_wind_lean = wind_lean
		RenderingServer.global_shader_parameter_set("grass_wind_lean", wind_lean)
