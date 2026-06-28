## Unit tests for the GID-096 co-op world-sync helpers:
## EnemySync (position stream) and WorldObjectSync (discrete events + snapshot).
extends "res://tests/framework/test_case.gd"

const EnemySync = preload("res://game_logic/net/EnemySync.gd")
const WorldObjectSync = preload("res://game_logic/net/WorldObjectSync.gd")


# ---------------------------------------------------------------------------
# EnemySync — state encode/decode round-trip
# ---------------------------------------------------------------------------

func test_enemy_state_round_trip() -> void:
	var payload: Array = EnemySync.encode_state("orc_3", 12.5, -7.25, true)
	var d: Dictionary = EnemySync.decode_state(payload)
	assert_eq(str(d["id"]), "orc_3")
	assert_almost_eq(float(d["x"]), 12.5)
	assert_almost_eq(float(d["z"]), -7.25)
	assert_true(bool(d["alive"]))


func test_enemy_state_alive_false_survives() -> void:
	var d: Dictionary = EnemySync.decode_state(EnemySync.encode_state("g", 0.0, 0.0, false))
	assert_false(bool(d["alive"]))


func test_enemy_state_decode_short_payload_defaults() -> void:
	var d: Dictionary = EnemySync.decode_state([])
	assert_eq(str(d["id"]), "")
	assert_almost_eq(float(d["x"]), 0.0)
	assert_true(bool(d["alive"]))


func test_enemy_batch_round_trip() -> void:
	var batch: Array = EnemySync.encode_batch([
		EnemySync.encode_state("a", 1.0, 2.0, true),
		EnemySync.encode_state("b", 3.0, 4.0, false),
	])
	var out: Array = EnemySync.decode_batch(batch)
	assert_eq(out.size(), 2)
	assert_eq(str((out[0] as Dictionary)["id"]), "a")
	assert_eq(str((out[1] as Dictionary)["id"]), "b")
	assert_false(bool((out[1] as Dictionary)["alive"]))


func test_enemy_batch_skips_non_array_entries() -> void:
	var out: Array = EnemySync.decode_batch(["garbage", EnemySync.encode_state("ok", 0.0, 0.0, true)])
	assert_eq(out.size(), 1)
	assert_eq(str((out[0] as Dictionary)["id"]), "ok")


func test_enemy_interp_moves_toward_target() -> void:
	var result: Vector3 = EnemySync.interp(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 1.0 / 5.0, 12.0)
	assert_gt(result.x, 0.0)
	assert_lte(result.x, 10.0)


func test_enemy_interp_static_target_is_noop() -> void:
	# Static co-op enemies: target == current position → no movement.
	var pos := Vector3(4.0, 1.0, 9.0)
	var result: Vector3 = EnemySync.interp(pos, pos, 1.0 / 5.0, 12.0)
	assert_almost_eq(result.x, pos.x)
	assert_almost_eq(result.z, pos.z)


# ---------------------------------------------------------------------------
# WorldObjectSync — discrete event encode/decode
# ---------------------------------------------------------------------------

func test_event_round_trip() -> void:
	var payload: Array = WorldObjectSync.encode_event(WorldObjectSync.EV_ENEMY_REMOVED, "orc_3")
	var d: Dictionary = WorldObjectSync.decode_event(payload)
	assert_eq(str(d["kind"]), WorldObjectSync.EV_ENEMY_REMOVED)
	assert_eq(str(d["id"]), "orc_3")


func test_event_chest_opened_kind() -> void:
	var d: Dictionary = WorldObjectSync.decode_event(
		WorldObjectSync.encode_event(WorldObjectSync.EV_CHEST_OPENED, "dc_1"))
	assert_eq(str(d["kind"]), "chest_opened")
	assert_eq(str(d["id"]), "dc_1")


func test_event_decode_short_payload_defaults() -> void:
	var d: Dictionary = WorldObjectSync.decode_event([])
	assert_eq(str(d["kind"]), "")
	assert_eq(str(d["id"]), "")


func test_event_kinds_are_distinct() -> void:
	var kinds: Array = [
		WorldObjectSync.EV_ENEMY_ENGAGED,
		WorldObjectSync.EV_ENEMY_REMOVED,
		WorldObjectSync.EV_ENEMY_DEFEATED,
		WorldObjectSync.EV_CHEST_OPENED,
	]
	var seen: Array = []
	for k in kinds:
		assert_does_not_have(seen, k, "duplicate event kind %s" % k)
		seen.append(k)


# ---------------------------------------------------------------------------
# WorldObjectSync — late-join snapshot
# ---------------------------------------------------------------------------

func test_snapshot_round_trip() -> void:
	var payload: Array = WorldObjectSync.encode_snapshot(["orc_1", "orc_2"], ["dc_1"])
	var d: Dictionary = WorldObjectSync.decode_snapshot(payload)
	var removed: Array = d["removed_enemies"]
	var opened: Array = d["opened_objects"]
	assert_eq(removed.size(), 2)
	assert_has(removed, "orc_1")
	assert_has(removed, "orc_2")
	assert_eq(opened.size(), 1)
	assert_has(opened, "dc_1")


func test_snapshot_empty_round_trip() -> void:
	var d: Dictionary = WorldObjectSync.decode_snapshot(WorldObjectSync.encode_snapshot([], []))
	assert_eq((d["removed_enemies"] as Array).size(), 0)
	assert_eq((d["opened_objects"] as Array).size(), 0)


func test_snapshot_decode_garbage_defaults() -> void:
	var d: Dictionary = WorldObjectSync.decode_snapshot([])
	assert_eq((d["removed_enemies"] as Array).size(), 0)
	assert_eq((d["opened_objects"] as Array).size(), 0)


func test_snapshot_coerces_ids_to_strings() -> void:
	# keys() from a Dictionary-backed set are arbitrary Variants; ensure they
	# survive as strings through the wire helper.
	var d: Dictionary = WorldObjectSync.decode_snapshot(
		WorldObjectSync.encode_snapshot([123, "x"], [456]))
	assert_has(d["removed_enemies"], "123")
	assert_has(d["opened_objects"], "456")
