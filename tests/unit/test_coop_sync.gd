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


func test_encode_returns_six_elements() -> void:
	# Carries the sender's map name (TID-352) as a 5th element and the co-op
	# downed/rescue flag (TID-389) as a 6th.
	var payload: Array = AvatarSync.encode(1.0, 2.0, true, true, "madrian", true)
	assert_eq(payload.size(), 6)


func test_decode_returns_all_keys() -> void:
	var payload: Array = AvatarSync.encode(3.0, 4.0, false, true)
	var d: Dictionary = AvatarSync.decode(payload)
	assert_true(d.has("x"), "missing key x")
	assert_true(d.has("z"), "missing key z")
	assert_true(d.has("flip_h"), "missing key flip_h")
	assert_true(d.has("moving"), "missing key moving")
	assert_true(d.has("map"), "missing key map")
	assert_true(d.has("downed"), "missing key downed")


# ---------------------------------------------------------------------------
# map field (TID-352) — round-trip + backward/garbage tolerance
# ---------------------------------------------------------------------------

func test_encode_decode_preserves_map() -> void:
	var d: Dictionary = AvatarSync.decode(AvatarSync.encode(0.0, 0.0, false, false, "madrian"))
	assert_eq(str(d["map"]), "madrian")


func test_decode_default_map_is_empty() -> void:
	# Omitted map arg encodes "" and round-trips to "".
	var d: Dictionary = AvatarSync.decode(AvatarSync.encode(0.0, 0.0, false, false))
	assert_eq(str(d["map"]), "")


func test_decode_legacy_four_element_payload_map_empty() -> void:
	# A pre-TID-352 4-element payload must still decode, with map defaulting to "".
	var d: Dictionary = AvatarSync.decode([1.0, 2.0, true, false])
	assert_almost_eq(float(d["x"]), 1.0)
	assert_eq(str(d["map"]), "")


# ---------------------------------------------------------------------------
# downed field (GID-105 / TID-389) — round-trip + backward tolerance
# ---------------------------------------------------------------------------

func test_encode_decode_preserves_downed_true() -> void:
	var d: Dictionary = AvatarSync.decode(AvatarSync.encode(0.0, 0.0, false, false, "madrian", true))
	assert_true(d["downed"], "downed true should survive round-trip")


func test_decode_default_downed_is_false() -> void:
	# Omitted downed arg encodes false and round-trips to false.
	var d: Dictionary = AvatarSync.decode(AvatarSync.encode(0.0, 0.0, false, false, "madrian"))
	assert_false(d["downed"], "downed should default false")


func test_decode_legacy_five_element_payload_downed_false() -> void:
	# A pre-TID-389 5-element payload must still decode, with downed defaulting to false.
	var d: Dictionary = AvatarSync.decode([1.0, 2.0, true, false, "madrian"])
	assert_almost_eq(float(d["x"]), 1.0)
	assert_false(d["downed"])


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


# ---------------------------------------------------------------------------
# spawn_offset — deterministic N-peer fan-out (TID-341)
# ---------------------------------------------------------------------------

func test_spawn_offset_is_deterministic() -> void:
	var a: Vector2 = AvatarSync.spawn_offset(42, 2.0)
	var b: Vector2 = AvatarSync.spawn_offset(42, 2.0)
	assert_almost_eq(a.x, b.x)
	assert_almost_eq(a.y, b.y)


func test_spawn_offset_distinct_slots_distinct_offsets() -> void:
	# Four peer ids mapping to four different ring slots must not stack.
	var ids: Array[int] = [1, 2, 3, 4]
	var seen: Array[Vector2] = []
	for pid in ids:
		var off: Vector2 = AvatarSync.spawn_offset(pid, 2.0)
		for prev in seen:
			assert_gt(off.distance_to(prev), 0.01,
				"peer %d offset collides with an earlier peer" % pid)
		seen.append(off)


func test_spawn_offset_radius_is_two_tiles() -> void:
	# Every slot sits on a ring of radius 2 * tile_size from the centre.
	var tile: float = 3.0
	var off: Vector2 = AvatarSync.spawn_offset(5, tile)
	assert_almost_eq(off.length(), 2.0 * tile)


func test_spawn_offset_never_at_centre() -> void:
	# A zero offset would stack the avatar on the local player — never allowed.
	for pid in range(0, 24):
		var off: Vector2 = AvatarSync.spawn_offset(pid, 1.0)
		assert_gt(off.length(), 0.01, "peer %d landed at the centre" % pid)


func test_spawn_offset_handles_large_peer_ids() -> void:
	# Real ENet peer ids are large random ints; abs(%) must stay in range.
	var off: Vector2 = AvatarSync.spawn_offset(2138472913, 2.0)
	assert_almost_eq(off.length(), 4.0)
