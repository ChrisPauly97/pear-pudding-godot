## Unit tests for AvatarSync (GID-090 / TID-352, hardened alongside the WorldScene
## split). decode() reads packets straight off the wire, so its contract is that
## any Variant — truncated array, wrong type, junk — yields a usable dict rather
## than faulting the RPC handler. Every other *Sync decoder in game_logic/net
## follows the same rule.
extends "res://tests/framework/test_case.gd"

const AvatarSync = preload("res://game_logic/net/AvatarSync.gd")


func test_round_trip_preserves_all_fields() -> void:
	var d: Dictionary = AvatarSync.decode(AvatarSync.encode(3.5, -7.25, true, true, "dungeon_2", true))
	assert_eq(d["x"], 3.5)
	assert_eq(d["z"], -7.25)
	assert_true(d["flip_h"])
	assert_true(d["moving"])
	assert_eq(d["map"], "dungeon_2")
	assert_true(d["downed"])


## Legacy peers send four elements; map/downed must default rather than fault.
func test_legacy_four_element_payload_defaults_map_and_downed() -> void:
	var d: Dictionary = AvatarSync.decode([1.0, 2.0, false, true])
	assert_eq(d["x"], 1.0)
	assert_eq(d["map"], "")
	assert_false(d["downed"])


func test_empty_payload_yields_defaults() -> void:
	var d: Dictionary = AvatarSync.decode([])
	assert_eq(d["x"], 0.0)
	assert_eq(d["z"], 0.0)
	assert_false(d["flip_h"])
	assert_false(d["moving"])
	assert_eq(d["map"], "")
	assert_false(d["downed"])


## A partially-truncated payload is the realistic corruption case.
func test_truncated_payload_yields_defaults_for_missing_fields() -> void:
	var d: Dictionary = AvatarSync.decode([9.0])
	assert_eq(d["x"], 9.0)
	assert_eq(d["z"], 0.0)
	assert_false(d["moving"])


func test_non_array_payload_yields_defaults() -> void:
	var d: Dictionary = AvatarSync.decode("not an array")
	assert_eq(d["x"], 0.0)
	assert_eq(d["map"], "")


func test_spawn_offset_is_stable_and_off_centre() -> void:
	var a: Vector2 = AvatarSync.spawn_offset(7, 4.0)
	assert_eq(a, AvatarSync.spawn_offset(7, 4.0))
	assert_gt(a.length(), 0.0)


func test_packet_velocity_from_consecutive_packets() -> void:
	var v: Vector2 = AvatarSync.packet_velocity(Vector2(0, 0), Vector2(0.4, 0), 0.1)
	assert_true(v.is_equal_approx(Vector2(4, 0)))


func test_packet_velocity_zero_for_stale_gap_and_capped() -> void:
	assert_eq(AvatarSync.packet_velocity(Vector2.ZERO, Vector2(5, 0), 1.0), Vector2.ZERO)
	assert_eq(AvatarSync.packet_velocity(Vector2.ZERO, Vector2(5, 0), 0.0), Vector2.ZERO)
	var fast: Vector2 = AvatarSync.packet_velocity(Vector2.ZERO, Vector2(100, 0), 0.1)
	assert_true(fast.length() <= AvatarSync.MAX_SPEED + 0.001)


func test_extrapolate_is_capped() -> void:
	var t := Vector2(10, 10)
	assert_eq(AvatarSync.extrapolate(t, Vector2(5, 0), 0.0), t)
	assert_true(AvatarSync.extrapolate(t, Vector2(5, 0), 0.1).is_equal_approx(Vector2(10.5, 10)))
	assert_true(AvatarSync.extrapolate(t, Vector2(5, 0), 5.0).is_equal_approx(
			t + Vector2(5, 0) * AvatarSync.MAX_EXTRAPOLATION))
