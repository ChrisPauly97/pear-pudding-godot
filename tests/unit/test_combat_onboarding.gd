## GID-135 / TID-552 / TID-553: real-time controls unlock one fight at a time.
extends "res://tests/framework/test_case.gd"

const CombatOnboarding = preload("res://game_logic/battle/CombatOnboarding.gd")
const SkillBar = preload("res://game_logic/battle/SkillBar.gd")
const TutorialRegistry = preload("res://game_logic/TutorialRegistry.gd")

const TIPS: Array[String] = ["rt_intro", "rt_skill_mend", "rt_skill_kick", "rt_cards", "rt_low_hp",
	"rt_enemy_cast", "rt_out_of_mana", "rt_ally", "rt_add"]

func test_ramp_unlocks_one_step_per_fight() -> void:
	var bar: Array[String] = SkillBar.DEFAULT_BAR
	assert_eq(CombatOnboarding.filter_skills(bar, CombatOnboarding.stage_for(0, 1)), ["strike"] as Array[String])
	assert_eq(CombatOnboarding.filter_skills(bar, CombatOnboarding.stage_for(1, 1)),
			["strike", "mend"] as Array[String])
	assert_eq(CombatOnboarding.filter_skills(bar, CombatOnboarding.stage_for(2, 1)), bar)
	assert_eq(CombatOnboarding.stage_for(3, 1), -1, "fight 4 is the full fight")
	assert_eq(CombatOnboarding.filter_skills(bar, -1), bar)

func test_hand_and_clock_per_stage() -> void:
	assert_false(CombatOnboarding.shows_hand(0))
	assert_false(CombatOnboarding.shows_hand(2))
	assert_true(CombatOnboarding.shows_hand(-1))
	assert_true(CombatOnboarding.slow_clock(0))
	assert_false(CombatOnboarding.slow_clock(1))
	assert_false(CombatOnboarding.slow_clock(-1))

func test_experienced_players_skip_the_ramp() -> void:
	assert_eq(CombatOnboarding.stage_for(0, CombatOnboarding.MAX_LEVEL + 1), -1)
	assert_eq(CombatOnboarding.stage_for(0, CombatOnboarding.MAX_LEVEL), 0)

func test_new_skills_per_stage() -> void:
	assert_eq(CombatOnboarding.new_skills(0), [] as Array[String])
	assert_eq(CombatOnboarding.new_skills(1), ["mend"] as Array[String])
	assert_eq(CombatOnboarding.new_skills(2), ["kick"] as Array[String])

func test_every_stage_skill_is_a_real_ability_with_a_tip() -> void:
	for stage: Dictionary in CombatOnboarding.STAGES:
		for id: Variant in stage["skills"]:
			assert_true(SkillBar.ABILITIES.has(str(id)), "unknown skill %s" % id)
	for s: int in CombatOnboarding.STAGES.size():
		for id: String in CombatOnboarding.new_skills(s):
			assert_false(TutorialRegistry.get_entry("rt_skill_" + id).is_empty(), "no tip for " + id)

func test_every_tip_has_text() -> void:
	for id: String in TIPS:
		var e: Dictionary = TutorialRegistry.get_entry(id)
		assert_false(str(e.get("title", "")).is_empty(), id)
		assert_false(str(e.get("body", "")).is_empty(), id)
