## GID-135 / TID-552 / TID-553, reworked by GID-141 / TID-588: a fight contains
## only what the player has learned from a trainer.
extends "res://tests/framework/test_case.gd"

const CombatOnboarding = preload("res://game_logic/battle/CombatOnboarding.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
const TutorialRegistry = preload("res://game_logic/TutorialRegistry.gd")

const TIPS: Array[String] = ["rt_intro", "rt_skill_mend", "rt_skill_kick", "rt_cards", "rt_low_hp",
	"rt_enemy_cast", "rt_out_of_mana", "rt_ally", "rt_add"]
const ALL: Array = ["mend", "kick", "feat_minions", "feat_spells"]

func test_stage_counts_combat_unlocks() -> void:
	assert_eq(CombatOnboarding.stage_for([]), 0)
	assert_eq(CombatOnboarding.stage_for(["mend"]), 1)
	assert_eq(CombatOnboarding.stage_for(["mend", "kick", "feat_minions"]), 3)
	assert_eq(CombatOnboarding.stage_for(ALL), -1, "all learned = the full fight")

func test_fresh_player_knows_only_strike() -> void:
	assert_eq(TechniqueDefs.known_cards([]), ["tech_strike"] as Array[String])
	assert_eq(TechniqueDefs.known_cards(["mend", "feat_minions"]), ["tech_strike", "tech_mend"] as Array[String])

func test_hand_and_spells_follow_the_ladder() -> void:
	assert_false(CombatOnboarding.shows_hand(["mend", "kick"]))
	assert_true(CombatOnboarding.shows_hand([UnlockLadder.FEAT_MINIONS]))
	assert_false(CombatOnboarding.allows_spells([UnlockLadder.FEAT_MINIONS]))
	assert_true(CombatOnboarding.allows_spells([UnlockLadder.FEAT_SPELLS]))

func test_slow_clock_only_first_fight() -> void:
	assert_true(CombatOnboarding.slow_clock(0, []))
	assert_false(CombatOnboarding.slow_clock(1, []))
	assert_false(CombatOnboarding.slow_clock(0, ALL), "migrated veterans never get the slow clock")

func test_handless_players_fight_in_real_time() -> void:
	assert_eq(CombatOnboarding.battle_mode("turn", []), "realtime")
	assert_eq(CombatOnboarding.battle_mode("realtime_slow", []), "realtime_slow")
	assert_eq(CombatOnboarding.battle_mode("turn", [UnlockLadder.FEAT_MINIONS]), "turn")

func test_every_tip_has_text() -> void:
	for id: String in TIPS:
		var e: Dictionary = TutorialRegistry.get_entry(id)
		assert_false(str(e.get("title", "")).is_empty(), id)
		assert_false(str(e.get("body", "")).is_empty(), id)

func test_early_levels_keep_fights_small() -> void:
	var early: int = CombatOnboarding.EARLY_LEVEL - 1
	assert_lt(CombatOnboarding.ally_cap(early), RealtimeCombat.MAX_ALLIES)
	assert_eq(CombatOnboarding.ally_cap(CombatOnboarding.EARLY_LEVEL), RealtimeCombat.MAX_ALLIES)
	assert_lt(CombatOnboarding.opening_hand(early), CombatOnboarding.opening_hand(CombatOnboarding.EARLY_LEVEL))
