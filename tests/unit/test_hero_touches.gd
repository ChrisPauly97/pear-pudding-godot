## Hero touches (GID-134 / TID-526): stepped walk bob and the interact glow.
extends "res://tests/framework/test_case.gd"

const IL = preload("res://game_logic/IdleLife.gd")
const SO = preload("res://game_logic/SpriteOutline.gd")


func test_walk_bob_lifts_on_passing_frames_only() -> void:
	assert_eq(IL.hero_bob(true, 0, 0.0), 0.0, "contact frame is grounded")
	assert_eq(IL.hero_bob(true, 1, 0.0), IL.HERO_STEP_LIFT)
	assert_eq(IL.hero_bob(true, 2, 0.0), 0.0)
	assert_eq(IL.hero_bob(true, 3, 0.0), IL.HERO_STEP_LIFT)


func test_idle_breath_is_occasional() -> void:
	var up: int = 0
	for i in 100:
		if IL.hero_bob(false, 0, float(i) * 0.05) > 0.0:
			up += 1
	assert_gt(up, 0, "the hero breathes")
	assert_lt(up, 40, "but mostly stands still")


func test_glow_warms_the_outline() -> void:
	var s := Sprite3D.new()
	SO.apply(s)
	SO.set_glow(s, 1.0)
	var c: Color = (s.material_override as ShaderMaterial).get_shader_parameter("outline_color")
	assert_true(c.is_equal_approx(SO.GLOW_COLOR))
	SO.set_glow(s, 0.0)
	c = (s.material_override as ShaderMaterial).get_shader_parameter("outline_color")
	assert_true(c.is_equal_approx(SO.OUTLINE_COLOR))
	s.free()
