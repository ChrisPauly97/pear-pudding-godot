## DeckBarkRules (GID-180 / TID-744): Maiteln's deck-builder comments.
extends "res://tests/framework/test_case.gd"

const DeckBarkRules = preload("res://game_logic/inventory/DeckBarkRules.gd")

var _t: Dictionary = {
	"imp": {"card_class": "minion", "keywords": PackedStringArray()},
	"bolt": {"card_class": "spell", "keywords": PackedStringArray()},
	"giant": {"card_class": "minion", "keywords": PackedStringArray()},
}


func _deck(spec: Array) -> Array:
	var out: Array = []
	for i in range(spec.size()):
		var s: Array = spec[i]
		out.append({"uid": "u%d" % i, "template_id": s[0], "rarity": "common", "attack": 1, "health": 1,
			"cost": int(s[1])})
	return out


func test_every_order_id_has_a_line() -> void:
	for id: String in DeckBarkRules.ORDER:
		assert_ne(DeckBarkRules.text_for(id), "", id)


func test_small_deck_only_says_too_small() -> void:
	assert_eq(DeckBarkRules.candidates(_deck([["imp", 1]]), [], _t), ["too_small"])


func test_top_heavy_and_no_early() -> void:
	var d: Array = _deck([["giant", 6], ["giant", 6], ["giant", 7], ["giant", 5], ["bolt", 4], ["imp", 3],
		["imp", 2], ["imp", 3]])
	var c: Array[String] = DeckBarkRules.candidates(d, [], _t)
	assert_true(c.has("top_heavy"))
	assert_true(c.has("no_early"))
	assert_false(c.has("no_spells"))


func test_no_spells_and_upgrade() -> void:
	var d: Array = _deck([["imp", 1], ["imp", 1], ["imp", 2], ["imp", 2], ["imp", 1], ["imp", 1], ["imp", 2],
		["imp", 3]])
	var bag: Array = [{"uid": "b", "template_id": "imp", "rarity": "epic", "attack": 3, "health": 3, "cost": 1}]
	var c: Array[String] = DeckBarkRules.candidates(d, bag, _t)
	assert_true(c.has("no_spells"))
	assert_true(c.has("upgrade"))


func test_rate_limit_and_no_repeat() -> void:
	var c: Array[String] = ["top_heavy", "no_early"]
	assert_eq(DeckBarkRules.next_bark(c, "", 1.0), "", "too soon")
	assert_eq(DeckBarkRules.next_bark(c, "", 10.0), "top_heavy")
	assert_eq(DeckBarkRules.next_bark(c, "top_heavy", 10.0), "no_early")
	assert_eq(DeckBarkRules.next_bark(["top_heavy"] as Array[String], "top_heavy", 10.0), "")


func test_eligibility() -> void:
	assert_true(DeckBarkRules.is_eligible("", false))
	assert_true(DeckBarkRules.is_eligible("maiteln", true))
	assert_false(DeckBarkRules.is_eligible("", true))
