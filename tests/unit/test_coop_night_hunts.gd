## Unit tests for CoopNightHunts — deterministic nightly spawn planning.
extends "res://tests/framework/test_case.gd"

const CoopNightHunts = preload("res://game_logic/CoopNightHunts.gd")


func test_supports_madrian() -> void:
	assert_true(CoopNightHunts.supports_map("madrian"))


func test_does_not_support_unknown_map() -> void:
	assert_false(CoopNightHunts.supports_map("infinite"))


func test_generate_hunt_empty_for_unsupported_map() -> void:
	var plan: Array[Dictionary] = CoopNightHunts.generate_hunt("dungeon_123", 5)
	assert_true(plan.is_empty())


func test_generate_hunt_is_deterministic() -> void:
	var a: Array[Dictionary] = CoopNightHunts.generate_hunt("madrian", 7)
	var b: Array[Dictionary] = CoopNightHunts.generate_hunt("madrian", 7)
	assert_eq(a.size(), b.size())
	for i in range(a.size()):
		assert_eq(str(a[i]["id"]), str(b[i]["id"]))
		assert_eq(str(a[i]["enemy_type"]), str(b[i]["enemy_type"]))
		var off_a: Vector2 = a[i]["offset"]
		var off_b: Vector2 = b[i]["offset"]
		assert_almost_eq(off_a.x, off_b.x)
		assert_almost_eq(off_a.y, off_b.y)


func test_generate_hunt_differs_across_nights() -> void:
	var night1: Array[Dictionary] = CoopNightHunts.generate_hunt("madrian", 1)
	var night2: Array[Dictionary] = CoopNightHunts.generate_hunt("madrian", 2)
	var ids1: Array = []
	for e in night1:
		ids1.append(e["id"])
	var ids2: Array = []
	for e in night2:
		ids2.append(e["id"])
	assert_ne(ids1, ids2, "different nights should have different deterministic ids")


func test_generate_hunt_ids_are_unique() -> void:
	var plan: Array[Dictionary] = CoopNightHunts.generate_hunt("madrian", 3)
	var seen: Dictionary = {}
	for entry: Dictionary in plan:
		var id: String = str(entry["id"])
		assert_false(seen.has(id), "duplicate id %s" % id)
		seen[id] = true


func test_generate_hunt_size_capped_at_hunt_size() -> void:
	var plan: Array[Dictionary] = CoopNightHunts.generate_hunt("madrian", 9)
	assert_lte(plan.size(), CoopNightHunts.HUNT_SIZE)


func test_generate_hunt_enemy_types_are_spectral() -> void:
	var plan: Array[Dictionary] = CoopNightHunts.generate_hunt("madrian", 4)
	var known: Array[String] = ["spectre_wisp", "spectre_haunt", "spectre_dread"]
	for entry: Dictionary in plan:
		assert_true(known.has(str(entry["enemy_type"])), "unexpected enemy type")


func test_party_drop_tier_bonus_solo_is_zero() -> void:
	assert_eq(CoopNightHunts.party_drop_tier_bonus(1), 0)


func test_party_drop_tier_bonus_full_party_is_positive() -> void:
	assert_gt(CoopNightHunts.party_drop_tier_bonus(4), 0)
