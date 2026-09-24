## Unit tests for the small ambient touches (GID-129 / TID-493): dust puffs,
## fireflies and leaves. Pins the AmbientParticles gates and factories; the
## AmbientTouches module itself is exercised by world_scene_smoke.
extends "res://tests/framework/test_case.gd"

const AP = preload("res://game_logic/AmbientParticles.gd")
const GQ = preload("res://game_logic/GraphicsQuality.gd")


func test_fireflies_only_at_night_in_green_biomes() -> void:
	assert_almost_eq(AP.firefly_level(0.0, AP.BIOME_GRASSLANDS, ""), 0.0, 0.0001, "none by day")
	assert_almost_eq(AP.firefly_level(1.0, AP.BIOME_GRASSLANDS, ""), 1.0, 0.0001, "full at night")
	assert_almost_eq(AP.firefly_level(1.0, AP.BIOME_FOREST, ""), 1.0, 0.0001, "forest too")
	assert_almost_eq(AP.firefly_level(1.0, 2, ""), 0.0, 0.0001, "not in the desert")
	assert_almost_eq(AP.firefly_level(1.0, -1, ""), 0.0, 0.0001, "not on named maps")
	assert_almost_eq(AP.firefly_level(1.0, AP.BIOME_FOREST, "rain"), 0.0, 0.0001, "grounded by rain")
	var dusk: float = AP.firefly_level(0.6, AP.BIOME_GRASSLANDS, "")
	assert_true(dusk > 0.0 and dusk < 1.0, "fade in through dusk")


func test_leaves_only_in_forest_and_follow_wind() -> void:
	assert_almost_eq(AP.leaf_level(AP.BIOME_GRASSLANDS, "", 1.0), 0.0, 0.0001)
	assert_gt(AP.leaf_level(AP.BIOME_FOREST, "", 1.0), 0.0)
	assert_gt(AP.leaf_level(AP.BIOME_FOREST, "rain", 1.6), AP.leaf_level(AP.BIOME_FOREST, "", 1.0),
			"more leaves in wind")
	assert_almost_eq(AP.leaf_level(AP.BIOME_FOREST, "snow", 1.0), 0.0, 0.0001, "none under snow")
	assert_lte(AP.leaf_level(AP.BIOME_FOREST, "heavy_rain", 2.6), 1.0)


func test_apply_wind_points_down_wind() -> void:
	var pm := ParticleProcessMaterial.new()
	AP.apply_wind(pm, Vector2(0.0, 1.0), 2.0)
	assert_gt(pm.direction.z, 0.5, "drifts along +Z")
	assert_lt(pm.direction.y, 0.0, "and falls")
	assert_gt(pm.gravity.z, 0.0)
	var calm := ParticleProcessMaterial.new()
	AP.apply_wind(calm, Vector2.ZERO, 1.0)
	assert_false(is_nan(calm.direction.x), "zero wind never normalizes to NaN")
	assert_gt(pm.initial_velocity_max, calm.initial_velocity_max, "stronger wind, faster leaves")


func test_factories_have_a_draw_pass_and_material() -> void:
	var nodes: Array[GPUParticles3D] = [AP.make_fireflies(), AP.make_leaves(), AP.make_dust_puff(8)]
	for n: GPUParticles3D in nodes:
		assert_not_null(n.draw_pass_1, "visible particles need a draw pass")
		assert_not_null(n.draw_pass_1.surface_get_material(0), "draw pass carries its material")
		assert_not_null(n.process_material)
		n.free()


func test_shared_meshes_are_reused() -> void:
	var a: GPUParticles3D = AP.make_dust_puff(4)
	var b: GPUParticles3D = AP.make_dust_puff(4)
	assert_true(a.draw_pass_1 == b.draw_pass_1, "puffs share one mesh")
	assert_true(a.draw_pass_1 == AP.dust_mesh(), "player dust shares it too")
	a.free()
	b.free()


func test_fireflies_bloom() -> void:
	var ff: GPUParticles3D = AP.make_fireflies()
	var mat := ff.draw_pass_1.surface_get_material(0) as StandardMaterial3D
	assert_gt(mat.albedo_color.r * AP.FIREFLY_COLOR.g, 1.2, "brighter than the glow threshold")
	ff.free()


func test_tiers() -> void:
	assert_false(bool(GQ.TIERS[GQ.LOW]["ambient_particles"]), "off on Low")
	assert_true(bool(GQ.TIERS[GQ.MEDIUM]["ambient_particles"]))
	assert_true(bool(GQ.TIERS[GQ.HIGH]["ambient_particles"]))
	assert_lt(GQ.scaled_amount(AP.FIREFLY_AMOUNT, GQ.TIERS[GQ.MEDIUM]), AP.FIREFLY_AMOUNT, "Medium scales down")
