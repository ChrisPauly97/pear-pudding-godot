## GID-178 / TID-728: critical hits on auto-attack swings, both sides.
extends "res://tests/framework/test_case.gd"

const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")

var _tune := CombatTuning.new()

func _run(rt: RealtimeCombat, seconds: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t: float = 0.0
	while t < seconds + 0.05:
		out.append_array(rt.advance(0.1))
		t += 0.1
	return out

## Swings crit on a seeded roll; a crit is × crit_mult (at least +1).
func _crit_rt(chance: float) -> RealtimeCombat:
	var gs := GameState.new()
	for p: PlayerState in gs.players:
		p.hand.clear()
		p.draw_deck.clear()
	var rt := RealtimeCombat.new(gs, [1, 1],
		CombatTuning.new({"crit_chance": chance, "enemy_crit_chance": chance}))
	rt.unarmed[RealtimeCombat.ENEMY] = 0
	rt.state.players[1].hero.attack = 0
	return rt

func _first_player_swing(rt: RealtimeCombat) -> Dictionary:
	for e: Dictionary in _run(rt, _tune.get_f("hero_swing") + 0.2):
		if str(e.get("type", "")) == "swing" and int(e.get("side", -1)) == RealtimeCombat.PLAYER:
			return e
	return {}

func test_crit_multiplies_swing_damage() -> void:
	var rt := _crit_rt(1.0)
	var foe := rt.state.players[1].hero
	var hp: int = foe.health
	var dmg: int = rt.main_hand_damage(RealtimeCombat.PLAYER)
	var ev: Dictionary = _first_player_swing(rt)
	assert_true(bool(ev.get("crit", false)), "crit flagged on the event")
	assert_eq(hp - foe.health, maxi(dmg + 1, roundi(float(dmg) * _tune.get_f("crit_mult"))))

func test_no_crit_at_zero_chance() -> void:
	var rt := _crit_rt(0.0)
	var foe := rt.state.players[1].hero
	var hp: int = foe.health
	var dmg: int = rt.main_hand_damage(RealtimeCombat.PLAYER)
	var ev: Dictionary = _first_player_swing(rt)
	assert_false(bool(ev.get("crit", true)))
	assert_eq(hp - foe.health, dmg)

func test_enemies_crit_too() -> void:
	var rt := _crit_rt(1.0)
	rt.unarmed[RealtimeCombat.ENEMY] = 2
	var crit: bool = false
	for e: Dictionary in _run(rt, _tune.get_f("hero_swing") * 2.0):
		if str(e.get("type", "")) == "swing" and int(e.get("side", -1)) == RealtimeCombat.ENEMY:
			crit = crit or bool(e.get("crit", false))
	assert_true(crit, "an enemy hero swing crits")
