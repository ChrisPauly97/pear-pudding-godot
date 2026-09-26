## GID-135 / TID-550: fixed ability bar — reusable skills on their own cooldowns.
extends "res://tests/framework/test_case.gd"

const SkillBar = preload("res://game_logic/battle/SkillBar.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

func _rt() -> RealtimeCombat:
	var gs := GameState.new()
	for p: PlayerState in gs.players:
		p.hand.clear()
		p.draw_deck.clear()
	var rt := RealtimeCombat.new(gs)
	gs.players[0].hero.mana = gs.players[0].hero.max_mana
	return rt

func _slot(bar: SkillBar, id: String) -> int:
	return bar.ids.find(id)

func test_bar_uses_saved_ids_or_default() -> void:
	assert_eq(SkillBar.new().ids, SkillBar.DEFAULT_BAR)
	assert_eq(SkillBar.new(["kick", "bogus", "kick"]).ids, ["kick"] as Array[String])
	var many: Array = SkillBar.ABILITIES.keys() + SkillBar.ABILITIES.keys()
	assert_true(SkillBar.new(many).ids.size() <= SkillBar.SLOTS)

func test_strike_hits_enemy_hero_and_goes_on_cooldown() -> void:
	var rt := _rt()
	var bar := SkillBar.new()
	var i: int = _slot(bar, "strike")
	var enemy: PlayerState = rt.state.players[1]
	var hp: int = enemy.hero.health
	var mana: int = rt.state.players[0].hero.mana
	assert_eq(bar.blocker(i, rt), "")
	bar.apply(i, rt)
	bar.start_cooldown(i)
	assert_eq(enemy.hero.health, hp - 3)
	assert_eq(rt.state.players[0].hero.mana, mana - int(SkillBar.def("strike")["cost"]))
	assert_false(bar.ready(i))
	assert_eq(bar.blocker(i, rt), "Not ready yet")
	bar.advance(float(SkillBar.def("strike")["cooldown"]) + 0.01)
	assert_true(bar.ready(i), "reusable once the cooldown runs out")

func test_strike_hits_focused_minion_and_kills_it() -> void:
	var rt := _rt()
	var bar := SkillBar.new()
	var m := CardInstance.new({"id": "m", "name": "M", "cost": 1, "attack": 1, "health": 2, "card_class": "minion"})
	rt.state.players[1].board.add_card(m)
	rt.focus_target = m
	bar.apply(_slot(bar, "strike"), rt)
	assert_false(rt.state.players[1].board.get_cards().has(m))
	assert_true(rt.state.players[1].discard.has(m))
	assert_null(rt.focus_target)

func test_mend_heals_and_needs_mana() -> void:
	var rt := _rt()
	var bar := SkillBar.new()
	var i: int = _slot(bar, "mend")
	var hero: HeroState = rt.state.players[0].hero
	hero.health = 10
	bar.apply(i, rt)
	assert_eq(hero.health, 16)
	hero.mana = 0
	assert_eq(bar.blocker(i, rt), "Not enough mana")

func test_kick_interrupts_only_a_casting_enemy() -> void:
	var rt := _rt()
	var bar := SkillBar.new()
	var i: int = _slot(bar, "kick")
	assert_eq(bar.blocker(i, rt), "Nothing to interrupt")
	var spell := CardInstance.new({"id": "s", "name": "Bolt", "cost": 2, "card_class": "spell"})
	rt.casting[1] = spell
	assert_eq(bar.blocker(i, rt), "")
	var out: Dictionary = bar.apply(i, rt)
	assert_null(rt.casting[1])
	assert_eq(str(out["text"]), "Interrupted Bolt!")
	assert_true(bool(SkillBar.def("kick")["off_gcd"]))

func test_cooldown_multiplier_and_sweep() -> void:
	var bar := SkillBar.new()
	bar.start_cooldown(0, 0.5)
	var full: float = float(bar.def_at(0)["cooldown"])
	assert_almost_eq(bar.cooldown_left(0), full * 0.5, 0.001)
	bar.advance(full * 0.25)
	assert_almost_eq(bar.fraction(0), 0.5, 0.01)
