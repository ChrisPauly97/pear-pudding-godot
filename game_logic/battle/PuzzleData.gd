class_name PuzzleData
extends Resource

## Describes a frozen board-state puzzle: the player must find the lethal line
## in a single turn. Placed at PuzzleShrine entities in named maps.

@export var puzzle_id: String = ""
@export var title: String = ""
@export var hint_text: String = ""

## Card IDs in the player's hand at puzzle start.
@export var player_hand: Array[String] = []

## Card IDs on the player's board (up to 5); "" = empty slot.
## Board cards have no summoning sickness — they can attack immediately.
@export var player_board: Array[String] = []

@export var player_mana: int = 1
@export var player_hero_hp: int = 30

## Card IDs on the enemy's board (up to 5); "" = empty slot.
@export var enemy_board: Array[String] = []

@export var enemy_hero_hp: int = 10

## Keyword grants applied to enemy board slots after placement.
## Format: "slot_idx:keyword" e.g. "0:ward" adds Ward to slot 0.
@export var enemy_board_buffs: Array[String] = []

## Card ID awarded on first solve. "" = no reward.
@export var reward_card_id: String = ""

## Returns a list of validation errors. Empty list = valid.
func validate() -> Array[String]:
	const CardReg = preload("res://autoloads/CardRegistry.gd")
	var errors: Array[String] = []
	if puzzle_id.is_empty():
		errors.append("puzzle_id is empty")
	if title.is_empty():
		errors.append("title is empty")
	if enemy_hero_hp <= 0:
		errors.append("enemy_hero_hp must be > 0")
	if player_board.size() > 5:
		errors.append("player_board has > 5 entries")
	if enemy_board.size() > 5:
		errors.append("enemy_board has > 5 entries")
	for cid: String in player_hand:
		if cid != "" and CardReg.get_template(cid).is_empty():
			errors.append("unknown card in player_hand: " + cid)
	for cid: String in player_board:
		if cid != "" and CardReg.get_template(cid).is_empty():
			errors.append("unknown card in player_board: " + cid)
	for cid: String in enemy_board:
		if cid != "" and CardReg.get_template(cid).is_empty():
			errors.append("unknown card in enemy_board: " + cid)
	if reward_card_id != "" and CardReg.get_template(reward_card_id).is_empty():
		errors.append("unknown reward_card_id: " + reward_card_id)
	return errors
