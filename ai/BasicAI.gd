class_name BasicAI
extends RefCounted

const GameState = preload("res://game_logic/battle/GameState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")

## Returns a list of actions the AI wants to take (as Callables to execute on game state).
static func decide_turn(state: GameState) -> Array[Callable]:
	var actions: Array[Callable] = []
	var ai := state.current_player()

	# Play affordable cards
	var cards_to_play := ai.hand.duplicate()
	for card in cards_to_play:
		if ai.can_play(card):
			var c := card as CardInstance  # capture
			actions.append(func(): ai.play_card(c))

	# Attack with all minions that can attack
	for my_card in ai.board.get_cards():
		if not my_card.can_attack():
			continue
		var targets := state.opponent().board.get_cards()
		if targets.is_empty():
			# Attack hero
			var mc := my_card
			actions.append(func():
				if mc.can_attack():
					state.opponent().hero.take_damage(mc.attack)
					mc.attack_count -= 1
			)
		else:
			# Attack first target
			var mc := my_card
			var tgt := targets[0]
			actions.append(func():
				if mc.can_attack():
					tgt.take_damage(mc.attack)
					mc.take_damage(tgt.attack)
					mc.attack_count -= 1
					if not tgt.is_alive():
						state.opponent().board.remove_card(tgt)
						state.opponent().discard.append(tgt)
					if not mc.is_alive():
						ai.board.remove_card(mc)
						ai.discard.append(mc)
			)

	return actions
