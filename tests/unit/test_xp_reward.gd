## Unit tests for GID-069 TID-252: EnemyRegistry.get_xp_reward and speed setting.
extends "res://tests/framework/test_case.gd"

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# EnemyRegistry.get_xp_reward
# ---------------------------------------------------------------------------

func test_xp_reward_undead_basic() -> void:
	assert_eq(EnemyRegistry.get_xp_reward("undead_basic", false), 20)

func test_xp_reward_undead_horde() -> void:
	assert_eq(EnemyRegistry.get_xp_reward("undead_horde", false), 35)

func test_xp_reward_ghoul_pack() -> void:
	assert_eq(EnemyRegistry.get_xp_reward("ghoul_pack", false), 50)

func test_xp_reward_undead_elite() -> void:
	assert_eq(EnemyRegistry.get_xp_reward("undead_elite", false), 80)

func test_xp_reward_roaming_terror() -> void:
	assert_eq(EnemyRegistry.get_xp_reward("roaming_terror", false), 150)

func test_xp_reward_default_unknown() -> void:
	assert_eq(EnemyRegistry.get_xp_reward("some_unknown_enemy", false), 25)

func test_xp_reward_boss_double() -> void:
	assert_eq(EnemyRegistry.get_xp_reward("undead_basic", true), 40, "boss doubles base XP")

func test_xp_reward_boss_elite_double() -> void:
	assert_eq(EnemyRegistry.get_xp_reward("undead_elite", true), 160)

# ---------------------------------------------------------------------------
# battle_speed setting round-trip
# ---------------------------------------------------------------------------

func test_battle_speed_default_is_normal() -> void:
	var val: String = str(_sm.get_setting("battle_speed", "normal"))
	assert_eq(val, "normal")

func test_battle_speed_set_fast_persists() -> void:
	_sm.set_setting("battle_speed", "fast")
	var val: String = str(_sm.get_setting("battle_speed", "normal"))
	assert_eq(val, "fast")

func test_battle_speed_set_normal_persists() -> void:
	_sm.set_setting("battle_speed", "fast")
	_sm.set_setting("battle_speed", "normal")
	var val: String = str(_sm.get_setting("battle_speed", "normal"))
	assert_eq(val, "normal")
