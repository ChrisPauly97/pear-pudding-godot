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
##   shadow_max_distance, shadow_split_1, shadow_blend_splits,
##   shadow_bias, shadow_normal_bias, moon_shadows — `apply()` (tuned in TID-485)
##   ssao, volumetric_fog, glow, msaa_3d — `apply()` (volumetric fog then driven by SunRaysFx, TID-488)
##   sun_rays                   — SUN_RAYS_* mode, read by scenes/world/SunRaysFx.gd (TID-488)
##   max_night_lights, night_light_shadows — night point lights (TID-489)
##   particle_scale             — multiplier for every GPUParticles3D amount (`scaled_amount`)
##   ambient_particles          — dust / fireflies / leaves on or off (TID-493)
##   ray_samples, moon_rays     — screen-ray occlusion taps + night moon rays, SunRaysFx (TID-496)
##   ground_mist                — low mist particles at night/dawn, AmbientTouches (TID-497)
##   fake_shafts, light_halos   — fake volumetric sun shafts (count) / night-light halos,
##                                FakeVolumetrics + NightLights (TID-495)
##   depth_fog                  — full-screen depth-fog pass, FakeVolumetrics (TID-498)
##   fxaa, taa                  — screen-space edge smoothing on the viewport, `apply()` (GID-131 / TID-501);
##                                taa is Forward+ only
##   debanding                  — viewport dithering against 8-bit gradient steps, `apply()` (TID-502)
##   height_fog                 — valley mist via Environment height fog, DayNightCycle (GID-130 / TID-494)
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
const FORWARD_PLUS_ONLY: Array[String] = ["ssao", "volumetric_fog", "taa"]
## Fake stand-ins (GID-130) that duplicate real volumetric fog: zeroed wherever
## `volumetric_fog` actually runs, so the two never stack.
const FAKE_VOLUMETRIC: Dictionary = {"fake_shafts": 0, "depth_fog": false}

## Shadow tuning (TID-485). The iso camera is orthographic (size 15) and sits
## 34.6 units from the player, so on-screen ground lies ~24–45 units deep:
## `shadow_max_distance` just covers it, and `shadow_split_1` (a fraction of
## that distance) ends the near PSSM cascade just past the player's depth so it
## holds the player's surroundings while the far one covers the top of the
## screen. Coarser atlases need more bias to keep terrain free of acne.
const TIERS: Array[Dictionary] = [
	{ # LOW — cheapest look: no shadows, no glow, no MSAA, half particles.
		"sun_shadows": false,
		"shadow_mode": DirectionalLight3D.SHADOW_ORTHOGONAL,
		"shadow_atlas_size": 1024,
		"soft_shadow_quality": RenderingServer.SHADOW_QUALITY_HARD,
		"shadow_max_distance": 45.0,
		"shadow_split_1": 0.7,
		"shadow_blend_splits": false,
		"shadow_bias": 0.15,
		"shadow_normal_bias": 1.6,
		"moon_shadows": false,
		"ssao": false,
		"volumetric_fog": false,
		"glow": false,
		"msaa_3d": Viewport.MSAA_DISABLED,
		"particle_scale": 0.5,
		"ambient_particles": false,
		"sun_rays": SUN_RAYS_OFF,
		"max_night_lights": 0,
		"night_light_shadows": false,
		"fxaa": false,
		"taa": false,
		"debanding": false,
		"height_fog": false,
		"fake_shafts": 0,
		"light_halos": false,
		"depth_fog": false,
		"ground_mist": false,
		"ray_samples": 0,
		"moon_rays": false,
	},
	{ # MEDIUM — the pre-GID-129 mobile look (sun shadows were already off on phones).
		"sun_shadows": false,
		"shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		"shadow_atlas_size": 2048,
		"soft_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		"shadow_max_distance": 50.0,
		"shadow_split_1": 0.7,
		"shadow_blend_splits": false,
		"shadow_bias": 0.1,
		"shadow_normal_bias": 1.3,
		"moon_shadows": false,
		"ssao": false,
		"volumetric_fog": false,
		"glow": true,
		"msaa_3d": Viewport.MSAA_4X,
		"particle_scale": 0.75,
		"ambient_particles": true,
		"sun_rays": SUN_RAYS_SCREEN,
		"max_night_lights": 4,
		"night_light_shadows": false,
		"fxaa": true,
		"taa": false,
		"debanding": true,
		"height_fog": true,
		"fake_shafts": 6,
		"light_halos": true,
		"depth_fog": false,
		"ground_mist": true,
		"ray_samples": 10,
		"moon_rays": false,
	},
	{ # HIGH — the pre-GID-129 desktop look plus the Forward+ extras.
		"sun_shadows": true,
		"shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		"shadow_atlas_size": 4096,
		"soft_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"shadow_max_distance": 55.0,
		"shadow_split_1": 0.7,
		"shadow_blend_splits": true,
		"shadow_bias": 0.08,
		"shadow_normal_bias": 1.0,
		"moon_shadows": true,
		"ssao": true,
		# Tuned by TID-488 (SunRaysFx): sun-only injection, density scaled by the
		# low-sun ray strength and switched off entirely by midday, so it never hazes.
		"volumetric_fog": true,
		"glow": true,
		"msaa_3d": Viewport.MSAA_4X,
		"particle_scale": 1.0,
		"ambient_particles": true,
		"sun_rays": SUN_RAYS_VOLUMETRIC,
		"max_night_lights": 8,
		"night_light_shadows": false,
		"fxaa": true,
		"taa": true,
		"debanding": true,
		"height_fog": true,
		"fake_shafts": 10,
		"light_halos": true,
		"depth_fog": true,
		"ground_mist": true,
		"ray_samples": 16,
		"moon_rays": true,
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
		if bool(out.get("volumetric_fog", false)):
			out.merge(FAKE_VOLUMETRIC, true)
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
static func apply(knobs: Dictionary, env: Environment, sun: DirectionalLight3D, viewport: Viewport,
		moon: DirectionalLight3D = null) -> void:
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
		sun.directional_shadow_split_1 = float(knobs.get("shadow_split_1", 0.1))
		sun.directional_shadow_blend_splits = bool(knobs.get("shadow_blend_splits", false))
		sun.shadow_bias = float(knobs.get("shadow_bias", 0.1))
		sun.shadow_normal_bias = float(knobs.get("shadow_normal_bias", 1.0))
	if moon != null:
		# The moon is dim, so a single low-res orthogonal map is plenty. It
		# shares the directional atlas with the sun, but the two are never
		# visible at the same time (DayNightCycle hides a zero-energy light).
		moon.shadow_enabled = bool(knobs.get("moon_shadows", false))
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		moon.directional_shadow_max_distance = float(knobs.get("shadow_max_distance", 60.0))
		moon.shadow_bias = float(knobs.get("shadow_bias", 0.1)) * 1.5
		moon.shadow_normal_bias = float(knobs.get("shadow_normal_bias", 1.0)) * 1.5
		moon.shadow_opacity = 0.5
	if viewport != null:
		var msaa: int = int(knobs.get("msaa_3d", Viewport.MSAA_DISABLED))
		viewport.msaa_3d = msaa as Viewport.MSAA
		# MSAA misses alpha-cut sprite edges and shader-drawn edges; FXAA and
		# TAA catch those (GID-131 / TID-501).
		var fxaa: bool = bool(knobs.get("fxaa", false))
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
		viewport.use_taa = bool(knobs.get("taa", false))
		# Sky, fog and mist gradients step visibly on 8-bit phone panels (TID-502).
		viewport.use_debanding = bool(knobs.get("debanding", false))
	RenderingServer.directional_shadow_atlas_set_size(int(knobs.get("shadow_atlas_size", 4096)), true)
	var soft: int = int(knobs.get("soft_shadow_quality", RenderingServer.SHADOW_QUALITY_SOFT_LOW))
	RenderingServer.directional_soft_shadow_filter_set_quality(soft as RenderingServer.ShadowQuality)
