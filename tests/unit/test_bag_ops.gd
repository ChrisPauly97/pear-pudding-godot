## BagOps (GID-144): the backpack's sort orders, search and the "Extras" pick.
## Extras feeds a bulk sell/scrap, so a wrong pick destroys cards the player
## wanted — the deck, best-copy and protection rules are asserted here.
extends "res://tests/framework/test_case.gd"

const BagOps = preload("res://game_logic/inventory/BagOps.gd")

var _tmpls: Dictionary = {
	"ghost": {"name": "Ghost", "description": "A restless shade.", "keywords": PackedStringArray(["ward"])},
	"zombie": {"name": "Zombie", "description": "Slow but sure."},
	"relic": {"name": "Relic", "is_unique": true},
}


func _tmpl(tid: String) -> Dictionary:
	return _tmpls.get(tid, {})


func _inst(uid: String, tid: String, rarity: String = "common", atk: int = 1, hp: int = 1,
		cost: int = 1) -> Dictionary:
	return {"uid": uid, "template_id": tid, "rarity": rarity, "attack": atk, "health": hp, "cost": cost}


func test_extras_keep_best_copy_and_skip_decks() -> void:
	var insts: Array[Dictionary] = [
		_inst("g1", "ghost", "common", 1, 1),
		_inst("g2", "ghost", "rare", 2, 2),
		_inst("g3", "ghost", "common", 1, 2),
		_inst("z1", "zombie"),
		_inst("z2", "zombie"),
	]
	var picks: Array[String] = BagOps.pick_extras(insts, {"z2": "Deck 2"}, _tmpl)
	assert_false(picks.has("g2"), "the best (rare) ghost is kept")
	assert_true(picks.has("g1") and picks.has("g3"), "lesser ghosts are extras")
	assert_false(picks.has("z2"), "a card in a deck is never picked")
	assert_true(picks.has("z1"), "the spare zombie is an extra (%s)" % [picks])


func test_extras_skip_protected_copies() -> void:
	var renamed := _inst("g2", "ghost")
	renamed["custom_name"] = "Boo"
	var veteran := _inst("g3", "ghost")
	veteran["kills"] = 99
	var insts: Array[Dictionary] = [_inst("g1", "ghost", "rare"), renamed, veteran,
			_inst("r1", "relic"), _inst("r2", "relic")]
	var picks: Array[String] = BagOps.pick_extras(insts, {}, _tmpl)
	assert_eq(picks.size(), 0, "renamed, veteran and unique copies are protected (%s)" % [picks])


func test_sort_orders() -> void:
	var insts: Array[Dictionary] = [_inst("a", "zombie", "common", 1, 1, 4), _inst("b", "ghost", "epic", 5, 5, 2),
			_inst("c", "ghost", "common", 1, 1, 1)]
	BagOps.sort_instances(insts, "name", _tmpl)
	assert_eq(str(insts[0]["uid"]), "b", "name sort: Ghost first, best rarity first")
	BagOps.sort_instances(insts, "cost", _tmpl)
	assert_eq(str(insts[0]["uid"]), "c", "cost sort: cheapest first")
	BagOps.sort_instances(insts, "power", _tmpl)
	assert_eq(str(insts[0]["uid"]), "b", "power sort: strongest first")
	var seq: Array[Dictionary] = [_inst("old", "ghost"), _inst("new", "ghost")]
	BagOps.sort_instances(seq, "newest", _tmpl)
	assert_eq(str(seq[0]["uid"]), "new", "newest sort: last acquired first")
	var mode: String = "name"
	for i in range(BagOps.SORT_MODES.size()):
		mode = BagOps.next_sort(mode)
	assert_eq(mode, "name", "sort cycle wraps")


func test_search_matches_name_text_and_keywords() -> void:
	assert_true(BagOps.matches_search(_tmpl("ghost"), ""), "empty query matches")
	assert_true(BagOps.matches_search(_tmpl("ghost"), "GHO"), "name, case-insensitive")
	assert_true(BagOps.matches_search(_tmpl("ghost"), "restless"), "description")
	assert_true(BagOps.matches_search(_tmpl("ghost"), "ward"), "keyword")
	assert_false(BagOps.matches_search(_tmpl("zombie"), "ward"), "no false hits")


func test_deck_membership_and_value() -> void:
	var loadouts: Array = [{"name": "Main", "cards": ["a"]}, {"name": "Aggro", "cards": ["b"]}]
	var m: Dictionary = BagOps.deck_membership(loadouts, ["c"], 0, "this deck")
	assert_eq(str(m.get("b", "")), "Aggro", "other loadouts are named")
	assert_eq(str(m.get("c", "")), "this deck", "working deck replaces the active loadout")
	assert_false(m.has("a"), "the saved active loadout is superseded by the working deck")
	var v: Dictionary = BagOps.bulk_value([_inst("x", "ghost", "common"), _inst("y", "ghost", "rare")])
	assert_eq(int(v["gold"]), 20)
	assert_eq(int(v["essence"]), 20)
