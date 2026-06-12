class_name GameState
extends RefCounted

const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

var players: Array[PlayerState] = []
var current_player_idx: int = 0
var turn_number: int = 1
var friendly_duel: bool = false
var wager_coins: int = 0
var puzzle_mode: bool = false
var puzzle_data_id: String = ""

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

## Builds a GameState seeded from a PuzzleData resource.
## Board minions have no summoning sickness. No deck; no enemy turn.
static func load_puzzle(p: Resource) -> GameState:
	const PD = preload("res://game_logic/battle/PuzzleData.gd")
	const CR = preload("res://autoloads/CardRegistry.gd")
	const CI = preload("res://game_logic/battle/CardInstance.gd")

	var pdata: PD = p as PD
	if pdata == null:
		push_error("GameState.load_puzzle: invalid PuzzleData resource")
		return GameState.new()

	var gs := GameState.new()
	gs.puzzle_mode = true
	gs.puzzle_data_id = pdata.puzzle_id

	# --- Player (pid 0) ---
	gs.players[0].draw_deck.clear()
	gs.players[0].hand.clear()
	gs.players[0].hero.health = pdata.player_hero_hp
	gs.players[0].hero.max_health = pdata.player_hero_hp
	gs.players[0].hero.mana = pdata.player_mana
	gs.players[0].hero.max_mana = pdata.player_mana

	for cid: String in pdata.player_hand:
		if cid.is_empty():
			continue
		var tmpl: Dictionary = CR.get_template(cid)
		if tmpl.is_empty():
			continue
		var ci := CI.new(tmpl)
		ci.summoning_sick = false
		gs.players[0].hand.append(ci)

	for i in range(mini(pdata.player_board.size(), 5)):
		var cid: String = pdata.player_board[i]
		if cid.is_empty():
			continue
		var tmpl: Dictionary = CR.get_template(cid)
		if tmpl.is_empty():
			continue
		var ci := CI.new(tmpl)
		ci.summoning_sick = false
		ci.attack_count = 1
		gs.players[0].board.slots[i] = ci

	# --- Enemy (pid 1) ---
	gs.players[1].draw_deck.clear()
	gs.players[1].hand.clear()
	gs.players[1].hero.health = pdata.enemy_hero_hp
	gs.players[1].hero.max_health = pdata.enemy_hero_hp

	for i in range(mini(pdata.enemy_board.size(), 5)):
		var cid: String = pdata.enemy_board[i]
		if cid.is_empty():
			continue
		var tmpl: Dictionary = CR.get_template(cid)
		if tmpl.is_empty():
			continue
		var ci := CI.new(tmpl)
		ci.summoning_sick = false
		ci.attack_count = 1
		gs.players[1].board.slots[i] = ci

	# Apply keyword buffs to enemy board slots: format "slot_idx:keyword"
	for buff: String in pdata.enemy_board_buffs:
		var parts: PackedStringArray = buff.split(":")
		if parts.size() != 2:
			continue
		var slot_i: int = int(parts[0])
		if slot_i < 0 or slot_i >= 5:
			continue
		var bcard: CI = gs.players[1].board.slots[slot_i]
		if bcard != null and not bcard.keywords.has(str(parts[1])):
			bcard.keywords.append(str(parts[1]))

	gs.current_player_idx = 0
	gs.turn_number = 1
	return gs

func to_dict() -> Dictionary:
	var player_arr: Array = []
	for p: PlayerState in players:
		player_arr.append(p.to_dict())
	return {
		"current_player_idx": current_player_idx,
		"turn_number": turn_number,
		"players": player_arr,
		"friendly_duel": friendly_duel,
		"wager_coins": wager_coins,
		"puzzle_mode": puzzle_mode,
		"puzzle_data_id": puzzle_data_id,
	}

static func from_dict(d: Dictionary) -> GameState:
	var gs := GameState.new()
	gs.current_player_idx = int(d.get("current_player_idx", 0))
	gs.turn_number = int(d.get("turn_number", 1))
	gs.friendly_duel = bool(d.get("friendly_duel", false))
	gs.wager_coins = int(d.get("wager_coins", 0))
	gs.puzzle_mode = bool(d.get("puzzle_mode", false))
	gs.puzzle_data_id = str(d.get("puzzle_data_id", ""))
	gs.players.clear()
	for pd in d.get("players", []):
		if pd is Dictionary:
			gs.players.append(PlayerState.from_dict(pd))
	return gs
