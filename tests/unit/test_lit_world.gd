## Unit tests for lit grass/props on High (GID-131 / TID-508).
extends "res://tests/framework/test_case.gd"

const GB = preload("res://scenes/world/GrassBlades.gd")
const CR = preload("res://scenes/world/ChunkRenderer.gd")
const GQ = preload("res://game_logic/GraphicsQuality.gd")
const SR = preload("res://game_logic/SpriteRegistry.gd")


func test_lit_world_only_on_high() -> void:
	assert_false(bool(GQ.TIERS[GQ.LOW]["lit_world"]))
	assert_false(bool(GQ.TIERS[GQ.MEDIUM]["lit_world"]), "phones keep the cheap unshaded grass")
	assert_true(bool(GQ.TIERS[GQ.HIGH]["lit_world"]))

func test_grass_swaps_shader_variant() -> void:
	var g: GB = GB.new()
	g.set_lit(true)
	g._init_material()
	assert_eq(g._mat.shader, GB._TuftShaderLit)
	g.set_lit(false)
	assert_eq(g._mat.shader, GB._TuftShader)
	assert_false(g.is_lit())
	g.free()

func test_prop_and_landmark_materials_follow_lit_world() -> void:
	var m := StandardMaterial3D.new()
	CR._prop_visual_cache["__test_prop"] = {"mat": m, "mesh": null}
	CR.set_lit_world(true)
	assert_eq(m.shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL)
	assert_false(m.disable_receive_shadows)
	CR.set_lit_world(false)
	assert_eq(m.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_true(m.disable_receive_shadows)
	CR._prop_visual_cache.erase("__test_prop")


## TID-647: swaying plants get the sway shader (lit/unshaded variant follows
## lit_world); rigid props keep the StandardMaterial3D; every swaying key is real.
func test_sway_props_use_sway_shader() -> void:
	var tex: Texture2D = SR.prop_texture("fern")
	var sway: Material = CR._make_sway_material("fern", tex)
	assert_true(sway is ShaderMaterial, "fern sways")
	CR._prop_visual_cache["__test_sway"] = {"mat": sway, "mesh": null}
	CR.set_lit_world(true)
	assert_eq((sway as ShaderMaterial).shader, CR._PropSwayShaderLit)
	CR.set_lit_world(false)
	assert_eq((sway as ShaderMaterial).shader, CR._PropSwayShader)
	CR._prop_visual_cache.erase("__test_sway")
	for key: String in CR.PROP_SWAY:
		assert_false(SR.prop_variants(key).is_empty(), "sway key %s has sprites" % key)
	assert_false(CR.PROP_SWAY.has("rock"), "rocks stay rigid")
