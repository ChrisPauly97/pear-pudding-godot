## Unit tests for scripted story battles (GID-108).
## Verifies deterministic draw order, opening hand count, no-shuffle guarantee,
## and completion-state serialization for GameState.load_scripted_battle().
extends "res://tests/framework/test_case.gd"

const GameState = preload("res://game_logic/battle/GameState.gd")
const ScriptedBattleData = preload("res://game_logic/battle/ScriptedBattleData.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _sbd(player_order: Array[String], enemy_order: Array[String] = ["ghost"]) -> ScriptedBattleData:
	var sd := ScriptedBattleData.new()
	sd.battle_id = "test_scripted"
	sd.title = "Test Scripted Battle"
	sd.player_deck_order = player_order
	sd.opening_hand_count = 1
	sd.player_hero_hp = 30
	sd.enemy_deck_order = enemy_order
	sd.enemy_opening_hand_count = 1
	sd.enemy_hero_hp = 5
	sd.tutorial_steps = []
	sd.reward_card_id = ""
	sd.completion_flag = ""
	return sd


# ---------------------------------------------------------------------------
# PlayerState.build_scripted_deck — deterministic draw order
# ---------------------------------------------------------------------------

func test_build_scripted_deck_no_shuffle_matches_order() -> void:
	var order: Array[String] = ["ghost", "skeleton", "zombie", "ghoul"]
	var ps := PlayerState.new(0, false)
	ps.build_scripted_deck(order)
	var drawn: Array[String] = []
	for _i in range(order.size()):
		var c: CardInstance = ps.draw_card()
		drawn.append(c.template_id)
	assert_eq(drawn, order)


func test_build_scripted_deck_is_deterministic_across_builds() -> void:
	var order: Array[String] = ["ghost", "skeleton", "ghost", "zombie", "skeleton", "ghoul"]
	var ps1 := PlayerState.new(0, false)
	ps1.build_scripted_deck(order)
	var ps2 := PlayerState.new(0, false)
	ps2.build_scripted_deck(order)
	var drawn1: Array[String] = []
	var drawn2: Array[String] = []
	for _i in range(order.size()):
		drawn1.append(ps1.draw_card().template_id)
		drawn2.append(ps2.draw_card().template_id)
	assert_eq(drawn1, drawn2)
	assert_eq(drawn1, order)


func test_build_scripted_deck_skips_unknown_card_ids() -> void:
	var order: Array[String] = ["ghost", "not_a_real_card", "skeleton"]
	var ps := PlayerState.new(0, false)
	ps.build_scripted_deck(order)
	assert_eq(ps.draw_deck.size(), 2)


# ---------------------------------------------------------------------------
# GameState.load_scripted_battle
# ---------------------------------------------------------------------------

func test_load_scripted_battle_sets_scripted_battle_true() -> void:
	var sd := _sbd(["ghost", "skeleton"])
	var gs := GameState.new()
	gs.load_scripted_battle(sd)
	assert_true(gs.scripted_battle)


func test_load_scripted_battle_sets_battle_id() -> void:
	var sd := _sbd(["ghost", "skeleton"])
	var gs := GameState.new()
	gs.load_scripted_battle(sd)
	assert_eq(gs.scripted_battle_id, "test_scripted")


func test_load_scripted_battle_sets_current_player_to_zero() -> void:
	var sd := _sbd(["ghost", "skeleton"])
	var gs := GameState.new()
	gs.load_scripted_battle(sd)
	assert_eq(gs.current_player_idx, 0)


func test_load_scripted_battle_sets_hero_hp() -> void:
	var sd := _sbd(["ghost", "skeleton"])
	sd.player_hero_hp = 20
	sd.enemy_hero_hp = 7
	var gs := GameState.new()
	gs.load_scripted_battle(sd)
	assert_eq(gs.current_player().hero.health, 20)
	assert_eq(gs.opponent().hero.health, 7)


func test_load_scripted_battle_draws_exact_opening_hand_count() -> void:
	var sd := _sbd(["ghost", "skeleton", "zombie"])
	sd.opening_hand_count = 2
	var gs := GameState.new()
	gs.load_scripted_battle(sd)
	assert_eq(gs.current_player().hand.size(), 2)
	assert_eq(gs.current_player().draw_deck.size(), 1)


func test_load_scripted_battle_opening_hand_matches_order_prefix() -> void:
	var order: Array[String] = ["ghost", "skeleton", "zombie", "ghoul"]
	var sd := _sbd(order)
	sd.opening_hand_count = 2
	var gs := GameState.new()
	gs.load_scripted_battle(sd)
	var hand: Array[CardInstance] = gs.current_player().hand
	assert_eq(hand[0].template_id, "ghost")
	assert_eq(hand[1].template_id, "skeleton")


func test_load_scripted_battle_enemy_gets_own_scripted_deck() -> void:
	var sd := _sbd(["ghost", "skeleton"], ["zombie", "ghoul"])
	sd.enemy_opening_hand_count = 1
	var gs := GameState.new()
	gs.load_scripted_battle(sd)
	assert_eq(gs.opponent().hand[0].template_id, "zombie")


# ---------------------------------------------------------------------------
# to_dict / from_dict round-trip
# ---------------------------------------------------------------------------

func test_scripted_battle_survives_serialization() -> void:
	var sd := _sbd(["ghost", "skeleton"])
	var gs := GameState.new()
	gs.load_scripted_battle(sd)
	var d := gs.to_dict()
	var gs2 := GameState.new()
	gs2.from_dict(d)
	assert_true(gs2.scripted_battle)
	assert_eq(gs2.scripted_battle_id, "test_scripted")


# ---------------------------------------------------------------------------
# ScriptedBattleData.validate()
# ---------------------------------------------------------------------------

func test_validate_flags_empty_battle_id() -> void:
	var sd := _sbd(["ghost"])
	sd.battle_id = ""
	assert_gt(sd.validate().size(), 0)


func test_validate_flags_unknown_card() -> void:
	var sd := _sbd(["ghost"])
	sd.player_deck_order = ["totally_unknown_card_id"]
	assert_gt(sd.validate().size(), 0)


func test_validate_flags_opening_hand_exceeding_deck_size() -> void:
	var sd := _sbd(["ghost"])
	sd.opening_hand_count = 5
	assert_gt(sd.validate().size(), 0)


func test_validate_flags_malformed_tutorial_step() -> void:
	var sd := _sbd(["ghost", "skeleton"])
	sd.tutorial_steps = ["not_a_valid_step"]
	assert_gt(sd.validate().size(), 0)


func test_validate_accepts_wellformed_tutorial_step() -> void:
	var sd := _sbd(["ghost", "skeleton"])
	sd.tutorial_steps = ["1:Play your first card."]
	assert_eq(sd.validate().size(), 0)


func test_validate_passes_for_wellformed_data() -> void:
	var sd := _sbd(["ghost", "skeleton"])
	assert_eq(sd.validate().size(), 0)
