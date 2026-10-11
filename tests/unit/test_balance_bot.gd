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

## GID-187 / TID-784: the default policy is unchanged; the casual knobs are deterministic per seed.
func test_default_preset_is_the_default_policy() -> void:
	assert_eq(str(BalanceBot.preset("default")), str(BalanceBot.DEFAULT_POLICY), "preset default = knob defaults")
	assert_eq(float(BalanceBot.DEFAULT_POLICY["react"]), 0.0)
	assert_eq(float(BalanceBot.DEFAULT_POLICY["kick_miss"]), 0.0)
	assert_eq(float(BalanceBot.DEFAULT_POLICY["think"]), 0.0)
	var cfg: Dictionary = {"seed": 7, "learned": ALL, "player_level": 6}
	assert_eq(str(BalanceFight.run(cfg)), str(BalanceFight.run(cfg, BalanceBot.preset("default"))),
		"the default preset plays the same fight as no policy")

func test_casual_preset_turns_the_knobs_on() -> void:
	var p: Dictionary = BalanceBot.preset("casual")
	assert_gt(float(p["react"]), 0.0, "casual reacts late")
	assert_gt(float(p["kick_miss"]), 0.0, "casual misses some Kicks")
	assert_gt(float(p["think"]), 0.0, "casual waits between plays")
	assert_false(bool(p["focus"]), "casual never swaps focus")
	assert_true(BalanceBot.has_preset("casual"))
	assert_false(BalanceBot.has_preset("sharp"))

func test_casual_fight_is_deterministic_per_seed() -> void:
	var cfg: Dictionary = {"seed": 13, "learned": ALL, "player_level": 6}
	var casual: Dictionary = BalanceBot.preset("casual")
	assert_eq(str(BalanceFight.run(cfg, casual)), str(BalanceFight.run(cfg, casual)),
		"same seed gives the same casual fight")

func test_kick_miss_of_one_never_interrupts() -> void:
	var cfg: Dictionary = {"seed": 3, "learned": ALL, "player_level": 6}
	var sure: Dictionary = BalanceBot.preset("default")
	assert_gt(int(BalanceFight.run(cfg, sure)["interrupts"]), 0, "the default bot interrupts in this fight")
	sure["kick_miss"] = 1.0
	assert_eq(int(BalanceFight.run(cfg, sure)["interrupts"]), 0, "every Kick whiffs")

func test_reaction_delays_the_interrupt() -> void:
	var c := _caster()
	c.rt.state.players[1].board.slots.fill(null)
	c.rt.state.players[0].hand.clear()
	_give(c, "tech_kick")
	c.rt.casting[1] = CardInstance.new(CardRegistry.get_template("ghost"))
	var bot := BalanceBot.new({"react": 0.5})
	assert_eq(bot.act(c, _resolver(c.rt.state), 0.0), "", "too early to react")
	assert_eq(bot.act(c, _resolver(c.rt.state), 0.3), "", "still reacting")
	assert_eq(bot.act(c, _resolver(c.rt.state), 0.3), "tech_kick", "answers after 0.5 s")

func test_think_spaces_out_plays() -> void:
	var c := _caster()
	c.rt.state.players[0].hand.clear()
	_give(c, "tech_kick")
	_give(c, "tech_kick")
	c.rt.casting[1] = CardInstance.new(CardRegistry.get_template("ghost"))
	var bot := BalanceBot.new({"think": 1.0})
	assert_eq(bot.act(c, _resolver(c.rt.state), 0.0), "tech_kick", "first play at once")
	c.rt.casting[1] = CardInstance.new(CardRegistry.get_template("ghost"))
	assert_eq(bot.act(c, _resolver(c.rt.state), 0.5), "", "thinking")
	assert_eq(bot.act(c, _resolver(c.rt.state), 0.6), "tech_kick", "next play after 1 s")
