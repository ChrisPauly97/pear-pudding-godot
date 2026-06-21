extends RefCounted

const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CaptureTracker = preload("res://game_logic/battle/CaptureTracker.gd")

# Co-located with resolver so match arms and targeting UI stay in sync.
const ENEMY_TARGETED_EFFECTS: Array[String] = ["deal_damage_single", "curse_minion", "lifesteal_hit"]
const FRIENDLY_TARGETED_EFFECTS: Array[String] = ["heal_single", "shield_minion", "buff_attack"]
const SLOT_TARGETED_EFFECTS: Array[String] = ["bless_slot", "ward_slot"]

var extra_turn_granted: bool = false
var capture_tracker: CaptureTracker

var _state: GameState

func setup(state: GameState) -> void:
	_state = state

## Fires when a minion with an emergence_effect is placed on the board.
func resolve_emergence(card: CardInstance, caster_pid: int) -> void:
	if card.emergence_effect == "":
		return
	AudioManager.play_sfx("spell_resolve")
	var opponent: PlayerState = _state.players[1 - caster_pid]
	var caster: PlayerState = _state.players[caster_pid]
	match card.emergence_effect:
		"emergence_deal_damage":
			opponent.hero.take_damage(BattlefieldRules.modify_damage(card.emergence_power, _state.battlefield_biome))
		"emergence_heal_hero":
			caster.hero.health = mini(caster.hero.max_health, caster.hero.health + card.emergence_power)
		"emergence_draw":
			for _i in range(card.emergence_power):
				caster.draw_card()
		"emergence_buff_friendly":
			var others: Array[CardInstance] = []
			for c: CardInstance in caster.board.get_cards():
				if c != card:
					others.append(c)
			if not others.is_empty():
				others[randi() % others.size()].attack += card.emergence_power
		"emergence_apply_poison":
			var enemies := opponent.board.get_cards()
			if not enemies.is_empty():
				enemies[randi() % enemies.size()].apply_status("poison", card.emergence_power)

## Resolves the effect of a spell card played by caster_pid against the opponent.
## explicit_target: optional dict with "type" ("minion"/"hero") and "card" (CardInstance).
func resolve_spell(card: CardInstance, caster_pid: int, explicit_target: Dictionary = {}) -> void:
	AudioManager.play_sfx("spell_resolve")
	var _ct_board_before: int = _state.players[1 - caster_pid].board.get_cards().size() if caster_pid == 0 else 0
	var opponent: PlayerState = _state.players[1 - caster_pid]
	var _spell_dmg: int = BattlefieldRules.modify_damage(card.spell_power, _state.battlefield_biome)
	match card.spell_effect:
		"deal_damage_single":
			var target_card: CardInstance = explicit_target.get("card", null) as CardInstance
			if target_card != null:
				target_card.take_damage(_spell_dmg)
				if not target_card.is_alive():
					opponent.board.remove_card(target_card)
					opponent.discard.append(target_card)
			elif explicit_target.get("type", "") == "hero":
				opponent.hero.take_damage(_spell_dmg)
			else:
				var targets := opponent.board.get_cards()
				if targets.is_empty():
					opponent.hero.take_damage(_spell_dmg)
				else:
					targets[0].take_damage(_spell_dmg)
					if not targets[0].is_alive():
						opponent.board.remove_card(targets[0])
						opponent.discard.append(targets[0])
		"deal_damage_all":
			for t in opponent.board.get_cards():
				t.take_damage(_spell_dmg)
			for t in opponent.board.get_cards().duplicate():
				if not t.is_alive():
					opponent.board.remove_card(t)
					opponent.discard.append(t)
		"deal_damage_random":
			var targets := opponent.board.get_cards()
			if targets.is_empty():
				opponent.hero.take_damage(_spell_dmg)
			else:
				var idx: int = randi() % targets.size()
				targets[idx].take_damage(_spell_dmg)
				if not targets[idx].is_alive():
					opponent.board.remove_card(targets[idx])
					opponent.discard.append(targets[idx])
		"debuff_attack":
			for t in opponent.board.get_cards():
				t.attack = maxi(0, t.attack - card.spell_power)
		"destroy_low_hp":
			for t in opponent.board.get_cards().duplicate():
				if t.health <= card.spell_power:
					opponent.board.remove_card(t)
					opponent.discard.append(t)
		"resurrect_last":
			var caster: PlayerState = _state.players[caster_pid]
			for i in range(caster.discard.size() - 1, -1, -1):
				var t := caster.discard[i] as CardInstance
				if t.card_class == "minion" and not caster.board.is_full():
					t.health = t.max_health
					t.summoning_sick = true
					caster.board.add_card(t)
					caster.discard.remove_at(i)
					break
		"heal_single":
			var caster: PlayerState = _state.players[caster_pid]
			var t: CardInstance = explicit_target.get("card", null) as CardInstance
			if t == null:
				var friendlies := caster.board.get_cards()
				if not friendlies.is_empty():
					t = friendlies[0]
			if t != null:
				t.health = mini(t.max_health, t.health + card.spell_power)
		"heal_all":
			var caster: PlayerState = _state.players[caster_pid]
			for t in caster.board.get_cards():
				t.health = mini(t.max_health, t.health + card.spell_power)
		"shield_minion":
			var caster: PlayerState = _state.players[caster_pid]
			var t: CardInstance = explicit_target.get("card", null) as CardInstance
			if t == null:
				var friendlies := caster.board.get_cards()
				if not friendlies.is_empty():
					t = friendlies[0]
			if t != null:
				t.apply_status("armor", t.get_status_value("armor") + card.spell_power)
		"buff_attack":
			var caster: PlayerState = _state.players[caster_pid]
			var t: CardInstance = explicit_target.get("card", null) as CardInstance
			if t == null:
				var friendlies := caster.board.get_cards()
				if not friendlies.is_empty():
					t = friendlies[0]
			if t != null:
				t.attack += card.spell_power
		"lifesteal_hit":
			var caster: PlayerState = _state.players[caster_pid]
			var t: CardInstance = explicit_target.get("card", null) as CardInstance
			if t == null:
				var targets := opponent.board.get_cards()
				if not targets.is_empty():
					t = targets[0]
			if t != null:
				t.take_damage(_spell_dmg)
				caster.hero.health = mini(caster.hero.max_health, caster.hero.health + _spell_dmg)
				if not t.is_alive():
					opponent.board.remove_card(t)
					opponent.discard.append(t)
		"mana_drain":
			opponent.hero.mana = maxi(0, opponent.hero.mana - card.spell_power)
		"curse_minion":
			var t: CardInstance = explicit_target.get("card", null) as CardInstance
			if t == null:
				var targets := opponent.board.get_cards()
				if not targets.is_empty():
					t = targets[0]
			if t != null:
				t.attack = maxi(0, t.attack - card.spell_power)
				t.health -= _spell_dmg
				if not t.is_alive():
					opponent.board.remove_card(t)
					opponent.discard.append(t)
		"draw_card":
			var caster: PlayerState = _state.players[caster_pid]
			for _i in range(card.spell_power):
				caster.draw_card()
		"bless_slot":
			var caster: PlayerState = _state.players[caster_pid]
			var slot: int = caster.board.first_empty_slot()
			if slot >= 0:
				caster.board.enhance_slot(slot, "atk_bonus", card.spell_power)
		"ward_slot":
			var caster: PlayerState = _state.players[caster_pid]
			var slot: int = caster.board.first_empty_slot()
			if slot >= 0:
				caster.board.enhance_slot(slot, "shroud", 1)
		"extra_turn":
			extra_turn_granted = true
		"destroy_all_draw_3":
			var caster: PlayerState = _state.players[caster_pid]
			for t in _state.players[0].board.get_cards().duplicate():
				_state.players[0].board.remove_card(t)
				_state.players[0].discard.append(t)
			for t in _state.players[1].board.get_cards().duplicate():
				_state.players[1].board.remove_card(t)
				_state.players[1].discard.append(t)
			for _i in range(3):
				caster.draw_card()
	if capture_tracker != null and caster_pid == 0:
		var _ct_board_after: int = _state.players[1].board.get_cards().size()
		capture_tracker.note_spell_resolved(0, _ct_board_before, _ct_board_after)

## Drains pending_auto_spells for the given player and resolves each.
## Called after any draw event (opening hand, turn draw).
func flush_auto_spells(player_idx: int) -> void:
	var player: PlayerState = _state.players[player_idx]
	while not player.pending_auto_spells.is_empty():
		var card: CardInstance = player.pending_auto_spells.pop_front() as CardInstance
		resolve_spell(card, player_idx)
