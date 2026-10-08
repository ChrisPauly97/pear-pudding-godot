## GID-177 / TID-721: the slow XP curve and the migration of old saves.
extends "res://tests/framework/test_case.gd"

const XpCurve = preload("res://game_logic/progression/XpCurve.gd")
const SaveMigrations = preload("res://game_logic/save/SaveMigrations.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

func test_level_one_takes_about_ten_minutes_then_longer() -> void:
	assert_eq(XpCurve.minutes_for(1), 10.0)
	var prev: float = 0.0
	for l: int in range(1, 20):
		var mins: float = float(XpCurve.step(l)) / XpCurve.xp_per_minute(l)
		assert_lt(absf(mins - XpCurve.minutes_for(l)), 0.5, "level %d ≈ %.0f min" % [l, XpCurve.minutes_for(l)])
		assert_gt(mins, prev, "each level takes longer than the last")
		prev = mins

func test_curve_is_consistent() -> void:
	assert_eq(XpCurve.xp_to_reach(1), 0)
	for l: int in range(1, XpCurve.MAX_LEVEL):
		assert_lt(XpCurve.xp_to_reach(l), XpCurve.xp_to_reach(l + 1), "monotonic at %d" % l)
		assert_eq(XpCurve.level_for(XpCurve.xp_to_reach(l)), l, "level_for(xp_to_reach(%d))" % l)
		assert_eq(XpCurve.level_for(XpCurve.xp_to_reach(l + 1) - 1), l, "just short of %d" % (l + 1))
	assert_eq(XpCurve.level_for(999999999), XpCurve.MAX_LEVEL)

func test_much_slower_than_before() -> void:
	assert_gt(XpCurve.xp_to_reach(10), 2 * XpCurve.legacy_xp_to_reach(10), "level 10 needs far more XP")
	var hours: float = 0.0
	for l: int in range(1, 10):
		hours += XpCurve.minutes_for(l) / 60.0
	assert_lt(absf(hours - 4.5), 0.01, "about 4.5 h of play to level 10")

func test_migration_keeps_level_and_progress() -> void:
	for old_xp: int in [0, 150, 200, 449, 450, 1000, 5000, 11250, 60000]:
		var old_level: int = XpCurve.legacy_level_for(old_xp)
		var new_xp: int = XpCurve.migrate_xp(old_xp)
		assert_eq(XpCurve.level_for(new_xp), old_level, "%d XP keeps level %d" % [old_xp, old_level])
	var mid_old: int = (XpCurve.legacy_xp_to_reach(5) + XpCurve.legacy_xp_to_reach(6)) / 2
	var mid_new: int = XpCurve.migrate_xp(mid_old)
	var frac: float = float(mid_new - XpCurve.xp_to_reach(5)) / float(XpCurve.step(5))
	assert_lt(absf(frac - 0.5), 0.02, "halfway stays halfway")

func test_save_migration_row() -> void:
	var d: Dictionary = {"version": 46, "xp": 1250}
	SaveMigrations.apply(d)
	assert_eq(int(d["version"]), SaveMigrations.CURRENT_VERSION)
	assert_eq(XpCurve.level_for(int(d["xp"])), 5, "an old level-5 save stays level 5")

func test_session_character_keeps_its_level() -> void:
	var sm := SaveManagerScript.new()
	sm.adopt_session_character({"level": 7, "xp": 2500})
	assert_eq(sm.level, 7)
	assert_gte(sm.xp, SaveManagerScript.xp_for_level(7))

func test_slot_summary_shows_migrated_level() -> void:
	assert_eq(SaveManagerScript._slot_level({"version": 46, "xp": 1250}), 5, "old level-5 save shown as 5")
