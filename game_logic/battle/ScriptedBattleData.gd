class_name ScriptedBattleData
extends Resource

## Describes a fully deterministic story battle: fixed decks for both sides drawn
## in an exact order (no shuffle), a reduced opening hand, and turn-keyed Maiteln
## tutorial popups. Used for scripted story tutorial battles (rabbit hunt,
## Chapter 2 ambush) where the player must be taught a mechanic with zero RNG.

@export var battle_id: String = ""
@export var title: String = ""

## Card IDs in the order they will be drawn — first entry drawn first.
## PlayerState.build_scripted_deck() reverses this internally to match the
## draw_deck.pop_back() draw order used by PlayerState.draw_card().
@export var player_deck_order: Array[String] = []
@export var opening_hand_count: int = 1
@export var player_hero_hp: int = 30

## Fixed, weak enemy deck — same draw-order convention as player_deck_order.
@export var enemy_deck_order: Array[String] = []
@export var enemy_opening_hand_count: int = 1
@export var enemy_hero_hp: int = 10

## Turn-keyed Maiteln guidance. Each entry is "<player_turn_number>:<text>" —
## shown once, at the start of the player's Nth turn (player_turn_numbers[0] == N).
@export var tutorial_steps: Array[String] = []

## Card ID awarded on victory. "" = no reward.
@export var reward_card_id: String = ""

## Story flag set on victory. "" = no flag.
@export var completion_flag: String = ""

## Returns a list of validation errors. Empty list = valid.
func validate() -> Array[String]:
	const CardReg = preload("res://autoloads/CardRegistry.gd")
	var errors: Array[String] = []
	if battle_id.is_empty():
		errors.append("battle_id is empty")
	if title.is_empty():
		errors.append("title is empty")
	if player_deck_order.is_empty():
		errors.append("player_deck_order is empty")
	if opening_hand_count > player_deck_order.size():
		errors.append("opening_hand_count exceeds player_deck_order size")
	if enemy_hero_hp <= 0:
		errors.append("enemy_hero_hp must be > 0")
	if player_hero_hp <= 0:
		errors.append("player_hero_hp must be > 0")
	for cid: String in player_deck_order:
		if CardReg.get_template(cid).is_empty():
			errors.append("unknown card in player_deck_order: " + cid)
	for cid: String in enemy_deck_order:
		if CardReg.get_template(cid).is_empty():
			errors.append("unknown card in enemy_deck_order: " + cid)
	if reward_card_id != "" and CardReg.get_template(reward_card_id).is_empty():
		errors.append("unknown reward_card_id: " + reward_card_id)
	for step: String in tutorial_steps:
		var parts: PackedStringArray = step.split(":", true, 1)
		if parts.size() != 2 or not parts[0].is_valid_int():
			errors.append("malformed tutorial_step: " + step)
	return errors
