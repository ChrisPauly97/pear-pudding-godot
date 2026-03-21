## Unit tests for BasicAI.
##
## Tests verify that the AI returns a correctly typed array of Callables and
## that executing those actions produces the expected game-state mutations:
## cards played, attacks dealt to hero, attacks dealt to minions, and lethal
## minion cleanup.
##
## GameState requires the CardRegistry autoload, so run via:
##   godot --headless --path . -s tests/runner.gd
extends "res://tests/framework/test_case.gd"

const BasicAI = preload("res://ai/BasicAI.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _tmpl(id: String = "ghost", cost: int = 1, attack: int = 1, health: int = 2) -> Dictionary:
	return {
		"id": id, "name": id.capitalize(), "cost": cost,
		"attack": attack, "health": health,
		"card_class": "minion", "description": "",
	}


func _card(cost: int = 1, attack: int = 1, health: int = 2) -> CardInstance:
	return CardInstance.from_template(_tmpl("ghost", cost, attack, health))


## Build a fresh GameState and return it.
func _state() -> GameState:
	return GameState.new()


## Advance state so it is the AI's turn (player index 1).
func _ai_turn_state() -> GameState:
	var gs = _state()
	gs.end_turn()  # player 0 ends → player 1 (AI) acts
	return gs


## Clear the hand for the given player and populate it with specific cards.
func _set_hand(player: PlayerState, cards: Array) -> void:
	player.hand.clear()
	for c in cards:
		player.hand.append(c)


## Place a card directly on a player's board (ready to attack).
func _place_on_board(player: PlayerState, card: CardInstance) -> void:
	card.summoning_sick = false
	player.board.add_card(card)


# ---------------------------------------------------------------------------
# Return type
# ---------------------------------------------------------------------------

func test_decide_turn_returns_array() -> void:
	var gs = _ai_turn_state()
	var actions = BasicAI.decide_turn(gs)
	assert_true(actions is Array)


func test_decide_turn_with_empty_hand_and_board_returns_empty_array() -> void:
	var gs = _ai_turn_state()
	gs.current_player().hand.clear()
	var actions = BasicAI.decide_turn(gs)
	assert_eq(actions.size(), 0)


# ---------------------------------------------------------------------------
# Playing cards from hand
# ---------------------------------------------------------------------------

func test_ai_queues_action_to_play_affordable_card() -> void:
	var gs = _ai_turn_state()
	var ai_player = gs.current_player()
	ai_player.hero.gain_mana_for_turn(10)
	var affordable_card = _card(1)
	_set_hand(ai_player, [affordable_card])

	var actions = BasicAI.decide_turn(gs)
	# Execute all queued actions
	for a in actions:
		a.call()

	assert_has(ai_player.board.get_cards(), affordable_card)


func test_ai_does_not_play_cards_that_cost_more_than_mana() -> void:
	var gs = _ai_turn_state()
	var ai_player = gs.current_player()
	ai_player.hero.gain_mana_for_turn(1)
	var expensive_card = _card(5)
	_set_hand(ai_player, [expensive_card])

	var actions = BasicAI.decide_turn(gs)
	for a in actions:
		a.call()

	assert_eq(ai_player.board.get_cards().size(), 0)


func test_ai_plays_multiple_affordable_cards() -> void:
	var gs = _ai_turn_state()
	var ai_player = gs.current_player()
	ai_player.hero.gain_mana_for_turn(10)
	var cards: Array[CardInstance] = []
	for _i in range(3):
		cards.append(_card(1))
	_set_hand(ai_player, cards)

	var actions = BasicAI.decide_turn(gs)
	for a in actions:
		a.call()

	assert_eq(ai_player.board.get_cards().size(), 3)


# ---------------------------------------------------------------------------
# Attacking the hero when opponent board is empty
# ---------------------------------------------------------------------------

func test_ai_attacks_hero_when_opponent_board_empty() -> void:
	var gs = _ai_turn_state()
	var ai_player = gs.current_player()
	var opponent = gs.opponent()
	_set_hand(ai_player, [])
	opponent.board.slots.fill(null)  # ensure opponent board empty

	var attacker = _card(1, 3, 2)
	_place_on_board(ai_player, attacker)

	var hero_hp_before: int = opponent.hero.health
	var actions = BasicAI.decide_turn(gs)
	for a in actions:
		a.call()

	assert_lt(opponent.hero.health, hero_hp_before)


func test_ai_hero_attack_deals_correct_damage() -> void:
	var gs = _ai_turn_state()
	var ai_player = gs.current_player()
	var opponent = gs.opponent()
	_set_hand(ai_player, [])
	opponent.board.slots.fill(null)

	var attacker = _card(1, 5, 2)  # 5 attack
	_place_on_board(ai_player, attacker)

	var actions = BasicAI.decide_turn(gs)
	for a in actions:
		a.call()

	assert_eq(opponent.hero.health, opponent.hero.max_health - 5)


# ---------------------------------------------------------------------------
# Attacking opponent minions
# ---------------------------------------------------------------------------

func test_ai_attacks_opponent_minion_when_present() -> void:
	var gs = _ai_turn_state()
	var ai_player = gs.current_player()
	_set_hand(ai_player, [])

	var attacker = _card(1, 2, 4)
	_place_on_board(ai_player, attacker)

	var target = _card(1, 1, 5)
	target.summoning_sick = false
	gs.opponent().board.add_card(target)

	var target_hp_before: int = target.health
	var actions = BasicAI.decide_turn(gs)
	for a in actions:
		a.call()

	assert_lt(target.health, target_hp_before)


func test_ai_minion_takes_return_damage_when_attacking() -> void:
	var gs = _ai_turn_state()
	var ai_player = gs.current_player()
	_set_hand(ai_player, [])

	var attacker = _card(1, 1, 5)  # 1 attack, 5 health
	_place_on_board(ai_player, attacker)

	var target = _card(1, 3, 5)  # 3 attack, 5 health
	target.summoning_sick = false
	gs.opponent().board.add_card(target)

	var actions = BasicAI.decide_turn(gs)
	for a in actions:
		a.call()

	# Attacker took 3 damage back → 2 health remaining
	assert_eq(attacker.health, 2)


func test_ai_removes_killed_target_from_board() -> void:
	var gs = _ai_turn_state()
	var ai_player = gs.current_player()
	_set_hand(ai_player, [])

	var attacker = _card(1, 10, 5)  # lethal attacker
	_place_on_board(ai_player, attacker)

	var target = _card(1, 1, 2)  # 2 health — dies to 10 damage
	target.summoning_sick = false
	gs.opponent().board.add_card(target)

	var actions = BasicAI.decide_turn(gs)
	for a in actions:
		a.call()

	assert_does_not_have(gs.opponent().board.get_cards(), target)


func test_ai_removes_killed_attacker_from_board() -> void:
	var gs = _ai_turn_state()
	var ai_player = gs.current_player()
	_set_hand(ai_player, [])

	var attacker = _card(1, 1, 1)  # 1 health — dies to return damage
	_place_on_board(ai_player, attacker)

	var target = _card(1, 5, 10)  # 5 attack — kills attacker
	target.summoning_sick = false
	gs.opponent().board.add_card(target)

	var actions = BasicAI.decide_turn(gs)
	for a in actions:
		a.call()

	assert_does_not_have(ai_player.board.get_cards(), attacker)


# ---------------------------------------------------------------------------
# Summoning sickness — freshly played cards do not attack
# ---------------------------------------------------------------------------

func test_newly_played_card_does_not_attack_same_turn() -> void:
	var gs = _ai_turn_state()
	var ai_player = gs.current_player()
	ai_player.hero.gain_mana_for_turn(10)
	var opponent = gs.opponent()
	opponent.board.slots.fill(null)

	var new_card = _card(1, 5, 2)  # 5 attack — would hurt if it attacked
	_set_hand(ai_player, [new_card])

	var hero_hp_before: int = opponent.hero.health
	var actions = BasicAI.decide_turn(gs)
	for a in actions:
		a.call()

	# Card was played (summoning sick), should not have attacked hero
	assert_eq(opponent.hero.health, hero_hp_before)
