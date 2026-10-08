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
	assert_true(rt.heavy_enabled, "kick learned → heavy blows")

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
