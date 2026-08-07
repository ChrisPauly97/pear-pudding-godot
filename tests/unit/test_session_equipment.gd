## Unit tests for the session-scoped equipment inventory (BID-033): the
## SaveManager.adopt_session_character / export_session_character round-trip for the
## new owned_weapons/owned_armor/equipped_weapon/equipped_armor fields, and the pure
## LootRoll.roll_equipment_drop chest-loot-roll logic. Mirrors test_weapon_upgrades.gd's
## SaveManagerScript.new() instance pattern and test_loot_roll.gd's seeded-RNG pattern.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const LootRoll = preload("res://game_logic/net/LootRoll.gd")

var _sm: Node


func before_each() -> void:
	_sm = SaveManagerScript.new()


func after_each() -> void:
	_sm.free()


static func _seeded_rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng


# ---------------------------------------------------------------------------
# adopt_session_character — equipment fields
# ---------------------------------------------------------------------------

func test_adopt_session_character_loads_owned_weapons_as_instances() -> void:
	_sm.adopt_session_character({
		"owned_weapons": ["berserker_axe", "dusk_blade"],
		"owned_armor": ["chainmail"],
		"equipped_weapon": "berserker_axe",
		"equipped_armor": "chainmail",
	})
	var ids: Array[String] = _sm.get_owned_by_slot("weapon")
	assert_true(ids.has("berserker_axe"))
	assert_true(ids.has("dusk_blade"))
	assert_eq(ids.size(), 2)
	# Each instance starts at upgrade_level 0 — the session shape carries no per-
	# instance upgrade data (documented simplification).
	assert_eq(int(_sm.get_owned_weapon_by_id("berserker_axe").get("upgrade_level", -1)), 0)
	assert_eq(_sm.owned_armor, ["chainmail"])
	assert_eq(_sm.equipped_weapon, "berserker_axe")
	assert_eq(_sm.equipped_armor, "chainmail")


func test_adopt_session_character_defaults_equipment_to_empty_when_absent() -> void:
	# A record from before BID-033 (or a starter with no gear yet) has none of these
	# keys at all — adopt must not crash and must leave a clean empty state.
	var stale_weapons: Array[Dictionary] = [{"weapon_id": "stale_weapon", "upgrade_level": 3}]
	_sm.owned_weapons = stale_weapons
	var stale_armor: Array[String] = ["stale_armor"]
	_sm.owned_armor = stale_armor
	_sm.equipped_weapon = "stale_weapon"
	_sm.equipped_armor = "stale_armor"
	_sm.adopt_session_character({"coins": 10})
	assert_eq(_sm.owned_weapons.size(), 0, "prior in-memory weapons cleared, not merged")
	assert_eq(_sm.owned_armor.size(), 0, "prior in-memory armor cleared, not merged")
	assert_eq(_sm.equipped_weapon, "")
	assert_eq(_sm.equipped_armor, "")


func test_adopt_session_character_dedupes_repeated_weapon_ids() -> void:
	_sm.adopt_session_character({"owned_weapons": ["dusk_blade", "dusk_blade"]})
	assert_eq(_sm.get_owned_by_slot("weapon").size(), 1, "a duplicate id in the record must not create two instances")


func test_adopt_session_character_ignores_blank_ids() -> void:
	_sm.adopt_session_character({"owned_weapons": ["", "dusk_blade"], "owned_armor": ["", "chainmail"]})
	assert_eq(_sm.get_owned_by_slot("weapon"), ["dusk_blade"])
	assert_eq(_sm.owned_armor, ["chainmail"])


func test_adopt_session_character_forces_unloaded_for_equipment_too() -> void:
	# The isolation invariant (no session data can leak to save_slot_*.json) must hold
	# regardless of which fields were populated.
	_sm._loaded = true
	_sm.adopt_session_character({"owned_weapons": ["dusk_blade"]})
	assert_false(_sm._loaded)


# ---------------------------------------------------------------------------
# export_session_character — equipment fields (mirror image of adopt)
# ---------------------------------------------------------------------------

func test_export_session_character_flattens_owned_weapons_to_ids() -> void:
	_sm._loaded = true
	_sm.add_weapon("dusk_blade")
	_sm.add_equipment("chainmail", "armor")
	_sm.equip_weapon("dusk_blade")
	_sm.equip_item("chainmail", "armor")
	var rec: Dictionary = _sm.export_session_character()
	assert_eq(rec.get("owned_weapons", []), ["dusk_blade"])
	assert_eq(rec.get("owned_armor", []), ["chainmail"])
	assert_eq(str(rec.get("equipped_weapon", "")), "dusk_blade")
	assert_eq(str(rec.get("equipped_armor", "")), "chainmail")


func test_export_session_character_empty_equipment_by_default() -> void:
	var rec: Dictionary = _sm.export_session_character()
	assert_eq(rec.get("owned_weapons", ["x"]), [])
	assert_eq(rec.get("owned_armor", ["x"]), [])
	assert_eq(str(rec.get("equipped_weapon", "x")), "")
	assert_eq(str(rec.get("equipped_armor", "x")), "")


# ---------------------------------------------------------------------------
# Round trip: export -> adopt -> export is stable
# ---------------------------------------------------------------------------

func test_export_adopt_export_round_trip_is_stable() -> void:
	_sm._loaded = true
	_sm.add_weapon("berserker_axe")
	_sm.add_weapon("dusk_blade")
	_sm.add_equipment("chainmail", "armor")
	_sm.equip_weapon("berserker_axe")
	var exported: Dictionary = _sm.export_session_character()

	var sm2: Node = SaveManagerScript.new()
	sm2.adopt_session_character(exported)
	var reexported: Dictionary = sm2.export_session_character()
	sm2.free()

	assert_eq(reexported.get("owned_weapons", []), exported.get("owned_weapons", []))
	assert_eq(reexported.get("owned_armor", []), exported.get("owned_armor", []))
	assert_eq(reexported.get("equipped_weapon", ""), exported.get("equipped_weapon", ""))
	assert_eq(reexported.get("equipped_armor", ""), exported.get("equipped_armor", ""))


# ---------------------------------------------------------------------------
# LootRoll.roll_equipment_drop — pure chest-loot-roll equipment logic (BID-033)
# ---------------------------------------------------------------------------

func test_roll_equipment_drop_treasure_room_chance_is_higher_than_default() -> void:
	assert_true(LootRoll.EQUIPMENT_CHANCE_TREASURE_ROOM > LootRoll.EQUIPMENT_CHANCE_DEFAULT)


func test_roll_equipment_drop_never_returns_already_owned_id() -> void:
	var weapon_ids: Array = ["berserker_axe", "dusk_blade"]
	var armor_ids: Array = ["chainmail"]
	var owned_weapons: Array = ["berserker_axe", "dusk_blade"]
	var owned_armor: Array = []
	# Chance is high enough (tier 3) that across many seeds we'd see a hit if the
	# exclusion were broken; every result must be "" or the one remaining armor id.
	for seed_val in range(40):
		var picked: String = LootRoll.roll_equipment_drop(
			3, weapon_ids, armor_ids, owned_weapons, owned_armor, _seeded_rng(seed_val))
		assert_true(picked == "" or picked == "chainmail",
			"picked %s at seed %d must be empty or the one unowned candidate" % [picked, seed_val])


func test_roll_equipment_drop_excludes_rusty_dagger() -> void:
	var weapon_ids: Array = ["rusty_dagger"]
	var armor_ids: Array = []
	for seed_val in range(40):
		var picked: String = LootRoll.roll_equipment_drop(
			3, weapon_ids, armor_ids, [], [], _seeded_rng(seed_val))
		assert_eq(picked, "", "rusty_dagger must never be offered as a chest drop")


func test_roll_equipment_drop_returns_empty_when_pool_exhausted() -> void:
	var weapon_ids: Array = ["dusk_blade"]
	var armor_ids: Array = ["chainmail"]
	var owned_weapons: Array = ["dusk_blade"]
	var owned_armor: Array = ["chainmail"]
	for seed_val in range(20):
		var picked: String = LootRoll.roll_equipment_drop(
			3, weapon_ids, armor_ids, owned_weapons, owned_armor, _seeded_rng(seed_val))
		assert_eq(picked, "", "every candidate already owned -> always empty")


func test_roll_equipment_drop_deterministic_for_same_seed() -> void:
	var weapon_ids: Array = ["berserker_axe", "dusk_blade", "ember_wand"]
	var armor_ids: Array = ["chainmail", "leather_vest"]
	var a: String = LootRoll.roll_equipment_drop(3, weapon_ids, armor_ids, [], [], _seeded_rng(11))
	var b: String = LootRoll.roll_equipment_drop(3, weapon_ids, armor_ids, [], [], _seeded_rng(11))
	assert_eq(a, b)


func test_roll_equipment_drop_default_tier_uses_default_chance() -> void:
	# tier != 3 must use EQUIPMENT_CHANCE_DEFAULT, not the treasure-room rate — proven
	# indirectly: over many seeds, the hit rate for tier 1 must be lower than tier 3's,
	# well outside noise for this many trials.
	var weapon_ids: Array = ["berserker_axe", "dusk_blade", "ember_wand", "dawn_staff"]
	var armor_ids: Array = ["chainmail", "leather_vest", "warded_cloak"]
	var hits_tier3 := 0
	var hits_tier1 := 0
	var trials := 300
	for seed_val in range(trials):
		if LootRoll.roll_equipment_drop(3, weapon_ids, armor_ids, [], [], _seeded_rng(seed_val)) != "":
			hits_tier3 += 1
		if LootRoll.roll_equipment_drop(1, weapon_ids, armor_ids, [], [], _seeded_rng(seed_val + 100000)) != "":
			hits_tier1 += 1
	assert_true(hits_tier3 > hits_tier1,
		"tier-3 hit rate (%d/%d) should exceed tier-1 hit rate (%d/%d) over %d trials"
			% [hits_tier3, trials, hits_tier1, trials, trials])
