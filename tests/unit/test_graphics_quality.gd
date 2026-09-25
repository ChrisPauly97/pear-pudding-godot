## Unit tests for the Graphics Quality tier table (GID-129 / TID-484).
##
## Every atmosphere effect reads its knob from GraphicsQuality, so a tier that
## misses a key, costs less than the tier below it, or leaks a Forward+-only
## effect onto the Mobile renderer would only show up on a device.
extends "res://tests/framework/test_case.gd"

const GQ = preload("res://game_logic/GraphicsQuality.gd")

const _RENDERERS: Array[String] = ["forward_plus", "mobile", "gl_compatibility"]


func test_three_tiers_with_labels() -> void:
	assert_eq(GQ.TIERS.size(), 3)
	assert_eq(GQ.LABELS.size(), GQ.TIERS.size())
	assert_eq(GQ.LOW, 0)
	assert_eq(GQ.HIGH, GQ.TIERS.size() - 1)

func test_every_tier_has_the_same_knobs() -> void:
	var keys: Array = GQ.TIERS[0].keys()
	keys.sort()
	for i: int in GQ.TIERS.size():
		var k: Array = GQ.TIERS[i].keys()
		k.sort()
		assert_eq(k, keys, "tier %d knob set differs from Low" % i)

func test_cost_never_drops_as_tier_rises() -> void:
	for i: int in range(1, GQ.TIERS.size()):
		var lo: Dictionary = GQ.TIERS[i - 1]
		var hi: Dictionary = GQ.TIERS[i]
		for key: String in ["shadow_atlas_size", "shadow_max_distance", "particle_scale",
				"max_night_lights", "msaa_3d", "ray_samples", "sun_rays", "soft_shadow_quality"]:
			assert_gte(hi[key], lo[key], "%s drops from tier %d to %d" % [key, i - 1, i])
		for key: String in ["sun_shadows", "ssao", "glow", "ambient_particles", "moon_shadows",
				"shadow_blend_splits", "height_fog", "moon_rays"]:
			assert_true(bool(hi[key]) or not bool(lo[key]), "%s turns off at tier %d" % [key, i])

func test_low_is_cheap_and_high_is_full() -> void:
	var low: Dictionary = GQ.TIERS[GQ.LOW]
	assert_false(low["sun_shadows"])
	assert_eq(low["sun_rays"], GQ.SUN_RAYS_OFF)
	assert_eq(low["max_night_lights"], 0)
	assert_false(low["ambient_particles"])
	var high: Dictionary = GQ.TIERS[GQ.HIGH]
	assert_true(high["sun_shadows"])
	assert_almost_eq(float(high["particle_scale"]), 1.0)

func test_platform_defaults() -> void:
	assert_eq(GQ.default_tier(true), GQ.MEDIUM)
	assert_eq(GQ.default_tier(false), GQ.HIGH)

func test_setting_value_is_clamped() -> void:
	assert_eq(GQ.tier_from_setting(null, true), GQ.MEDIUM)
	assert_eq(GQ.tier_from_setting(null, false), GQ.HIGH)
	assert_eq(GQ.tier_from_setting("high", false), GQ.HIGH)
	assert_eq(GQ.tier_from_setting(7, true), GQ.MEDIUM)
	assert_eq(GQ.tier_from_setting(-1, false), GQ.HIGH)
	assert_eq(GQ.tier_from_setting(0, false), GQ.LOW)
	# JSON round-trips ints as floats.
	assert_eq(GQ.tier_from_setting(1.0, false), GQ.MEDIUM)

func test_forward_plus_only_flags_off_on_other_renderers() -> void:
	var all_on: Dictionary = GQ.TIERS[GQ.HIGH].duplicate()
	for key: String in GQ.FORWARD_PLUS_ONLY:
		all_on[key] = true
	all_on["sun_rays"] = GQ.SUN_RAYS_VOLUMETRIC
	for method: String in ["mobile", "gl_compatibility", "dummy"]:
		var k: Dictionary = GQ.clamp_to_renderer(all_on, method)
		for key: String in GQ.FORWARD_PLUS_ONLY:
			assert_false(k[key], "%s left on for %s" % [key, method])
		assert_eq(k["sun_rays"], GQ.SUN_RAYS_SCREEN, "volumetric rays not downgraded on %s" % method)
	var fp: Dictionary = GQ.clamp_to_renderer(all_on, "forward_plus")
	for key: String in GQ.FORWARD_PLUS_ONLY:
		assert_true(fp[key], "%s stripped on forward_plus" % key)
	assert_eq(fp["sun_rays"], GQ.SUN_RAYS_VOLUMETRIC)

func test_knobs_for_every_tier_and_renderer() -> void:
	for tier: int in GQ.TIERS.size():
		for method: String in _RENDERERS:
			var k: Dictionary = GQ.knobs_for(tier, method)
			assert_eq(k.size(), GQ.TIERS[tier].size())
			if method != "forward_plus":
				assert_false(k["ssao"])
				assert_false(k["volumetric_fog"])

func test_knobs_for_returns_a_copy() -> void:
	var k: Dictionary = GQ.knobs_for(GQ.HIGH, "forward_plus")
	k["sun_shadows"] = false
	assert_true(GQ.TIERS[GQ.HIGH]["sun_shadows"], "knobs_for leaked a reference to TIERS")

func test_scaled_amount() -> void:
	assert_eq(GQ.scaled_amount(200, GQ.TIERS[GQ.HIGH]), 200)
	assert_eq(GQ.scaled_amount(200, GQ.TIERS[GQ.LOW]), 100)
	assert_eq(GQ.scaled_amount(1, GQ.TIERS[GQ.LOW]), 1)

func test_apply_writes_env_and_sun() -> void:
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	GQ.apply(GQ.knobs_for(GQ.LOW, "forward_plus"), env, sun, null)
	assert_false(env.glow_enabled)
	assert_false(env.ssao_enabled)
	assert_false(sun.shadow_enabled)
	GQ.apply(GQ.knobs_for(GQ.HIGH, "forward_plus"), env, sun, null)
	assert_true(env.glow_enabled)
	assert_true(env.ssao_enabled)
	assert_true(sun.shadow_enabled)
	GQ.apply(GQ.knobs_for(GQ.HIGH, "mobile"), env, sun, null)
	assert_false(env.ssao_enabled, "SSAO applied on the Mobile renderer")
	assert_false(env.volumetric_fog_enabled)
	sun.free()
	# Leave the global shadow atlas at the desktop default for later suites.
	GQ.apply(GQ.knobs_for(GQ.HIGH, "forward_plus"), null, null, null)

func test_shadow_tuning_applied_to_sun_and_moon() -> void:
	var sun := DirectionalLight3D.new()
	var moon := DirectionalLight3D.new()
	var high: Dictionary = GQ.knobs_for(GQ.HIGH, "forward_plus")
	GQ.apply(high, null, sun, null, moon)
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	assert_almost_eq(sun.directional_shadow_max_distance, float(high["shadow_max_distance"]))
	assert_almost_eq(sun.directional_shadow_split_1, float(high["shadow_split_1"]))
	assert_almost_eq(sun.shadow_bias, float(high["shadow_bias"]))
	assert_almost_eq(sun.shadow_normal_bias, float(high["shadow_normal_bias"]))
	assert_true(sun.directional_shadow_blend_splits)
	assert_true(moon.shadow_enabled, "High should give the moon shadows")
	assert_eq(moon.directional_shadow_mode, DirectionalLight3D.SHADOW_ORTHOGONAL)
	GQ.apply(GQ.knobs_for(GQ.MEDIUM, "mobile"), null, sun, null, moon)
	assert_false(moon.shadow_enabled)
	assert_false(sun.shadow_enabled)
	# The iso view's ground spans ~24-45 units of depth; every tier must cover it.
	for tier: Dictionary in GQ.TIERS:
		assert_between(float(tier["shadow_max_distance"]), 45.0, 60.0)
		assert_between(float(tier["shadow_split_1"]), 0.1, 0.9)
	sun.free()
	moon.free()
	GQ.apply(GQ.knobs_for(GQ.HIGH, "forward_plus"), null, null, null)
