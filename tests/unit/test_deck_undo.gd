## DeckUndo (GID-180 / TID-737): auto-saved deck edits stay reversible.
extends "res://tests/framework/test_case.gd"

const DeckUndo = preload("res://game_logic/inventory/DeckUndo.gd")


func _deck(uids: Array) -> Array[String]:
	var d: Array[String] = []
	d.assign(uids)
	return d


func test_push_pop_order() -> void:
	var u: DeckUndo = DeckUndo.new()
	assert_false(u.can_undo())
	u.push(_deck(["a"]))
	u.push(_deck(["a", "b"]))
	assert_eq(u.pop(), _deck(["a", "b"]))
	assert_eq(u.pop(), _deck(["a"]))
	assert_false(u.can_undo())
	assert_eq(u.pop(), _deck([]))


func test_duplicate_snapshot_skipped() -> void:
	var u: DeckUndo = DeckUndo.new()
	u.push(_deck(["a"]))
	u.push(_deck(["a"]))
	u.pop()
	assert_false(u.can_undo())


func test_snapshot_is_a_copy_and_capped() -> void:
	var u: DeckUndo = DeckUndo.new()
	var live: Array[String] = _deck(["a"])
	u.push(live)
	live.append("b")
	assert_eq(u.pop(), _deck(["a"]))
	for i in range(DeckUndo.CAP + 5):
		u.push(_deck([str(i)]))
	var n: int = 0
	while u.can_undo():
		u.pop()
		n += 1
	assert_eq(n, DeckUndo.CAP)
