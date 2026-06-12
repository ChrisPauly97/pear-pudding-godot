## Unit tests for PuzzleRegistry.
extends "res://tests/framework/test_case.gd"

const PuzzleRegistry = preload("res://autoloads/PuzzleRegistry.gd")
const PuzzleData = preload("res://game_logic/battle/PuzzleData.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _pd(id: String) -> PuzzleData:
	return PuzzleRegistry.get_puzzle(id) as PuzzleData


# ---------------------------------------------------------------------------
# Registry lookup
# ---------------------------------------------------------------------------

func test_all_ids_not_empty() -> void:
	assert_gt(PuzzleRegistry.all_ids().size(), 0)


func test_get_puzzle_returns_nonnull_for_surge_lethal() -> void:
	assert_ne(_pd("puzzle_surge_lethal"), null)


func test_get_puzzle_returns_nonnull_for_ward_bypass() -> void:
	assert_ne(_pd("puzzle_ward_bypass"), null)


func test_get_puzzle_returns_nonnull_for_shroud_timing() -> void:
	assert_ne(_pd("puzzle_shroud_timing"), null)


func test_get_puzzle_returns_nonnull_for_attack_order() -> void:
	assert_ne(_pd("puzzle_attack_order"), null)


func test_get_puzzle_returns_nonnull_for_mana_efficiency() -> void:
	assert_ne(_pd("puzzle_mana_efficiency"), null)


func test_get_puzzle_returns_null_for_unknown_id() -> void:
	assert_eq(PuzzleRegistry.get_puzzle("nonexistent_puzzle"), null)


# ---------------------------------------------------------------------------
# PuzzleData fields
# ---------------------------------------------------------------------------

func test_surge_lethal_has_nonempty_title() -> void:
	var pd := _pd("puzzle_surge_lethal")
	assert_true(pd != null and pd.title != "")


func test_surge_lethal_has_positive_enemy_hero_hp() -> void:
	var pd := _pd("puzzle_surge_lethal")
	assert_gt(pd.enemy_hero_hp, 0)


func test_surge_lethal_has_reward_card() -> void:
	var pd := _pd("puzzle_surge_lethal")
	assert_ne(pd.reward_card_id, "")


func test_ward_bypass_has_enemy_board() -> void:
	var pd := _pd("puzzle_ward_bypass")
	assert_gt(pd.enemy_board.size(), 0)


func test_ward_bypass_has_enemy_board_buffs() -> void:
	var pd := _pd("puzzle_ward_bypass")
	assert_gt(pd.enemy_board_buffs.size(), 0)


func test_mana_efficiency_has_multiple_hand_cards() -> void:
	var pd := _pd("puzzle_mana_efficiency")
	assert_gt(pd.player_hand.size(), 1)


func test_mana_efficiency_has_five_mana() -> void:
	var pd := _pd("puzzle_mana_efficiency")
	assert_eq(pd.player_mana, 5)
