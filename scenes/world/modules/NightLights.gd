## Night point lights with flicker (GID-129 / TID-489): towns and camps glow
## warm from dusk to dawn.
##
## One shared manager, no per-light scripts. Every GATHER_INTERVAL it collects
## the light sources WorldScene already tracks (doors = lanterns, waystones,
## mana wells, the wilderness camp fire), keeps the nearest MAX_RIGS to the
## player and assigns them to pooled rigs; `_process` only writes each rig's
## flicker. A rig is
##   * a billboarded additive glow dot at the source — every tier;
##   * a light pool (night_light_pool.gdshader) — the first `max_night_lights`
##     rigs (GraphicsQuality: Low 0 / Medium 4 / High 8). It rebuilds world
##     positions from the depth texture, so it lights the unshaded grass,
##     props and sprites that a real OmniLight3D cannot reach (BID-060);
##   * a shadow-casting OmniLight3D — only while `night_light_shadows` is on.
## Rigs hide in daylight and the gather is skipped then, so the day costs nothing.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _DayNightCycle = preload("res://scenes/world/DayNightCycle.gd")
const _NightLightMath = preload("res://game_logic/NightLightMath.gd")
const _POOL_SHADER = preload("res://assets/shaders/night_light_pool.gdshader")

const GATHER_INTERVAL: float = 0.5
const MAX_RIGS: int = 8
const MAX_DISTANCE: float = 30.0
const POOL_LIFT: float = 0.5       # pool centre above the source's ground point
const DOT_SIZE: float = 0.7
# Nudges the dot toward the orthographic iso camera: pure depth, zero screen
# movement, so it draws in front of the door / stone sprite it belongs to.
const DOT_TOWARD_CAMERA := Vector3(0.23, 0.23, 0.23)

class Rig:
	var root: Node3D
	var pool: MeshInstance3D
	var pool_mat: ShaderMaterial
	var dot_mat: StandardMaterial3D
	var omni: OmniLight3D
	var style: Dictionary = {}
	var phase: float = 0.0

static var _pool_mesh: SphereMesh
static var _dot_mesh: QuadMesh
static var _dot_tex: GradientTexture2D

var _world: _WorldScene = null

var _rigs: Array[Rig] = []
var _active: int = 0            # rigs currently assigned to a source
var _pool_cap: int = 0
var _shadows: bool = false
var _night: float = 0.0
var _gather_in: float = 0.0
var _time: float = 0.0


static func _ensure_shared() -> void:
	if _pool_mesh != null:
		return
	_pool_mesh = SphereMesh.new()
	_pool_mesh.radius = 1.0
	_pool_mesh.height = 2.0
	_pool_mesh.radial_segments = 12
	_pool_mesh.rings = 6
	_dot_mesh = QuadMesh.new()
	_dot_mesh.size = Vector2(DOT_SIZE, DOT_SIZE)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	_dot_tex = GradientTexture2D.new()
	_dot_tex.gradient = grad
	_dot_tex.fill = GradientTexture2D.FILL_RADIAL
	_dot_tex.fill_from = Vector2(0.5, 0.5)
	_dot_tex.fill_to = Vector2(0.5, 0.0)
	_dot_tex.width = 32
	_dot_tex.height = 32


## Night factor in use (0 day .. 1 night); exposed for tests and debugging.
func night_level() -> float:
	return _night


## Rigs currently showing a light pool.
func pool_count() -> int:
	var n: int = 0
	for i: int in _active:
		if _rigs[i].pool.visible:
			n += 1
	return n


func active_count() -> int:
	return _active


func _process(delta: float) -> void:
	if _world == null or _world._dnc == null:
		return
	_time += delta
	_gather_in -= delta
	if _gather_in <= 0.0:
		_gather_in = GATHER_INTERVAL
		refresh()
	for i: int in _active:
		_apply_flicker(_rigs[i])


## Re-reads the night factor and the tier knobs, then re-assigns rigs to the
## nearest sources. Runs every GATHER_INTERVAL.
func refresh() -> void:
	var sun_h: float = _DayNightCycle.sun_direction(_world._dnc.get_time_of_day()).y
	_night = _NightLightMath.night_factor(sun_h)
	var knobs: Dictionary = _world.graphics_knobs()
	_pool_cap = int(knobs.get("max_night_lights", 0))
	_shadows = bool(knobs.get("night_light_shadows", false))
	var player: Node3D = _world._player
	if _night < 0.01 or player == null:
		_assign([])
		return
	_assign(_NightLightMath.nearest(_gather_sources(), player.global_position, MAX_RIGS, MAX_DISTANCE))


func _gather_sources() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_collect(out, _world._door_nodes, "lantern")
	_collect(out, _world._waystone_nodes, "waystone")
	_collect(out, _world._mana_well_nodes, "mana_well")
	var camp: Node3D = _world._valid_node3d(_world._wilderness_camp_node)
	if camp != null and camp.is_inside_tree():
		out.append({"pos": camp.global_position, "style": "campfire"})
	return out


func _collect(out: Array[Dictionary], nodes: Dictionary, style: String) -> void:
	for v: Variant in nodes.values():
		var n: Node3D = _world._valid_node3d(v)
		if n != null and n.is_inside_tree() and n.visible:
			out.append({"pos": n.global_position, "style": style})


func _assign(picked: Array[Dictionary]) -> void:
	_ensure_shared()
	for i: int in picked.size():
		if i >= _rigs.size():
			_rigs.append(_make_rig())
		var rig: Rig = _rigs[i]
		var src: Dictionary = picked[i]
		var pos: Vector3 = src["pos"]
		rig.style = _NightLightMath.STYLES[String(src["style"])]
		rig.phase = _NightLightMath.phase_for(pos)
		_place_rig(rig, pos, i < _pool_cap)
	for i: int in range(picked.size(), _rigs.size()):
		_rigs[i].root.visible = false
	_active = picked.size()


func _make_rig() -> Rig:
	var rig := Rig.new()
	rig.root = Node3D.new()
	rig.root.name = "NightLight"
	rig.pool = MeshInstance3D.new()
	rig.pool.mesh = _pool_mesh
	rig.pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.pool.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	rig.pool_mat = ShaderMaterial.new()
	rig.pool_mat.shader = _POOL_SHADER
	rig.pool.material_override = rig.pool_mat
	rig.root.add_child(rig.pool)
	var dot := MeshInstance3D.new()
	dot.name = "Glow"
	dot.mesh = _dot_mesh
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.dot_mat = StandardMaterial3D.new()
	rig.dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rig.dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rig.dot_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rig.dot_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	rig.dot_mat.albedo_texture = _dot_tex
	dot.material_override = rig.dot_mat
	rig.root.add_child(dot)
	rig.omni = OmniLight3D.new()
	rig.omni.shadow_enabled = true
	rig.omni.light_volumetric_fog_energy = 0.0
	rig.omni.visible = false
	rig.root.add_child(rig.omni)
	rig.root.visible = false
	_world.add_child(rig.root)
	return rig


func _place_rig(rig: Rig, ground: Vector3, with_pool: bool) -> void:
	var st: Dictionary = rig.style
	var radius: float = st["radius"]
	var col: Color = st["color"]
	var height: float = st["height"]
	rig.root.global_position = ground
	rig.root.visible = true
	rig.pool.visible = with_pool
	rig.pool.position = Vector3(0.0, POOL_LIFT, 0.0)
	var squash: float = 0.75
	rig.pool.scale = Vector3(radius * 1.08, radius / squash * 1.08, radius * 1.08)
	rig.pool_mat.set_shader_parameter("light_color", col)
	rig.pool_mat.set_shader_parameter("radius", radius)
	rig.pool_mat.set_shader_parameter("vertical_squash", squash)
	var dot: Node3D = rig.root.get_node("Glow") as Node3D
	dot.position = Vector3(0.0, height, 0.0) + DOT_TOWARD_CAMERA
	rig.omni.visible = with_pool and _shadows
	rig.omni.position = Vector3(0.0, height, 0.0)
	rig.omni.light_color = col
	rig.omni.omni_range = radius
	_apply_flicker(rig)


func _apply_flicker(rig: Rig) -> void:
	var st: Dictionary = rig.style
	var f: float = _NightLightMath.flicker(_time, rig.phase, float(st["flicker"]), float(st["speed"]))
	var e: float = float(st["energy"]) * f * _night
	if rig.pool.visible:
		rig.pool_mat.set_shader_parameter("energy", e)
	var col: Color = st["color"]
	rig.dot_mat.albedo_color = Color(col.r, col.g, col.b, clampf(_night * f, 0.0, 1.0))
	if rig.omni.visible:
		rig.omni.light_energy = e * 2.0
