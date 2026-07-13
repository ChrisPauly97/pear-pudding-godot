## Unit tests for TID-443 (BID-049): new_game() baseline vs. opt-in Head Start.
## A fresh save must be a true level-1 start; the boosted start is opt-in only.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")


func test_new_game_default_is_level_one() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	assert_eq(sm.level, 1)
	assert_eq(sm.xp, 0)
	assert_eq(sm.skill_points, 0)

func test_new_game_default_coins_are_small_float() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	assert_eq(sm.coins, 50)

func test_new_game_head_start_values() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game(true)
	assert_eq(sm.level, 15)
	assert_eq(sm.xp, 11250)
	assert_eq(sm.skill_points, 14)
	assert_eq(sm.coins, 5000)

func test_head_start_level_consistent_with_xp_curve() -> void:
	assert_eq(SaveManagerScript._compute_level(11250), 15,
		"head-start xp must map to head-start level so the next level-up behaves normally")

func test_default_start_first_level_up_reachable() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	sm.add_xp(200)  # xp_for_level(2) == 200
	assert_eq(sm.level, 2)
	assert_eq(sm.skill_points, 1)
