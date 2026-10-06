## GID-139: auto-attack toggle, essence siphon, combo charges, free-cast procs.
extends "res://tests/framework/test_case.gd"

const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const SkillBar = preload("res://game_logic/battle/SkillBar.gd")

func _rt() -> RealtimeCombat:
	var gs := GameState.new()
	for p: PlayerState in gs.players:
		p.hand.clear()
		p.draw_deck.clear()
	gs.players[1].hero.health = 100000
	var rt := RealtimeCombat.new(gs)
	rt.tune.set_value("proc_chance", 0.0)
	rt.tune.set_value("auto_proc_chance", 0.0)
	return rt

func _run(rt: RealtimeCombat, seconds: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t: float = 0.0
	while t < seconds + 0.05:
		out.append_array(rt.advance(0.1))
		t += 0.1
	return out

func _player_swings(events: Array[Dictionary]) -> int:
	var n: int = 0
	for e: Dictionary in events:
		if str(e.get("type", "")) == "swing" and int(e.get("side", -1)) == 0:
			n += 1
	return n

func test_auto_attack_is_always_on() -> void:
	var rt := _rt()
	assert_true(rt.auto_attack, "melee swings are automatic")
	assert_gt(_player_swings(_run(rt, rt.swing_speed(0) * 2.0)), 0)

func test_hits_siphon_mana() -> void:
	var rt := _rt()
	var h := rt.state.players[0].hero
	h.mana = 0
	rt.on_player_hit(3, false)
	assert_eq(h.mana, 3 * rt.tune.get_i("siphon_per_damage"))
	assert_eq(rt.combo, 0, "auto hits don't build combo")

func test_strike_builds_combo_to_cap() -> void:
	var rt := _rt()
	var bar := SkillBar.new()
	var i: int = bar.ids.find("strike")
	for _n: int in rt.tune.get_i("combo_max") + 2:
		bar.apply(i, rt)
	assert_eq(rt.combo, rt.tune.get_i("combo_max"))
	assert_true(rt.combo_full())
	assert_true(rt.next_card_instant(), "a full combo makes the next card instant")

func test_card_spends_combo_for_mana() -> void:
	var rt := _rt()
	var h := rt.state.players[0].hero
	rt.combo = 2
	h.mana = 0
	assert_eq(rt.spend_combo(), 2)
	assert_eq(rt.combo, 0)
	assert_eq(h.mana, 2 * rt.tune.get_i("combo_refund"))
	assert_eq(rt.spend_combo(), 0)

func test_proc_makes_next_card_free_once() -> void:
	var rt := _rt()
	rt.tune.set_value("proc_chance", 1.0)
	var me: PlayerState = rt.state.players[0]
	var card := CardInstance.new({"id": "b", "name": "Bolt", "cost": 3, "card_class": "spell"})
	me.hand.append(card)
	me.hero.mana = 0
	assert_false(me.can_play(card))
	assert_true(rt.on_player_hit(2, true))
	assert_false(rt.on_player_hit(2, true), "doesn't re-fire while one is banked")
	assert_true(me.can_play(card), "free while the proc is banked")
	var before: int = me.hero.mana
	assert_true(me.play_card(card))
	assert_eq(me.hero.mana, before, "cost nothing")
	assert_false(me.next_card_free, "consumed by the play")

func test_auto_hit_emits_proc_event() -> void:
	var rt := _rt()
	rt.tune.set_value("auto_proc_chance", 1.0)
	var procs: int = 0
	for e: Dictionary in _run(rt, rt.swing_speed(0) + 0.2):
		if str(e.get("type", "")) == "proc":
			procs += 1
	assert_eq(procs, 1)
	assert_true(rt.state.players[0].next_card_free)
