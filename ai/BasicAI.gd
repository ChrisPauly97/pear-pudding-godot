class_name BasicAI
extends RefCounted

const GameState = preload("res://game_logic/battle/GameState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")

## Returns a list of actions the AI wants to take (as Callables to execute on game state).
## Decisions are deferred to execution time so plays and attacks use current state,
## preventing double-discard corruption and stale-plan silent failures.
static func decide_turn(state: GameState) -> Array[Callable]:
	var actions: Array[Callable] = []
	var ai := state.current_player()

	# One Callable per hand slot — each re-checks can_play at execution time so
	# earlier plays that spent mana don't silently try to over-spend.
	var hand_snapshot := ai.hand.duplicate()
	for card in hand_snapshot:
		var c := card as CardInstance
		actions.append(func():
			if c in ai.hand and ai.can_play(c):
				ai.play_card(c)
		)

	# One Callable per board slot — targets are resolved at execution time so a
	# minion killed by a previous attack isn't targeted again (double-discard fix).
	for my_card in ai.board.get_cards():
		var mc := my_card as CardInstance
		actions.append(func():
			if not mc.can_attack():
				return
			var all_targets := state.opponent().board.get_cards()
			var ward_targets: Array[CardInstance] = []
			for t: CardInstance in all_targets:
				if t.keywords.has(Keywords.WARD):
					ward_targets.append(t)
			var targets := ward_targets if not ward_targets.is_empty() else all_targets
			if targets.is_empty():
				# Attack hero — take retaliation (passive_atk symmetry fix)
				state.opponent().hero.take_damage(BattlefieldRules.modify_damage(mc.attack, state.battlefield_biome))
				mc.take_damage(BattlefieldRules.modify_damage(state.opponent().hero.attack, state.battlefield_biome))
				mc.attack_count -= 1
				if not mc.is_alive():
					ai.board.remove_card(mc)
					ai.discard.append(mc)
			else:
				var tgt := targets[0] as CardInstance
				tgt.take_damage(BattlefieldRules.modify_damage(mc.attack, state.battlefield_biome))
				mc.take_damage(BattlefieldRules.modify_damage(tgt.attack, state.battlefield_biome))
				mc.attack_count -= 1
				if not tgt.is_alive():
					state.opponent().board.remove_card(tgt)
					state.opponent().discard.append(tgt)
				if not mc.is_alive():
					ai.board.remove_card(mc)
					ai.discard.append(mc)
		)

	return actions

## Returns a human-readable description of the AI's first planned action.
static func describe_turn(state: GameState) -> String:
	var ai := state.current_player()

	# Check if any card can be played
	for card in ai.hand:
		var c := card as CardInstance
		if ai.can_play(c):
			return "Enemy will play " + c.name

	# Check if any minion can attack
	for my_card in ai.board.get_cards():
		var mc := my_card as CardInstance
		if not mc.can_attack():
			continue
		var all_targets := state.opponent().board.get_cards()
		var ward_targets: Array[CardInstance] = []
		for t: CardInstance in all_targets:
			if t.keywords.has(Keywords.WARD):
				ward_targets.append(t)
		var targets := ward_targets if not ward_targets.is_empty() else all_targets
		if targets.is_empty():
			return "Enemy will attack your hero with " + mc.name
		else:
			var tgt := targets[0] as CardInstance
			return "Enemy attacks " + tgt.name + " with " + mc.name

	return "Enemy is thinking..."
