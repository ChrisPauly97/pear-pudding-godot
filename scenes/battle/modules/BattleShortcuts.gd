## Battle input flow (GID-135 / TID-530): keyboard shortcuts and auto end turn.
##
## - Number keys play hand cards (the same as tapping them): 1–9 in turn-based
##   fights; in real time they start after the skill bar's keys (1–3 are skills).
## - Space ends the turn (turn-based).
## - Auto end turn (setting `auto_end_turn`, on by default): in a solo turn-based
##   fight, once nothing is playable — no affordable card, no ready attacker, no
##   unused hero power — the End Turn button reads "Ending turn…" and the turn
##   ends after AUTO_END_DELAY unless something became playable. Potions don't
##   count as a move (they're optional and on a cooldown).
##
## A child of BattleScene (`BattleScene.shortcuts`), created by `_ensure_battle_modules()`.
extends Node

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

const SETTING: String = "auto_end_turn"
const AUTO_END_DELAY: float = 1.2

var _battle: _BattleScene
var _auto_end_pending: bool = false


func _init(battle: _BattleScene) -> void:
	_battle = battle


## Key that plays the first hand card.
func first_hand_key() -> Key:
	if _battle.realtime != null and _battle.realtime.is_active() and _battle.realtime.skills != null:
		return (KEY_1 + _battle.realtime.skills.bar.ids.size()) as Key
	return KEY_1


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or _battle._state == null:
		return
	if k.keycode == KEY_SPACE and not _battle.realtime.is_active():
		_battle._on_end_turn()
		get_viewport().set_input_as_handled()
		return
	var first: int = first_hand_key()
	if k.keycode >= first and k.keycode <= KEY_9:
		var hand: Array[CardInstance] = _battle._state.players[_battle._my_idx()].hand
		var i: int = k.keycode - first
		if i < hand.size():
			_battle.card_input._on_hand_card_tap(hand[i])
			get_viewport().set_input_as_handled()


## Called after every refresh: schedules the auto end turn when nothing is left to do.
func check_auto_end() -> void:
	if _auto_end_pending or not _auto_end_allowed() or has_move():
		return
	_auto_end_pending = true
	var btn: Button = _battle._end_turn_btn
	var label: String = btn.text
	btn.text = "Ending turn…"
	await get_tree().create_timer(AUTO_END_DELAY, false).timeout
	_auto_end_pending = false
	if is_instance_valid(btn):
		btn.text = label
	if _auto_end_allowed() and not has_move():
		_battle._on_end_turn()


## Whether the local player can still do anything meaningful this turn.
func has_move() -> bool:
	var me: PlayerState = _battle._state.players[_battle._my_idx()]
	for card: CardInstance in me.hand:
		if me.can_play(card):
			return true
	for card: CardInstance in me.board.get_cards():
		if card.attack > 0 and card.can_attack():
			return true
	return _battle._hero_power_btn != null and not _battle._hero_power_used


func _auto_end_allowed() -> bool:
	var b := _battle
	if not bool(SceneManager.save_manager.get_setting(SETTING, true)):
		return false
	if b._state == null or b._state.is_game_over() or b._state.puzzle_mode or b._state.scripted_battle:
		return false
	if b._pvp or b._coop_pve or b._team_pvp or b.realtime.is_active():
		return false
	if b._state.current_player_idx != b._my_idx() or not b._can_local_act():
		return false
	# Mid-selection (aiming a spell, picking a slot, an attacker chosen) is still a move in progress.
	return not (b._targeting_active or b._slot_select_card != null or b._slot_targeting_spell != null
			or not b._dragged_card.is_empty() or b._ally_targeting_active)
