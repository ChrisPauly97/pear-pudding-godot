## Unit tests for CoopSiege — deterministic wave planning for co-op Town Siege.
extends "res://tests/framework/test_case.gd"

const CoopSiege = preload("res://game_logic/CoopSiege.gd")


func test_supports_madrian() -> void:
	assert_true(CoopSiege.supports_map("madrian"))


func test_does_not_support_unsupported_map() -> void:
	assert_false(CoopSiege.supports_map("infinite"))


func test_generate_wave_empty_for_unsupported_map() -> void:
	var plan: Array[Dictionary] = CoopSiege.generate_wave("infinite", 1, 0)
	assert_true(plan.is_empty())


func test_generate_wave_is_deterministic() -> void:
	var a: Array[Dictionary] = CoopSiege.generate_wave("madrian", 42, 1)
	var b: Array[Dictionary] = CoopSiege.generate_wave("madrian", 42, 1)
	assert_eq(a.size(), b.size())
	for i in range(a.size()):
		assert_eq(str(a[i]["id"]), str(b[i]["id"]))
		assert_eq(str(a[i]["enemy_type"]), str(b[i]["enemy_type"]))


func test_generate_wave_differs_by_siege_id() -> void:
	var a: Array[Dictionary] = CoopSiege.generate_wave("madrian", 1, 0)
	var b: Array[Dictionary] = CoopSiege.generate_wave("madrian", 2, 0)
	assert_ne(a[0]["id"], b[0]["id"])


func test_generate_wave_ids_are_unique_within_wave() -> void:
	var plan: Array[Dictionary] = CoopSiege.generate_wave("madrian", 5, 2)
	var seen: Dictionary = {}
	for entry: Dictionary in plan:
		var id: String = str(entry["id"])
		assert_false(seen.has(id), "duplicate id %s" % id)
		seen[id] = true


func test_wave_enemy_count_escalates() -> void:
	var c0: int = CoopSiege.wave_enemy_count(0)
	var c1: int = CoopSiege.wave_enemy_count(1)
	var c2: int = CoopSiege.wave_enemy_count(2)
	assert_lt(c0, c1)
	assert_lt(c1, c2)


func test_wave_enemy_type_escalates_tiers() -> void:
	assert_eq(CoopSiege.wave_enemy_type(0), "martarquas_raider_1")
	assert_eq(CoopSiege.wave_enemy_type(1), "martarquas_raider_2")
	assert_eq(CoopSiege.wave_enemy_type(2), "martarquas_raider_3")


func test_wave_enemy_type_clamps_beyond_wave_count() -> void:
	# Defensive: a wave index beyond WAVE_COUNT must not throw or go out of range.
	assert_eq(CoopSiege.wave_enemy_type(10), "martarquas_raider_3")


func test_generate_wave_matches_enemy_count() -> void:
	var plan: Array[Dictionary] = CoopSiege.generate_wave("madrian", 1, 1)
	assert_eq(plan.size(), CoopSiege.wave_enemy_count(1))


func test_boss_id_deterministic_and_distinct() -> void:
	assert_eq(CoopSiege.boss_id(7), CoopSiege.boss_id(7))
	assert_ne(CoopSiege.boss_id(7), CoopSiege.boss_id(8))


func test_boss_enemy_type_is_stable() -> void:
	assert_eq(CoopSiege.boss_enemy_type(), "roaming_terror")
