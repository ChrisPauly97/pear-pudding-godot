## GID-186: the wide balance coverage checks (BalanceCoverage) on synthetic
## measurements, and that its cell tables cover the roster. The real measurement
## runs in CI as tests/balance_coverage.gd.
extends "res://tests/framework/test_case.gd"

const BalanceCoverage = preload("res://game_logic/battle/BalanceCoverage.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")

## Types no section fights: the training dummy (passive, never fights back).
const NOT_COVERED: Array[String] = ["training_dummy"]

func _cell(win: float) -> Dictionary:
	return {"win_rate": win, "median_s": 30.0, "n": 8}

func _ladder_ok() -> Dictionary:
	return {"a@5+0": _cell(1.0), "a@5+1": _cell(0.75), "b@9+0": _cell(1.0), "b@9+1": _cell(0.7)}

func test_ladder_on_target_passes() -> void:
	assert_eq(BalanceCoverage.check_ladder("t", _ladder_ok()).size(), 0)

func test_ladder_same_level_floor() -> void:
	var m := _ladder_ok()
	m["a@5+0"] = _cell(0.75)
	assert_eq(BalanceCoverage.check_ladder("t", m).size(), 1)

func test_ladder_wall_cell_fails() -> void:
	var m := _ladder_ok()
	m["a@5+1"] = _cell(0.1)
	m["b@9+1"] = _cell(1.0)
	m["c@3+0"] = _cell(1.0)
	m["c@3+1"] = _cell(1.0)  # mean 70 % stays in band; only the wall fails
	var fails: Array[String] = BalanceCoverage.check_ladder("t", m)
	assert_eq(fails.size(), 1, str(fails))

func test_ladder_mean_band() -> void:
	var easy := _ladder_ok()
	easy["a@5+1"] = _cell(1.0)
	easy["b@9+1"] = _cell(1.0)
	assert_eq(BalanceCoverage.check_ladder("t", easy).size(), 1, "walkover")
	var hard := _ladder_ok()
	hard["a@5+1"] = _cell(0.3)
	hard["b@9+1"] = _cell(0.3)
	assert_eq(BalanceCoverage.check_ladder("t", hard).size(), 1, "too hard")

func test_ladder_level_up_never_hurts() -> void:
	var m := _ladder_ok()
	m["a@5+0"] = _cell(0.875)
	m["a@5+1"] = _cell(1.0)  # 12.5 pp over same level: within the slack
	assert_eq(BalanceCoverage.check_ladder("t", m).size(), 0)
	m["b@9+0"] = _cell(0.5)
	m["b@9+1"] = _cell(0.75)
	var fails: Array[String] = BalanceCoverage.check_ladder("t", m)
	assert_true(fails.any(func(f: String) -> bool: return f.contains("wins more")), str(fails))

func _schools(weak_rate: float, resist_rate: float) -> Dictionary:
	return {
		"x/weak/a@5": {"kind": "weak", "same": false, "rate": weak_rate, "untagged": 0.5},
		"x/resist/b@5": {"kind": "resist", "same": true, "rate": resist_rate, "untagged": 0.7},
	}

func test_school_matrix_right_direction_passes() -> void:
	assert_eq(BalanceCoverage.check_schools(_schools(0.7, 0.5)).size(), 0)

func test_school_matrix_wrong_direction_fails() -> void:
	var fails: Array[String] = BalanceCoverage.check_schools(_schools(0.3, 0.5))
	assert_eq(fails.size(), 2, "wrong way + weak mean gap: %s" % str(fails))

func test_school_matrix_needs_a_mean_effect() -> void:
	var fails: Array[String] = BalanceCoverage.check_schools(_schools(0.5, 0.7))  # no effect at all
	assert_eq(fails.size(), 2, str(fails))

func test_school_matrix_resist_floor() -> void:
	var fails: Array[String] = BalanceCoverage.check_schools(_schools(0.7, 0.3))
	assert_true(fails.any(func(f: String) -> bool: return f.contains("a wall")), str(fails))

func test_boss_floor() -> void:
	assert_eq(BalanceCoverage.check_bosses({"g@20+0": _cell(0.5)}).size(), 0)
	assert_eq(BalanceCoverage.check_bosses({"g@20+0": _cell(0.25)}).size(), 1)

func test_range_section_covers_every_chapter1_level() -> void:
	var cells: Array = BalanceCoverage.ladder_cells("range")
	for t: String in EnemyRegistry.LEVEL_RANGES:
		var r: Vector2i = EnemyRegistry.level_range(t)
		for lv: int in range(r.x, r.y + 1):
			assert_true(cells.has([t, lv]), "range lacks %s@%d" % [t, lv])

func test_world_cells_inside_each_range() -> void:
	for section: String in ["world_low", "world_high"]:
		for cell: Array in BalanceCoverage.ladder_cells(section):
			var r: Vector2i = EnemyRegistry.level_range(str(cell[0]))
			assert_between(int(cell[1]), maxi(r.x, BalanceCoverage.PROGRESSION_MIN_LEVEL), r.y, str(cell))
			assert_lt(int(cell[1]), BalanceCoverage.MAX_LEVEL, "+1 must stay a real level")

func test_every_enemy_type_is_covered() -> void:
	var covered: Array[String] = []
	covered.append_array(BalanceCoverage.WORLD_LOW)
	covered.append_array(BalanceCoverage.WORLD_HIGH)
	covered.append_array(BalanceCoverage.BOSSES)
	for t: String in EnemyRegistry.LEVEL_RANGES:
		covered.append(t)
	for t: String in EnemyRegistry.get_all_enemy_ids():
		if not NOT_COVERED.has(t):
			assert_true(covered.has(t), "%s is in no balance section" % t)
	for t: String in BalanceCoverage.BOSSES:
		assert_true(EnemyRegistry.is_boss(t), "%s is not a boss" % t)
	for t: String in BalanceCoverage.WORLD_LOW + BalanceCoverage.WORLD_HIGH:
		assert_false(EnemyRegistry.is_boss(t), "%s is a boss" % t)
		assert_false(EnemyRegistry.LEVEL_RANGES.has(t), "%s is a Chapter 1 type" % t)

func test_school_matrix_rows_match_profiles() -> void:
	var seen: Dictionary = {}
	for row: Array in BalanceCoverage.SCHOOL_MATRIX:
		var prof: Dictionary = EnemyRegistry.get_school_profile(str(row[2]), 1)
		assert_true((prof[str(row[1])] as Dictionary).has(str(row[0])), "%s does not %s %s" % [row[2], row[1], row[0]])
		seen["%s/%s" % [row[0], row[1]]] = true
	for s: String in DamageSchools.all_schools():
		for kind: String in ["weak", "resist"]:
			assert_true(seen.has("%s/%s" % [s, kind]), "matrix lacks %s %s" % [s, kind])

func test_neutral_school_avoids_profiled_schools() -> void:
	for t: String in BalanceCoverage.WORLD_LOW + BalanceCoverage.WORLD_HIGH + BalanceCoverage.BOSSES:
		var s: String = BalanceCoverage.neutral_school(t)
		var school: String = DamageSchools.PHYSICAL if s == "" else s
		var prof: Dictionary = EnemyRegistry.get_school_profile(t, 1)
		for kind: String in ["resist", "weak", "immune"]:
			assert_false((prof[kind] as Dictionary).has(school), "%s: %s is %s" % [t, school, kind])
