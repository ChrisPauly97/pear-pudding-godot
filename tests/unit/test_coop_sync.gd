## Unit tests for AvatarSync — encode/decode round-trip and interpolation.
extends "res://tests/framework/test_case.gd"

const AvatarSync = preload("res://game_logic/net/AvatarSync.gd")


# ---------------------------------------------------------------------------
# encode / decode round-trip
# ---------------------------------------------------------------------------

func test_encode_decode_preserves_x() -> void:
	var payload: Array = AvatarSync.encode(12.5, 0.0, false, false)
	var d: Dictionary = AvatarSync.decode(payload)
	var x: float = d["x"]
	assert_almost_eq(x, 12.5)


func test_encode_decode_preserves_z() -> void:
	var payload: Array = AvatarSync.encode(0.0, -7.25, false, false)
	var d: Dictionary = AvatarSync.decode(payload)
	var z: float = d["z"]
	assert_almost_eq(z, -7.25)


func test_encode_decode_preserves_flip_h_true() -> void:
	var payload: Array = AvatarSync.encode(0.0, 0.0, true, false)
	var d: Dictionary = AvatarSync.decode(payload)
	assert_true(d["flip_h"], "flip_h true should survive round-trip")


func test_encode_decode_preserves_flip_h_false() -> void:
	var payload: Array = AvatarSync.encode(0.0, 0.0, false, false)
	var d: Dictionary = AvatarSync.decode(payload)
	assert_false(d["flip_h"], "flip_h false should survive round-trip")


func test_encode_decode_preserves_moving_true() -> void:
	var payload: Array = AvatarSync.encode(0.0, 0.0, false, true)
	var d: Dictionary = AvatarSync.decode(payload)
	assert_true(d["moving"], "moving true should survive round-trip")


func test_encode_decode_preserves_moving_false() -> void:
	var payload: Array = AvatarSync.encode(0.0, 0.0, false, false)
	var d: Dictionary = AvatarSync.decode(payload)
	assert_false(d["moving"], "moving false should survive round-trip")


func test_encode_returns_four_elements() -> void:
	var payload: Array = AvatarSync.encode(1.0, 2.0, true, true)
	assert_eq(payload.size(), 4)


func test_decode_returns_all_keys() -> void:
	var payload: Array = AvatarSync.encode(3.0, 4.0, false, true)
	var d: Dictionary = AvatarSync.decode(payload)
	assert_true(d.has("x"), "missing key x")
	assert_true(d.has("z"), "missing key z")
	assert_true(d.has("flip_h"), "missing key flip_h")
	assert_true(d.has("moving"), "missing key moving")


# ---------------------------------------------------------------------------
# interp — moves toward target
# ---------------------------------------------------------------------------

func test_interp_moves_closer_to_target() -> void:
	var current := Vector3(0.0, 0.0, 0.0)
	var target := Vector3(10.0, 0.0, 0.0)
	var result: Vector3 = AvatarSync.interp(current, target, 1.0 / 15.0, 12.0)
	assert_gt(result.x, 0.0, "should move toward target")
	assert_lt(result.x, 10.0, "should not overshoot target")


func test_interp_zero_delta_returns_current() -> void:
	var current := Vector3(5.0, 0.0, 3.0)
	var target := Vector3(10.0, 0.0, 8.0)
	var result: Vector3 = AvatarSync.interp(current, target, 0.0, 12.0)
	assert_almost_eq(result.x, current.x)
	assert_almost_eq(result.z, current.z)


func test_interp_large_delta_clamps_to_target() -> void:
	var current := Vector3(0.0, 0.0, 0.0)
	var target := Vector3(5.0, 0.0, 5.0)
	# delta * rate >> 1 → factor clamped to 1.0 → result == target
	var result: Vector3 = AvatarSync.interp(current, target, 100.0, 12.0)
	assert_almost_eq(result.x, target.x)
	assert_almost_eq(result.z, target.z)


func test_interp_already_at_target_returns_target() -> void:
	var pos := Vector3(3.0, 0.0, 7.0)
	var result: Vector3 = AvatarSync.interp(pos, pos, 1.0 / 15.0, 12.0)
	assert_almost_eq(result.x, pos.x)
	assert_almost_eq(result.z, pos.z)


func test_interp_does_not_overshoot_on_normal_tick() -> void:
	var current := Vector3(0.0, 0.0, 0.0)
	var target := Vector3(1.0, 0.0, 0.0)
	# Simulate 15 Hz tick at rate 12 → factor ≈ 0.8; result must stay ≤ target
	var result: Vector3 = AvatarSync.interp(current, target, 1.0 / 15.0, 12.0)
	assert_lte(result.x, target.x + 0.0001, "must not overshoot target")
