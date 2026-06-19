## Unit tests for mimic chest system (TID-209).
##
## Validates mimic assignment in DungeonGen, EnemyRegistry mimic data,
## and find_chest_by_id() helper.
extends "res://tests/framework/test_case.gd"

const DungeonGen = preload("res://game_logic/world/DungeonGen.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const WorldMapScript = preload("res://game_logic/world/WorldMap.gd")


func _gen(seed_val: int) -> RefCounted:
	return DungeonGen.generate("test_mimic_%d" % seed_val, seed_val)


# ---------------------------------------------------------------------------
# EnemyRegistry mimic data
# ---------------------------------------------------------------------------

func test_mimic_registry_has_deck() -> void:
	var deck: Array[String] = EnemyRegistry.get_deck("mimic")
	assert_true(deck.size() >= 4, "mimic deck should have at least 4 cards")


func test_mimic_registry_has_drop_pool() -> void:
	var pool: Array[String] = EnemyRegistry.get_drop_pool("mimic")
	assert_true(pool.size() >= 1, "mimic drop pool should not be empty")


func test_mimic_registry_coin_reward() -> void:
	var coins: int = EnemyRegistry.get_coin_reward("mimic")
	assert_true(coins > 0, "mimic should give coin reward > 0")


func test_mimic_registry_difficulty_tier() -> void:
	var tier: int = EnemyRegistry.get_difficulty_tier("mimic")
	assert_true(tier >= 2, "mimic difficulty should be tier 2 or higher")


func test_mimic_registry_not_boss() -> void:
	assert_false(EnemyRegistry.get_is_boss("mimic"), "mimic should not be flagged as a boss")


# ---------------------------------------------------------------------------
# DungeonGen mimic seeding
# ---------------------------------------------------------------------------

func test_some_dungeon_chests_are_mimics() -> void:
	# Run several seeds; at 15% chance at least one should produce a mimic
	var found_mimic: bool = false
	for seed_val in range(0, 50):
		var map: RefCounted = _gen(seed_val)
		for chest in map.chests:
			if bool(chest.get("is_mimic", false)):
				found_mimic = true
				break
		if found_mimic:
			break
	assert_true(found_mimic, "at least one seed among 0-49 should produce a mimic chest")


func test_mimic_chests_not_opened_initially() -> void:
	for seed_val in range(0, 20):
		var map: RefCounted = _gen(seed_val)
		for chest in map.chests:
			if bool(chest.get("is_mimic", false)):
				assert_false(bool(chest.get("opened", false)),
					"mimic chest should start closed (seed %d)" % seed_val)


func test_mimic_chests_have_card_ids() -> void:
	for seed_val in range(0, 30):
		var map: RefCounted = _gen(seed_val)
		for chest in map.chests:
			if bool(chest.get("is_mimic", false)):
				assert_true(chest.get("card_ids", []).size() >= 1,
					"mimic chest should contain card_ids")
				return


func test_dungeon_mimic_determinism() -> void:
	var map1: RefCounted = _gen(42)
	var map2: RefCounted = _gen(42)
	assert_eq(map1.chests.size(), map2.chests.size(),
		"same seed should produce same chest count")
	for i in range(map1.chests.size()):
		var is_mimic1: bool = bool(map1.chests[i].get("is_mimic", false))
		var is_mimic2: bool = bool(map2.chests[i].get("is_mimic", false))
		assert_eq(is_mimic1, is_mimic2,
			"chest %d mimic flag should be identical for same seed" % i)


# ---------------------------------------------------------------------------
# WorldMap.find_chest_by_id()
# ---------------------------------------------------------------------------

func test_find_chest_by_id_returns_correct_chest() -> void:
	var map: RefCounted = _gen(12345)
	if map.chests.is_empty():
		return
	var first_id: String = str(map.chests[0].get("id", ""))
	var found: Dictionary = map.find_chest_by_id(first_id)
	assert_false(found.is_empty(), "find_chest_by_id should find existing chest")
	assert_eq(str(found.get("id", "")), first_id, "returned chest should have matching id")


func test_find_chest_by_id_returns_empty_for_missing() -> void:
	var map: RefCounted = _gen(12345)
	var found: Dictionary = map.find_chest_by_id("nonexistent_chest_id_xyz")
	assert_true(found.is_empty(), "find_chest_by_id should return empty for unknown id")


func test_find_chest_by_id_reflects_mutation() -> void:
	var map: RefCounted = _gen(12345)
	if map.chests.is_empty():
		return
	var cid: String = str(map.chests[0].get("id", ""))
	var chest: Dictionary = map.find_chest_by_id(cid)
	chest["opened"] = true
	var chest2: Dictionary = map.find_chest_by_id(cid)
	assert_true(bool(chest2.get("opened", false)),
		"mutations to the returned dict should be reflected in WorldMap.chests")
