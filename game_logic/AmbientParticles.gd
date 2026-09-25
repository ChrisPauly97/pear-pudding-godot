## Small ambient touches (GID-129 / TID-493): dust puffs, fireflies, leaves,
## and low ground mist (GID-130 / TID-497).
##
## Same shape as `WeatherParticles.make()`: each factory returns a configured
## GPUParticles3D and the caller parents and positions it. Draw meshes, their
## materials and the ramp textures are built once and shared statically, so
## spawning a puff never rebuilds GPU resources (CLAUDE.md chest-hitch note).
## The `*_level` helpers are the pure rules the AmbientTouches module applies
## (0 = off .. 1 = full); tests pin them.
extends RefCounted

const BIOME_GRASSLANDS: int = 0
const BIOME_FOREST: int = 1
const BIOME_MOUNTAINS: int = 4

const FIREFLY_AMOUNT: int = 36
const LEAF_AMOUNT: int = 28
const MIST_AMOUNT: int = 14

## Ground mist (TID-497): how much each biome holds (missing = none, e.g. desert).
const MIST_BIOMES: Dictionary = {BIOME_GRASSLANDS: 0.7, BIOME_FOREST: 1.0, BIOME_MOUNTAINS: 0.8}
## Weathers whose wind or own particles replace ground mist.
const MIST_BLOCKING: Array[String] = ["sandstorm", "dust_devil", "volcanic", "blizzard"]
## Per-weather mist multiplier for the rest (missing = 1).
const MIST_WEATHER: Dictionary = {"rain": 1.25, "heavy_rain": 1.1, "snow": 0.6, "ash_fall": 0.7}
## Peak puff alpha: several puffs overlap, so each stays faint.
const MIST_ALPHA: float = 0.16
const MIST_NIGHT_COLOR := Color(0.42, 0.47, 0.58)
const MIST_DAY_COLOR := Color(0.92, 0.90, 0.86)

## Firefly albedo is multiplied past the environment's glow threshold (1.2) so
## they bloom on tiers with glow on and still read as bright dots without it.
const FIREFLY_HDR: float = 3.0
const FIREFLY_COLOR := Color(0.80, 1.0, 0.35, 1.0)

## Weathers that keep fireflies grounded (anything falling or blowing hard).
const FIREFLY_BLOCKING: Array[String] = [
	"rain", "heavy_rain", "sandstorm", "dust_devil", "ash_fall", "volcanic", "snow", "blizzard",
]
## Weathers that strip the air of leaves (snow cover).
const LEAF_BLOCKING: Array[String] = ["snow", "blizzard"]
# Footstep splashes on wet ground (see set_wet).
const SPLASH_TINT := Color(0.80, 0.88, 0.97)
const SPLASH_GRAVITY := Vector3(0.0, -9.0, 0.0)
const SPLASH_SCALE: float = 0.6

static var _dust_mesh: QuadMesh
static var _firefly_mesh: QuadMesh
static var _leaf_mesh: QuadMesh
static var _dust_fade: GradientTexture1D
static var _dust_grow: CurveTexture
static var _firefly_blink: GradientTexture1D
static var _leaf_tints: GradientTexture1D
static var _mist_mesh: QuadMesh
static var _mist_mat: StandardMaterial3D
static var _mist_fade: GradientTexture1D


static func _soft_dot() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	return tex


static func _particle_material(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex
	return m


static func _ramp(offsets: Array[float], colors: Array[Color]) -> GradientTexture1D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array(offsets)
	grad.colors = PackedColorArray(colors)
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	tex.width = 64
	return tex


static func _ensure_shared() -> void:
	if _dust_mesh != null:
		return
	var dot := _soft_dot()
	_dust_mesh = QuadMesh.new()
	_dust_mesh.size = Vector2(1.0, 1.0)
	_dust_mesh.material = _particle_material(dot)
	_firefly_mesh = QuadMesh.new()
	_firefly_mesh.size = Vector2(0.22, 0.22)
	var ff := _particle_material(dot)
	ff.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ff.albedo_color = Color(FIREFLY_HDR, FIREFLY_HDR, FIREFLY_HDR, 1.0)
	_firefly_mesh.material = ff
	_leaf_mesh = QuadMesh.new()
	_leaf_mesh.size = Vector2(0.16, 0.10)
	_leaf_mesh.material = _particle_material(null)
	_dust_fade = _ramp([0.0, 0.25, 1.0], [Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.0))
	_dust_grow = CurveTexture.new()
	_dust_grow.curve = grow
	# Two slow blinks per lifetime; ends dark so respawns never pop.
	_firefly_blink = _ramp([0.0, 0.2, 0.35, 0.5, 0.7, 1.0], [Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0),
			Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	_mist_mesh = QuadMesh.new()
	_mist_mesh.size = Vector2(5.0, 2.6)
	_mist_mat = _particle_material(dot)
	# Soft where a puff meets the ground or a sprite instead of a hard line.
	_mist_mat.proximity_fade_enabled = true
	_mist_mat.proximity_fade_distance = 1.2
	_mist_mat.albedo_color = MIST_NIGHT_COLOR
	_mist_mesh.material = _mist_mat
	_mist_fade = _ramp([0.0, 0.3, 0.7, 1.0], [Color(1, 1, 1, 0.0), Color(1, 1, 1, MIST_ALPHA),
			Color(1, 1, 1, MIST_ALPHA), Color(1, 1, 1, 0.0)])
	_leaf_tints = _ramp([0.0, 0.4, 0.7, 1.0], [Color(0.42, 0.55, 0.22), Color(0.78, 0.62, 0.20),
			Color(0.82, 0.40, 0.16), Color(0.55, 0.30, 0.14)])


## Shared soft-puff draw pass for every dust emitter (Player foot/mount/landing).
static func dust_mesh() -> QuadMesh:
	_ensure_shared()
	return _dust_mesh


## Fades a dust process material in and out and lets puffs swell as they rise.
static func style_dust(pm: ParticleProcessMaterial) -> void:
	_ensure_shared()
	pm.color_ramp = _dust_fade
	pm.scale_curve = _dust_grow


## Footstep dust on wet ground reads as water: pale blue droplets that are
## smaller and fall fast. The dry look is stashed on the material the first
## time, so toggling back restores it exactly.


static func set_wet(pm: ParticleProcessMaterial, wet: bool) -> void:
	if not pm.has_meta(&"dry_color"):
		pm.set_meta(&"dry_color", pm.color)
		pm.set_meta(&"dry_gravity", pm.gravity)
		pm.set_meta(&"dry_scale", Vector2(pm.scale_min, pm.scale_max))
	var dry_col: Color = pm.get_meta(&"dry_color")
	var dry_grav: Vector3 = pm.get_meta(&"dry_gravity")
	var dry_scale: Vector2 = pm.get_meta(&"dry_scale")
	if wet:
		pm.color = Color(SPLASH_TINT, dry_col.a * 0.8)
		pm.gravity = SPLASH_GRAVITY
		pm.scale_min = dry_scale.x * SPLASH_SCALE
		pm.scale_max = dry_scale.y * SPLASH_SCALE
	else:
		pm.color = dry_col
		pm.gravity = dry_grav
		pm.scale_min = dry_scale.x
		pm.scale_max = dry_scale.y


## A one-shot ground puff (landing, move start). `amount` is pre-scaled.
static func make_dust_puff(amount: int) -> GPUParticles3D:
	_ensure_shared()
	var node := GPUParticles3D.new()
	node.amount = maxi(1, amount)
	node.lifetime = 0.5
	node.one_shot = true
	node.explosiveness = 0.9
	node.emitting = false
	node.position = Vector3(0.0, 0.2, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 75.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0.0, -2.0, 0.0)
	pm.damping_min = 1.5
	pm.damping_max = 2.5
	pm.scale_min = 0.22
	pm.scale_max = 0.38
	pm.color = Color(0.72, 0.60, 0.42, 0.6)
	style_dust(pm)
	node.process_material = pm
	node.draw_pass_1 = _dust_mesh
	return node


## Night fireflies drifting around the player. Emits in world space so the
## glow stays put while the emitter follows the player.
static func make_fireflies() -> GPUParticles3D:
	_ensure_shared()
	var node := GPUParticles3D.new()
	node.amount = FIREFLY_AMOUNT
	node.lifetime = 5.0
	node.preprocess = 5.0
	node.local_coords = false
	node.emitting = false
	node.visibility_aabb = AABB(Vector3(-14, -3, -14), Vector3(28, 8, 28))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(11.0, 0.8, 11.0)
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	pm.color = FIREFLY_COLOR
	pm.color_ramp = _firefly_blink
	node.process_material = pm
	node.draw_pass_1 = _firefly_mesh
	return node


## Forest leaves tumbling down-wind above the player. The process material is
## per emitter (`apply_wind` rewrites it); the draw pass is shared.
static func make_leaves() -> GPUParticles3D:
	_ensure_shared()
	var node := GPUParticles3D.new()
	node.amount = LEAF_AMOUNT
	node.lifetime = 6.0
	node.preprocess = 6.0
	node.local_coords = false
	node.emitting = false
	node.visibility_aabb = AABB(Vector3(-24, -10, -24), Vector3(48, 14, 48))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14.0, 0.5, 14.0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -200.0
	pm.angular_velocity_max = 200.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.0
	pm.turbulence_noise_scale = 6.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.2
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	pm.color_initial_ramp = _leaf_tints
	node.process_material = pm
	node.draw_pass_1 = _leaf_mesh
	apply_wind(pm, Vector2(1.0, 0.0), 1.0)
	return node


## Low rolling ground mist around the player: a few large, faint billboard
## puffs drifting down-wind (TID-497). Tint follows the time of day (`set_mist_tint`).
static func make_mist() -> GPUParticles3D:
	_ensure_shared()
	var node := GPUParticles3D.new()
	node.amount = MIST_AMOUNT
	node.lifetime = 12.0
	node.preprocess = 12.0
	node.local_coords = false
	node.emitting = false
	node.visibility_aabb = AABB(Vector3(-22, -3, -22), Vector3(44, 6, 44))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(15.0, 0.25, 15.0)
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	pm.color_ramp = _mist_fade
	node.process_material = pm
	node.draw_pass_1 = _mist_mesh
	apply_mist_wind(pm, Vector2(1.0, 0.0), 1.0)
	return node


## Mist creeps slowly along the weather wind.
static func apply_mist_wind(pm: ParticleProcessMaterial, wind_dir: Vector2, wind_scale: float) -> void:
	var w: Vector2 = wind_dir.normalized() if wind_dir.length_squared() > 0.0001 else Vector2(1.0, 0.0)
	pm.direction = Vector3(w.x, 0.0, w.y)
	pm.spread = 30.0
	var s: float = clampf(wind_scale, 0.5, 2.0)
	pm.initial_velocity_min = 0.15 * s
	pm.initial_velocity_max = 0.45 * s


## Tints the shared mist draw pass (cool at night, warm pale by day).
static func set_mist_tint(col: Color) -> void:
	_ensure_shared()
	_mist_mat.albedo_color = col


## Mist colour for a sun height: night blue-grey → pale warm white by morning.
static func mist_color(sun_h: float) -> Color:
	return MIST_NIGHT_COLOR.lerp(MIST_DAY_COLOR, smoothstep(-0.1, 0.25, sun_h))


## 0..1 ground-mist density: night and dawn, thinning out by mid-morning, in
## damp biomes and calm or wet weather.
static func mist_level(sun_h: float, biome: int, weather: String) -> float:
	if not MIST_BIOMES.has(biome) or weather in MIST_BLOCKING:
		return 0.0
	var time: float = 1.0 - smoothstep(0.1, 0.35, sun_h)
	var level: float = time * float(MIST_BIOMES[biome]) * float(MIST_WEATHER.get(weather, 1.0))
	return clampf(level, 0.0, 1.0)


## Points leaf drift along the weather's grass-wind direction (WeatherLook),
## faster and flatter as the wind strengthens.
static func apply_wind(pm: ParticleProcessMaterial, wind_dir: Vector2, wind_scale: float) -> void:
	var w: Vector2 = wind_dir.normalized() if wind_dir.length_squared() > 0.0001 else Vector2(1.0, 0.0)
	var s: float = clampf(wind_scale, 0.5, 3.0)
	pm.direction = Vector3(w.x, -0.35, w.y).normalized()
	pm.initial_velocity_min = 0.8 * s
	pm.initial_velocity_max = 1.6 * s
	pm.gravity = Vector3(w.x * 0.4 * s, -0.9, w.y * 0.4 * s)


## 0..1 firefly density: grassland/forest at night, in still air only.
static func firefly_level(night: float, biome: int, weather: String) -> float:
	if biome != BIOME_GRASSLANDS and biome != BIOME_FOREST:
		return 0.0
	if weather in FIREFLY_BLOCKING:
		return 0.0
	# Fireflies wait for real dusk, later than the lamps light up.
	return clampf((night - 0.4) / 0.5, 0.0, 1.0)


## 0..1 leaf density: forest only, thicker in wind, none under snow.
static func leaf_level(biome: int, weather: String, wind_scale: float) -> float:
	if biome != BIOME_FOREST or weather in LEAF_BLOCKING:
		return 0.0
	return clampf(0.45 + 0.25 * wind_scale, 0.0, 1.0)
