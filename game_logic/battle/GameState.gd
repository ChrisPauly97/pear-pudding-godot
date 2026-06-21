class_name GameState
extends RefCounted

signal turn_ended(player_id: int)

const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

var players: Array[PlayerState] = []
var current_player_idx: int = 0
var turn_number: int = 1
# Per-player turn counters so each player ramps mana independently.
# p0 starts at 1 (set by BattleScene); p1 starts at 0 and becomes 1 on first end_turn.
var player_turn_numbers: Array[int] = [1, 0]
var friendly_duel: bool = false
var wager_coins: int = 0
var puzzle_mode: bool = false
var puzzle_data_id: String = ""

# Battlefield Resonance context (GID-059).
# battlefield_biome: -1 = dungeon/named map (no rule), 0..4 = biome id.
var battlefield_biome: int = -1
var is_night: bool = false

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
	player_turn_numbers[current_player_idx] += 1
	current_player().start_turn(player_turn_numbers[current_player_idx])
	turn_ended.emit(current_player_idx)

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
func load_puzzle(p: Resource) -> void:
	const PD = preload("res://game_logic/battle/PuzzleData.gd")
	const CR = preload("res://autoloads/CardRegistry.gd")
	const CI = preload("res://game_logic/battle/CardInstance.gd")

	var pdata: PD = p as PD
	if pdata == null:
		push_error("GameState.load_puzzle: invalid PuzzleData resource")
		return

	puzzle_mode = true
	puzzle_data_id = pdata.puzzle_id

	# --- Player (pid 0) ---
	players[0].draw_deck.clear()
	players[0].hand.clear()
	players[0].hero.health = pdata.player_hero_hp
	players[0].hero.max_health = pdata.player_hero_hp
	players[0].hero.mana = pdata.player_mana
	players[0].hero.max_mana = pdata.player_mana

	for cid: String in pdata.player_hand:
		if cid.is_empty():
			continue
		var tmpl: Dictionary = CR.get_template(cid)
		if tmpl.is_empty():
			continue
		var ci := CI.new(tmpl)
		ci.summoning_sick = false
		players[0].hand.append(ci)

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
		players[0].board.slots[i] = ci

	# --- Enemy (pid 1) ---
	players[1].draw_deck.clear()
	players[1].hand.clear()
	players[1].hero.health = pdata.enemy_hero_hp
	players[1].hero.max_health = pdata.enemy_hero_hp

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
		players[1].board.slots[i] = ci

	# Apply keyword buffs to enemy board slots: format "slot_idx:keyword"
	for buff: String in pdata.enemy_board_buffs:
		var parts: PackedStringArray = buff.split(":")
		if parts.size() != 2:
			continue
		var slot_i: int = int(parts[0])
		if slot_i < 0 or slot_i >= 5:
			continue
		var bcard: CI = players[1].board.slots[slot_i]
		if bcard != null and not bcard.keywords.has(str(parts[1])):
			bcard.keywords.append(str(parts[1]))

	current_player_idx = 0
	turn_number = 1

## Sets battlefield context on this GameState and propagates to both PlayerStates.
## Call once after building a new GameState for a non-resumed battle.
func set_battlefield_context(biome: int, night: bool) -> void:
	battlefield_biome = biome
	is_night = night
	for p: PlayerState in players:
		p.battlefield_biome = biome
		p.is_night = night

func to_dict() -> Dictionary:
	var player_arr: Array = []
	for p: PlayerState in players:
		player_arr.append(p.to_dict())
	return {
		"current_player_idx": current_player_idx,
		"turn_number": turn_number,
		"player_turn_numbers": [player_turn_numbers[0], player_turn_numbers[1]],
		"players": player_arr,
		"friendly_duel": friendly_duel,
		"wager_coins": wager_coins,
		"puzzle_mode": puzzle_mode,
		"puzzle_data_id": puzzle_data_id,
		"battlefield_biome": battlefield_biome,
		"is_night": is_night,
	}

func from_dict(d: Dictionary) -> void:
	current_player_idx = int(d.get("current_player_idx", 0))
	turn_number = int(d.get("turn_number", 1))
	var ptn = d.get("player_turn_numbers", [turn_number, turn_number - 1])
	if ptn is Array and ptn.size() >= 2:
		player_turn_numbers[0] = int(ptn[0])
		player_turn_numbers[1] = int(ptn[1])
	else:
		# Old save: derive from shared turn_number as a best-effort fallback
		player_turn_numbers[0] = int(ceil(float(turn_number) / 2.0))
		player_turn_numbers[1] = int(floor(float(turn_number) / 2.0))
	friendly_duel = bool(d.get("friendly_duel", false))
	wager_coins = int(d.get("wager_coins", 0))
	puzzle_mode = bool(d.get("puzzle_mode", false))
	puzzle_data_id = str(d.get("puzzle_data_id", ""))
	battlefield_biome = int(d.get("battlefield_biome", -1))
	is_night = bool(d.get("is_night", false))
	players.clear()
	for pd in d.get("players", []):
		if pd is Dictionary:
			var pid: int = int(pd.get("player_id", 0))
			var ai: bool = bool(pd.get("is_ai", false))
			var ps := PlayerState.new(pid, ai)
			ps.from_dict(pd)
			players.append(ps)
