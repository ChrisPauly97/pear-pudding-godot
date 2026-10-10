## Unit tests for the matchup loadout scorer (GID-181 / TID-756): weak-hit counting,
## resist tie-break, invalid loadouts never best, unknown profile highlights nothing.
extends "res://tests/framework/test_case.gd"

const _LoadoutMatchup = preload("res://game_logic/battle/LoadoutMatchup.gd")

func _entry(index: int, schools: Array[String], valid: bool = true) -> Dictionary:
	return {"index": index, "name": "Deck %d" % index, "schools": schools, "valid": valid}

func _strs(items: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(items)
	return out

func test_weak_hits_counts_only_weak_schools() -> void:
	var schools: Array[String] = _strs(["light", "light", "dark", "physical"])
	assert_eq(_LoadoutMatchup.weak_hits(schools, _strs(["light"])), 2)
	assert_eq(_LoadoutMatchup.weak_hits(schools, _strs([])), 0)

func test_resist_hits_counts_only_resisted_schools() -> void:
	var schools: Array[String] = _strs(["dark", "verdant"])
	assert_eq(_LoadoutMatchup.resist_hits(schools, _strs(["dark"])), 1)

func test_best_is_highest_weak_count() -> void:
	var entries: Array[Dictionary] = [
		_entry(0, _strs(["dark", "dark", "physical"])),
		_entry(1, _strs(["light", "light", "dark"])),
		_entry(2, _strs(["light", "physical", "physical"])),
	]
	var ranked: Array[Dictionary] = _LoadoutMatchup.rank(entries, _strs(["light"]), _strs(["dark"]))
	assert_eq(int(ranked[0]["index"]), 1)
	assert_eq(_LoadoutMatchup.best_index(ranked), 1)

func test_resist_breaks_a_tie_then_index() -> void:
	var entries: Array[Dictionary] = [
		_entry(0, _strs(["light", "dark"])),
		_entry(1, _strs(["light", "physical"])),
		_entry(2, _strs(["light", "physical"])),
	]
	var ranked: Array[Dictionary] = _LoadoutMatchup.rank(entries, _strs(["light"]), _strs(["dark"]))
	assert_eq(int(ranked[0]["index"]), 1)
	assert_eq(int(ranked[1]["index"]), 2)
	assert_eq(int(ranked[2]["index"]), 0)

func test_invalid_loadout_is_never_best() -> void:
	var entries: Array[Dictionary] = [
		_entry(0, _strs(["light", "light", "light"]), false),
		_entry(1, _strs(["light"]), true),
	]
	var ranked: Array[Dictionary] = _LoadoutMatchup.rank(entries, _strs(["light"]), _strs([]))
	assert_eq(int(ranked[0]["index"]), 1)
	assert_eq(_LoadoutMatchup.best_index(ranked), 1)
	var only_invalid: Array[Dictionary] = [_entry(0, _strs(["light"]), false)]
	assert_eq(_LoadoutMatchup.best_index(_LoadoutMatchup.rank(only_invalid, _strs(["light"]), _strs([]))), -1)

func test_unknown_profile_highlights_nothing() -> void:
	var entries: Array[Dictionary] = [_entry(0, _strs(["light"])), _entry(1, _strs(["dark"]))]
	var ranked: Array[Dictionary] = _LoadoutMatchup.rank(entries, _strs([]), _strs([]))
	assert_eq(_LoadoutMatchup.best_index(ranked), -1)
	assert_eq(int(ranked[0]["index"]), 0)

func test_rank_does_not_mutate_input() -> void:
	var entries: Array[Dictionary] = [_entry(0, _strs(["light"]))]
	_LoadoutMatchup.rank(entries, _strs(["light"]), _strs([]))
	assert_false(entries[0].has("score"))

func test_empty_loadout_list() -> void:
	var entries: Array[Dictionary] = []
	var ranked: Array[Dictionary] = _LoadoutMatchup.rank(entries, _strs(["light"]), _strs([]))
	assert_eq(_LoadoutMatchup.best_index(ranked), -1)
