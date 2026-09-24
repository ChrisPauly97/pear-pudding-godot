## Graphics quality tiers (GID-129 / TID-484) — the one table that decides which
## atmosphere effects run.
##
## Every atmosphere effect reads its knob from `knobs_for()` instead of checking
## the platform or renderer itself. Tier 0 Low / 1 Medium / 2 High; Medium is
## the mobile default, High the desktop default. Effects the Mobile and
## Compatibility renderers cannot draw (`FORWARD_PLUS_ONLY`) are forced off
## unless Forward+ is actually running, whatever tier the player picked.
##
## Knob reference (who reads what):
##   sun_shadows, shadow_mode, shadow_atlas_size, soft_shadow_quality,
##   shadow_max_distance        — `apply()` (TID-485 tunes the values)
##   ssao, volumetric_fog, glow, msaa_3d — `apply()` (TID-488 enables volumetric fog)
##   sun_rays                   — SUN_RAYS_* mode, read by the sun-ray effect (TID-488)
##   max_night_lights, night_light_shadows — night point lights (TID-489)
##   particle_scale             — multiplier for every GPUParticles3D amount (`scaled_amount`)
##   ambient_particles          — dust / fireflies / leaves on or off (TID-493)
extends RefCounted

const LOW := 0
const MEDIUM := 1
const HIGH := 2

const SETTING_KEY := "graphics_quality"
const LABELS: Array[String] = ["Low", "Medium", "High"]

const SUN_RAYS_OFF := 0
const SUN_RAYS_SCREEN := 1       # screen-space radial blur, works on every renderer
const SUN_RAYS_VOLUMETRIC := 2   # volumetric fog light shafts, Forward+ only

const RENDERER_FORWARD_PLUS := "forward_plus"

## Boolean knobs that need the Forward+ renderer. `clamp_to_renderer` turns them off elsewhere.
const FORWARD_PLUS_ONLY: Array[String] = ["ssao", "volumetric_fog"]

const TIERS: Array[Dictionary] = [
	{ # LOW — cheapest look: no shadows, no glow, no MSAA, half particles.
		"sun_shadows": false,
		"shadow_mode": DirectionalLight3D.SHADOW_ORTHOGONAL,
		"shadow_atlas_size": 1024,
		"soft_shadow_quality": RenderingServer.SHADOW_QUALITY_HARD,
		"shadow_max_distance": 40.0,
		"ssao": false,
		"volumetric_fog": false,
		"glow": false,
		"msaa_3d": Viewport.MSAA_DISABLED,
		"particle_scale": 0.5,
		"ambient_particles": false,
		"sun_rays": SUN_RAYS_OFF,
		"max_night_lights": 0,
		"night_light_shadows": false,
	},
	{ # MEDIUM — the pre-GID-129 mobile look (sun shadows were already off on phones).
		"sun_shadows": false,
		"shadow_mode": DirectionalLight3D.SHADOW_ORTHOGONAL,
		"shadow_atlas_size": 2048,
		"soft_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		"shadow_max_distance": 50.0,
		"ssao": false,
		"volumetric_fog": false,
		"glow": true,
		"msaa_3d": Viewport.MSAA_4X,
		"particle_scale": 0.75,
		"ambient_particles": true,
		"sun_rays": SUN_RAYS_SCREEN,
		"max_night_lights": 4,
		"night_light_shadows": false,
	},
	{ # HIGH — the pre-GID-129 desktop look plus the Forward+ extras.
		"sun_shadows": true,
		"shadow_mode": DirectionalLight3D.SHADOW_ORTHOGONAL,
		"shadow_atlas_size": 4096,
		"soft_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"shadow_max_distance": 60.0,
		"ssao": true,
		# Off until TID-488 tunes density against the glow threshold — enabled
		# with engine defaults it hazes the whole midday screen.
		"volumetric_fog": false,
		"glow": true,
		"msaa_3d": Viewport.MSAA_4X,
		"particle_scale": 1.0,
		"ambient_particles": true,
		"sun_rays": SUN_RAYS_VOLUMETRIC,
		"max_night_lights": 8,
		"night_light_shadows": false,
	},
]


static func is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android")


static func default_tier(is_mobile: bool) -> int:
	return MEDIUM if is_mobile else HIGH


## Resolves a stored setting value (missing, junk or out of range) to a tier.
static func tier_from_setting(value: Variant, is_mobile: bool) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return default_tier(is_mobile)
	var tier: int = int(value)
	if tier < LOW or tier > HIGH:
		return default_tier(is_mobile)
	return tier


## Turns off anything the running renderer cannot draw. Returns a copy.
static func clamp_to_renderer(knobs: Dictionary, rendering_method: String) -> Dictionary:
	var out: Dictionary = knobs.duplicate()
	if rendering_method == RENDERER_FORWARD_PLUS:
		return out
	for key: String in FORWARD_PLUS_ONLY:
		out[key] = false
	if int(out.get("sun_rays", SUN_RAYS_OFF)) == SUN_RAYS_VOLUMETRIC:
		out["sun_rays"] = SUN_RAYS_SCREEN
	return out


## The knobs for a tier on a given renderer. Always a fresh copy.
static func knobs_for(tier: int, rendering_method: String) -> Dictionary:
	var t: int = clampi(tier, LOW, HIGH)
	return clamp_to_renderer(TIERS[t], rendering_method)


## The knobs for the stored setting on this device and renderer.
static func current_knobs(setting_value: Variant) -> Dictionary:
	var tier := tier_from_setting(setting_value, is_mobile_platform())
	return knobs_for(tier, RenderingServer.get_current_rendering_method())


## Particle count for a system whose full-quality amount is `amount`.
static func scaled_amount(amount: int, knobs: Dictionary) -> int:
	var scale: float = float(knobs.get("particle_scale", 1.0))
	return maxi(1, roundi(amount * scale))


## Writes the knobs this module owns to the world's Environment, sun and
## viewport. Any argument may be null (e.g. a headless test without a viewport).
static func apply(knobs: Dictionary, env: Environment, sun: DirectionalLight3D, viewport: Viewport) -> void:
	if env != null:
		env.glow_enabled = bool(knobs.get("glow", true))
		env.ssao_enabled = bool(knobs.get("ssao", false))
		if env.ssao_enabled:
			# Gentle contact shading only; the iso view reads flat with engine defaults (2.0).
			env.ssao_intensity = 1.0
			env.ssao_radius = 1.0
		env.volumetric_fog_enabled = bool(knobs.get("volumetric_fog", false))
	if sun != null:
		sun.shadow_enabled = bool(knobs.get("sun_shadows", false))
		var mode: int = int(knobs.get("shadow_mode", DirectionalLight3D.SHADOW_ORTHOGONAL))
		sun.directional_shadow_mode = mode as DirectionalLight3D.ShadowMode
		sun.directional_shadow_max_distance = float(knobs.get("shadow_max_distance", 60.0))
	if viewport != null:
		var msaa: int = int(knobs.get("msaa_3d", Viewport.MSAA_DISABLED))
		viewport.msaa_3d = msaa as Viewport.MSAA
	RenderingServer.directional_shadow_atlas_set_size(int(knobs.get("shadow_atlas_size", 4096)), true)
	var soft: int = int(knobs.get("soft_shadow_quality", RenderingServer.SHADOW_QUALITY_SOFT_LOW))
	RenderingServer.directional_soft_shadow_filter_set_quality(soft as RenderingServer.ShadowQuality)
