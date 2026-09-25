extends RefCounted
## Contact shadows under characters (GID-131 / TID-503) — caster registry and
## the pure rules; `scenes/world/modules/ContactShadows.gd` writes the shader
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
	var sorted: Array[Vector4] = casters.duplicate()
	sorted.sort_custom(func(a: Vector4, b: Vector4) -> bool:
		return Vector3(a.x, a.y, a.z).distance_squared_to(center) < Vector3(b.x, b.y, b.z).distance_squared_to(center))
	var out: Array[Vector4] = []
	for i: int in MAX_CASTERS:
		out.append(sorted[i] if i < sorted.size() else EMPTY)
	return out
