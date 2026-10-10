# Unit tests for enemy material drops (GID-182 / TID-761).
extends "res://tests/framework/test_case.gd"

const MaterialDrops = preload("res://game_logic/professions/MaterialDrops.gd")
const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const HeroVitality = preload("res://game_logic/HeroVitality.gd")


func _rolls(seed_value: int, enemy_type: String, tier: int, count: int, allowed: bool = true) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	for i: int in count:
		out.append(MaterialDrops.roll(enemy_type, tier, rng, allowed))
	return out


func _total(rolls: Array) -> int:
	var total: int = 0
	for drops: Variant in rolls:
		for id: String in (drops as Dictionary):
			total += int((drops as Dictionary)[id])
	return total


func test_seeded_rolls_repeat() -> void:
	assert_eq(_rolls(7, "wolf_pack", 2, 60), _rolls(7, "wolf_pack", 2, 60), "same seed, same loot")
	assert_eq(_rolls(8, "spectre_wisp", 3, 60), _rolls(8, "spectre_wisp", 3, 60))


func test_family_mapping() -> void:
	assert_eq(MaterialDrops.family_of("wolf_pack"), MaterialDrops.FAMILY_BEAST)
	assert_eq(MaterialDrops.family_of("spectre_wisp"), MaterialDrops.FAMILY_MAGICAL)
	assert_eq(MaterialDrops.family_of("undead_basic"), "", "undead drop nothing")
	assert_eq(MaterialDrops.family_of("training_dummy"), "")
	assert_eq(MaterialDrops.family_of(""), "")


func test_beasts_drop_meat_and_hide_magic_drops_cores() -> void:
	var beast_ids: Dictionary = {}
	var magic_ids: Dictionary = {}
	for drops: Variant in _rolls(3, "sand_stalker", 4, 200):
		for id: String in (drops as Dictionary):
			beast_ids[id] = true
	for drops: Variant in _rolls(3, "bog_hag", 4, 200):
		for id: String in (drops as Dictionary):
			magic_ids[id] = true
	assert_true(beast_ids.has("game_meat"))
	assert_true(beast_ids.has("rough_hide"))
	assert_false(beast_ids.has("arcane_core"), "beasts never drop cores")
	assert_eq(magic_ids.keys(), ["arcane_core"], "magical foes drop only cores")


func test_every_mapped_enemy_exists_and_every_material_is_real() -> void:
	var known: Array[String] = EnemyRegistry.get_all_enemy_ids()
	for enemy_type: String in MaterialDrops.FAMILY_BY_ENEMY:
		assert_true(known.has(enemy_type), "%s is a real enemy" % enemy_type)
	for family: String in MaterialDrops.TABLES:
		for entry: Variant in MaterialDrops.TABLES[family]:
			assert_true(ProfessionDefs.MATERIALS.has(str((entry as Dictionary)["material"])))


func test_higher_tiers_drop_more() -> void:
	var low: int = _total(_rolls(99, "wolf_pack", 1, 2000))
	var high: int = _total(_rolls(99, "wolf_pack", 4, 2000))
	assert_true(high > low, "tier 4 (%d) beats tier 1 (%d)" % [high, low])


func test_tier_is_clamped() -> void:
	assert_eq(_rolls(5, "wraith", 0, 40), _rolls(5, "wraith", 1, 40), "below 1 reads as tier 1")
	assert_eq(_rolls(5, "wraith", 9, 40), _rolls(5, "wraith", 4, 40), "above 4 reads as tier 4")


func test_excluded_fights_drop_nothing() -> void:
	assert_eq(_total(_rolls(11, "wolf_pack", 4, 200, false)), 0, "practice / duel / puzzle fights")
	assert_eq(_total(_rolls(11, "spectre_dread", 4, 200, false)), 0)
	# The caller's exclusion mirrors HeroVitality.carries_over.
	assert_false(HeroVitality.carries_over({"enemy_type": "training_dummy"}, false, false, false))
	assert_false(HeroVitality.carries_over({"enemy_type": "wolf_pack"}, false, false, true), "friendly duel")


func test_roll_into_skips_duels_and_practice_and_stacks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var duel_bag: Dictionary = {}
	for i: int in 50:
		MaterialDrops.roll_into(duel_bag, {"enemy_type": "wolf_pack", "duel_npc_id": "npc_a"}, "wolf_pack", 4, rng)
	assert_true(duel_bag.is_empty(), "a friendly duel drops nothing")
	var practice_bag: Dictionary = {}
	MaterialDrops.roll_into(practice_bag, {"enemy_type": "training_dummy"}, "training_dummy", 4, rng)
	assert_true(practice_bag.is_empty(), "practice drops nothing")
	var bag: Dictionary = {}
	for i: int in 50:
		MaterialDrops.roll_into(bag, {"enemy_type": "wolf_pack"}, "wolf_pack", 4, rng)
	assert_true(int(bag.get("game_meat", 0)) > 0, "fights stack into one bag")


func test_unmapped_enemy_drops_nothing() -> void:
	assert_true(MaterialDrops.roll("undead_basic", 4, RandomNumberGenerator.new()).is_empty())


func test_describe() -> void:
	assert_eq(MaterialDrops.describe({}), "")
	assert_eq(MaterialDrops.describe({"arcane_core": 2}), "+2 Arcane Core")
