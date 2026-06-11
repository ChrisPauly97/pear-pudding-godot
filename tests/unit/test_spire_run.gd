## Unit tests for the Endless Spire run state in SaveManager.
##
## Tests cover the v15→v16 migration and the start/advance/draft/end lifecycle.
## SaveManager is instantiated directly (no _ready() call) so no scene tree or
## timer is needed — only the pure data-manipulation helpers are exercised.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# Migration v15 → v16
# ---------------------------------------------------------------------------

func test_migration_adds_spire_run_to_old_save() -> void:
	var data: Dictionary = {"version": 15}
	SaveManagerScript._migrate_v15_to_v16(data)
	assert_true(data.has("spire_run"), "spire_run key must be present after migration")

func test_migration_default_spire_run_is_inactive() -> void:
	var data: Dictionary = {"version": 15}
	SaveManagerScript._migrate_v15_to_v16(data)
	assert_false(bool(data["spire_run"].get("active", true)), "default spire_run.active must be false")

func test_migration_bumps_version_to_16() -> void:
	var data: Dictionary = {"version": 15}
	SaveManagerScript._migrate_v15_to_v16(data)
	assert_eq(data["version"], 16)

func test_migration_does_not_overwrite_existing_spire_run() -> void:
	var existing: Dictionary = {"active": true, "floor": 3}
	var data: Dictionary = {"version": 15, "spire_run": existing}
	SaveManagerScript._migrate_v15_to_v16(data)
	assert_true(bool(data["spire_run"].get("active", false)), "existing active run must be preserved")
	assert_eq(data["spire_run"].get("floor", 0), 3)

func test_apply_migrations_reaches_v16_from_v15() -> void:
	var data: Dictionary = {"version": 15}
	SaveManagerScript._apply_migrations(data)
	assert_eq(data.get("version", 0), 16)
	assert_true(data.has("spire_run"))

# ---------------------------------------------------------------------------
# is_spire_active / get_spire_run defaults
# ---------------------------------------------------------------------------

func test_spire_inactive_by_default() -> void:
	assert_false(_sm.is_spire_active())

func test_get_spire_run_returns_inactive_dict_by_default() -> void:
	var run: Dictionary = _sm.get_spire_run()
	assert_false(bool(run.get("active", true)))

# ---------------------------------------------------------------------------
# start_spire_run
# ---------------------------------------------------------------------------

func test_start_spire_run_marks_active() -> void:
	_sm.start_spire_run(1234)
	assert_true(_sm.is_spire_active())

func test_start_spire_run_sets_floor_to_one() -> void:
	_sm.start_spire_run(1234)
	assert_eq(int(_sm.get_spire_run().get("floor", 0)), 1)

func test_start_spire_run_stores_seed() -> void:
	_sm.start_spire_run(9999)
	assert_eq(int(_sm.get_spire_run().get("seed", 0)), 9999)

func test_start_spire_run_hero_hp_is_30() -> void:
	_sm.start_spire_run(1)
	assert_eq(int(_sm.get_spire_run().get("hero_hp", 0)), 30)

func test_start_spire_run_draft_deck_is_empty() -> void:
	_sm.start_spire_run(1)
	assert_eq((_sm.get_spire_run().get("draft_deck", []) as Array).size(), 0)

func test_start_spire_run_enemies_defeated_zero() -> void:
	_sm.start_spire_run(1)
	assert_eq(int(_sm.get_spire_run().get("enemies_defeated", -1)), 0)

func test_start_spire_run_cards_drafted_zero() -> void:
	_sm.start_spire_run(1)
	assert_eq(int(_sm.get_spire_run().get("cards_drafted", -1)), 0)

# ---------------------------------------------------------------------------
# advance_spire_floor
# ---------------------------------------------------------------------------

func test_advance_floor_increments_floor() -> void:
	_sm.start_spire_run(1)
	_sm.advance_spire_floor()
	assert_eq(int(_sm.get_spire_run().get("floor", 0)), 2)

func test_advance_floor_increments_enemies_defeated() -> void:
	_sm.start_spire_run(1)
	_sm.advance_spire_floor()
	assert_eq(int(_sm.get_spire_run().get("enemies_defeated", 0)), 1)

func test_advance_floor_twice_gives_floor_three() -> void:
	_sm.start_spire_run(1)
	_sm.advance_spire_floor()
	_sm.advance_spire_floor()
	assert_eq(int(_sm.get_spire_run().get("floor", 0)), 3)

func test_advance_floor_noop_when_inactive() -> void:
	_sm.advance_spire_floor()
	assert_false(_sm.is_spire_active())

# ---------------------------------------------------------------------------
# add_drafted_card
# ---------------------------------------------------------------------------

func test_add_drafted_card_appends_to_deck() -> void:
	_sm.start_spire_run(1)
	_sm.add_drafted_card("ghost")
	assert_eq((_sm.get_spire_run().get("draft_deck", []) as Array).size(), 1)

func test_add_drafted_card_increments_cards_drafted() -> void:
	_sm.start_spire_run(1)
	_sm.add_drafted_card("ghost")
	assert_eq(int(_sm.get_spire_run().get("cards_drafted", 0)), 1)

func test_add_drafted_card_stores_correct_id() -> void:
	_sm.start_spire_run(1)
	_sm.add_drafted_card("skeleton")
	var deck: Array = _sm.get_spire_run().get("draft_deck", [])
	assert_eq(str(deck[0]), "skeleton")

func test_add_drafted_card_noop_when_inactive() -> void:
	_sm.add_drafted_card("ghost")
	assert_false(_sm.is_spire_active())

# ---------------------------------------------------------------------------
# set_spire_hero_hp
# ---------------------------------------------------------------------------

func test_set_spire_hero_hp_updates_value() -> void:
	_sm.start_spire_run(1)
	_sm.set_spire_hero_hp(15)
	assert_eq(int(_sm.get_spire_run().get("hero_hp", -1)), 15)

func test_set_spire_hero_hp_noop_when_inactive() -> void:
	_sm.set_spire_hero_hp(15)
	assert_false(_sm.is_spire_active())

# ---------------------------------------------------------------------------
# end_spire_run
# ---------------------------------------------------------------------------

func test_end_spire_run_returns_floors_cleared() -> void:
	_sm.start_spire_run(1)
	_sm.advance_spire_floor()
	_sm.advance_spire_floor()
	var stats: Dictionary = _sm.end_spire_run()
	assert_eq(int(stats.get("floors_cleared", -1)), 2)

func test_end_spire_run_returns_enemies_defeated() -> void:
	_sm.start_spire_run(1)
	_sm.advance_spire_floor()
	var stats: Dictionary = _sm.end_spire_run()
	assert_eq(int(stats.get("enemies_defeated", -1)), 1)

func test_end_spire_run_returns_cards_drafted() -> void:
	_sm.start_spire_run(1)
	_sm.add_drafted_card("ghost")
	_sm.add_drafted_card("skeleton")
	var stats: Dictionary = _sm.end_spire_run()
	assert_eq(int(stats.get("cards_drafted", -1)), 2)

func test_end_spire_run_returns_seed() -> void:
	_sm.start_spire_run(5555)
	var stats: Dictionary = _sm.end_spire_run()
	assert_eq(int(stats.get("seed", 0)), 5555)

func test_end_spire_run_clears_active_flag() -> void:
	_sm.start_spire_run(1)
	_sm.end_spire_run()
	assert_false(_sm.is_spire_active())

func test_end_fresh_run_floors_cleared_zero() -> void:
	_sm.start_spire_run(1)
	var stats: Dictionary = _sm.end_spire_run()
	assert_eq(int(stats.get("floors_cleared", -1)), 0)
