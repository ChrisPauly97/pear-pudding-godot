## Unit tests for the player home & trophy hall (GID-046).
##
## Tests cover SaveManager v21→v22 (home_owned) and v22→v23 (respawn fields),
## TrophyRegistry predicate evaluation, and respawn helper methods.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const TrophyRegistry    = preload("res://game_logic/TrophyRegistry.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# Migration v21 → v22: home_owned
# ---------------------------------------------------------------------------

func test_migration_v21_v22_adds_home_owned() -> void:
	var data: Dictionary = {"version": 21}
	SaveManagerScript._migrate_v21_to_v22(data)
	assert_true(data.has("home_owned"), "home_owned key must exist after v22 migration")

func test_migration_v21_v22_defaults_home_owned_false() -> void:
	var data: Dictionary = {"version": 21}
	SaveManagerScript._migrate_v21_to_v22(data)
	assert_false(bool(data["home_owned"]), "home_owned default must be false")

func test_migration_v21_v22_bumps_version() -> void:
	var data: Dictionary = {"version": 21}
	SaveManagerScript._migrate_v21_to_v22(data)
	assert_eq(data["version"], 22)

func test_migration_v21_v22_preserves_existing_home_owned_true() -> void:
	var data: Dictionary = {"version": 21, "home_owned": true}
	SaveManagerScript._migrate_v21_to_v22(data)
	assert_true(bool(data["home_owned"]), "existing home_owned = true must be preserved")

# ---------------------------------------------------------------------------
# Migration v22 → v23: respawn fields
# ---------------------------------------------------------------------------

func test_migration_v22_v23_adds_respawn_map() -> void:
	var data: Dictionary = {"version": 22}
	SaveManagerScript._migrate_v22_to_v23(data)
	assert_true(data.has("respawn_map"), "respawn_map must exist after v23 migration")

func test_migration_v22_v23_defaults_respawn_map_empty() -> void:
	var data: Dictionary = {"version": 22}
	SaveManagerScript._migrate_v22_to_v23(data)
	assert_eq(str(data["respawn_map"]), "")

func test_migration_v22_v23_adds_respawn_x_and_z() -> void:
	var data: Dictionary = {"version": 22}
	SaveManagerScript._migrate_v22_to_v23(data)
	assert_true(data.has("respawn_x"), "respawn_x must exist")
	assert_true(data.has("respawn_z"), "respawn_z must exist")

func test_migration_v22_v23_defaults_respawn_coords_zero() -> void:
	var data: Dictionary = {"version": 22}
	SaveManagerScript._migrate_v22_to_v23(data)
	assert_eq(float(data["respawn_x"]), 0.0)
	assert_eq(float(data["respawn_z"]), 0.0)

func test_migration_v22_v23_bumps_version() -> void:
	var data: Dictionary = {"version": 22}
	SaveManagerScript._migrate_v22_to_v23(data)
	assert_eq(data["version"], 23)

func test_apply_migrations_reaches_v23_from_v21() -> void:
	var data: Dictionary = {"version": 21}
	SaveManagerScript._apply_migrations(data)
	assert_eq(int(data.get("version", 0)), SaveManagerScript.CURRENT_SAVE_VERSION)
	assert_true(data.has("home_owned"))
	assert_true(data.has("respawn_map"))
	assert_true(data.has("respawn_x"))
	assert_true(data.has("respawn_z"))

# ---------------------------------------------------------------------------
# SaveManager home_owned and respawn API
# ---------------------------------------------------------------------------

func test_home_owned_defaults_false() -> void:
	assert_false(_sm.home_owned)

func test_respawn_fields_default_empty() -> void:
	assert_eq(_sm.respawn_map, "")
	assert_eq(_sm.respawn_x, 0.0)
	assert_eq(_sm.respawn_z, 0.0)

func test_set_respawn_point_stores_values() -> void:
	_sm.set_respawn_point("player_home", 100.0, 106.0)
	assert_eq(_sm.respawn_map, "player_home")
	assert_eq(_sm.respawn_x, 100.0)
	assert_eq(_sm.respawn_z, 106.0)

func test_has_respawn_point_false_when_no_map() -> void:
	_sm.home_owned = true
	assert_false(_sm.has_respawn_point())

func test_has_respawn_point_false_when_not_home_owned() -> void:
	_sm.set_respawn_point("player_home", 100.0, 106.0)
	_sm.home_owned = false
	assert_false(_sm.has_respawn_point())

func test_has_respawn_point_true_when_owned_and_map_set() -> void:
	_sm.home_owned = true
	_sm.set_respawn_point("player_home", 100.0, 106.0)
	assert_true(_sm.has_respawn_point())

# ---------------------------------------------------------------------------
# TrophyRegistry get_all / get_trophy
# ---------------------------------------------------------------------------

func test_trophy_registry_has_three_trophies() -> void:
	var all: Array[Dictionary] = TrophyRegistry.get_all()
	assert_eq(all.size(), 3)

func test_trophy_registry_get_champion() -> void:
	var t: Dictionary = TrophyRegistry.get_trophy("champion")
	assert_false(t.is_empty(), "champion trophy must exist")
	assert_eq(str(t["id"]), "champion")

func test_trophy_registry_get_spire_7() -> void:
	var t: Dictionary = TrophyRegistry.get_trophy("spire_7")
	assert_false(t.is_empty(), "spire_7 trophy must exist")

func test_trophy_registry_get_first_boss() -> void:
	var t: Dictionary = TrophyRegistry.get_trophy("first_boss")
	assert_false(t.is_empty(), "first_boss trophy must exist")

func test_trophy_registry_get_unknown_returns_empty() -> void:
	var t: Dictionary = TrophyRegistry.get_trophy("nonexistent")
	assert_true(t.is_empty())

# ---------------------------------------------------------------------------
# TrophyRegistry predicate: champion
# ---------------------------------------------------------------------------

func test_champion_not_earned_with_empty_duelists() -> void:
	_sm.defeated_duelists = []
	assert_false(TrophyRegistry.is_earned("champion", _sm))

func test_champion_earned_with_one_defeated_duelist() -> void:
	_sm.defeated_duelists = ["npc_duelist_1"]
	assert_true(TrophyRegistry.is_earned("champion", _sm))

# ---------------------------------------------------------------------------
# TrophyRegistry predicate: spire_7
# ---------------------------------------------------------------------------

func test_spire_7_not_earned_when_best_floor_zero() -> void:
	_sm.spire_best_floor = 0
	assert_false(TrophyRegistry.is_earned("spire_7", _sm))

func test_spire_7_not_earned_when_best_floor_six() -> void:
	_sm.spire_best_floor = 6
	assert_false(TrophyRegistry.is_earned("spire_7", _sm))

func test_spire_7_earned_when_best_floor_seven() -> void:
	_sm.spire_best_floor = 7
	assert_true(TrophyRegistry.is_earned("spire_7", _sm))

func test_spire_7_earned_when_best_floor_ten() -> void:
	_sm.spire_best_floor = 10
	assert_true(TrophyRegistry.is_earned("spire_7", _sm))

# ---------------------------------------------------------------------------
# TrophyRegistry predicate: first_boss (graceful fallback)
# ---------------------------------------------------------------------------

func test_first_boss_not_earned_with_empty_defeated_enemies() -> void:
	_sm.defeated_enemies = []
	assert_false(TrophyRegistry.is_earned("first_boss", _sm))

func test_first_boss_graceful_fallback_when_enemy_type_unknown() -> void:
	_sm.defeated_enemies = ["enemy_cx0_cz0_0"]
	# World enemy IDs are not boss type IDs — is_earned returns false gracefully.
	var result: bool = TrophyRegistry.is_earned("first_boss", _sm)
	assert_false(result, "Unknown enemy id must not be treated as boss")

# ---------------------------------------------------------------------------
# TrophyRegistry: unknown trophy id
# ---------------------------------------------------------------------------

func test_is_earned_returns_false_for_unknown_trophy() -> void:
	assert_false(TrophyRegistry.is_earned("nonexistent", _sm))
