extends RefCounted
## Contact shadows under characters (GID-131 / TID-503) — caster registry and
## the pure rules; `scenes/world/modules/CharacterPresence.gd` writes the shader
## globals each frame and `contact_shadow.gdshaderinc` darkens the terrain and
## grass around each caster's feet.
##
## Medium, the phone default, has no sun shadows, so billboard characters
## floated. A separate decal quad was tried first: terrain vertex jitter (up to
## 0.12) and dense grass hid it. Shading the surfaces themselves avoids both.

const GROUP := "contact_shadow_caster"
const META_RADIUS := "contact_shadow_radius"
## Shader slots (contact_shadow_0 .. _5 in project.godot).
const MAX_CASTERS: int = 6
const PARAM_PREFIX := "contact_shadow_"
const OPACITY_PARAM := "contact_shadow_opacity"
const OPACITY_NO_SUN_SHADOWS: float = 0.55
const OPACITY_WITH_SUN_SHADOWS: float = 0.3
const MIN_RADIUS: float = 0.35
const MAX_RADIUS: float = 1.6
## An unused slot: radius 0, far below the world.
const EMPTY := Vector4(0.0, -1000.0, 0.0, 0.0)


## Radius for a character of `world_height` units.
static func radius_for_height(world_height: float) -> float:
	return clampf(world_height * 0.45, MIN_RADIUS, MAX_RADIUS)


## Marks `node` (origin at the feet) as casting a contact shadow.
static func register(node: Node3D, radius: float) -> void:
	node.add_to_group(GROUP)
	node.set_meta(META_RADIUS, clampf(radius, MIN_RADIUS, MAX_RADIUS))


## Opacity for a GraphicsQuality knob set: fainter where real sun shadows
## already ground the sprites.
static func opacity_for(knobs: Dictionary) -> float:
	return OPACITY_WITH_SUN_SHADOWS if bool(knobs.get("sun_shadows", false)) else OPACITY_NO_SUN_SHADOWS


## The MAX_CASTERS slot values for casters `(x, y, z, radius)`, nearest to
## `center` first, padded with EMPTY.
static func pick_slots(casters: Array[Vector4], center: Vector3) -> Array[Vector4]:
	# Runs every frame over every caster: keep only the nearest MAX_CASTERS by
	# insertion instead of copying and fully sorting the whole list.
	var best: Array[Vector4] = []
	var best_d: PackedFloat32Array = PackedFloat32Array()
	for c: Vector4 in casters:
		var d: float = Vector3(c.x, c.y, c.z).distance_squared_to(center)
		var n: int = best.size()
		if n == MAX_CASTERS and d >= best_d[n - 1]:
			continue
		var i: int = n
		while i > 0 and best_d[i - 1] > d:
			i -= 1
		best.insert(i, c)
		best_d.insert(i, d)
		if best.size() > MAX_CASTERS:
			best.resize(MAX_CASTERS)
			best_d.resize(MAX_CASTERS)
	while best.size() < MAX_CASTERS:
		best.append(EMPTY)
	return best
