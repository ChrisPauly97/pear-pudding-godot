## Unit tests for VeterancyUtil.
extends "res://tests/framework/test_case.gd"

const VeterancyUtil = preload("res://game_logic/VeterancyUtil.gd")

# ---------------------------------------------------------------------------
# rank_for — threshold tests
# ---------------------------------------------------------------------------

func test_rank_zero_with_no_kills_or_battles() -> void:
	assert_eq(VeterancyUtil.rank_for(0, 0), 0)

func test_rank_zero_below_all_thresholds() -> void:
	assert_eq(VeterancyUtil.rank_for(4, 9), 0)

func test_rank_one_via_kills_threshold() -> void:
	assert_eq(VeterancyUtil.rank_for(5, 0), 1)

func test_rank_one_via_battles_threshold() -> void:
	assert_eq(VeterancyUtil.rank_for(0, 10), 1)

func test_rank_two_via_kills_threshold() -> void:
	assert_eq(VeterancyUtil.rank_for(15, 0), 2)

func test_rank_two_via_battles_threshold() -> void:
	assert_eq(VeterancyUtil.rank_for(0, 25), 2)

func test_rank_three_via_kills_threshold() -> void:
	assert_eq(VeterancyUtil.rank_for(40, 0), 3)

func test_rank_three_via_battles_threshold() -> void:
	assert_eq(VeterancyUtil.rank_for(0, 60), 3)

func test_rank_three_stays_at_three_with_huge_numbers() -> void:
	assert_eq(VeterancyUtil.rank_for(1000, 1000), 3)

# ---------------------------------------------------------------------------
# title_for
# ---------------------------------------------------------------------------

func test_title_for_rank_zero_is_empty() -> void:
	assert_eq(VeterancyUtil.title_for(0), "")

func test_title_for_rank_one_is_non_empty() -> void:
	assert_ne(VeterancyUtil.title_for(1), "")

func test_title_for_rank_two_is_non_empty() -> void:
	assert_ne(VeterancyUtil.title_for(2), "")

func test_title_for_rank_three_is_non_empty() -> void:
	assert_ne(VeterancyUtil.title_for(3), "")

func test_title_for_out_of_range_is_empty() -> void:
	assert_eq(VeterancyUtil.title_for(4), "")

# ---------------------------------------------------------------------------
# hp_bonus_for
# ---------------------------------------------------------------------------

func test_hp_bonus_rank_zero_is_zero() -> void:
	assert_eq(VeterancyUtil.hp_bonus_for(0), 0)

func test_hp_bonus_rank_one_is_one() -> void:
	assert_eq(VeterancyUtil.hp_bonus_for(1), 1)

func test_hp_bonus_rank_two_is_two() -> void:
	assert_eq(VeterancyUtil.hp_bonus_for(2), 2)

func test_hp_bonus_rank_three_is_three() -> void:
	assert_eq(VeterancyUtil.hp_bonus_for(3), 3)

# ---------------------------------------------------------------------------
# atk_bonus_for
# ---------------------------------------------------------------------------

func test_atk_bonus_rank_zero_is_zero() -> void:
	assert_eq(VeterancyUtil.atk_bonus_for(0), 0)

func test_atk_bonus_rank_one_is_zero() -> void:
	assert_eq(VeterancyUtil.atk_bonus_for(1), 0)

func test_atk_bonus_rank_two_is_one() -> void:
	assert_eq(VeterancyUtil.atk_bonus_for(2), 1)

func test_atk_bonus_rank_three_is_two() -> void:
	assert_eq(VeterancyUtil.atk_bonus_for(3), 2)

# ---------------------------------------------------------------------------
# display_name
# ---------------------------------------------------------------------------

func test_display_name_uses_custom_name_when_set() -> void:
	var inst := {"kills": 100, "battles_survived": 100, "custom_name": "Sir Bones"}
	assert_eq(VeterancyUtil.display_name(inst, "Skeleton"), "Sir Bones")

func test_display_name_uses_base_name_at_rank_zero() -> void:
	var inst := {"kills": 0, "battles_survived": 0, "custom_name": ""}
	assert_eq(VeterancyUtil.display_name(inst, "Ghost"), "Ghost")

func test_display_name_appends_title_at_rank_one() -> void:
	var inst := {"kills": 5, "battles_survived": 0, "custom_name": ""}
	var result: String = VeterancyUtil.display_name(inst, "Ghost")
	assert_true(result.begins_with("Ghost "), "should start with base name")
	assert_true(result.length() > "Ghost ".length(), "should have title appended")

func test_display_name_custom_name_overrides_title_even_at_high_rank() -> void:
	var inst := {"kills": 200, "battles_survived": 200, "custom_name": "Reaper"}
	assert_eq(VeterancyUtil.display_name(inst, "Zombie"), "Reaper")

func test_display_name_missing_fields_treated_as_zeros() -> void:
	var inst: Dictionary = {}
	assert_eq(VeterancyUtil.display_name(inst, "Ghoul"), "Ghoul")
