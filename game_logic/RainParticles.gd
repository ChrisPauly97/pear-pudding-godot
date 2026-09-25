extends RefCounted
## Rain striking the ground (GID-133 / TID-514): expanding ripple rings flat on
## the ground plus tiny droplets bouncing up, both in a box around the player.
## Same shape as AmbientParticles: factories return a configured
## GPUParticles3D; draw meshes/materials are shared statically; the pure
## `splash_level` rule says how hard it is raining (0 = off). AmbientTouches
## spawns, follows and fades them (`amount_ratio`).

const RING_AMOUNT: int = 70
const DROP_AMOUNT: int = 90
## Splash strength per weather id (missing = no splashes; snow/sand don't splash).
const LEVELS: Dictionary = {"rain": 0.6, "heavy_rain": 1.0}
## Above the terrain's flat-ground vertex jitter (≤ 0.12) so rings never clip.
const RING_LIFT: float = 0.14
const BOX_HALF: float = 13.0

static var _ring_mesh: QuadMesh
static var _drop_mesh: QuadMesh
static var _ring_fade: GradientTexture1D
static var _drop_fade: GradientTexture1D
static var _ring_grow: CurveTexture


static func _ensure_shared() -> void:
	if _ring_mesh != null:
		return
	# Thin bright ring on a transparent disc.
	var rg := Gradient.new()
	rg.offsets = PackedFloat32Array([0.0, 0.62, 0.8, 0.9, 1.0])
	rg.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.85),
			Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	var ring_tex := GradientTexture2D.new()
	ring_tex.gradient = rg
	ring_tex.fill = GradientTexture2D.FILL_RADIAL
	ring_tex.fill_from = Vector2(0.5, 0.5)
	ring_tex.fill_to = Vector2(0.5, 0.0)
	ring_tex.width = 64
	ring_tex.height = 64
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.vertex_color_use_as_albedo = true
	rm.albedo_texture = ring_tex
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_mesh = QuadMesh.new()
	_ring_mesh.orientation = PlaneMesh.FACE_Y
	_ring_mesh.size = Vector2(0.6, 0.6)
	_ring_mesh.material = rm
	var dg := Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 1))
	dg.set_color(1, Color(1, 1, 1, 0))
	var dot := GradientTexture2D.new()
	dot.gradient = dg
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.width = 16
	dot.height = 16
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	dm.albedo_texture = dot
	_drop_mesh = QuadMesh.new()
	_drop_mesh.size = Vector2(0.07, 0.07)
	_drop_mesh.material = dm
	_ring_fade = _ramp([0.0, 0.15, 1.0], [Color(0.85, 0.9, 1.0, 0.0), Color(0.85, 0.9, 1.0, 0.8),
			Color(0.85, 0.9, 1.0, 0.0)])
	_drop_fade = _ramp([0.0, 0.7, 1.0], [Color(0.85, 0.92, 1.0, 0.9), Color(0.85, 0.92, 1.0, 0.7),
			Color(0.85, 0.92, 1.0, 0.0)])
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.15))
	grow.add_point(Vector2(1.0, 1.0))
	_ring_grow = CurveTexture.new()
	_ring_grow.curve = grow


static func _ramp(offsets: Array[float], colors: Array[Color]) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 32
	return t


static func _box(node: GPUParticles3D, amount: int, lifetime: float) -> ParticleProcessMaterial:
	node.amount = amount
	node.lifetime = lifetime
	node.preprocess = lifetime
	node.local_coords = false
	node.emitting = false
	node.visibility_aabb = AABB(Vector3(-BOX_HALF - 2, -2, -BOX_HALF - 2), Vector3(BOX_HALF * 2 + 4, 5, BOX_HALF * 2 + 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(BOX_HALF, 0.0, BOX_HALF)
	node.process_material = pm
	return pm


## Ripple rings: spawn small, grow to full size and fade, flat on the ground.
static func make_rings() -> GPUParticles3D:
	_ensure_shared()
	var node := GPUParticles3D.new()
	var pm := _box(node, RING_AMOUNT, 0.55)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.scale_curve = _ring_grow
	pm.color_ramp = _ring_fade
	node.draw_pass_1 = _ring_mesh
	return node


## Droplets: a short upward bounce that falls back under gravity.
static func make_drops() -> GPUParticles3D:
	_ensure_shared()
	var node := GPUParticles3D.new()
	var pm := _box(node, DROP_AMOUNT, 0.35)
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 35.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(0.0, -12.0, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.color_ramp = _drop_fade
	node.draw_pass_1 = _drop_mesh
	return node


## 0..1 splash strength for a weather id; 0 when splashes are off.
static func splash_level(weather: String, enabled: bool) -> float:
	if not enabled:
		return 0.0
	return float(LEVELS.get(weather, 0.0))
