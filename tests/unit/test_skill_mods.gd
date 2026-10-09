## GID-179 / TID-732 / TID-733: skill-tree nodes modify cards in real-time
## fights (recycle, cost, cast, power, crit, on-crit triggers); spells crit.
extends "res://tests/framework/test_case.gd"

const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
const PlayerCaster = preload("res://game_logic/battle/PlayerCaster.gd")
const SkillMods = preload("res://game_logic/battle/SkillMods.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

var _events: Array[String] = []

## [rt, caster, resolver, mods]; `crit` = the base crit chance.
func _setup(crit: float = 0.0) -> Array:
	SpellEffectResolver.silent = true
	var gs := GameState.new()
	for p: PlayerState in gs.players:
		p.hand.clear()
		p.draw_deck.clear()
	gs.players[1].hero.health = 1000
	gs.players[1].hero.max_health = 1000
	var rt := RealtimeCombat.new(gs, [5, 5], CombatTuning.new({"crit_chance": crit, "enemy_crit_chance": 0.0}))
	rt.set_passive(RealtimeCombat.ENEMY)
	rt.tune.set_value("proc_chance", 0.0)
	rt.tune.set_value("auto_proc_chance", 0.0)
	var me: PlayerState = gs.players[0]
	me.hero.mana = me.hero.max_mana
	var mods := SkillMods.new()
	me.skill_mods = mods
	var c := PlayerCaster.new(rt)
	_events.clear()
	c.notify = func(kind: String, _d: Dictionary) -> void: _events.append(kind)
	var res := SpellEffectResolver.new()
	res.setup(gs)
	res.power_hook = c.modify_power
	return [rt, c, res, mods]

func _card(id: String) -> CardInstance:
	return CardInstance.new(CardRegistry.get_template(id))

func _give(rt: RealtimeCombat, id: String) -> CardInstance:
	var card := _card(id)
	rt.state.players[0].hand.append(card)
	return card

func _run(rt: RealtimeCombat, c: PlayerCaster, secs: float) -> void:
	var t: float = 0.0
	while t < secs:
		c.tick(0.05)
		rt.gcd[0] = maxf(0.0, rt.gcd[0] - 0.05)
		t += 0.05

func test_filters() -> void:
	var strike := _card("tech_strike")
	var ghost := _card("ghost")
	assert_true(SkillMods.matches(strike, "technique"))
	assert_true(SkillMods.matches(strike, "spell"))
	assert_true(SkillMods.matches(strike, "damage"))
	assert_false(SkillMods.matches(strike, "heal"))
	assert_true(SkillMods.matches(_card("tech_mend"), "heal"))
	assert_true(SkillMods.matches(ghost, "ally"))
	assert_false(SkillMods.matches(ghost, "spell"))
	assert_true(SkillMods.matches(strike, "tech_strike"))
	assert_false(SkillMods.matches(strike, "ember"))

func test_cost_cut_shows_in_effective_cost_and_floors_at_one() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var mods: SkillMods = s[3]
	var me: PlayerState = rt.state.players[0]
	var ghost := _card("ghost")
	var before: int = me.effective_cost(ghost)
	mods.add("mod_cost", 5, "ally")
	assert_eq(mods.cost_for(ghost), mini(ghost.cost, 1), "never below 1")
	assert_true(me.effective_cost(ghost) < before or ghost.cost <= 1)
	assert_eq(mods.cost_for(_card("tech_strike")), 0, "a 0-cost card stays 0")

func test_recycle_faster() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	var mods: SkillMods = s[3]
	mods.add("mod_recycle", 50, "technique")
	var strike := _give(rt, "tech_strike")
	assert_eq(c.play(strike, s[2], {"type": "hero"}), "")
	_run(rt, c, 0.1)
	var full: float = TechniqueDefs.recycle_time("tech_strike") * rt.tune.get_f("tech_recycle_mult")
	assert_almost_eq(c.return_left(strike), full * 0.5, 0.11)

func test_cast_faster() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	var mods: SkillMods = s[3]
	mods.add("mod_cast", 50, "tech_mend")
	assert_eq(c.play(_give(rt, "tech_mend"), s[2]), "")
	_run(rt, c, 0.85)
	assert_false(c.is_casting(), "1.5 s cast halved")

func test_power_up() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	var mods: SkillMods = s[3]
	mods.add("mod_power", 100, "technique")
	var hp: int = rt.state.players[1].hero.health
	assert_eq(c.play(_give(rt, "tech_strike"), s[2], {"type": "hero"}), "")
	_run(rt, c, 0.2)
	assert_eq(hp - rt.state.players[1].hero.health, 2 * int(TechniqueDefs.def("tech_strike")["rt_value"]))

func test_spells_crit_without_nodes() -> void:
	var s: Array = _setup(1.0)
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	rt.state.players[0].skill_mods = null
	var hp: int = rt.state.players[1].hero.health
	assert_eq(c.play(_give(rt, "tech_strike"), s[2], {"type": "hero"}), "")
	_run(rt, c, 0.2)
	assert_true(_events.has("crit"))
	assert_true(hp - rt.state.players[1].hero.health > int(TechniqueDefs.def("tech_strike")["rt_value"]))

func test_no_crit_at_zero_chance_and_utility_never_crits() -> void:
	var s: Array = _setup(0.0)
	var c: PlayerCaster = s[1]
	assert_eq(c.modify_power(_card("tech_strike"), 0, 2), 2)
	var s2: Array = _setup(1.0)
	var c2: PlayerCaster = s2[1]
	assert_eq(c2.modify_power(_card("tech_guard"), 0, 6), 6, "armor isn't damage or heal")
	assert_eq(c2.modify_power(_card("tech_strike"), 1, 2), 2, "enemy casts untouched")

func test_crit_bonus_node() -> void:
	var s: Array = _setup(0.0)
	var c: PlayerCaster = s[1]
	var mods: SkillMods = s[3]
	mods.add("mod_crit", 100, "damage")
	assert_true(c.modify_power(_card("tech_strike"), 0, 4) > 4)

func test_on_crit_instant_makes_the_next_cast_instant() -> void:
	var s: Array = _setup(1.0)
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	var mods: SkillMods = s[3]
	mods.add("on_crit_instant", 0, "damage")
	assert_eq(c.play(_give(rt, "tech_strike"), s[2], {"type": "hero"}), "")
	_run(rt, c, 0.2)
	assert_true(rt.instant_next)
	rt.gcd[0] = 0.0
	assert_eq(c.play(_give(rt, "tech_mend"), s[2]), "")
	_run(rt, c, 0.1)
	assert_false(c.is_casting(), "Mend skipped its 1.5 s cast")
	assert_false(rt.instant_next, "consumed")

func test_on_crit_refund() -> void:
	var s: Array = _setup(1.0)
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	var mods: SkillMods = s[3]
	mods.add("on_crit_refund", 1, "damage")
	var me: PlayerState = rt.state.players[0]
	me.hero.mana = 0
	c.modify_power(_card("tech_strike"), 0, 2)
	assert_eq(me.hero.mana, me.hero.mana_scale)

func test_apply_skill_mods() -> void:
	var gs := GameState.new()
	var me: PlayerState = gs.players[0]
	BattleSetup.apply_skill_mods(me, [])
	assert_null(me.skill_mods, "no nodes, no mods")
	BattleSetup.apply_skill_mods(me, ["no_such_skill"])
	assert_null(me.skill_mods)
