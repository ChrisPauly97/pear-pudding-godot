## Unit tests for rain splashes (GID-133 / TID-514).
extends "res://tests/framework/test_case.gd"

const RP = preload("res://game_logic/RainParticles.gd")


func test_splash_level_rules() -> void:
	assert_almost_eq(RP.splash_level("", true), 0.0)
	assert_almost_eq(RP.splash_level("snow", true), 0.0, 0.0001, "snow doesn't splash")
	assert_gt(RP.splash_level("heavy_rain", true), RP.splash_level("rain", true))
	assert_almost_eq(RP.splash_level("heavy_rain", false), 0.0, 0.0001, "off with ambient particles off")

func test_factories() -> void:
	var r: GPUParticles3D = RP.make_rings()
	var d: GPUParticles3D = RP.make_drops()
	assert_eq(r.amount, RP.RING_AMOUNT)
	assert_eq(d.amount, RP.DROP_AMOUNT)
	assert_false(r.local_coords)
	assert_eq((r.draw_pass_1 as QuadMesh).orientation, PlaneMesh.FACE_Y, "rings lie flat")
	assert_not_null(d.draw_pass_1)
	var r2: GPUParticles3D = RP.make_rings()
	assert_eq(r2.draw_pass_1, r.draw_pass_1, "shared mesh")
	r2.free()
	assert_gt(RP.RING_LIFT, 0.12, "above terrain vertex jitter")
	r.free()
	d.free()
