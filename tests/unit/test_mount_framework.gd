## Unit tests for the mount framework (TID-179 / GID-048).
##
## Covers SaveManager v23→v24 migration, summon/dismiss mutators,
## MountRegistry data, and the apply_migrations round-trip.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const MountRegistry     = preload("res://game_logic/MountRegistry.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# MountRegistry
# ---------------------------------------------------------------------------

func test_mount_registry_stable_horse_exists() -> void:
	var m: Dictionary = MountRegistry.get_mount("stable_horse")
	assert_false(m.is_empty(), "stable_horse must be in registry")

func test_mount_registry_stable_horse_id() -> void:
	var m: Dictionary = MountRegistry.get_mount("stable_horse")
	assert_eq(str(m.get("id", "")), "stable_horse")

func test_mount_registry_stable_horse_multiplier() -> void:
	var m: Dictionary = MountRegistry.get_mount("stable_horse")
	assert_almost_eq(float(m.get("speed_multiplier", 0.0)), 2.0)

func test_mount_registry_stable_horse_price() -> void:
	var m: Dictionary = MountRegistry.get_mount("stable_horse")
	assert_eq(int(m.get("price", 0)), 750)

func test_mount_registry_unknown_returns_empty() -> void:
	var m: Dictionary = MountRegistry.get_mount("nonexistent_mount")
	assert_true(m.is_empty())

func test_mount_registry_get_all_has_one_entry() -> void:
	var all: Array[Dictionary] = MountRegistry.get_all()
	assert_eq(all.size(), 1)

# ---------------------------------------------------------------------------
# Migration v23 → v24
# ---------------------------------------------------------------------------

func test_migration_v23_v24_adds_owned_mounts() -> void:
	var data: Dictionary = {"version": 23}
	SaveManagerScript._migrate_v23_to_v24(data)
	assert_true(data.has("owned_mounts"), "owned_mounts must exist after migration")

func test_migration_v23_v24_owned_mounts_default_empty() -> void:
	var data: Dictionary = {"version": 23}
	SaveManagerScript._migrate_v23_to_v24(data)
	assert_eq(int((data["owned_mounts"] as Array).size()), 0)

func test_migration_v23_v24_adds_active_mount() -> void:
	var data: Dictionary = {"version": 23}
	SaveManagerScript._migrate_v23_to_v24(data)
	assert_true(data.has("active_mount"))
	assert_eq(str(data["active_mount"]), "")

func test_migration_v23_v24_adds_is_mounted() -> void:
	var data: Dictionary = {"version": 23}
	SaveManagerScript._migrate_v23_to_v24(data)
	assert_true(data.has("is_mounted"))
	assert_false(bool(data["is_mounted"]))

func test_migration_v23_v24_bumps_version() -> void:
	var data: Dictionary = {"version": 23}
	SaveManagerScript._migrate_v23_to_v24(data)
	assert_eq(int(data["version"]), 24)

func test_migration_v23_v24_preserves_existing_owned_mounts() -> void:
	var data: Dictionary = {"version": 23, "owned_mounts": ["stable_horse"]}
	SaveManagerScript._migrate_v23_to_v24(data)
	assert_eq(int((data["owned_mounts"] as Array).size()), 1)

# ---------------------------------------------------------------------------
# apply_migrations round-trip from v23
# ---------------------------------------------------------------------------

func test_apply_migrations_reaches_v24_from_v23() -> void:
	var data: Dictionary = {"version": 23}
	SaveManagerScript._apply_migrations(data)
	assert_eq(int(data.get("version", 0)), SaveManagerScript.CURRENT_SAVE_VERSION)
	assert_true(data.has("owned_mounts"))
	assert_true(data.has("active_mount"))
	assert_true(data.has("is_mounted"))

# ---------------------------------------------------------------------------
# SaveManager defaults
# ---------------------------------------------------------------------------

func test_sm_owned_mounts_default_empty() -> void:
	assert_eq(_sm.owned_mounts.size(), 0)

func test_sm_active_mount_default_empty() -> void:
	assert_eq(_sm.active_mount, "")

func test_sm_is_mounted_default_false() -> void:
	assert_false(_sm.is_mounted)

# ---------------------------------------------------------------------------
# summon_mount / dismiss_mount
# ---------------------------------------------------------------------------

func test_summon_mount_sets_active_mount() -> void:
	_sm.owned_mounts.append("stable_horse")
	_sm.summon_mount("stable_horse")
	assert_eq(_sm.active_mount, "stable_horse")

func test_summon_mount_sets_is_mounted_true() -> void:
	_sm.owned_mounts.append("stable_horse")
	_sm.summon_mount("stable_horse")
	assert_true(_sm.is_mounted)

func test_summon_mount_fails_when_not_owned() -> void:
	_sm.summon_mount("stable_horse")
	assert_eq(_sm.active_mount, "")
	assert_false(_sm.is_mounted)

func test_dismiss_mount_clears_active_mount() -> void:
	_sm.owned_mounts.append("stable_horse")
	_sm.summon_mount("stable_horse")
	_sm.dismiss_mount()
	assert_eq(_sm.active_mount, "")

func test_dismiss_mount_sets_is_mounted_false() -> void:
	_sm.owned_mounts.append("stable_horse")
	_sm.summon_mount("stable_horse")
	_sm.dismiss_mount()
	assert_false(_sm.is_mounted)

# ---------------------------------------------------------------------------
# Speed multiplier math (pure arithmetic, no Player node required)
# ---------------------------------------------------------------------------

func test_speed_multiplier_value_for_stable_horse() -> void:
	const BASE_SPEED: float = 6.0
	var m: Dictionary = MountRegistry.get_mount("stable_horse")
	var multiplier: float = float(m.get("speed_multiplier", 1.0))
	assert_almost_eq(BASE_SPEED * multiplier, 12.0)

func test_speed_without_mount_is_base() -> void:
	const BASE_SPEED: float = 6.0
	assert_almost_eq(BASE_SPEED * 1.0, 6.0)
