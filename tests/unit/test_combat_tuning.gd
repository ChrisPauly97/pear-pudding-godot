## GID-135 / TID-549: combat tuning table + WoW-style timing rules (pure logic).
extends "res://tests/framework/test_case.gd"

const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const _BattleRealtime = preload("res://scenes/battle/modules/BattleRealtime.gd")
const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")

## Default tuning — what every RealtimeCombat below runs with.
var _tune := CombatTuning.new()

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

# ---------------------------------------------------------------------------
# TID-549: tuning table, spell queue, weapon speed, five-second rule, pushback, interrupt
# ---------------------------------------------------------------------------

func test_tuning_defaults_clamp_and_overrides() -> void:
	var t := CombatTuning.new({"player_gcd": 99.0, "nonsense": 1.0})
	assert_eq(t.get_f("player_gcd"), 3.0, "clamped to the row max")
	assert_false(t.has_key("nonsense"))
	assert_eq(t.overrides().keys(), ["player_gcd"])
	t.nudge("player_gcd", -5)
	assert_eq(t.get_f("player_gcd"), 2.5)
	t.reset()
	assert_true(t.overrides().is_empty())

func test_tuning_drives_the_gcd() -> void:
	var gs := GameState.new()
	var levels: Array[int] = [1, 1]
	var rt := RealtimeCombat.new(gs, levels, CombatTuning.new({"player_gcd": 2.0}))
	rt.start_gcd(0)
	assert_eq(rt.gcd[0], 2.0)

func test_spell_queue_window() -> void:
	var rt := _rt()
	rt.start_gcd(0)
	assert_false(rt.in_queue_window(0), "fresh GCD is outside the window")
	_run(rt, _tune.get_f("player_gcd") - _tune.get_f("spell_queue") + 0.05)
	assert_true(rt.in_queue_window(0), "last stretch of the GCD accepts the next play")

func test_five_second_rule_pauses_regen_after_spending() -> void:
	var rt := _rt()
	var h := rt.state.players[0].hero
	h.mana = h.max_mana - 300
	_run(rt, _tune.get_f("mana_regen_delay") - 0.3)
	assert_eq(h.mana, h.max_mana - 300, "no regen right after spending")
	_run(rt, 1.5)
	assert_gt(h.mana, h.max_mana - 300, "regen resumes after the pause")

func test_slow_weapon_hits_harder_per_swing() -> void:
	var rt := _rt()
	var base: int = rt.main_hand_damage(0)
	rt.weapon_speed[0] = _tune.get_f("hero_swing") * 2.0
	assert_eq(rt.main_hand_damage(0), base * 2, "twice as slow, twice the damage per swing")
	assert_eq(rt.swing_speed(0), _tune.get_f("hero_swing") * 2.0)

func test_enemy_cast_pushback_and_interrupt() -> void:
	var rt := _rt()
	rt.unarmed[0] = 0  # keep the player's hero from auto-hitting
	rt.state.players[1].hand.append(_card(1, 1, 1))
	rt.advance(0.1)
	assert_not_null(rt.enemy_casting)
	var left: float = rt.enemy_cast_remaining
	rt.state.players[1].hero.take_damage(1)
	rt.advance(0.0)
	assert_true(rt.enemy_cast_remaining > left, "a hit pushes the cast back")
	var cut: Object = rt.interrupt_enemy_cast()
	assert_not_null(cut)
	assert_null(rt.enemy_casting)
	assert_true(rt.state.players[1].hand.has(cut), "interrupted card stays in hand")
	assert_false(rt.gcd_ready(1), "interrupt puts the enemy on cooldown")
