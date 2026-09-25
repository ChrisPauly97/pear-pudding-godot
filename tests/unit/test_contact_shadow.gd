## Unit tests for character contact shadows (GID-131 / TID-503).
extends "res://tests/framework/test_case.gd"

const CS = preload("res://game_logic/ContactShadow.gd")


func test_register_marks_caster() -> void:
	var n := Node3D.new()
	CS.register(n, 99.0)
	assert_true(n.is_in_group(CS.GROUP))
	assert_almost_eq(float(n.get_meta(CS.META_RADIUS)), CS.MAX_RADIUS)
	n.free()

func test_pick_slots_nearest_first_and_padded() -> void:
	var casters: Array[Vector4] = [Vector4(10, 0, 0, 0.5), Vector4(1, 0, 0, 0.5), Vector4(5, 0, 0, 0.5)]
	var slots: Array[Vector4] = CS.pick_slots(casters, Vector3.ZERO)
	assert_eq(slots.size(), CS.MAX_CASTERS)
	assert_almost_eq(slots[0].x, 1.0)
	assert_almost_eq(slots[1].x, 5.0)
	assert_eq(slots[CS.MAX_CASTERS - 1], CS.EMPTY)
	var many: Array[Vector4] = []
	for i: int in 20:
		many.append(Vector4(float(i), 0, 0, 0.5))
	assert_eq(CS.pick_slots(many, Vector3.ZERO).size(), CS.MAX_CASTERS)

func test_opacity_and_radius_rules() -> void:
	assert_lt(CS.opacity_for({"sun_shadows": true}), CS.opacity_for({"sun_shadows": false}))
	assert_almost_eq(CS.radius_for_height(0.1), CS.MIN_RADIUS)
	assert_almost_eq(CS.radius_for_height(99.0), CS.MAX_RADIUS)

func test_shader_globals_are_declared() -> void:
	for i: int in CS.MAX_CASTERS:
		assert_true(ProjectSettings.has_setting("shader_globals/" + CS.PARAM_PREFIX + str(i)), "slot %d" % i)
	assert_true(ProjectSettings.has_setting("shader_globals/" + CS.OPACITY_PARAM))
