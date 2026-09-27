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

## GID-136 / TID-537: trainer-taught abilities beyond the always-known trio.

func test_learnable_ids_exclude_always_known() -> void:
	var learnable: Array[String] = SkillBar.learnable_ids()
	assert_eq(learnable.size(), 5, "5 new trainer-taught abilities")
	for id: String in SkillBar.ALWAYS_KNOWN:
		assert_false(learnable.has(id))
	for id: String in learnable:
		assert_true(SkillBar.ABILITIES.has(id))

func test_every_learnable_ability_is_weaker_than_a_typical_deck_spell() -> void:
	# House rule (user's design): the bar stays a set of weak, reliable
	# abilities. Deck spells commonly hit for 5-10+; keep every bar ability's
	# primary value at or below that band.
	for id: String in SkillBar.learnable_ids():
		var a: Dictionary = SkillBar.def(id)
		assert_true(int(a.get("value", 0)) <= 9, "%s value should stay modest" % id)

func test_can_learn_gates_on_level_and_coins() -> void:
	assert_false(SkillBar.can_learn("guard", 1, 1000, []))
	assert_false(SkillBar.can_learn("guard", 3, 0, []))
	assert_true(SkillBar.can_learn("guard", 3, 40, []))
	assert_false(SkillBar.can_learn("guard", 3, 40, ["guard"]), "already learned")
	assert_false(SkillBar.can_learn("strike", 99, 9999, []), "always known, not learnable")

func test_unlearned_ability_is_dropped_from_a_saved_bar() -> void:
	# Without `learned`, only the always-known trio can populate the bar —
	# an id copied into save data by mistake (or from a stale save) can't
	# surface a trainer-taught ability the player never actually learned.
	var bar := SkillBar.new(["guard", "mend"])
	assert_eq(bar.ids, ["mend"] as Array[String])

func test_learned_ability_can_populate_the_bar() -> void:
	var bar := SkillBar.new(["guard", "mend"], ["guard"])
	assert_eq(bar.ids, ["guard", "mend"] as Array[String])

func test_guard_stacks_armor_and_absorbs_damage() -> void:
	var rt := _rt()
	var bar := SkillBar.new(["guard"], ["guard"])
	var caster: PlayerState = rt.state.players[0]
	bar.apply(0, rt)
	assert_eq(caster.hero.get_status_value("armor"), int(SkillBar.def("guard")["value"]))
	var before: int = caster.hero.health
	caster.hero.take_damage(4)
	assert_eq(caster.hero.health, before, "armor absorbed it")

func test_mana_tap_deals_damage_and_restores_mana() -> void:
	var rt := _rt()
	var bar := SkillBar.new(["mana_tap"], ["mana_tap"])
	var caster: PlayerState = rt.state.players[0]
	var enemy: PlayerState = rt.state.players[1]
	caster.hero.mana = 0
	var before_hp: int = enemy.hero.health
	bar.apply(0, rt)
	assert_eq(enemy.hero.health, before_hp - int(SkillBar.def("mana_tap")["value"]))
	assert_true(caster.hero.mana > 0)

func test_sweep_hits_every_enemy_minion() -> void:
	var rt := _rt()
	var bar := SkillBar.new(["sweep"], ["sweep"])
	var enemy: PlayerState = rt.state.players[1]
	var a := CardInstance.new({"id": "a", "name": "A", "cost": 1, "attack": 1, "health": 10, "card_class": "minion"})
	var b := CardInstance.new({"id": "b", "name": "B", "cost": 1, "attack": 1, "health": 2, "card_class": "minion"})
	enemy.board.add_card(a)
	enemy.board.add_card(b)
	bar.apply(0, rt)
	assert_eq(a.health, 10 - int(SkillBar.def("sweep")["value"]))
	assert_false(enemy.board.get_cards().has(b), "3 damage kills a 2-health minion")

func test_daze_stuns_and_interrupts_the_enemy_hero() -> void:
	var rt := _rt()
	var bar := SkillBar.new(["daze"], ["daze"])
	var enemy: PlayerState = rt.state.players[1]
	var spell := CardInstance.new({"id": "s", "name": "Bolt", "cost": 2, "card_class": "spell"})
	rt.casting[1] = spell
	bar.apply(0, rt)
	assert_true(enemy.hero.has_status("stun"))
	assert_null(rt.casting[1], "daze also interrupts an in-flight cast")

func test_daze_without_a_target_hits_the_default_enemy() -> void:
	var rt := _rt()
	var bar := SkillBar.new(["daze"], ["daze"])
	var result: Dictionary = bar.apply(0, rt)
	assert_eq(int(result.get("side")), 1)
	assert_true(rt.state.players[1].hero.has_status("stun"))

## GID-136 / TID-556: the loadout picker's resolved/known helpers.

func test_known_ids_is_always_known_plus_learned() -> void:
	var known: Array[String] = SkillBar.known_ids(["guard", "daze"])
	assert_eq(known.size(), 5)
	for id: String in SkillBar.ALWAYS_KNOWN:
		assert_true(known.has(id))
	assert_true(known.has("guard"))
	assert_true(known.has("daze"))
	assert_false(known.has("sweep"), "not learned")

func test_resolved_bar_is_always_exactly_slots_long() -> void:
	assert_eq(SkillBar.resolved_bar([], []).size(), SkillBar.SLOTS)
	assert_eq(SkillBar.resolved_bar(["guard"], []).size(), SkillBar.SLOTS)
	assert_eq(SkillBar.resolved_bar(["guard", "sweep", "daze"], ["guard", "sweep", "daze"]).size(), SkillBar.SLOTS)

func test_resolved_bar_fresh_save_is_the_default() -> void:
	assert_eq(SkillBar.resolved_bar([], []), ["strike", "mend", "kick"] as Array[String])

func test_resolved_bar_keeps_learned_choices_and_pads_with_unused_defaults() -> void:
	var result: Array[String] = SkillBar.resolved_bar(["guard"], ["guard"])
	assert_eq(result[0], "guard")
	assert_eq(result.size(), 3)
	# strike/mend/kick fill the rest, in DEFAULT_BAR order.
	assert_eq(result, ["guard", "strike", "mend"] as Array[String])

func test_resolved_bar_drops_unlearned_ids() -> void:
	var result: Array[String] = SkillBar.resolved_bar(["guard", "sweep"], [])
	assert_false(result.has("guard"))
	assert_false(result.has("sweep"))
	assert_eq(result, ["strike", "mend", "kick"] as Array[String])
