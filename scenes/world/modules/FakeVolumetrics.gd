## Fake volumetrics (GID-130): stand-ins for Forward+ volumetric fog that run
## on every renderer, so Android (Mobile renderer) gets atmospheric depth.
##
##   * light shafts (TID-495) — a pool of slanted additive beams
##     (fake_light_shaft.gdshader) on world-anchored cells around the player,
##     lit by the dawn/dusk sun: `SunRayMath.strength × WeatherLook.sun_rays`.
##     Count = GraphicsQuality `fake_shafts` (0 Low / 6 Medium / 10 High;
##     clamped to 0 where real volumetric fog runs). Infinite world only —
##     named maps include interiors and dungeons.
##
## Everything hides when its strength is ~0 (midday, night, storms), so the
## day's middle costs nothing.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _DayNightCycle = preload("res://scenes/world/DayNightCycle.gd")
const _SunRayMath = preload("res://game_logic/SunRayMath.gd")
const _AtmosphereMath = preload("res://game_logic/AtmosphereMath.gd")
const _SHAFT_SHADER = preload("res://assets/shaders/fake_light_shaft.gdshader")

const REFRESH_INTERVAL: float = 0.25
const SHAFT_LENGTH: float = 14.0
const SHAFT_WIDTH_MIN: float = 1.2
const SHAFT_WIDTH_MAX: float = 2.6

static var _quad: QuadMesh

var _world: _WorldScene = null

var _shafts: Array[MeshInstance3D] = []
var _shaft_mats: Array[ShaderMaterial] = []
var _visible_shafts: int = 0
var _shaft_strength: float = 0.0
var _refresh_in: float = 0.0


## Shafts currently drawn and the strength they draw with (tests, debugging).
func visible_shafts() -> int:
	return _visible_shafts


func shaft_strength() -> float:
	return _shaft_strength


func _process(delta: float) -> void:
	if _world == null or _world._dnc == null or _world._player == null:
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = REFRESH_INTERVAL
		refresh()


## Re-reads knobs, time and weather and re-places the effects.
func refresh() -> void:
	var knobs: Dictionary = _world.graphics_knobs()
	var tod: float = _world._dnc.get_time_of_day()
	var sun_h: float = sin((tod - 0.25) * TAU)
	var look: Dictionary = _world._dnc.weather_look()
	var count: int = int(knobs.get("fake_shafts", 0)) if _world._is_infinite else 0
	_shaft_strength = _SunRayMath.strength(sun_h, float(look.get("sun_rays", 1.0))) if count > 0 else 0.0
	if _shaft_strength < _SunRayMath.MIN_STRENGTH:
		_shaft_strength = 0.0
		count = 0
	_update_shafts(count, _DayNightCycle.sun_direction(tod), _DayNightCycle.sun_color_for(sun_h))


func _update_shafts(count: int, sun_dir: Vector3, col: Color) -> void:
	var anchors: Array[Vector3] = []
	if count > 0:
		var p: Vector3 = _world._player.global_position
		anchors = _AtmosphereMath.shaft_anchors(Vector2(p.x, p.z), count)
	while _shafts.size() < anchors.size():
		_make_shaft()
	var axis: Vector3 = _AtmosphereMath.shaft_axis(sun_dir)
	for i: int in _shafts.size():
		var mi: MeshInstance3D = _shafts[i]
		if i >= anchors.size():
			mi.visible = false
			continue
		var a: Vector3 = anchors[i]
		var mat: ShaderMaterial = _shaft_mats[i]
		mi.global_position = Vector3(a.x, _world.get_terrain_height(a.x, a.y), a.y)
		mi.visible = true
		mat.set_shader_parameter("axis", axis)
		mat.set_shader_parameter("width", lerpf(SHAFT_WIDTH_MIN, SHAFT_WIDTH_MAX, a.z))
		mat.set_shader_parameter("shaft_length", SHAFT_LENGTH)
		mat.set_shader_parameter("shaft_color", col)
		mat.set_shader_parameter("strength", _shaft_strength)
		mat.set_shader_parameter("seed", a.z)
	_visible_shafts = anchors.size()


func _make_shaft() -> void:
	if _quad == null:
		_quad = QuadMesh.new()
	var mi := MeshInstance3D.new()
	mi.name = "FakeShaft"
	mi.mesh = _quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# The vertex shader stretches the unit quad far past its mesh bounds.
	mi.custom_aabb = AABB(Vector3(-SHAFT_LENGTH, -1.0, -SHAFT_LENGTH),
			Vector3(SHAFT_LENGTH * 2.0, SHAFT_LENGTH + 2.0, SHAFT_LENGTH * 2.0))
	var mat := ShaderMaterial.new()
	mat.shader = _SHAFT_SHADER
	mi.material_override = mat
	mi.visible = false
	_world.add_child(mi)
	_shafts.append(mi)
	_shaft_mats.append(mat)
