## Unit tests for BattleResultUI.count_up_steps (TID-429): the pure step
## sequence generator behind the victory-screen coin/XP count-up ticker.
extends "res://tests/framework/test_case.gd"

const BattleResultUI = preload("res://scenes/battle/BattleResultUI.gd")

func test_zero_target_returns_single_zero_step() -> void:
	var steps: Array[int] = BattleResultUI.count_up_steps(0)
	assert_eq(steps, [0])

func test_negative_target_returns_single_zero_step() -> void:
	var steps: Array[int] = BattleResultUI.count_up_steps(-5)
	assert_eq(steps, [0])

func test_last_step_always_equals_target() -> void:
	for target in [1, 3, 8, 37, 1000]:
		var steps: Array[int] = BattleResultUI.count_up_steps(target)
		assert_eq(steps[steps.size() - 1], target, "target=%d" % target)

func test_step_count_capped_at_max_steps() -> void:
	var steps: Array[int] = BattleResultUI.count_up_steps(1000, 8)
	assert_eq(steps.size(), 8)

func test_small_target_does_not_over_produce_steps() -> void:
	# A target smaller than max_steps shouldn't produce more steps than the target itself.
	var steps: Array[int] = BattleResultUI.count_up_steps(3, 8)
	assert_eq(steps.size(), 3)
	assert_eq(steps, [1, 2, 3])

func test_steps_are_non_decreasing() -> void:
	var steps: Array[int] = BattleResultUI.count_up_steps(53, 8)
	for i in range(1, steps.size()):
		assert_gte(steps[i], steps[i - 1], "step %d should not decrease" % i)
