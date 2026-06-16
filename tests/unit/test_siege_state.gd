## Unit tests for SaveManager siege state management and v30→v31 migration.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true   # allow save/mutator calls without a disk save

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# Migration v30 → v31
# ---------------------------------------------------------------------------

func test_migration_adds_siege_field() -> void:
	var data: Dictionary = {"version": 30}
	SaveManagerScript._migrate_v30_to_v31(data)
	assert_true(data.has("siege"))

func test_migration_siege_default_is_empty_dict() -> void:
	var data: Dictionary = {"version": 30}
	SaveManagerScript._migrate_v30_to_v31(data)
	assert_eq(data["siege"], {})

func test_migration_adds_last_siege_day() -> void:
	var data: Dictionary = {"version": 30}
	SaveManagerScript._migrate_v30_to_v31(data)
	assert_true(data.has("last_siege_day"))
	assert_eq(data["last_siege_day"], 0)

func test_migration_adds_town_discounts() -> void:
	var data: Dictionary = {"version": 30}
	SaveManagerScript._migrate_v30_to_v31(data)
	assert_true(data.has("town_discounts"))
	assert_eq(data["town_discounts"], {})

func test_migration_bumps_version_to_31() -> void:
	var data: Dictionary = {"version": 30}
	SaveManagerScript._migrate_v30_to_v31(data)
	assert_eq(data["version"], 31)

func test_apply_migrations_reaches_31_from_v30() -> void:
	var data: Dictionary = {"version": 30}
	SaveManagerScript._apply_migrations(data)
	assert_eq(data.get("version", 0), SaveManagerScript.CURRENT_SAVE_VERSION)
	assert_true(data.has("siege"))
	assert_true(data.has("last_siege_day"))
	assert_true(data.has("town_discounts"))

# ---------------------------------------------------------------------------
# start_siege
# ---------------------------------------------------------------------------

func test_start_siege_sets_town() -> void:
	_sm.start_siege("madrian")
	assert_eq(str(_sm.get_active_siege().get("town", "")), "madrian")

func test_start_siege_stage_0() -> void:
	_sm.start_siege("madrian")
	assert_eq(int(_sm.get_active_siege().get("stage", -1)), 0)

func test_start_siege_hero_hp_30() -> void:
	_sm.start_siege("madrian")
	assert_eq(int(_sm.get_active_siege().get("hero_hp", 0)), 30)

func test_start_siege_day_started_equals_days_elapsed() -> void:
	_sm.days_elapsed = 5
	_sm.start_siege("madrian")
	assert_eq(int(_sm.get_active_siege().get("day_started", -1)), 5)

# ---------------------------------------------------------------------------
# get_active_siege
# ---------------------------------------------------------------------------

func test_no_active_siege_returns_empty() -> void:
	assert_true(_sm.get_active_siege().is_empty())

# ---------------------------------------------------------------------------
# advance_siege_stage
# ---------------------------------------------------------------------------

func test_advance_stage_from_0_to_1() -> void:
	_sm.start_siege("madrian")
	_sm.advance_siege_stage()
	assert_eq(int(_sm.get_active_siege().get("stage", 0)), 1)

func test_advance_stage_from_1_to_2() -> void:
	_sm.start_siege("madrian")
	_sm.advance_siege_stage()
	_sm.advance_siege_stage()
	assert_eq(int(_sm.get_active_siege().get("stage", 0)), 2)

func test_advance_stage_no_op_when_empty() -> void:
	_sm.advance_siege_stage()   # should not crash
	assert_true(_sm.get_active_siege().is_empty())

# ---------------------------------------------------------------------------
# set_siege_hero_hp
# ---------------------------------------------------------------------------

func test_set_siege_hero_hp_updates_value() -> void:
	_sm.start_siege("madrian")
	_sm.set_siege_hero_hp(15)
	assert_eq(int(_sm.get_active_siege().get("hero_hp", 0)), 15)

func test_set_siege_hero_hp_no_op_when_empty() -> void:
	_sm.set_siege_hero_hp(10)   # should not crash
	assert_true(_sm.get_active_siege().is_empty())

# ---------------------------------------------------------------------------
# end_siege_victory
# ---------------------------------------------------------------------------

func test_end_victory_clears_siege() -> void:
	_sm.start_siege("madrian")
	_sm.end_siege_victory()
	assert_true(_sm.get_active_siege().is_empty())

func test_end_victory_updates_last_siege_day() -> void:
	_sm.days_elapsed = 7
	_sm.start_siege("madrian")
	_sm.end_siege_victory()
	assert_eq(_sm.last_siege_day, 7)

# ---------------------------------------------------------------------------
# end_siege_defeat
# ---------------------------------------------------------------------------

func test_end_defeat_clears_siege() -> void:
	_sm.start_siege("maykalene")
	_sm.end_siege_defeat()
	assert_true(_sm.get_active_siege().is_empty())

func test_end_defeat_updates_last_siege_day() -> void:
	_sm.days_elapsed = 4
	_sm.start_siege("maykalene")
	_sm.end_siege_defeat()
	assert_eq(_sm.last_siege_day, 4)
