## Unit tests for the treasure map system (TID-164, TID-165).
##
## Covers: fragment counter, map assembly, no-drop when active, migration,
## TreasureGen determinism and differentiation.
## SaveManager is instantiated directly — no scene tree needed.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const TreasureGen       = preload("res://game_logic/world/TreasureGen.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true  # skip the "not loaded" guard in mutators

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# Migration v18 → v19
# ---------------------------------------------------------------------------

func test_migration_adds_treasure_fields() -> void:
	var data: Dictionary = {"version": 18}
	SaveManagerScript._migrate_v18_to_v19(data)
	assert_true(data.has("treasure_fragments"), "treasure_fragments key must be added")
	assert_true(data.has("active_treasure"), "active_treasure key must be added")
	assert_true(data.has("treasures_completed"), "treasures_completed key must be added")

func test_migration_default_fragment_count_is_zero() -> void:
	var data: Dictionary = {"version": 18}
	SaveManagerScript._migrate_v18_to_v19(data)
	assert_eq(data["treasure_fragments"], 0)

func test_migration_default_active_treasure_is_empty() -> void:
	var data: Dictionary = {"version": 18}
	SaveManagerScript._migrate_v18_to_v19(data)
	assert_true(data["active_treasure"].is_empty())

func test_migration_bumps_version_to_19() -> void:
	var data: Dictionary = {"version": 18}
	SaveManagerScript._migrate_v18_to_v19(data)
	assert_eq(data["version"], 19)

func test_migration_does_not_overwrite_existing_fragments() -> void:
	var data: Dictionary = {"version": 18, "treasure_fragments": 2}
	SaveManagerScript._migrate_v18_to_v19(data)
	assert_eq(data["treasure_fragments"], 2)

func test_apply_migrations_reaches_current_from_v18() -> void:
	var data: Dictionary = {"version": 18}
	SaveManagerScript._apply_migrations(data)
	assert_eq(data.get("version", 0), SaveManagerScript.CURRENT_SAVE_VERSION)
	assert_true(data.has("treasure_fragments"))
	assert_true(data.has("active_treasure"))
	assert_true(data.has("treasures_completed"))

# ---------------------------------------------------------------------------
# Fragment defaults
# ---------------------------------------------------------------------------

func test_treasure_fragments_starts_at_zero() -> void:
	assert_eq(_sm.treasure_fragments, 0)

func test_active_treasure_starts_empty() -> void:
	assert_true(_sm.active_treasure.is_empty())

func test_treasures_completed_starts_at_zero() -> void:
	assert_eq(_sm.treasures_completed, 0)

# ---------------------------------------------------------------------------
# collect_treasure_fragment
# ---------------------------------------------------------------------------

func test_collect_fragment_increments_count() -> void:
	_sm.collect_treasure_fragment()
	assert_eq(_sm.treasure_fragments, 1)

func test_collect_two_fragments_counts_two() -> void:
	_sm.collect_treasure_fragment()
	_sm.collect_treasure_fragment()
	assert_eq(_sm.treasure_fragments, 2)

func test_three_fragments_assembles_map() -> void:
	_sm.collect_treasure_fragment()
	_sm.collect_treasure_fragment()
	_sm.collect_treasure_fragment()
	assert_eq(_sm.treasure_fragments, 0, "fragments should reset to 0 after assembly")
	assert_false(_sm.active_treasure.is_empty(), "active_treasure should be populated after assembly")

func test_assembled_map_has_required_keys() -> void:
	_sm.collect_treasure_fragment()
	_sm.collect_treasure_fragment()
	_sm.collect_treasure_fragment()
	var at: Dictionary = _sm.active_treasure
	assert_true(at.has("site_x"), "active_treasure must have site_x")
	assert_true(at.has("site_z"), "active_treasure must have site_z")
	assert_true(at.has("completed"), "active_treasure must have completed flag")

func test_assembled_map_not_completed() -> void:
	_sm.collect_treasure_fragment()
	_sm.collect_treasure_fragment()
	_sm.collect_treasure_fragment()
	assert_false(bool(_sm.active_treasure.get("completed", true)))

# ---------------------------------------------------------------------------
# complete_treasure
# ---------------------------------------------------------------------------

func test_complete_treasure_marks_completed() -> void:
	_sm.collect_treasure_fragment()
	_sm.collect_treasure_fragment()
	_sm.collect_treasure_fragment()
	_sm.complete_treasure(100, "ghost")
	assert_true(bool(_sm.active_treasure.get("completed", false)))

func test_complete_treasure_increments_treasures_completed() -> void:
	_sm.collect_treasure_fragment()
	_sm.collect_treasure_fragment()
	_sm.collect_treasure_fragment()
	_sm.complete_treasure(100, "ghost")
	assert_eq(_sm.treasures_completed, 1)

func test_complete_treasure_no_op_when_no_active() -> void:
	_sm.complete_treasure(100, "ghost")  # should not crash
	assert_eq(_sm.treasures_completed, 0)

# ---------------------------------------------------------------------------
# TreasureGen: determinism
# ---------------------------------------------------------------------------

func test_get_dig_site_is_deterministic() -> void:
	var site_a: Vector2i = TreasureGen.get_dig_site(42, 0)
	var site_b: Vector2i = TreasureGen.get_dig_site(42, 0)
	assert_eq(site_a.x, site_b.x, "x coordinate must be deterministic")
	assert_eq(site_a.y, site_b.y, "z coordinate must be deterministic")

func test_different_counters_produce_different_sites() -> void:
	var site_a: Vector2i = TreasureGen.get_dig_site(42, 0)
	var site_b: Vector2i = TreasureGen.get_dig_site(42, 1)
	assert_true(site_a.x != site_b.x or site_a.y != site_b.y, "counter 0 and 1 should produce different sites")

func test_different_seeds_produce_different_sites() -> void:
	var site_a: Vector2i = TreasureGen.get_dig_site(42,    0)
	var site_b: Vector2i = TreasureGen.get_dig_site(99999, 0)
	assert_true(site_a.x != site_b.x or site_a.y != site_b.y, "different seeds should produce different sites")

func test_site_is_within_radius_bounds() -> void:
	for counter: int in range(5):
		var site: Vector2i = TreasureGen.get_dig_site(42, counter)
		var dist: float = sqrt(float(site.x * site.x + site.y * site.y))
		# Allow up to MAX_RADIUS + 5-tile nudge buffer
		assert_true(dist >= float(TreasureGen.DIG_SITE_MIN_RADIUS) - 5 and
			dist <= float(TreasureGen.DIG_SITE_MAX_RADIUS) + 5,
			"site must be within ring distance (counter %d, dist %.1f)" % [counter, dist])
