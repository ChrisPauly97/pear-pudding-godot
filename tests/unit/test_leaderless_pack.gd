## BID-077: leaderless packs — no enemy hero to hit; clearing the board wins.
extends "res://tests/framework/test_case.gd"

const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")


func _card(attack: int = 2, health: int = 3) -> CardInstance:
	return CardInstance.new({
		"id": "unit", "name": "Unit", "cost": 1, "attack": attack, "health": health,
		"card_class": "minion", "description": "", "keywords": [],
	})


## Two-seat state whose enemy is a leaderless pack of `units`.
func _pack_state(units: Array[CardInstance]) -> GameState:
	var gs := GameState.new()
	for p: PlayerState in gs.players:
		p.hand.clear()
		p.draw_deck.clear()
	for c: CardInstance in units:
		gs.players[1].board.add_card(c)
	gs.players[1].hero.leaderless = true
	return gs


func test_leaderless_hero_takes_no_damage() -> void:
	var gs := _pack_state([_card()])
	var hero: HeroState = gs.players[1].hero
	var hp: int = hero.health
	hero.take_damage(10)
	assert_eq(hero.health, hp)
	assert_true(gs.players[1].hero_unreachable())
	assert_false(gs.is_game_over())


func test_clearing_the_board_wins() -> void:
	var unit := _card()
	var gs := _pack_state([unit])
	gs.players[1].board.remove_card(unit)
	assert_true(gs.is_game_over())
	assert_eq(gs.winner(), 0)
	assert_false(gs.players[1].hero.is_alive())


func test_ordinary_hero_unaffected_by_empty_board() -> void:
	var gs := GameState.new()
	gs.players[1].board.get_cards().clear()
	assert_false(gs.is_game_over())
	assert_false(gs.players[1].hero_unreachable())


func test_leaderless_flag_round_trips() -> void:
	var h := HeroState.new(1)
	h.leaderless = true
	var back := HeroState.new(1)
	back.from_dict(h.to_dict())
	assert_true(back.leaderless)
	var plain := HeroState.new(1)
	plain.from_dict({})
	assert_false(plain.leaderless)


func test_realtime_hero_swings_at_weakest_pack_member() -> void:
	var weak := _card(1, 2)
	var tough := _card(1, 9)
	var rt := RealtimeCombat.new(_pack_state([tough, weak]))
	assert_eq(rt.pick_target(RealtimeCombat.PLAYER), weak)


func test_pack_stand_in_never_swings() -> void:
	var rt := RealtimeCombat.new(_pack_state([_card()]))
	rt.state.players[1].hero.attack = 5
	assert_eq(rt.main_hand_damage(RealtimeCombat.ENEMY), 0)


func test_undead_horde_is_the_leaderless_pack() -> void:
	assert_true(EnemyRegistry.is_leaderless("undead_horde"))
	assert_false(EnemyRegistry.is_leaderless("ghoul_pack"))
	assert_false(EnemyRegistry.get_pack("undead_horde").is_empty())
