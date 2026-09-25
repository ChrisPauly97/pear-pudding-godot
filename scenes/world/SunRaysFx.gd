extends Node
## Sun rays (GID-129 / TID-488): light shafts at dawn and dusk.
##
## The Graphics Quality `sun_rays` knob picks the mode:
##   SUN_RAYS_OFF        — nothing (Low).
##   SUN_RAYS_SCREEN     — `sun_rays.gdshader` on a full-screen ColorRect: cheap
##                         screen-space shafts from a virtual source past the
##                         screen edge (Medium; any renderer, ≤10 texture taps).
##   SUN_RAYS_VOLUMETRIC — Forward+ volumetric fog lit by the shadowed sun, so
##                         real shafts fall between trees and cliffs, plus the
##                         screen pass at reduced weight (High).
##
## Strength comes from `SunRayMath.strength` (low sun only, zero at midday and
## night) times the WeatherLook `sun_rays` multiplier, so storms dampen the
## rays while the DayNightCycle blends weather. Below `MIN_STRENGTH` the layer
## is hidden and the volumetric fog switched off — no GPU cost at midday.
## WorldScene creates this node and forwards Graphics Quality changes to
## `set_mode`; it reads time and weather from the DayNightCycle itself.

const _SunRayMath = preload("res://game_logic/SunRayMath.gd")
const _GraphicsQuality = preload("res://game_logic/GraphicsQuality.gd")
const _DayNightCycle = preload("res://scenes/world/DayNightCycle.gd")
const _SHADER = preload("res://assets/shaders/sun_rays.gdshader")

## Under the HUD (layer 1), so HUD pixels neither feed the occlusion march nor
## get rays drawn over them. The vignette (127) still darkens the rays' edges.
const CANVAS_LAYER: int = 0
## High pairs volumetric fog with a lighter screen pass.
const VOLUMETRIC_SCREEN_WEIGHT: float = 0.6
## Seconds between updates — the sun moves slowly and weather blends over 4 s.
const UPDATE_INTERVAL: float = 0.1
## Volumetric fog look: warm, forward-scattering (bright when looking toward
## the sun), long enough to reach past the iso view's far ground (~45 units).
const FOG_ALBEDO := Color(1.0, 0.95, 0.88)
const FOG_ANISOTROPY: float = 0.7
const FOG_LENGTH: float = 96.0
const SUN_FOG_ENERGY: float = 1.5
## Moon rays (GID-130 / TID-496): cool light, and a lower lit threshold since
## the whole night screen sits under the day one.
const MOON_RAY_COLOR := Color(0.62, 0.72, 1.0)
const SUN_LIT_THRESHOLD: float = 0.35
const MOON_LIT_THRESHOLD: float = 0.08

var _camera: Camera3D = null
var _sun: DirectionalLight3D = null
var _moon: DirectionalLight3D = null
var _env: Environment = null
var _dnc: _DayNightCycle = null

var _mode: int = _GraphicsQuality.SUN_RAYS_OFF
var _layer: CanvasLayer = null
var _rect: ColorRect = null
var _mat: ShaderMaterial = null
var _timer: float = 0.0
var _strength: float = 0.0
var _screen_strength: float = 0.0
var _cached_density: float = -1.0
var _samples: int = 10
var _moon_rays: bool = false
var _from_moon: bool = false


func setup(camera: Camera3D, sun: DirectionalLight3D, moon: DirectionalLight3D,
		env: Environment, dnc: _DayNightCycle) -> void:
	_camera = camera
	_sun = sun
	_moon = moon
	_env = env
	_dnc = dnc


## Switches mode (a `GraphicsQuality.SUN_RAYS_*` value) and re-evaluates now.
func set_mode(mode: int) -> void:
	_mode = mode
	_cached_density = -1.0
	if _mode != _GraphicsQuality.SUN_RAYS_OFF:
		_ensure_layer()
	if _mode == _GraphicsQuality.SUN_RAYS_VOLUMETRIC:
		_configure_volumetric()
	elif _env != null:
		_env.volumetric_fog_enabled = false
	refresh()


## Occlusion taps and whether the moon casts rays (GraphicsQuality
## `ray_samples` / `moon_rays`, TID-496).
func set_quality(samples: int, moon_rays: bool) -> void:
	_samples = maxi(1, samples)
	_moon_rays = moon_rays
	if _mat != null:
		_mat.set_shader_parameter("samples", _samples)
	refresh()


## True while the screen pass is drawing moon rays instead of sun rays.
func is_moon_source() -> bool:
	return _from_moon


func mode() -> int:
	return _mode


## Overall ray strength (time of day × weather), before the mode's weighting.
func strength() -> float:
	return _strength


## Strength the screen-space pass is drawing with (0 when hidden).
func screen_strength() -> float:
	return _screen_strength


func is_screen_pass_visible() -> bool:
	return _layer != null and _layer.visible


func _process(delta: float) -> void:
	if _mode == _GraphicsQuality.SUN_RAYS_OFF:
		return
	_timer += delta
	if _timer < UPDATE_INTERVAL:
		return
	_timer = 0.0
	refresh()


## Recomputes strength from the DayNightCycle and writes the shader / fog.
func refresh() -> void:
	_strength = 0.0
	_from_moon = false
	var tod: float = 0.5
	if _dnc != null:
		tod = _dnc.get_time_of_day()
		var look: Dictionary = _dnc.weather_look()
		var sun_h: float = sin((tod - 0.25) * TAU)
		var mult: float = float(look.get("sun_rays", 1.0))
		_strength = _SunRayMath.strength(sun_h, mult)
		if _moon_rays and _strength < _SunRayMath.MIN_STRENGTH:
			_strength = _SunRayMath.moon_strength(-sun_h, mult)
			_from_moon = _strength >= _SunRayMath.MIN_STRENGTH
	if _mode == _GraphicsQuality.SUN_RAYS_OFF:
		_strength = 0.0
		_from_moon = false
	_update_screen_pass(tod)
	if _mode == _GraphicsQuality.SUN_RAYS_VOLUMETRIC:
		_update_volumetric()


func _update_screen_pass(tod: float) -> void:
	_screen_strength = 0.0
	if _layer == null:
		return
	var sun_dir: Vector3 = _DayNightCycle.sun_direction(tod)
	if _from_moon:
		sun_dir = -sun_dir
	var cam_basis: Basis = _camera.basis if _camera != null else Basis.IDENTITY
	var sd: Vector3 = _SunRayMath.screen_direction(sun_dir, cam_basis)
	var volumetric: bool = _mode == _GraphicsQuality.SUN_RAYS_VOLUMETRIC and not _from_moon
	var weight: float = VOLUMETRIC_SCREEN_WEIGHT if volumetric else 1.0
	var s: float = _strength * sd.z * weight
	if s < _SunRayMath.MIN_STRENGTH:
		_layer.visible = false
		return
	_screen_strength = s
	_layer.visible = true
	var aspect: float = 16.0 / 9.0
	if _rect.is_inside_tree():
		var size: Vector2 = _rect.get_viewport_rect().size
		if size.y > 0.0:
			aspect = size.x / size.y
	var sun_h: float = sin((tod - 0.25) * TAU)
	var col: Color = MOON_RAY_COLOR if _from_moon else _DayNightCycle.sun_color_for(sun_h)
	_mat.set_shader_parameter("lit_threshold", MOON_LIT_THRESHOLD if _from_moon else SUN_LIT_THRESHOLD)
	_mat.set_shader_parameter("strength", s)
	_mat.set_shader_parameter("aspect", aspect)
	_mat.set_shader_parameter("source_uv", _SunRayMath.source_uv(Vector2(sd.x, sd.y), aspect))
	_mat.set_shader_parameter("ray_color", Vector3(col.r, col.g, col.b))


func _update_volumetric() -> void:
	if _env == null:
		return
	var density: float = 0.0 if _from_moon else _SunRayMath.volumetric_density(_strength)
	if is_equal_approx(density, _cached_density):
		return
	_cached_density = density
	_env.volumetric_fog_enabled = density > 0.0
	_env.volumetric_fog_density = density


func _configure_volumetric() -> void:
	if _env != null:
		_env.volumetric_fog_albedo = FOG_ALBEDO
		_env.volumetric_fog_anisotropy = FOG_ANISOTROPY
		_env.volumetric_fog_length = FOG_LENGTH
		# Only the sun lights the fog: ambient, GI and sky injection would haze
		# the whole volume uniformly instead of drawing shafts.
		_env.volumetric_fog_emission = Color.BLACK
		_env.volumetric_fog_ambient_inject = 0.0
		_env.volumetric_fog_gi_inject = 0.0
		_env.volumetric_fog_sky_affect = 0.0
	if _sun != null:
		_sun.light_volumetric_fog_energy = SUN_FOG_ENERGY
	if _moon != null:
		_moon.light_volumetric_fog_energy = 0.0


func _ensure_layer() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "SunRaysLayer"
	_layer.layer = CANVAS_LAYER
	_layer.visible = false
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = _SHADER
	_mat.set_shader_parameter("samples", _samples)
	_rect.material = _mat
	_layer.add_child(_rect)
	add_child(_layer)
