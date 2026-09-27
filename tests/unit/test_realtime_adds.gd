## GID-135 / TID-551: a second enemy joins a real-time fight (WoW "add").
extends "res://tests/framework/test_case.gd"

const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

func _card(attack: int = 2, health: int = 3, cost: int = 1) -> CardInstance:
	return CardInstance.new({"id": "unit", "name": "Unit", "cost": cost, "attack": attack, "health": health,
		"card_class": "minion", "description": ""})

func _rt() -> RealtimeCombat:
	var gs := GameState.new()
	for p: PlayerState in gs.players:
		p.hand.clear()
		p.draw_deck.clear()
	return RealtimeCombat.new(gs)

func _add(rt: RealtimeCombat) -> int:
	var ps := PlayerState.new(0, true)
	return rt.add_enemy(ps, 1)

func _run(rt: RealtimeCombat, seconds: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t: float = 0.0
	while t < seconds + 0.05:
		out.append_array(rt.advance(0.1))
		t += 0.1
	return out

func test_add_makes_a_team_battle() -> void:
	var rt := _rt()
	var side: int = _add(rt)
	assert_eq(side, 2)
	assert_eq(rt.state.players.size(), 3)
	assert_true(rt.state.team_battle)
	assert_eq(rt.state.player_teams, [0, 1, 1] as Array[int])
	assert_eq(rt.enemy_sides(), [1, 2] as Array[int])
	assert_eq(rt.state.players[2].hero.max_mana, RealtimeCombat.max_mana_for(1, 0, rt.tune))
	assert_eq(_add(rt), -1, "only one add per fight")

func test_fight_ends_only_when_every_enemy_is_down() -> void:
	var rt := _rt()
	_add(rt)
	rt.state.players[1].hero.health = 0
	assert_false(rt.state.is_game_over(), "the add is still standing")
	rt.state.players[2].hero.health = 0
	assert_true(rt.state.is_game_over())
	assert_eq(rt.state.winner(), 0, "you win")

func test_auto_attack_moves_to_the_remaining_enemy() -> void:
	var rt := _rt()
	_add(rt)
	rt.unarmed[1] = 0
	rt.unarmed[2] = 0
	rt.state.players[1].hero.health = 0
	var hp2: int = rt.state.players[2].hero.health
	_run(rt, rt.tune.get_f("hero_swing"))
	assert_eq(rt.state.players[2].hero.health, hp2 - rt.main_hand_damage(0))

func test_focus_enemy_picks_the_hero_to_hit() -> void:
	var rt := _rt()
	_add(rt)
	rt.unarmed[1] = 0
	rt.unarmed[2] = 0
	rt.focus_enemy = 2
	var hp1: int = rt.state.players[1].hero.health
	var hp2: int = rt.state.players[2].hero.health
	_run(rt, rt.tune.get_f("hero_swing"))
	assert_eq(rt.state.players[1].hero.health, hp1)
	assert_true(rt.state.players[2].hero.health < hp2)

func test_add_swings_and_casts_on_its_own_timers() -> void:
	var rt := _rt()
	rt.unarmed[0] = 0
	rt.unarmed[1] = 0
	var side: int = _add(rt)
	rt.state.players[side].hand.append(_card(1, 1, 1))
	var hp: int = rt.state.players[0].hero.health
	var types: Array[String] = []
	for e: Dictionary in _run(rt, rt.tune.get_f("enemy_gcd") + rt.tune.get_f("enemy_cast") + 0.5):
		if int(e.get("side", -1)) == side:
			types.append(str(e.get("type", "")))
	assert_true(types.has("enemy_cast_start") and types.has("enemy_cast"), "the add casts")
	assert_eq(rt.state.players[side].board.get_cards().size(), 1)
	assert_true(rt.state.players[0].hero.health < hp, "the add auto-attacks you")

func test_fallen_enemy_minions_flee() -> void:
	var rt := _rt()
	_add(rt)
	rt.state.players[1].board.add_card(_card())
	rt.state.players[1].hero.health = 0
	var ev: Array[Dictionary] = rt.advance(0.1)
	assert_true(rt.state.players[1].board.get_cards().is_empty())
	var downs: Array[Dictionary] = ev.filter(func(e: Dictionary) -> bool: return str(e["type"]) == "enemy_down")
	assert_eq(downs.size(), 1)

func test_interrupt_targets_the_given_enemy() -> void:
	var rt := _rt()
	var side: int = _add(rt)
	var c := _card()
	rt.state.players[side].hand.append(c)
	rt.casting[side] = c
	rt.cast_remaining[side] = 5.0
	assert_null(rt.interrupt_enemy_cast(1), "the first enemy wasn't casting")
	assert_eq(rt.interrupt_enemy_cast(side), c)
