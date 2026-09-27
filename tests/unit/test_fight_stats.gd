## GID-135 / TID-559: per-fight real-time stats + the pure post-fight tip rule.
extends "res://tests/framework/test_case.gd"

const FightStats = preload("res://game_logic/battle/FightStats.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")

func test_record_tick_accumulates_duration_and_mana_time() -> void:
	var s := FightStats.new()
	s.record_tick(1.0, 500, 500)
	s.record_tick(1.0, 0, 500)
	s.record_tick(1.0, 250, 500)
	assert_eq(s.duration, 3.0)
	assert_eq(s.time_at_full_mana, 1.0)
	assert_eq(s.time_at_empty_mana, 1.0)

func test_record_hp_fraction_tracks_the_lowest() -> void:
	var s := FightStats.new()
	assert_eq(s.lowest_hp_fraction, 1.0)
	s.record_hp_fraction(0.8)
	s.record_hp_fraction(0.2)
	s.record_hp_fraction(0.5)
	assert_eq(s.lowest_hp_fraction, 0.2)

func test_record_potion_used_only_counts_low_hp() -> void:
	var s := FightStats.new()
	s.record_potion_used(0.9)
	assert_eq(s.potions_used_low_hp, 0)
	s.record_potion_used(0.3)
	assert_eq(s.potions_used_low_hp, 1)

func test_to_dict_round_trips_fields() -> void:
	var s := FightStats.new()
	s.record_skill_use()
	s.record_enemy_cast_completed()
	s.record_interrupt()
	s.record_autoattack_damage(5)
	s.record_card_damage(3)
	var d: Dictionary = s.to_dict()
	assert_eq(int(d["skill_uses"]), 1)
	assert_eq(int(d["enemy_casts_completed"]), 1)
	assert_eq(int(d["interrupts_landed"]), 1)
	assert_eq(int(d["autoattack_damage"]), 5)
	assert_eq(int(d["card_damage"]), 3)

func test_pick_tip_uncontested_casts_wins_first() -> void:
	var tip: String = FightStats.pick_tip({
		"enemy_casts_completed": 3, "interrupts_landed": 0,
		"time_at_full_mana": 40.0, "lowest_hp_fraction": 0.1, "potions_used_low_hp": 0,
	})
	assert_true(tip.contains("casts"), tip)

func test_pick_tip_skips_uncontested_casts_when_interrupted() -> void:
	var tip: String = FightStats.pick_tip({
		"enemy_casts_completed": 3, "interrupts_landed": 1,
		"time_at_full_mana": 40.0, "lowest_hp_fraction": 1.0, "potions_used_low_hp": 0,
	})
	assert_true(tip.contains("full mana"), tip)

func test_pick_tip_full_mana() -> void:
	var tip: String = FightStats.pick_tip({"time_at_full_mana": 35.0, "lowest_hp_fraction": 1.0})
	assert_true(tip.contains("full mana"), tip)

func test_pick_tip_low_hp_without_healing() -> void:
	var tip: String = FightStats.pick_tip({
		"time_at_full_mana": 0.0, "lowest_hp_fraction": 0.2, "potions_used_low_hp": 0,
	})
	assert_true(tip.contains("health"), tip)

func test_pick_tip_low_hp_suppressed_when_healed() -> void:
	var tip: String = FightStats.pick_tip({
		"time_at_full_mana": 0.0, "lowest_hp_fraction": 0.2, "potions_used_low_hp": 1,
		"duration": 5.0, "skill_uses": 5,
	})
	assert_eq(tip, "")

func test_pick_tip_few_skills_used() -> void:
	var tip: String = FightStats.pick_tip({
		"time_at_full_mana": 0.0, "lowest_hp_fraction": 1.0, "duration": 25.0, "skill_uses": 1,
	})
	assert_true(tip.contains("Strike") or tip.contains("hand"), tip)

func test_pick_tip_nothing_notable_returns_empty() -> void:
	var tip: String = FightStats.pick_tip({
		"enemy_casts_completed": 1, "interrupts_landed": 1, "time_at_full_mana": 2.0,
		"lowest_hp_fraction": 0.9, "potions_used_low_hp": 0, "duration": 10.0, "skill_uses": 4,
	})
	assert_eq(tip, "")

func test_enemy_health_sums_enemy_hero_and_board() -> void:
	var gs := GameState.new()
	var rt := RealtimeCombat.new(gs)
	var foe := gs.players[RealtimeCombat.ENEMY]
	var base: int = foe.hero.health
	foe.board.slots[0] = CardInstance.new({
		"id": "unit", "name": "Unit", "cost": 1, "attack": 1, "health": 4,
		"card_class": "minion", "description": "", "keywords": [],
	})
	assert_eq(FightStats.enemy_health(rt), base + 4)
	foe.hero.health -= 3
	assert_eq(FightStats.enemy_health(rt), base + 1)
