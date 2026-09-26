## GID-135 / TID-546: real-time combat driver (pure logic).
extends "res://tests/framework/test_case.gd"

const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const _BattleRealtime = preload("res://scenes/battle/modules/BattleRealtime.gd")

func _card(attack: int = 2, health: int = 3, cost: int = 1, keywords: Array = []) -> CardInstance:
	return CardInstance.new({
		"id": "unit", "name": "Unit", "cost": cost, "attack": attack, "health": health,
		"card_class": "minion", "description": "", "keywords": keywords,
	})

## Fresh state with empty hands/decks so draws and enemy casts are controlled.
func _rt() -> RealtimeCombat:
	var gs := GameState.new()
	for p: PlayerState in gs.players:
		p.hand.clear()
		p.draw_deck.clear()
	return RealtimeCombat.new(gs)

## Advance in 0.1 s steps (plus one step of slack for float drift), collecting events.
func _run(rt: RealtimeCombat, seconds: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t: float = 0.0
	while t < seconds + 0.05:
		out.append_array(rt.advance(0.1))
		t += 0.1
	return out

func test_player_pinned_and_start_mana() -> void:
	var rt := _rt()
	assert_eq(rt.state.current_player_idx, 0)
	assert_gte(rt.state.players[0].hero.max_mana, RealtimeCombat.START_MAX_MANA)
	assert_eq(rt.state.players[0].hero.mana, rt.state.players[0].hero.max_mana)

func test_mana_regenerates_on_clock() -> void:
	var rt := _rt()
	var h := rt.state.players[0].hero
	h.mana = 0
	_run(rt, RealtimeCombat.MANA_REGEN_INTERVAL)
	assert_eq(h.mana, 1)

func test_max_mana_grows_to_cap() -> void:
	var rt := _rt()
	rt.state.players[1].hero.health = 100000  # outlast the auto-attack
	_run(rt, RealtimeCombat.MAX_MANA_INTERVAL * 20.0)
	assert_eq(rt.state.players[0].hero.max_mana, RealtimeCombat.MANA_CAP)

func test_draw_on_clock_respects_hand_cap() -> void:
	var rt := _rt()
	var p := rt.state.players[0]
	rt.state.players[1].hero.health = 100000  # outlast the auto-attack
	for i in range(10):
		p.draw_deck.append(_card())
	_run(rt, RealtimeCombat.DRAW_INTERVAL)
	assert_eq(p.hand.size(), 1)
	_run(rt, RealtimeCombat.DRAW_INTERVAL * 20.0)
	assert_eq(p.hand.size(), RealtimeCombat.HAND_CAP)

func test_gcd_blocks_then_clears() -> void:
	var rt := _rt()
	assert_true(rt.gcd_ready(0))
	rt.start_gcd(0)
	assert_false(rt.gcd_ready(0))
	_run(rt, RealtimeCombat.PLAYER_GCD)
	assert_true(rt.gcd_ready(0))

func test_ally_swings_enemy_hero_without_retaliation() -> void:
	var rt := _rt()
	var ally := _card(2, 3)
	rt.state.players[0].board.add_card(ally)
	rt.state.players[1].hero.attack = 0
	var hp_before: int = rt.state.players[1].hero.health
	_run(rt, RealtimeCombat.SWING_INTERVAL)
	# One ally swing (2) + one main-hand hero swing (2.5 s) inside the window.
	assert_eq(rt.state.players[1].hero.health, hp_before - 2 - rt.main_hand_damage(0),
		"fresh ally swings after one interval")
	assert_eq(ally.health, 3, "no retaliation in real time")

func test_ward_is_hit_first() -> void:
	var rt := _rt()
	rt.state.players[0].board.add_card(_card(2, 3))
	var warden := _card(0, 9, 1, ["ward"])
	rt.state.players[1].board.add_card(warden)
	var hero_hp: int = rt.state.players[1].hero.health
	_run(rt, RealtimeCombat.SWING_INTERVAL)
	assert_eq(warden.health, 9 - 2 - rt.main_hand_damage(0), "ally and hero auto-attack both hit the Ward")
	assert_eq(rt.state.players[1].hero.health, hero_hp)

func test_focus_target_is_hit_and_cleared_on_death() -> void:
	var rt := _rt()
	rt.state.players[0].board.add_card(_card(5, 3))
	var foe := _card(0, 4)
	rt.state.players[1].board.add_card(foe)
	rt.focus_target = foe
	_run(rt, RealtimeCombat.SWING_INTERVAL)
	assert_false(foe.is_alive())
	assert_false(rt.state.players[1].board.get_cards().has(foe))
	assert_null(rt.focus_target)

func test_enemy_telegraphs_then_casts() -> void:
	var rt := _rt()
	var minion := _card(1, 1, 1)
	rt.state.players[1].hand.append(minion)
	var ev: Array[Dictionary] = rt.advance(0.1)
	assert_eq(str(ev[ev.size() - 1].get("type", "")), "enemy_cast_start")
	assert_false(rt.state.players[1].board.get_cards().has(minion), "not played during the cast bar")
	var types: Array[String] = []
	for e: Dictionary in _run(rt, RealtimeCombat.ENEMY_CAST_TIME):
		types.append(str(e.get("type", "")))
	assert_true(types.has("enemy_cast"))
	assert_true(rt.state.players[1].board.get_cards().has(minion))
	assert_false(rt.gcd_ready(1), "enemy GCD starts after the cast")

func test_no_events_after_game_over() -> void:
	var rt := _rt()
	rt.state.players[1].hero.health = 0
	assert_true(rt.advance(10.0).is_empty())

func test_eligibility() -> void:
	assert_true(_BattleRealtime.eligible("realtime", true, false, false, false))
	assert_true(_BattleRealtime.eligible("realtime_slow", true, false, false, false))
	assert_false(_BattleRealtime.eligible("turn", true, false, false, false))
	assert_false(_BattleRealtime.eligible("realtime", false, false, false, false), "resumed battles stay turn-based")
	assert_false(_BattleRealtime.eligible("realtime", true, true, false, false), "networked stays turn-based")
	assert_false(_BattleRealtime.eligible("realtime", true, false, true, false))
	assert_false(_BattleRealtime.eligible("realtime", true, false, false, true))

func test_player_auto_attacks_with_no_mana_or_units() -> void:
	var rt := _rt()
	rt.state.players[0].hero.mana = 0
	var hp: int = rt.state.players[1].hero.health
	_run(rt, RealtimeCombat.HERO_SWING_INTERVAL)
	assert_eq(rt.state.players[1].hero.health, hp - RealtimeCombat.UNARMED_DAMAGE)

func test_weapon_attack_adds_to_main_hand() -> void:
	var rt := _rt()
	rt.state.players[0].hero.attack = 3
	assert_eq(rt.main_hand_damage(0), 3 + RealtimeCombat.UNARMED_DAMAGE)

func test_offhand_swings_on_its_own_timer() -> void:
	var rt := _rt()
	rt.offhand_damage[0] = 1
	var hands: Array[String] = []
	for e: Dictionary in _run(rt, RealtimeCombat.HERO_SWING_INTERVAL):
		if str(e.get("type", "")) == "swing" and e.get("attacker") == null and int(e.get("side", -1)) == 0:
			hands.append(str(e.get("hand", "")))
	assert_true(hands.has("off"), "off hand swung")
	assert_true(hands.has("main"), "main hand swung")

func test_enemy_hero_without_attack_does_not_swing() -> void:
	var rt := _rt()
	rt.state.players[1].hero.attack = 0
	var hp: int = rt.state.players[0].hero.health
	_run(rt, RealtimeCombat.HERO_SWING_INTERVAL * 3.0)
	assert_eq(rt.state.players[0].hero.health, hp)

func test_frozen_hero_does_not_swing() -> void:
	var rt := _rt()
	rt.state.players[0].hero.status_effects["freeze"] = 1
	var hp: int = rt.state.players[1].hero.health
	_run(rt, RealtimeCombat.HERO_SWING_INTERVAL)
	assert_eq(rt.state.players[1].hero.health, hp)
