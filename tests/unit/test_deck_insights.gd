## Unit tests for DeckInsights (GID-180 / TID-736): deck name, crest,
## synergy pairs, mana curve, roll quality and upgrade comparison.
extends "res://tests/framework/test_case.gd"

const DeckInsights = preload("res://game_logic/inventory/DeckInsights.gd")

var _t: Dictionary = {
	"bone": {"attack": 2, "health": 2, "cost": 1, "card_class": "minion", "magic_branch": "ash",
		"keywords": PackedStringArray()},
	"rot": {"attack": 0, "health": 0, "cost": 2, "card_class": "spell", "magic_branch": "ash",
		"keywords": PackedStringArray()},
	"wall": {"attack": 1, "health": 10, "cost": 3, "card_class": "minion", "magic_branch": "dawn",
		"keywords": PackedStringArray(["ward"])},
	"shield": {"attack": 2, "health": 6, "cost": 2, "card_class": "minion", "magic_branch": "",
		"keywords": PackedStringArray(["ward"])},
	"titan": {"attack": 8, "health": 8, "cost": 7, "card_class": "minion", "magic_branch": "",
		"keywords": PackedStringArray()},
}


func _c(uid: String, tid: String, rarity: String = "common", atk: int = -1, hp: int = -1) -> Dictionary:
	var t: Dictionary = _t[tid]
	return {"uid": uid, "template_id": tid, "rarity": rarity,
		"attack": atk if atk >= 0 else int(t["attack"]), "health": hp if hp >= 0 else int(t["health"]),
		"cost": int(t["cost"])}


func test_empty_deck() -> void:
	assert_eq(DeckInsights.deck_name([], _t), "Empty Deck")
	assert_eq(DeckInsights.mana_curve([], _t), [0, 0, 0, 0, 0, 0, 0, 0])


func test_swarm_name_from_dominant_branch() -> void:
	var deck: Array = [_c("a", "bone"), _c("b", "bone"), _c("c", "rot"), _c("d", "bone")]
	assert_eq(DeckInsights.dominant_branch(deck, _t), "ash")
	assert_eq(DeckInsights.deck_name(deck, _t), "Bone-Choir Swarm")
	var crest: Dictionary = DeckInsights.crest(deck, _t)
	assert_eq(str(crest["glyph"]), "swarm")
	assert_eq(str(crest["rarity"]), "common")


func test_archetypes() -> void:
	assert_eq(DeckInsights.archetype([_c("a", "titan"), _c("b", "titan")], _t), "titans")
	assert_eq(DeckInsights.archetype([_c("a", "wall"), _c("b", "bone"), _c("c", "titan")], _t), "bulwark")
	assert_eq(DeckInsights.deck_name([_c("a", "titan")], _t), "Wanderer's Titans")


func test_curve_clamps_high_costs() -> void:
	var curve: Array[int] = DeckInsights.mana_curve([_c("a", "bone"), _c("b", "titan"),
		{"uid": "x", "template_id": "titan", "cost": 12}], _t)
	assert_eq(curve[1], 1)
	assert_eq(curve[7], 2)


func test_synergy_keyword_before_branch_and_one_per_template_pair() -> void:
	var deck: Array = [_c("a", "bone"), _c("a2", "bone"), _c("b", "rot"), _c("w", "wall"), _c("s", "shield")]
	var pairs: Array[Dictionary] = DeckInsights.synergy_pairs(deck, _t)
	assert_eq(pairs.size(), 2)
	assert_eq(str(pairs[0]["kind"]), "keyword")
	assert_eq(str(pairs[0]["tag"]), "ward")
	assert_eq(str(pairs[1]["kind"]), "branch")
	assert_eq(str(pairs[1]["a"]), "a")
	assert_eq(str(pairs[1]["b"]), "b")


func test_roll_quality_and_perfect_roll() -> void:
	# wall rare: health 10 × 1.3 ± 8 % → 12..14; attack 1 × 1.3 → 1..1 (no range).
	var low: Dictionary = _c("l", "wall", "rare", 1, 12)
	var top: Dictionary = _c("t", "wall", "rare", 1, 14)
	assert_true(DeckInsights.has_roll_range(top, _t))
	assert_eq(DeckInsights.roll_quality(low, _t), 0.0)
	assert_eq(DeckInsights.roll_quality(top, _t), 1.0)
	assert_true(DeckInsights.is_perfect_roll(top, _t))
	assert_false(DeckInsights.is_perfect_roll(low, _t))
	# Commons never vary, so never "perfect".
	assert_false(DeckInsights.is_perfect_roll(_c("c", "wall"), _t))


func test_compare_and_upgrade() -> void:
	var in_deck: Array = [_c("d1", "wall", "rare", 1, 12), _c("d2", "wall", "rare", 1, 14), _c("b", "bone")]
	var better: Dictionary = _c("n", "wall", "rare", 1, 13)
	assert_eq(str(DeckInsights.replace_target(better, in_deck)["uid"]), "d1")
	assert_true(DeckInsights.is_upgrade(better, in_deck))
	assert_false(DeckInsights.is_upgrade(_c("n2", "wall", "rare", 1, 12), in_deck))
	assert_false(DeckInsights.is_upgrade(in_deck[0], in_deck), "a deck card is not an upgrade over itself")
	assert_false(DeckInsights.is_upgrade(_c("t", "titan"), in_deck), "no twin in deck")
	assert_true(DeckInsights.is_upgrade(_c("e", "bone", "epic"), in_deck), "higher rarity wins")
	var d: Dictionary = DeckInsights.compare(better, in_deck[0])
	assert_eq(int(d["health"]), 1)
	assert_eq(int(d["attack"]), 0)
