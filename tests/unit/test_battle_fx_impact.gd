## Unit tests for BattleFx's pure impact-animation helpers (TID-426).
##
## Full tween-driven animation isn't practical to assert headlessly, so this
## covers the two pieces that are pure logic: the fast-mode duration scalar
## and diff-based death detection (used by both the player-attack path and
## the AI-turn loop to know which panels need a death beat).
extends "res://tests/framework/test_case.gd"

const BattleFx = preload("res://scenes/battle/BattleFx.gd")

func test_scaled_duration_normal_speed_is_unchanged() -> void:
	assert_almost_eq(BattleFx.scaled_duration(0.2, 1.0), 0.2)

func test_scaled_duration_fast_mode_shrinks_roughly_in_half() -> void:
	var fast: float = BattleFx.scaled_duration(0.2, 0.45)
	assert_almost_eq(fast, 0.09)
	assert_lt(fast, 0.2)

func test_scaled_duration_never_reaches_zero() -> void:
	assert_gt(BattleFx.scaled_duration(0.2, 0.0), 0.0)

func test_detect_deaths_finds_missing_card_id() -> void:
	var snap: Array[Dictionary] = [
		{"id": "hero_0", "hp": 30, "pos": Vector2.ZERO},
		{"id": "card_a", "hp": 3, "pos": Vector2.ZERO, "zone": "board", "slot_idx": 0},
		{"id": "card_b", "hp": 2, "pos": Vector2.ZERO, "zone": "board", "slot_idx": 1},
	]
	var alive_ids: Array[String] = ["card_a"]
	var dead: Array[String] = BattleFx.detect_deaths(snap, alive_ids)
	assert_eq(dead.size(), 1)
	assert_eq(dead[0], "card_b")

func test_detect_deaths_ignores_hero_entries() -> void:
	var snap: Array[Dictionary] = [
		{"id": "hero_0", "hp": 0, "pos": Vector2.ZERO},
		{"id": "hero_1", "hp": 30, "pos": Vector2.ZERO},
	]
	var dead: Array[String] = BattleFx.detect_deaths(snap, [])
	assert_true(dead.is_empty(), "hero deaths are not board-panel death animations")

func test_detect_deaths_empty_when_all_alive() -> void:
	var snap: Array[Dictionary] = [
		{"id": "card_a", "hp": 3, "pos": Vector2.ZERO, "zone": "board", "slot_idx": 0},
	]
	var dead: Array[String] = BattleFx.detect_deaths(snap, ["card_a"])
	assert_true(dead.is_empty())
