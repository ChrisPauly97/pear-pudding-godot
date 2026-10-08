## GID-175 / TID-707: technique cards — the old skill bar as deck cards that
## recycle to the bottom of the draw pile and work in both battle modes.
extends "res://tests/framework/test_case.gd"

const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
const SpellEffectLabels = preload("res://game_logic/battle/SpellEffectLabels.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

func _tech(id: String) -> CardInstance:
	return CardInstance.new(CardRegistry.get_template(id))

func _minion(health: int = 10) -> CardInstance:
	return CardInstance.new({
		"id": "unit", "name": "Unit", "cost": 1, "attack": 1, "health": health,
		"card_class": "minion", "description": "",
	})

## Fresh 2-player state, empty hands/decks; `scale` > 1 = real-time mana.
func _state(scale: int = 1) -> GameState:
	var gs := GameState.new()
	for p: PlayerState in gs.players:
		p.hand.clear()
		p.draw_deck.clear()
		p.hero.mana_scale = scale
		p.hero.max_mana = 10 * scale
		p.hero.mana = 5 * scale
	return gs

func _cast(gs: GameState, card: CardInstance, target: Dictionary = {}) -> void:
	var r := SpellEffectResolver.new()
	r.setup(gs)
	r.resolve_spell(card, 0, target)

func test_all_eight_load_as_typeless_unique_spells() -> void:
	var ids: Array[String] = CardRegistry.get_technique_ids()
	assert_eq(ids.size(), 8, "every technique .tres is preloaded")
	for id: String in ids:
		var t: Dictionary = CardRegistry.get_template(id)
		assert_eq(str(t.get("card_class", "")), "spell", id)
		assert_eq(str(t.get("magic_type", "x")), "", id + " is typeless")
		assert_true(bool(t.get("is_unique", false)), id + " can't be traded")
		assert_false(CardRegistry.is_craftable(id), id + " can't be crafted")
		assert_lte(int(t.get("cost", 9)), 1, id + " costs 0-1")
		assert_true(SpellEffectLabels.SPELL.has(str(t.get("spell_effect", ""))), id + " has a label")

func test_techniques_stay_out_of_random_pools() -> void:
	var pool: Array[String] = CardRegistry.get_all_ids()
	for id: String in TechniqueDefs.ids():
		assert_false(pool.has(id), id + " not in drop/shop/pack pools")

func test_values_stay_weaker_than_deck_spells() -> void:
	for id: String in TechniqueDefs.ids():
		var printed: int = int(CardRegistry.get_template(id).get("spell_power", 0))
		assert_lte(printed, 9, id + " turn-based")
		assert_lte(TechniqueDefs.power(id, printed, true), 9, id + " real time")

func test_played_technique_recycles_to_bottom_of_deck() -> void:
	var gs := _state()
	var p: PlayerState = gs.players[0]
	var filler := _minion()
	p.draw_deck.append(filler)
	var strike := _tech("tech_strike")
	p.hand.append(strike)
	assert_true(p.play_card(strike))
	assert_false(p.hand.has(strike))
	assert_false(p.discard.has(strike), "not discarded")
	assert_eq(p.draw_deck[0], strike, "bottom of the pile")
	assert_eq(p.draw_card(false), filler, "the rest of the deck comes first")

func test_normal_spell_still_discards() -> void:
	var gs := _state()
	var p: PlayerState = gs.players[0]
	var spell := CardInstance.new({"id": "spark", "name": "S", "cost": 0, "card_class": "spell",
		"spell_effect": "deal_damage_single", "spell_power": 1})
	p.hand.append(spell)
	assert_true(p.play_card(spell))
	assert_true(p.discard.has(spell))

func test_strike_uses_real_time_value_only_in_real_time() -> void:
	var gs := _state()
	var hp: int = gs.players[1].hero.health
	_cast(gs, _tech("tech_strike"), {"type": "hero"})
	assert_eq(gs.players[1].hero.health, hp - 2, "turn-based 2")
	var rt := _state(100)
	hp = rt.players[1].hero.health
	_cast(rt, _tech("tech_strike"), {"type": "hero"})
	assert_eq(rt.players[1].hero.health, hp - 5, "real time 5")

func test_mend_and_guard() -> void:
	var gs := _state()
	var hero := gs.players[0].hero
	hero.health = 10
	_cast(gs, _tech("tech_mend"))
	assert_eq(hero.health, 14)
	_cast(gs, _tech("tech_guard"))
	assert_true(hero.has_status("armor"))

func test_kick_stuns_and_daze_freezes_a_minion() -> void:
	var gs := _state()
	var foe := _minion()
	gs.players[1].board.add_card(foe)
	_cast(gs, _tech("tech_kick"), {"type": "minion", "card": foe})
	assert_true(foe.has_status("stun"))
	_cast(gs, _tech("tech_daze"), {"type": "minion", "card": foe})
	assert_true(foe.has_status("freeze"))

func test_sweep_hits_every_enemy_minion() -> void:
	var gs := _state()
	var a := _minion()
	var b := _minion()
	gs.players[1].board.add_card(a)
	gs.players[1].board.add_card(b)
	_cast(gs, _tech("tech_sweep"))
	assert_eq(a.health, 9)
	assert_eq(b.health, 9)

func test_mana_tap_hits_hero_and_returns_mana() -> void:
	var gs := _state(100)
	var me := gs.players[0].hero
	var hp: int = gs.players[1].hero.health
	var mana: int = me.mana
	_cast(gs, _tech("tech_mana_tap"))
	assert_eq(gs.players[1].hero.health, hp - 2)
	assert_eq(me.mana, mana + 100, "one unit, scaled")

func test_deck_rules() -> void:
	assert_eq(TechniqueDefs.deck_violation(["ghost", "tech_strike", "tech_kick", "tech_mend"]), "")
	assert_ne(TechniqueDefs.deck_violation(["tech_strike", "tech_strike"]), "", "one copy each")
	assert_ne(TechniqueDefs.deck_violation(["tech_strike", "tech_kick", "tech_mend", "tech_guard"]), "",
			"at most three")

func test_real_time_extras_match_old_bar() -> void:
	assert_eq(TechniqueDefs.cast_time("tech_mend"), 1.5)
	assert_eq(TechniqueDefs.cast_time("ghost"), -1.0)
	assert_true(TechniqueDefs.off_gcd("tech_kick"))
	assert_false(TechniqueDefs.off_gcd("tech_strike"))

func test_free_cast_proc_is_saved_for_a_real_card() -> void:
	var gs := _state(100)
	var p: PlayerState = gs.players[0]
	p.next_card_free = true
	var mend := _tech("tech_mend")
	assert_eq(p.effective_cost(mend), 100, "technique pays its own cost")
	p.hand.append(mend)
	assert_true(p.play_card(mend))
	assert_true(p.next_card_free, "proc still banked after a technique")
