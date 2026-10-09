## VendorPrefs (GID-180 / TID-746): per-town favoured cards + sale bonus.
extends "res://tests/framework/test_case.gd"

const VendorPrefs = preload("res://game_logic/inventory/VendorPrefs.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")


func test_every_stitched_town_has_a_vendor_taste() -> void:
	for town: String in RealmLayout.town_names():
		assert_true(VendorPrefs.TOWNS.has(town), town)
		assert_ne(VendorPrefs.pitch(town), "")


func test_town_of_place() -> void:
	assert_eq(VendorPrefs.town_of("maykalene"), "maykalene")
	assert_eq(VendorPrefs.town_of("blancogov_temple"), "blancogov")
	assert_eq(VendorPrefs.town_of("main"), "")


func test_bonus_price() -> void:
	var rare: Dictionary = {"rarity": "rare"}
	var base: int = int(IsoConst.RARITY_CONFIG["rare"]["sell_gold"])
	assert_eq(VendorPrefs.price(rare, {"magic_type": "rift"}, "maykalene"), roundi(base * 1.25))
	assert_eq(VendorPrefs.price(rare, {"magic_type": "light"}, "maykalene"), base)
	assert_eq(VendorPrefs.price(rare, {"magic_type": "rift"}, ""), base)
	assert_true(VendorPrefs.prefers({"magic_type": ""}, "marsax_hold"))


func test_buyback_returns_the_exact_card() -> void:
	var sm := SaveManagerScript.new()
	sm.new_game()
	var uid: String = sm.add_card_instance("ghost", "rare", 9, 9)
	sm.sell_card_instance(uid, 40)
	assert_true(sm.get_instance_by_uid(uid).is_empty())
	assert_eq(int(sm.buyback_cards[0]["_sold_for"]), 40)
	var coins: int = sm.coins
	assert_true(sm.buy_back(0))
	var back: Dictionary = sm.get_instance_by_uid(uid)
	assert_eq(int(back.get("attack", 0)), 9)
	assert_false(back.has("_sold_for"))
	assert_eq(sm.coins, coins - 40)
	assert_false(sm.buy_back(0), "shelf is empty now")
	sm.free()
