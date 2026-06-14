## Unit tests for the bestiary data layer (TID-170).
##
## Covers: record_enemy_seen/defeated counters, get_bestiary_entry,
## migration v21→v22, and lore_text presence on bundled enemy types.
## SaveManager is instantiated directly — no scene tree needed.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const EnemyRegistry     = preload("res://autoloads/EnemyRegistry.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# record_enemy_seen
# ---------------------------------------------------------------------------

func test_record_enemy_seen_increments_seen() -> void:
	_sm.record_enemy_seen("undead_basic")
	var entry: Dictionary = _sm.get_bestiary_entry("undead_basic")
	assert_eq(int(entry.get("seen", 0)), 1, "seen count must be 1 after one call")

func test_record_enemy_seen_twice_counts_two() -> void:
	_sm.record_enemy_seen("undead_basic")
	_sm.record_enemy_seen("undead_basic")
	var entry: Dictionary = _sm.get_bestiary_entry("undead_basic")
	assert_eq(int(entry.get("seen", 0)), 2, "seen count must be 2 after two calls")

func test_record_enemy_seen_does_not_increment_defeated() -> void:
	_sm.record_enemy_seen("undead_basic")
	var entry: Dictionary = _sm.get_bestiary_entry("undead_basic")
	assert_eq(int(entry.get("defeated", 0)), 0, "defeated must remain 0 after only seeing")

func test_record_enemy_seen_creates_entry_for_new_type() -> void:
	_sm.record_enemy_seen("ghoul_pack")
	assert_true(_sm.bestiary.has("ghoul_pack"), "bestiary must have key for newly seen type")

# ---------------------------------------------------------------------------
# record_enemy_defeated
# ---------------------------------------------------------------------------

func test_record_enemy_defeated_increments_defeated() -> void:
	_sm.record_enemy_defeated("undead_horde")
	var entry: Dictionary = _sm.get_bestiary_entry("undead_horde")
	assert_eq(int(entry.get("defeated", 0)), 1, "defeated count must be 1 after one call")

func test_record_enemy_defeated_twice_counts_two() -> void:
	_sm.record_enemy_defeated("undead_horde")
	_sm.record_enemy_defeated("undead_horde")
	var entry: Dictionary = _sm.get_bestiary_entry("undead_horde")
	assert_eq(int(entry.get("defeated", 0)), 2, "defeated count must be 2 after two calls")

func test_record_enemy_defeated_does_not_increment_seen() -> void:
	_sm.record_enemy_defeated("undead_horde")
	var entry: Dictionary = _sm.get_bestiary_entry("undead_horde")
	assert_eq(int(entry.get("seen", 0)), 0, "seen must remain 0 when only defeated is called")

# ---------------------------------------------------------------------------
# get_bestiary_entry
# ---------------------------------------------------------------------------

func test_get_bestiary_entry_returns_zeros_for_unknown() -> void:
	var entry: Dictionary = _sm.get_bestiary_entry("nonexistent_type")
	assert_eq(int(entry.get("seen", -1)), 0, "seen must default to 0 for unknown type")
	assert_eq(int(entry.get("defeated", -1)), 0, "defeated must default to 0 for unknown type")

func test_get_bestiary_entry_reflects_both_counters() -> void:
	_sm.record_enemy_seen("undead_elite")
	_sm.record_enemy_seen("undead_elite")
	_sm.record_enemy_defeated("undead_elite")
	var entry: Dictionary = _sm.get_bestiary_entry("undead_elite")
	assert_eq(int(entry.get("seen", 0)), 2)
	assert_eq(int(entry.get("defeated", 0)), 1)

# ---------------------------------------------------------------------------
# Migration v21 → v22
# ---------------------------------------------------------------------------

func test_migration_adds_bestiary_field() -> void:
	var data: Dictionary = {"version": 21}
	SaveManagerScript._migrate_v21_to_v22(data)
	assert_true(data.has("bestiary"), "bestiary key must be added by migration")

func test_migration_default_bestiary_is_empty_dict() -> void:
	var data: Dictionary = {"version": 21}
	SaveManagerScript._migrate_v21_to_v22(data)
	assert_true(data["bestiary"].is_empty(), "default bestiary must be an empty dict")

func test_migration_adds_bestiary_complete_rewarded() -> void:
	var data: Dictionary = {"version": 21}
	SaveManagerScript._migrate_v21_to_v22(data)
	assert_true(data.has("bestiary_complete_rewarded"), "bestiary_complete_rewarded key must be added")

func test_migration_default_rewarded_is_false() -> void:
	var data: Dictionary = {"version": 21}
	SaveManagerScript._migrate_v21_to_v22(data)
	assert_false(bool(data["bestiary_complete_rewarded"]), "default bestiary_complete_rewarded must be false")

func test_migration_bumps_version_to_22() -> void:
	var data: Dictionary = {"version": 21}
	SaveManagerScript._migrate_v21_to_v22(data)
	assert_eq(int(data["version"]), 22)

func test_migration_does_not_overwrite_existing_bestiary() -> void:
	var existing: Dictionary = {"undead_basic": {"seen": 5, "defeated": 3}}
	var data: Dictionary = {"version": 21, "bestiary": existing}
	SaveManagerScript._migrate_v21_to_v22(data)
	assert_eq(int(data["bestiary"]["undead_basic"]["defeated"]), 3, "existing bestiary data must be preserved")

func test_apply_migrations_reaches_v22_from_v21() -> void:
	var data: Dictionary = {"version": 21}
	SaveManagerScript._apply_migrations(data)
	assert_eq(int(data.get("version", 0)), SaveManagerScript.CURRENT_SAVE_VERSION)
	assert_true(data.has("bestiary"))
	assert_true(data.has("bestiary_complete_rewarded"))

# ---------------------------------------------------------------------------
# Lore text on bundled enemies
# ---------------------------------------------------------------------------

func test_all_bundled_enemies_have_non_empty_lore_text() -> void:
	var all_ids: Array[String] = EnemyRegistry.get_all_enemy_ids()
	assert_gt(all_ids.size(), 0, "EnemyRegistry must return at least one enemy type")
	for type_id: String in all_ids:
		var lore: String = EnemyRegistry.get_lore_text(type_id)
		assert_true(lore.length() > 0, "Enemy '%s' must have non-empty lore_text" % type_id)

func test_get_all_enemy_ids_returns_array() -> void:
	var ids: Array[String] = EnemyRegistry.get_all_enemy_ids()
	assert_gt(ids.size(), 0, "get_all_enemy_ids must return at least one id")

func test_get_all_enemy_ids_contains_known_types() -> void:
	var ids: Array[String] = EnemyRegistry.get_all_enemy_ids()
	assert_has(ids, "undead_basic", "undead_basic must be in enemy id list")
	assert_has(ids, "undead_elite", "undead_elite must be in enemy id list")
