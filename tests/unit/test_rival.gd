## Unit tests for the Isfig rival system (TID-194).
##
## Covers: RivalSystem.get_rival_type() pure function, SaveManager rival fields
## migration round-trip, and EnemyRegistry registration of the three rival decks.
extends "res://tests/framework/test_case.gd"

const RivalSystem = preload("res://game_logic/RivalSystem.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const EnemyRegistryScript = preload("res://autoloads/EnemyRegistry.gd")

# ---------------------------------------------------------------------------
# RivalSystem.get_rival_type
# ---------------------------------------------------------------------------

func test_encounter_0_low_level_returns_tier1() -> void:
	assert_eq(RivalSystem.get_rival_type(0, 1), "rival_isfig_1")

func test_encounter_0_high_level_nudges_to_tier2() -> void:
	# Level 8 > (0+1)*5 = 5, so bumped to tier 2
	assert_eq(RivalSystem.get_rival_type(0, 8), "rival_isfig_2")

func test_encounter_1_low_level_returns_tier2() -> void:
	assert_eq(RivalSystem.get_rival_type(1, 1), "rival_isfig_2")

func test_encounter_1_high_level_nudges_to_tier3() -> void:
	# Level 12 > (1+1)*5 = 10, so bumped to tier 3
	assert_eq(RivalSystem.get_rival_type(1, 12), "rival_isfig_3")

func test_encounter_2_always_returns_tier3() -> void:
	assert_eq(RivalSystem.get_rival_type(2, 1), "rival_isfig_3")

func test_encounter_2_max_level_stays_tier3() -> void:
	# Already at max tier — no further bump
	assert_eq(RivalSystem.get_rival_type(2, 99), "rival_isfig_3")

func test_encounters_won_clamped_below_zero() -> void:
	# Negative values behave as 0
	assert_eq(RivalSystem.get_rival_type(-1, 1), "rival_isfig_1")

# ---------------------------------------------------------------------------
# SaveManager rival fields
# ---------------------------------------------------------------------------

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true

func after_each() -> void:
	_sm.free()

func test_default_rival_encounters_won_zero() -> void:
	assert_eq(_sm.rival_encounters_won, 0)

func test_default_rival_defeated_false() -> void:
	assert_false(_sm.rival_defeated)

func test_record_rival_win_increments() -> void:
	_sm.rival_encounters_won = 0
	_sm.record_rival_win()
	assert_eq(_sm.rival_encounters_won, 1)

func test_record_rival_win_capped_at_two() -> void:
	_sm.rival_encounters_won = 2
	_sm.record_rival_win()
	assert_eq(_sm.rival_encounters_won, 2)

func test_set_rival_defeated() -> void:
	_sm.rival_defeated = false
	_sm.set_rival_defeated()
	assert_true(_sm.rival_defeated)

func test_migration_backfills_rival_fields() -> void:
	var data: Dictionary = {"version": 31, "bag_size": 20}
	SaveManagerScript._apply_migrations(data)
	assert_eq(int(data.get("rival_encounters_won", -1)), 0)
	assert_false(bool(data.get("rival_defeated", true)))
	assert_eq(int(data.get("version", 0)), SaveManagerScript.CURRENT_SAVE_VERSION)

# ---------------------------------------------------------------------------
# EnemyRegistry rival deck registration
# ---------------------------------------------------------------------------

func test_rival_isfig_1_deck_non_empty() -> void:
	var deck: Array[String] = EnemyRegistryScript.get_deck("rival_isfig_1")
	assert_gt(deck.size(), 0)

func test_rival_isfig_2_deck_non_empty() -> void:
	var deck: Array[String] = EnemyRegistryScript.get_deck("rival_isfig_2")
	assert_gt(deck.size(), 0)

func test_rival_isfig_3_deck_non_empty() -> void:
	var deck: Array[String] = EnemyRegistryScript.get_deck("rival_isfig_3")
	assert_gt(deck.size(), 0)

func test_rival_isfig_1_display_name() -> void:
	assert_eq(EnemyRegistryScript.get_display_name("rival_isfig_1"), "Isfig")

func test_rival_isfig_2_display_name() -> void:
	assert_eq(EnemyRegistryScript.get_display_name("rival_isfig_2"), "Isfig the Pursuing")

func test_rival_isfig_3_display_name() -> void:
	assert_eq(EnemyRegistryScript.get_display_name("rival_isfig_3"), "Isfig, Maiteln's Shadow")

func test_rival_isfig_3_difficulty_tier() -> void:
	assert_eq(EnemyRegistryScript.get_difficulty_tier("rival_isfig_3"), 3)
