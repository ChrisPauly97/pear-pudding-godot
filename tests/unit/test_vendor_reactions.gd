## VendorReactions (GID-180 / TID-745).
extends "res://tests/framework/test_case.gd"

const VendorReactions = preload("res://game_logic/inventory/VendorReactions.gd")


func test_priority() -> void:
	var common: Dictionary = {"rarity": "common"}
	assert_eq(VendorReactions.reaction_for({"rarity": "rare"}, {"perfect": true}), "perfect")
	assert_eq(VendorReactions.reaction_for({"rarity": "legendary"}, {"preferred": true}), "legendary")
	assert_eq(VendorReactions.reaction_for(common, {"preferred": true, "copies_sold": 3}), "preferred")
	assert_eq(VendorReactions.reaction_for(common, {"veteran": true}), "veteran")
	assert_eq(VendorReactions.reaction_for(common, {"copies_sold": 1}), "duplicate")
	assert_eq(VendorReactions.reaction_for(common, {}), "plain")


func test_lines() -> void:
	assert_true(VendorReactions.line("duplicate", 0, "Ghost").contains("Ghost"))
	assert_ne(VendorReactions.line("plain", 0), VendorReactions.line("plain", 1))
	assert_ne(VendorReactions.line("nope", 0), "", "unknown ids fall back to plain")
