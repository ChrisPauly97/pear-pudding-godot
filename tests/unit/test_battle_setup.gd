## GID-176 / TID-714: shared pure fight setup (game + balance simulator).
extends "res://tests/framework/test_case.gd"

const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const ZoneLevels = preload("res://game_logic/world/ZoneLevels.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")

const ALL: Array = ["mend", "kick", "feat_minions", "feat_spells"]

func _ids(cards: Array[CardInstance]) -> Array[String]:
	var out: Array[String] = []
	for c: CardInstance in cards:
		out.append(c.template_id)
	return out

func test_new_player_fights_with_techniques_only() -> void:
	var f: Dictionary = BattleSetup.build({"seed": 3})
	var me: PlayerState = (f["state"] as GameState).players[0]
	for id: String in _ids(me.hand) + _ids(me.draw_deck):
		assert_true(id.begins_with("tech_"), "%s kept before feat_minions" % id)

func test_full_learner_gets_minions_and_caps() -> void:
	var f: Dictionary = BattleSetup.build({"seed": 3, "learned": ALL, "player_level": 20})
	var st: GameState = f["state"]
	var rt: RealtimeCombat = f["rt"]
	assert_true(_ids(st.players[0].hand + st.players[0].draw_deck).has("ghost"))
	assert_eq(st.players[0].max_units, RealtimeCombat.MAX_ALLIES)
	assert_true(rt.heavy_enabled)

## TID-720: the enemy acts the same whatever the player has learned.
func test_enemy_ignores_player_unlocks() -> void:
	var a: RealtimeCombat = BattleSetup.build({"seed": 5, "learned": [], "enemy_level": 6})["rt"]
	var b: RealtimeCombat = BattleSetup.build({"seed": 5, "learned": ["mend", "kick"], "enemy_level": 6})["rt"]
	assert_eq(a.heavy_enabled, b.heavy_enabled)
	assert_eq(a.enemy_minion_cap, b.enemy_minion_cap)
	assert_eq(a.heavy_damage(), b.heavy_damage())

func test_enemy_minion_cap_by_enemy_level() -> void:
	var t := CombatTuning.new()
	var low: RealtimeCombat = BattleSetup.build({"seed": 5,
		"enemy_level": t.get_i("enemy_two_minions_level") - 1})["rt"]
	var high: RealtimeCombat = BattleSetup.build({"seed": 5, "enemy_level": t.get_i("enemy_two_minions_level")})["rt"]
	assert_eq(low.enemy_minion_cap, 1)
	assert_eq(high.enemy_minion_cap, RealtimeCombat.MAX_ENEMY_MINIONS)

func test_enemy_spell_scale_by_level() -> void:
	var low: RealtimeCombat = BattleSetup.build({"seed": 5, "enemy_level": 1})["rt"]
	var lvl: int = CombatTuning.new().get_i("enemy_full_level")
	var full: RealtimeCombat = BattleSetup.build({"seed": 5, "player_level": lvl, "enemy_level": lvl})["rt"]
	assert_lt(BattleSetup.enemy_spell_scale(low, RealtimeCombat.ENEMY), 1.0)
	assert_almost_eq(BattleSetup.enemy_spell_scale(full, RealtimeCombat.ENEMY), 1.0, 0.001)

func test_same_seed_same_setup() -> void:
	var a: Dictionary = BattleSetup.build({"seed": 9, "learned": ALL})
	var b: Dictionary = BattleSetup.build({"seed": 9, "learned": ALL})
	var pa: PlayerState = (a["state"] as GameState).players[0]
	var pb: PlayerState = (b["state"] as GameState).players[0]
	assert_eq(_ids(pa.hand), _ids(pb.hand))
	assert_eq(_ids(pa.draw_deck), _ids(pb.draw_deck))

func test_enemy_tier_boss_and_zone() -> void:
	assert_eq(BattleSetup.enemy_tier("", false, 1), 1)
	assert_eq(BattleSetup.enemy_tier("undead_basic", true, 1), 4, "boss")
	var base: int = EnemyRegistry.get_difficulty_tier("undead_basic")
	assert_eq(BattleSetup.enemy_tier("undead_basic", false, 21), ZoneLevels.scaled_tier(base, 21))

func test_zone_level_and_boss_hp() -> void:
	var gs := GameState.new()
	var foe: PlayerState = gs.players[1]
	var deck: Array[String] = ["ghost", "ghost", "ghost", "ghost", "ghost"]
	BattleSetup.setup_enemy(foe, gs.players[0], "undead_basic", deck, 1, 1, 50)
	assert_eq(foe.hero.max_health, 50, "boss HP")
	var gs2 := GameState.new()
	var base_hp: int = gs2.players[1].hero.max_health
	BattleSetup.setup_enemy(gs2.players[1], gs2.players[0], "undead_basic", deck, 1, 11)
	assert_eq(gs2.players[1].hero.max_health, ZoneLevels.scaled_hero_hp(base_hp, 11))
	assert_eq(gs2.players[1].hand.size(), BattleSetup.OPENING_HAND)

func test_empty_deck_keeps_default() -> void:
	var gs := GameState.new()
	var before: int = gs.players[1].draw_deck.size() + gs.players[1].hand.size()
	BattleSetup.setup_enemy(gs.players[1], gs.players[0], "", [] as Array[String], 1, 1)
	assert_eq(gs.players[1].draw_deck.size() + gs.players[1].hand.size(), before)

func test_unlock_filter() -> void:
	var deck: Array[CardInstance] = []
	for id: String in ["ghost", "spark", "tech_strike"]:
		deck.append(CardInstance.new(CardRegistry.get_template(id)))
	assert_eq(_ids(BattleSetup.unlock_filter(deck, [])), ["tech_strike"] as Array[String])
	assert_eq(_ids(BattleSetup.unlock_filter(deck, ["feat_minions"])), ["ghost", "tech_strike"] as Array[String])
	assert_eq(BattleSetup.unlock_filter(deck, ALL).size(), 3)

## TID-718: the hero grows `hp_per_level`; an enemy above you gets `gap_hp` more HP per level.
func test_hero_hp_grows_with_level() -> void:
	var t := CombatTuning.new()
	var l1: GameState = BattleSetup.build({"seed": 5, "player_level": 1, "enemy_level": 1})["state"]
	var l5: GameState = BattleSetup.build({"seed": 5, "player_level": 5, "enemy_level": 5})["state"]
	assert_eq(l5.players[0].hero.max_health - l1.players[0].hero.max_health, roundi(t.get_f("hp_per_level") * 4.0))
	assert_eq(l5.players[0].hero.health, l5.players[0].hero.max_health, "starts full")

func test_enemy_above_you_has_more_hp() -> void:
	var same: GameState = BattleSetup.build({"seed": 5, "player_level": 4, "enemy_level": 5})["state"]
	var above: GameState = BattleSetup.build({"seed": 5, "player_level": 3, "enemy_level": 5})["state"]
	var below: GameState = BattleSetup.build({"seed": 5, "player_level": 6, "enemy_level": 5})["state"]
	assert_gt(above.players[1].hero.max_health, same.players[1].hero.max_health)
	assert_lt(below.players[1].hero.max_health, same.players[1].hero.max_health)
	assert_eq(above.players[1].hero.health, above.players[1].hero.max_health)

## TID-718: a Strike-only deck must not take fatigue drawing its opening hand.
func test_small_deck_starts_unhurt() -> void:
	var st: GameState = BattleSetup.build({"seed": 5, "learned": []})["state"]
	assert_eq(st.players[0].hero.health, st.players[0].hero.max_health)
