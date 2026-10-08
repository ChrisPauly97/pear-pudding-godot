## GID-176 / TID-713: the player's real-time casting rules, pure — the same code
## the battle scene and the balance simulator run.
extends "res://tests/framework/test_case.gd"

const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
const PlayerCaster = preload("res://game_logic/battle/PlayerCaster.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

var _events: Array[String] = []

func _setup() -> Array:
	SpellEffectResolver.silent = true
	var gs := GameState.new()
	for p: PlayerState in gs.players:
		p.hand.clear()
		p.draw_deck.clear()
	gs.players[1].hero.health = 1000
	gs.players[1].hero.max_health = 1000
	var rt := RealtimeCombat.new(gs, [5, 5])
	rt.set_passive(RealtimeCombat.ENEMY)
	rt.tune.set_value("proc_chance", 0.0)
	rt.tune.set_value("auto_proc_chance", 0.0)
	var me: PlayerState = gs.players[0]
	me.hero.mana = me.hero.max_mana
	var c := PlayerCaster.new(rt)
	_events.clear()
	c.notify = func(kind: String, _d: Dictionary) -> void: _events.append(kind)
	var res := SpellEffectResolver.new()
	res.setup(gs)
	return [rt, c, res]

func _card(id: String) -> CardInstance:
	return CardInstance.new(CardRegistry.get_template(id))

func _give(rt: RealtimeCombat, id: String) -> CardInstance:
	var card := _card(id)
	rt.state.players[0].hand.append(card)
	return card

## Ticks the caster (and only the GCD clock, no swings) for `secs`.
func _run(rt: RealtimeCombat, c: PlayerCaster, secs: float) -> void:
	var t: float = 0.0
	while t < secs:
		c.tick(0.05)
		rt.gcd[0] = maxf(0.0, rt.gcd[0] - 0.05)
		t += 0.05

func test_instant_play_queues_then_resolves_and_starts_gcd() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	var strike := _give(rt, "tech_strike")
	var hp: int = rt.state.players[1].hero.health
	assert_eq(c.play(strike, s[2], {"type": "hero"}), "")
	assert_true(c.on_cooldown(), "casting blocks the next play")
	_run(rt, c, 0.2)
	assert_eq(rt.state.players[1].hero.health, hp - int(TechniqueDefs.def("tech_strike")["rt_value"]),
		"real-time Strike")
	assert_eq(rt.state.players[0].draw_deck[0], strike, "technique recycled")
	assert_true(rt.gcd[0] > 0.0, "GCD running")
	assert_ne(c.play_blocker(_give(rt, "tech_strike")), "", "next play waits out the GCD")

func test_mend_uses_its_own_cast_time_and_pushback() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	var me: PlayerState = rt.state.players[0]
	me.hero.health = 10
	assert_eq(c.play(_give(rt, "tech_mend"), s[2]), "")
	_run(rt, c, 1.0)
	assert_true(c.is_casting(), "1.5 s cast still running")
	me.hero.health -= 1  # a hit lands mid-cast → pushback
	_run(rt, c, 0.6)
	assert_true(c.is_casting(), "pushed back")
	_run(rt, c, 0.5)
	assert_false(c.is_casting())
	assert_eq(me.hero.health, 15, "9 + 6 healed")

func test_target_lost_fizzles_and_keeps_the_card() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	var foe := _card("ghost")
	rt.state.players[1].board.add_card(foe)
	var lance := _give(rt, "tech_ember_lance")
	assert_eq(c.play(lance, s[2], {"type": "minion", "card": foe}), "")
	rt.state.players[1].board.remove_card(foe)
	_run(rt, c, 2.0)
	assert_true(_events.has("fizzled"))
	assert_true(rt.state.players[0].hand.has(lance), "card stays in hand")

func test_kick_is_off_gcd_and_interrupts() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	var kick := _give(rt, "tech_kick")
	assert_eq(c.play_blocker(kick), "Nothing to interrupt")
	rt.casting[1] = _card("ghost")
	rt.start_gcd(0)
	assert_eq(c.play(kick, s[2]), "", "off the GCD")
	assert_null(rt.casting[1], "interrupted")
	assert_true(_events.has("interrupt"))

func test_hand_card_spends_combo() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	rt.combo = 2
	var spell := _give(rt, "spark")
	assert_eq(c.play(spell, s[2], {"type": "hero"}), "")
	_run(rt, c, 3.0)
	assert_eq(rt.combo, 0)
	assert_true(_events.has("combo"))

func test_technique_builds_combo_without_spending() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	rt.combo = 1
	assert_eq(c.play(_give(rt, "tech_strike"), s[2], {"type": "hero"}), "")
	_run(rt, c, 0.2)
	assert_eq(rt.combo, 2, "builder hit, no spend")
	assert_true(_events.has("technique"))

func test_minion_goes_to_first_free_slot() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	var ghost := _give(rt, "ghost")
	assert_eq(c.play(ghost, s[2]), "")
	_run(rt, c, 0.2)
	assert_true(rt.state.players[0].board.get_cards().has(ghost))

func after_each() -> void:
	SpellEffectResolver.silent = false

## GID-178 / TID-724: a resolved technique comes back to the hand after its recycle time.
func test_technique_returns_to_hand_after_recycle() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	var strike := _give(rt, "tech_strike")
	var me: PlayerState = rt.state.players[0]
	assert_eq(c.play(strike, s[2], {"type": "hero"}), "")
	_run(rt, c, 0.2)
	assert_false(me.hand.has(strike), "left the hand")
	assert_true(me.draw_deck.has(strike), "waits at the bottom of the deck")
	var wait: float = TechniqueDefs.recycle_time("tech_strike") * rt.tune.get_f("tech_recycle_mult")
	assert_almost_eq(c.return_left(strike), wait - 0.15, 0.11)
	_run(rt, c, wait)
	assert_true(me.hand.has(strike), "back in hand")
	assert_false(me.draw_deck.has(strike))
	assert_true(_events.has("returned"))

func test_technique_returns_even_to_a_full_hand() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	var strike := _give(rt, "tech_strike")
	var me: PlayerState = rt.state.players[0]
	assert_eq(c.play(strike, s[2], {"type": "hero"}), "")
	_run(rt, c, 0.2)
	for _i: int in rt.tune.get_i("hand_cap"):
		me.hand.append(_card("ghost"))
	_run(rt, c, TechniqueDefs.recycle_time("tech_strike") * rt.tune.get_f("tech_recycle_mult"))
	assert_true(me.hand.has(strike), "a clogged hand never locks out Strike")

func test_drawn_early_cancels_the_return() -> void:
	var s: Array = _setup()
	var rt: RealtimeCombat = s[0]
	var c: PlayerCaster = s[1]
	var strike := _give(rt, "tech_strike")
	var me: PlayerState = rt.state.players[0]
	assert_eq(c.play(strike, s[2], {"type": "hero"}), "")
	_run(rt, c, 0.2)
	me.draw_card(false)
	_run(rt, c, TechniqueDefs.recycle_time("tech_strike") * rt.tune.get_f("tech_recycle_mult"))
	assert_eq(me.hand.count(strike), 1, "no duplicate")
