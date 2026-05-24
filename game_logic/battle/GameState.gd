class_name GameState
extends RefCounted

const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

var players: Array[PlayerState] = []
var current_player_idx: int = 0
var turn_number: int = 1

func _init() -> void:
	var p1 := PlayerState.new(0, false)
	var p2 := PlayerState.new(1, true)
	var deck: Array[String] = [
		"ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul",
	]
	p1.build_deck(deck)
	p2.build_deck(deck)
	p1.draw_opening_hand(4)
	p2.draw_opening_hand(4)
	players.append(p1)
	players.append(p2)

func current_player() -> PlayerState:
	return players[current_player_idx]

func opponent() -> PlayerState:
	return players[1 - current_player_idx]

func end_turn() -> void:
	current_player_idx = 1 - current_player_idx
	turn_number += 1
	current_player().start_turn(turn_number)
	var _ml: MainLoop = Engine.get_main_loop()
	if _ml != null and _ml is SceneTree:
		var _gb: Node = (_ml as SceneTree).root.get_node_or_null("GameBus")
		if _gb != null:
			_gb.emit_signal("turn_ended", current_player_idx)

func is_game_over() -> bool:
	for p in players:
		if not p.hero.is_alive():
			return true
	return false

func winner() -> int:
	for p in players:
		if not p.hero.is_alive():
			return 1 - p.player_id
	return -1
