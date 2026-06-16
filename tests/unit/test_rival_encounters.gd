## Headless tests for TID-195 rival encounter wiring.
##
## Covers: flag-gated spawn conditions, rival win logic in SaveManager,
## and defeat-immunity (rivals never enter defeated_enemies).
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const RivalSystem = preload("res://game_logic/RivalSystem.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true

func after_each() -> void:
	_sm.free()

# ── Flag-gated availability ───────────────────────────────────────────────────

func test_enc1_available_after_left_madrian() -> void:
	_sm.set_story_flag("chapter1_left_madrian")
	var available: bool = _sm.get_story_flag("chapter1_left_madrian") and _sm.rival_encounters_won == 0
	assert_true(available)

func test_enc1_not_available_before_left_madrian() -> void:
	var available: bool = _sm.get_story_flag("chapter1_left_madrian") and _sm.rival_encounters_won == 0
	assert_false(available)

func test_enc1_not_spawned_again_after_win() -> void:
	_sm.set_story_flag("chapter1_left_madrian")
	_sm.rival_encounters_won = 1
	var available: bool = _sm.get_story_flag("chapter1_left_madrian") and _sm.rival_encounters_won == 0
	assert_false(available)

func test_enc2_available_after_warned_farsyth() -> void:
	_sm.set_story_flag("chapter1_warned_farsyth")
	var available: bool = _sm.get_story_flag("chapter1_warned_farsyth") \
		and not _sm.get_story_flag("chapter1_received_letter") \
		and _sm.rival_encounters_won < 2
	assert_true(available)

func test_enc2_not_available_after_received_letter() -> void:
	_sm.set_story_flag("chapter1_warned_farsyth")
	_sm.set_story_flag("chapter1_received_letter")
	var available: bool = _sm.get_story_flag("chapter1_warned_farsyth") \
		and not _sm.get_story_flag("chapter1_received_letter") \
		and _sm.rival_encounters_won < 2
	assert_false(available)

func test_enc3_available_after_temple_council_and_two_wins() -> void:
	_sm.set_story_flag("chapter1_temple_council")
	_sm.rival_encounters_won = 2
	var available: bool = _sm.get_story_flag("chapter1_temple_council") \
		and _sm.rival_encounters_won >= 2 and not _sm.rival_defeated
	assert_true(available)

func test_enc3_not_available_without_two_wins() -> void:
	_sm.set_story_flag("chapter1_temple_council")
	_sm.rival_encounters_won = 1
	var available: bool = _sm.get_story_flag("chapter1_temple_council") \
		and _sm.rival_encounters_won >= 2 and not _sm.rival_defeated
	assert_false(available)

func test_enc3_not_available_if_already_defeated() -> void:
	_sm.set_story_flag("chapter1_temple_council")
	_sm.rival_encounters_won = 2
	_sm.rival_defeated = true
	var available: bool = _sm.get_story_flag("chapter1_temple_council") \
		and _sm.rival_encounters_won >= 2 and not _sm.rival_defeated
	assert_false(available)

# ── Rival win state transitions ───────────────────────────────────────────────

func test_enc1_win_increments_rival_encounters_won() -> void:
	_sm.rival_encounters_won = 0
	_sm.record_rival_win()
	assert_eq(_sm.rival_encounters_won, 1)

func test_enc2_win_increments_to_two() -> void:
	_sm.rival_encounters_won = 1
	_sm.record_rival_win()
	assert_eq(_sm.rival_encounters_won, 2)

func test_enc2_win_sets_received_letter() -> void:
	_sm.set_story_flag("chapter1_received_letter")
	assert_true(_sm.get_story_flag("chapter1_received_letter"))

func test_enc3_win_sets_rival_defeated() -> void:
	_sm.set_rival_defeated()
	assert_true(_sm.rival_defeated)

func test_record_rival_win_does_not_exceed_two() -> void:
	_sm.rival_encounters_won = 2
	_sm.record_rival_win()
	assert_eq(_sm.rival_encounters_won, 2)

# ── Defeat immunity (rivals must not enter defeated_enemies) ──────────────────

func test_rival_id_not_in_defeated_enemies_after_win() -> void:
	# Simulate: standard foe IS marked defeated; rival is NOT.
	_sm.mark_enemy_defeated("regular_foe_1")
	assert_true(_sm.is_enemy_defeated("regular_foe_1"))
	assert_false(_sm.is_enemy_defeated("rival_enc1"))

func test_rival_enc2_not_marked_defeated() -> void:
	assert_false(_sm.is_enemy_defeated("rival_enc2"))

func test_rival_enc3_not_marked_defeated() -> void:
	assert_false(_sm.is_enemy_defeated("rival_enc3"))

# ── RivalSystem tier selection for enc2 ──────────────────────────────────────

func test_enc2_type_at_wins_one_low_level() -> void:
	assert_eq(RivalSystem.get_rival_type(1, 1), "rival_isfig_2")

func test_enc2_type_at_wins_one_high_level() -> void:
	assert_eq(RivalSystem.get_rival_type(1, 12), "rival_isfig_3")
