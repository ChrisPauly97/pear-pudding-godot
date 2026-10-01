## GID-135 / TID-552 / TID-553, reworked by GID-141 / TID-588: a fight contains
## only what the player has learned from a trainer.
extends "res://tests/framework/test_case.gd"

const CombatOnboarding = preload("res://game_logic/battle/CombatOnboarding.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const SkillBar = preload("res://game_logic/battle/SkillBar.gd")
const TutorialRegistry = preload("res://game_logic/TutorialRegistry.gd")

const TIPS: Array[String] = ["rt_intro", "rt_skill_mend", "rt_skill_kick", "rt_cards", "rt_low_hp",
	"rt_enemy_cast", "rt_out_of_mana", "rt_ally", "rt_add"]
const ALL: Array = ["mend", "kick", "feat_minions", "feat_spells"]

func test_stage_counts_combat_unlocks() -> void:
	assert_eq(CombatOnboarding.stage_for([]), 0)
	assert_eq(CombatOnboarding.stage_for(["mend"]), 1)
	assert_eq(CombatOnboarding.stage_for(["mend", "kick", "feat_minions"]), 3)
	assert_eq(CombatOnboarding.stage_for(ALL), -1, "all learned = the full fight")

func test_fresh_player_bar_is_strike_only() -> void:
	assert_eq(SkillBar.new([], []).ids, ["strike"] as Array[String])
	assert_eq(SkillBar.new([], ["mend"]).ids, ["strike", "mend"] as Array[String])

func test_hand_and_spells_follow_the_ladder() -> void:
	assert_false(CombatOnboarding.shows_hand(["mend", "kick"]))
	assert_true(CombatOnboarding.shows_hand([UnlockLadder.FEAT_MINIONS]))
	assert_false(CombatOnboarding.allows_spells([UnlockLadder.FEAT_MINIONS]))
	assert_true(CombatOnboarding.allows_spells([UnlockLadder.FEAT_SPELLS]))

func test_enemy_minion_cap_follows_the_ladder() -> void:
	assert_eq(CombatOnboarding.enemy_minion_cap([]), 1, "a Strike-only hero still sees one summon")
	assert_eq(CombatOnboarding.enemy_minion_cap(["mend", "kick"]), 1)
	assert_eq(CombatOnboarding.enemy_minion_cap([UnlockLadder.FEAT_MINIONS]), RealtimeCombat.MAX_ENEMY_MINIONS)

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
