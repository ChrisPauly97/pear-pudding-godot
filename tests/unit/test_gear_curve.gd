## GID-187 / TID-789: the gear curve — bands, stat budget, and every authored item on the curve.
extends "res://tests/framework/test_case.gd"

const GearCurve = preload("res://game_logic/items/GearCurve.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")

func _item(band: String, il: int, slot: String, stats: Dictionary, rarity: String = "common") -> WeaponData:
	var w := WeaponData.new()
	w.id = "t_item"
	w.band = band
	w.item_level = il
	w.level_req = il
	w.slot = slot
	w.stats = stats
	w.rarity = rarity
	return w

func _on_budget(il: int, slot: String, rarity: String = "common") -> int:
	return roundi(GearCurve.budget(il, slot, rarity))

func test_every_registered_item_is_on_the_curve() -> void:
	var ids: Array[String] = WeaponRegistry.get_all_ids()
	assert_gt(ids.size(), 0, "registry lists items")
	for id: Variant in ids:
		var w: WeaponData = WeaponRegistry.get_weapon(str(id))
		var problems: Array[String] = GearCurve.validate(w)
		assert_eq(problems.size(), 0, str(problems))

func test_bands_cover_every_level_once() -> void:
	var prev: int = 0
	for b: Array in GearCurve.BANDS:
		assert_eq(int(b[1]), prev + 1, str(b))
		prev = int(b[2])
	assert_eq(prev, 60)
	assert_eq(str(GearCurve.band_for_level(25)[0]), "superior")

func test_budget_grows_with_item_level_rarity_and_slot() -> void:
	assert_gt(GearCurve.budget(30, "armor"), GearCurve.budget(10, "armor"))
	assert_gt(GearCurve.budget(10, "armor", "epic"), GearCurve.budget(10, "armor"))
	assert_gt(GearCurve.budget(10, "armor"), GearCurve.budget(10, "ring"))

func test_basic_items_are_one_primary_stat() -> void:
	assert_eq(GearCurve.validate(_item("basic", 5, "armor", {"stamina": _on_budget(5, "armor")})).size(), 0)
	var with_haste := _item("basic", 5, "armor", {"stamina": _on_budget(5, "armor") - 2, "haste": 2})
	assert_eq(GearCurve.validate(with_haste).size(), 1, "Basic has no secondaries")
	var two_primary := _item("basic", 5, "armor", {"stamina": 6, "armor": 3})
	assert_eq(GearCurve.validate(two_primary).size(), 1)

func test_school_stats_open_at_superior() -> void:
	var b: int = _on_budget(15, "helmet")
	assert_eq(GearCurve.validate(_item("fine", 15, "helmet", {"stamina": b - 4, "haste": 4})).size(), 0)
	assert_eq(GearCurve.validate(_item("fine", 15, "helmet", {"stamina": b - 5, "mastery:dark": 6})).size(), 1)
	var s: int = _on_budget(25, "helmet")
	assert_eq(GearCurve.validate(_item("superior", 25, "helmet", {"stamina": s - 9, "haste": 5,
		"mastery:dark": 5})).size(), 0)

func test_budget_tolerance_both_ways() -> void:
	var b: int = _on_budget(20, "armor")
	assert_eq(GearCurve.validate(_item("superior", 20, "armor", {"stamina": b * 2})).size(), 1, "over")
	assert_eq(GearCurve.validate(_item("superior", 20, "armor", {"stamina": b / 3})).size(), 1, "under")

func test_upgrades_scale_stats() -> void:
	var w := _item("basic", 5, "weapon", {"stamina": 10})
	assert_eq(int(UpgradeDefs.scaled_stats(w, 0)["stamina"]), 10)
	assert_eq(int(UpgradeDefs.scaled_stats(w, 5)["stamina"]), 15)
	assert_eq(UpgradeDefs.get_display_string(w, 0), "+10 Stamina")
