## Unit tests for ScriptedBattleRegistry (GID-108).
extends "res://tests/framework/test_case.gd"

const ScriptedBattleRegistry = preload("res://autoloads/ScriptedBattleRegistry.gd")
const ScriptedBattleData = preload("res://game_logic/battle/ScriptedBattleData.gd")

func _sb(id: String) -> ScriptedBattleData:
	return ScriptedBattleRegistry.get_battle(id) as ScriptedBattleData


func test_all_ids_not_empty() -> void:
	assert_gt(ScriptedBattleRegistry.all_ids().size(), 0)


func test_get_battle_returns_nonnull_for_scripted_test() -> void:
	assert_ne(_sb("scripted_test"), null)


func test_get_battle_returns_null_for_unknown_id() -> void:
	assert_eq(ScriptedBattleRegistry.get_battle("nonexistent_scripted_battle"), null)


func test_scripted_test_has_nonempty_player_deck_order() -> void:
	var sd := _sb("scripted_test")
	assert_gt(sd.player_deck_order.size(), 0)


func test_scripted_test_validates_clean() -> void:
	var sd := _sb("scripted_test")
	assert_eq(sd.validate().size(), 0)
