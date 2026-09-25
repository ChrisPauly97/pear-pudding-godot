## Unit tests for world-sprite idle life (GID-132 / TID-511).
extends "res://tests/framework/test_case.gd"

const IL = preload("res://game_logic/IdleLife.gd")


func test_register_records_rest_pose() -> void:
	var sp := Sprite3D.new()
	sp.position = Vector3(0, 0.7, 0)
	IL.register(sp, IL.STYLE_BOB)
	assert_true(sp.is_in_group(IL.GROUP))
	assert_eq(sp.get_meta(IL.META_BASE), Vector3(0, 0.7, 0))
	sp.free()

func test_squash_keeps_feet_planted() -> void:
	var sp := Sprite3D.new()
	var base := Vector3(0, 0.7, 0)
	IL.apply(sp, base, Vector2(0.0, 0.05))
	# Feet = centre − half-height × scale; half-height is base.y.
	assert_almost_eq(sp.position.y - base.y * sp.scale.y, 0.0, 0.0001)
	assert_lt(sp.scale.x, 1.0, "stretching tall narrows")
	sp.free()

func test_styles_and_hop() -> void:
	for t: float in [0.0, 0.4, 1.3, 2.9]:
		assert_almost_eq(IL.pose(IL.STYLE_FLOAT, t, 0.0, false, -1.0).y, 0.0, 0.0001, "float never squashes")
		assert_almost_eq(IL.pose(IL.STYLE_BREATHE, t, 0.0, false, -1.0).x, 0.0, 0.0001, "breathe never leaves the ground")
		assert_gte(IL.pose(IL.STYLE_BOB, t, 0.0, false, -1.0).x, 0.0)
	var mid_hop: float = IL.pose(IL.STYLE_BOB, 0.0, 0.0, false, IL.HOP_TIME * 0.5).x
	assert_gt(mid_hop, IL.HOP_HEIGHT * 0.9, "hop peaks mid-way")
	assert_almost_eq(IL.pose(IL.STYLE_BOB, 0.0, 0.0, false, IL.HOP_TIME * 2.0).x,
			IL.pose(IL.STYLE_BOB, 0.0, 0.0, false, -1.0).x, 0.0001, "hop ends")
