## BinderOps (GID-180 / TID-739): pages, copy stacks, silhouettes.
extends "res://tests/framework/test_case.gd"

const BinderOps = preload("res://game_logic/inventory/BinderOps.gd")

var _tmpls: Dictionary = {
	"ghost": {"magic_type": "dark"},
	"spark": {"magic_type": "light"},
	"rock": {"magic_type": ""},
	"wisp": {"magic_type": "dark"},
}


func _tmpl(tid: String) -> Dictionary:
	return _tmpls.get(tid, {})


func _c(uid: String, tid: String, rarity: String, atk: int, hp: int) -> Dictionary:
	return {"uid": uid, "template_id": tid, "rarity": rarity, "attack": atk, "health": hp, "cost": 1}


func test_pages() -> void:
	assert_eq(BinderOps.page_of(_tmpl("ghost")), "dark")
	assert_eq(BinderOps.page_of(_tmpl("rock")), "neutral")
	assert_true(BinderOps.on_page(_tmpl("rock"), "all"))
	assert_false(BinderOps.on_page(_tmpl("spark"), "dark"))
	assert_eq(BinderOps.page_label("verdant"), "Verdant")


func test_stack_groups_by_template_and_rarity_best_first() -> void:
	var insts: Array[Dictionary] = [_c("a", "ghost", "common", 1, 2), _c("b", "spark", "common", 1, 1),
		_c("c", "ghost", "rare", 2, 3), _c("d", "ghost", "common", 1, 2), _c("e", "ghost", "rare", 3, 3)]
	var stacks: Array[Dictionary] = BinderOps.stack(insts, {})
	assert_eq(stacks.size(), 3)
	assert_eq(str(stacks[0]["key"]), "ghost|common")
	assert_eq((stacks[0]["copies"] as Array).size(), 2)
	assert_eq(str(stacks[2]["key"]), "ghost|rare")
	assert_eq(str((stacks[2]["best"] as Dictionary)["uid"]), "e")


func test_best_prefers_copy_in_no_deck() -> void:
	var insts: Array[Dictionary] = [_c("strong", "ghost", "rare", 5, 5), _c("weak", "ghost", "rare", 1, 1)]
	var stacks: Array[Dictionary] = BinderOps.stack(insts, {"strong": "Deck 2"})
	assert_eq(str((stacks[0]["best"] as Dictionary)["uid"]), "weak")
	assert_eq(int(stacks[0]["in_decks"]), 1)


func test_silhouettes_and_progress() -> void:
	var all_ids: Array[String] = ["ghost", "spark", "rock", "wisp"]
	var owned: Dictionary = {"ghost": true}
	assert_eq(BinderOps.missing_on_page("dark", owned, all_ids, _tmpl), ["wisp"])
	assert_eq(BinderOps.missing_on_page("all", owned, all_ids, _tmpl), [])
	assert_eq(BinderOps.page_progress("dark", owned, all_ids, _tmpl), Vector2i(1, 2))
	assert_eq(BinderOps.page_progress("all", owned, all_ids, _tmpl), Vector2i(1, 4))
