## Unit tests for iso camera pixel snapping (GID-131 / TID-504).
extends "res://tests/framework/test_case.gd"

const PS = preload("res://game_logic/PixelSnap.gd")

# WorldScene.tscn's iso camera basis (looks along −(1,1,1)).
const CAM_BASIS := Basis(Vector3(0.707107, 0.0, -0.707107), Vector3(-0.408248, 0.816497, -0.408248),
	Vector3(0.57735, 0.57735, 0.57735))


func test_one_pixel_is_size_over_height() -> void:
	# Camera3D.size is the full view height (the old code doubled it: 2 px steps).
	assert_almost_eq(PS.pixel_world_size(15.0, 1080.0), 15.0 / 1080.0, 0.000001)
	assert_gt(PS.pixel_world_size(15.0, 0.0), 0.0, "no divide by zero")

func test_snap_lands_on_grid_and_keeps_depth() -> void:
	var px: float = PS.pixel_world_size(15.0, 1080.0)
	var p := Vector3(3.1234, 0.77, -5.4321)
	var s: Vector3 = PS.snap(p, CAM_BASIS, px)
	var r: float = s.dot(CAM_BASIS.x.normalized()) / px
	var u: float = s.dot(CAM_BASIS.y.normalized()) / px
	assert_almost_eq(r, roundf(r), 0.001)
	assert_almost_eq(u, roundf(u), 0.001)
	assert_almost_eq(s.dot(CAM_BASIS.z.normalized()), p.dot(CAM_BASIS.z.normalized()), 0.0001)
	assert_lt(s.distance_to(p), px, "moves by less than a pixel")
	assert_eq(PS.snap(p, CAM_BASIS, 0.0), p)
