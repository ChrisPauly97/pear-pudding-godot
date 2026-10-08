## GID-176 / TID-715: the balance bot plays only legal moves through the real
## rules, reacts to casts and low HP, and a seeded fight replays exactly.
extends "res://tests/framework/test_case.gd"

const BalanceBot = preload("res://game_logic/battle/BalanceBot.gd")
const BalanceFight = preload("res://game_logic/battle/BalanceFight.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const PlayerCaster = preload("res://game_logic/battle/PlayerCaster.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

const ALL: Array = ["mend", "kick", "guard", "feat_minions", "feat_spells"]

func _caster(learned: Array = ALL) -> PlayerCaster:
	var f: Dictionary = BattleSetup.build({"seed": 5, "learned": learned, "player_level": 10})
	var rt: RealtimeCombat = f["rt"]
	var me: PlayerState = rt.state.players[0]
	me.hand.clear()
	me.hero.mana = me.hero.max_mana
	return PlayerCaster.new(rt)

func _give(c: PlayerCaster, id: String) -> CardInstance:
	var card := CardInstance.new(CardRegistry.get_template(id))
	c.rt.state.players[0].hand.append(card)
	return card

func test_kicks_an_enemy_cast() -> void:
	var c := _caster()
	_give(c, "tech_strike")
	var kick := _give(c, "tech_kick")
	c.rt.casting[1] = CardInstance.new(CardRegistry.get_template("ghost"))
	assert_eq(BalanceBot.new().decide(c).get("card"), kick)

func test_heals_when_low() -> void:
	var c := _caster()
	_give(c, "tech_strike")
	var mend := _give(c, "tech_mend")
	var me: PlayerState = c.rt.state.players[0]
	me.hero.health = 5
	assert_eq(BalanceBot.new().decide(c).get("card"), mend)
	me.hero.health = me.hero.max_health
	assert_ne(BalanceBot.new().decide(c).get("card"), mend, "no heal at full HP")

func test_strike_goes_at_the_hero_on_an_empty_board() -> void:
	var c := _caster()
	c.rt.state.players[1].board.slots.fill(null)
	var strike := _give(c, "tech_strike")
	var d: Dictionary = BalanceBot.new().decide(c)
	assert_eq(d.get("card"), strike)
	assert_eq((d["target"] as Dictionary).get("type"), "hero")

func test_every_decision_is_legal_over_whole_fights() -> void:
	for s: int in [1, 2, 3]:
		var f: Dictionary = BattleSetup.build({"seed": s, "learned": ALL, "player_level": 8})
		var rt: RealtimeCombat = f["rt"]
		var caster := PlayerCaster.new(rt)
		var bot := BalanceBot.new()
		var t: float = 0.0
		while t < 120.0 and not rt.state.is_game_over():
			var d: Dictionary = bot.decide(caster)
			if not d.is_empty():
				assert_eq(caster.play_blocker(d["card"] as CardInstance), "", "bot picked a legal play")
			bot.act(caster, _resolver(rt.state))
			caster.tick(0.05)
			rt.advance(0.05)
			t += 0.05

func _resolver(gs: GameState) -> Object:
	var r: Object = preload("res://scenes/battle/SpellEffectResolver.gd").new()
	r.call("setup", gs)
	return r

func test_fight_finishes_and_replays_exactly() -> void:
	var cfg: Dictionary = {"seed": 11, "learned": ALL, "player_level": 6}
	var a: Dictionary = BalanceFight.run(cfg)
	var b: Dictionary = BalanceFight.run(cfg)
	assert_ne(str(a["result"]), "", "a result")
	assert_gt(float(a["seconds"]), 1.0)
	assert_gt((a["plays"] as Dictionary).size(), 0, "the bot played cards")
	assert_eq(str(a), str(b), "same seed → identical fight")
