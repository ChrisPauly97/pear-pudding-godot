## GID-176 / TID-717: the balance-band checks (BalanceBands.check), on synthetic
## measurements. The real measurement runs in CI as tests/balance_bands.gd.
extends "res://tests/framework/test_case.gd"

const BalanceBands = preload("res://game_logic/battle/BalanceBands.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")

func _cell(win: float, secs: float = 30.0) -> Dictionary:
	return {"win_rate": win, "median_s": secs, "n": 20}

func _ok() -> Dictionary:
	return {"a@1+0": _cell(1.0), "a@1+1": _cell(0.75), "b@2+0": _cell(1.0), "b@2+1": _cell(0.8)}

func test_on_target_passes() -> void:
	assert_eq(BalanceBands.check(_ok(), _ok()).size(), 0)

func test_same_level_loss_fails() -> void:
	var m := _ok()
	m["a@1+0"] = _cell(0.9)
	assert_eq(BalanceBands.check(m, {}).size(), 1)

func test_one_level_up_mean_band() -> void:
	var easy := _ok()
	easy["a@1+1"] = _cell(1.0)
	easy["b@2+1"] = _cell(1.0)
	assert_eq(BalanceBands.check(easy, {}).size(), 1, "too easy")
	var hard := _ok()
	hard["a@1+1"] = _cell(0.3)
	hard["b@2+1"] = _cell(0.5)
	assert_eq(BalanceBands.check(hard, {}).size(), 1, "too hard")

func test_drift_from_baseline_fails() -> void:
	var m := _ok()
	m["a@1+1"] = _cell(0.75 - BalanceBands.DRIFT_WIN - 0.05)
	m["b@2+1"] = _cell(0.8, 30.0 * (1.0 + BalanceBands.DRIFT_SECONDS + 0.1))
	var fails: Array[String] = BalanceBands.check(m, _ok())
	assert_eq(fails.size(), 2, str(fails))

func test_every_cell_is_a_chapter1_type_in_range() -> void:
	for cell: Array in BalanceBands.CELLS:
		var r: Vector2i = EnemyRegistry.level_range(str(cell[0]))
		assert_true(EnemyRegistry.LEVEL_RANGES.has(str(cell[0])), str(cell[0]))
		assert_between(int(cell[1]), r.x, r.y, str(cell))

func test_baseline_covers_every_cell() -> void:
	var b: Dictionary = BalanceBands.load_baseline()
	for cell: Array in BalanceBands.CELLS:
		for o: int in [0, 1]:
			assert_true(b.has(BalanceBands.key(str(cell[0]), int(cell[1]), o)), "baseline lacks %s+%d" % [cell, o])

## TID-757: school bands. Synthetic measurements; the real run is tests/balance_bands.gd.
func _school_measure(matchup_gap: float) -> Dictionary:
	var rates: Dictionary = {"default": 0.5, "physical": 0.5, "light": 0.5, "dark": 0.5, "verdant": 0.5, "rift": 0.5}
	return {"roster": {"forest": rates}, "matchup": {"cactus_worm@6/4": {"weak": 0.9, "resist": 0.9 - matchup_gap}}}

func test_school_matchup_band_gates() -> void:
	assert_eq(BalanceBands.check_schools(_school_measure(0.5)).size(), 0)
	assert_eq(BalanceBands.check_schools(_school_measure(0.05)).size(), 1, "weak school barely beats resisted")

func test_school_roster_bands_are_report_only() -> void:
	var m: Dictionary = _school_measure(0.5)
	(m["roster"]["forest"] as Dictionary)["dark"] = 0.95  # far outside the band: a note, not a failure
	assert_eq(BalanceBands.check_schools(m).size(), 0)
	var notes: Array[String] = BalanceBands.report_schools(m)
	assert_true(notes.size() >= 2, str(notes))  # the (a) dark deviation and the (c) dark-best note

func test_school_matched_deck_is_the_default_with_school_cards() -> void:
	var learned: Array = BalanceBands.all_learned()
	var base: Array[String] = BattleSetup.level_deck(learned)
	assert_eq(BattleSetup.school_matched_deck("physical", learned), base, "physical is the default deck")
	var dark: Array[String] = BattleSetup.school_matched_deck("dark", learned)
	assert_eq(dark.size(), base.size())
	for keep: String in ["tech_strike", "tech_mend", "tech_kick"]:
		assert_true(dark.has(keep), "keeps " + keep)
	var swapped: int = 0
	for id: String in dark:
		if not base.has(id):
			swapped += 1
			assert_eq(BattleSetup._card_school(id), "dark", id)
	assert_eq(swapped, BattleSetup.MATCHED_SWAP)
