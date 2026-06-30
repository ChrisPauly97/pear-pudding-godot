class_name GameState
extends RefCounted

signal turn_ended(player_id: int)

const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

var players: Array[PlayerState] = []
var current_player_idx: int = 0
var turn_number: int = 1
# Injected by BattleScene; propagated to all PlayerState instances.
var gamebus_emitter: Callable = Callable()
# Per-player turn counters so each player ramps mana independently.
# In the 2-player case: p0 starts at 1, p1 starts at 0.
# In co-op: N ally entries + 1 boss entry, all starting at 0 except ally-0 (starts at 1).
var player_turn_numbers: Array[int] = [1, 0]
var friendly_duel: bool = false
var wager_coins: int = 0
var puzzle_mode: bool = false
var puzzle_data_id: String = ""

# Battlefield Resonance context (GID-059).
# battlefield_biome: -1 = dungeon/named map (no rule), 0..4 = biome id.
var battlefield_biome: int = -1
var is_night: bool = false

# Co-op joint battle flag (GID-099).
# When true: players[0..N-2] are allies, players[N-1] is the shared boss.
# Turn order rotates modulo players.size() (all allies then boss).
# Win: boss hero dead. Loss: all ally heroes dead.
var coop_battle: bool = false

# Team PvP flag (GID-102 / TID-371). When true: 4 players split into 2 teams of 2,
# interleaved [teamA_0, teamB_0, teamA_1, teamB_1] so the existing (idx+1) % size
# turn rotation alternates teams every turn with no rotation changes needed.
# Win: the other team's both heroes dead. player_teams[i] is 0 or 1, parallel to players.
var team_battle: bool = false
var player_teams: Array[int] = []

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

## Inject the GameBus emitter so PlayerState can emit signals without touching the SceneTree.
## emitter is called as emitter.call(player_id: int, damage: int) for fatigue_damage.
func inject_gamebus_emitter(emitter: Callable) -> void:
	gamebus_emitter = emitter
	_propagate_emitter()

func _propagate_emitter() -> void:
	for p: PlayerState in players:
		p.gamebus_emitter = gamebus_emitter

func current_player() -> PlayerState:
	return players[current_player_idx]

## Returns the opponent of the current player.
## 2-player: always the other player.
## Co-op ally turn: the shared boss.
## Co-op boss turn: the alive ally with the lowest hero HP (boss targeting rule).
## Team battle: the alive enemy-team member with the lowest hero HP (auto-target rule;
## BattleScene may override this per-attack with a manually focused enemy — see
## BattleScene._opp_idx() / docs/agent/multiplayer-coop.md "Team Duels").
func opponent() -> PlayerState:
	if team_battle:
		return _get_lowest_hp_enemy_team_member(current_player_idx)
	if not coop_battle:
		return players[1 - current_player_idx]
	var boss_idx: int = players.size() - 1
	if current_player_idx == boss_idx:
		# Boss turn — target the alive ally with the lowest HP.
		return _get_lowest_hp_ally()
	# Ally turn — boss is the opponent.
	return players[boss_idx]

## Index of opponent() within `players`. Used by callers that need the index rather
## than the PlayerState (e.g. attack/removal resolution).
func opponent_idx() -> int:
	return players.find(opponent())

## Convenience accessor — always returns the boss PlayerState when coop_battle.
func boss() -> PlayerState:
	return players[players.size() - 1]

## Returns all ally PlayerStates (players[0..N-2]) when coop_battle.
## Falls back to [players[0]] for the 2-player case.
func allies() -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	if not coop_battle:
		result.append(players[0])
		return result
	for i in range(players.size() - 1):
		result.append(players[i])
	return result

## True when idx is an ally in a co-op battle.
func is_ally(idx: int) -> bool:
	return coop_battle and idx >= 0 and idx < players.size() - 1

## Returns the alive ally PlayerState with the lowest hero HP.
## Prefers the first alive ally if all have equal HP (or none is alive).
func _get_lowest_hp_ally() -> PlayerState:
	var result: PlayerState = players[0]
	var lowest: int = players[0].hero.health
	for i in range(players.size() - 1):
		var p: PlayerState = players[i]
		if p.hero.is_alive() and p.hero.health < lowest:
			lowest = p.hero.health
			result = p
	return result

## Returns the alive member of the *other* team (relative to player_idx) with the
## lowest hero HP. Prefers any alive member over a dead one; falls back to the
## first enemy-team member only if the whole enemy team is dead (shouldn't happen
## mid-battle — that condition ends the game, see is_game_over()).
func _get_lowest_hp_enemy_team_member(player_idx: int) -> PlayerState:
	var my_team: int = player_teams[player_idx] if player_idx < player_teams.size() else 0
	var result: PlayerState = null
	var lowest: int = 0
	for i in range(players.size()):
		if i < player_teams.size() and player_teams[i] == my_team:
			continue
		var p: PlayerState = players[i]
		if result == null:
			result = p
			lowest = p.hero.health
			continue
		if p.hero.is_alive() and (not result.hero.is_alive() or p.hero.health < lowest):
			lowest = p.hero.health
			result = p
	return result

func end_turn() -> void:
	current_player_idx = (current_player_idx + 1) % players.size()
	turn_number += 1
	# Grow player_turn_numbers on demand (handles setup of 3-4 player co-op).
	while player_turn_numbers.size() <= current_player_idx:
		player_turn_numbers.append(0)
	player_turn_numbers[current_player_idx] += 1
	current_player().start_turn(player_turn_numbers[current_player_idx])
	turn_ended.emit(current_player_idx)

## In co-op: party wins when boss is dead; party loses when all allies are dead.
## In team battle: game over when one whole team's heroes are all dead.
## In 2-player: game over when any hero dies (unchanged).
func is_game_over() -> bool:
	if team_battle:
		var team0_alive: bool = false
		var team1_alive: bool = false
		for i in range(players.size()):
			var t: int = player_teams[i] if i < player_teams.size() else 0
			if players[i].hero.is_alive():
				if t == 0:
					team0_alive = true
				else:
					team1_alive = true
		return not (team0_alive and team1_alive)
	if coop_battle:
		# Boss dead → party wins.
		if not players[players.size() - 1].hero.is_alive():
			return true
		# All allies dead → party loses.
		for i in range(players.size() - 1):
			if players[i].hero.is_alive():
				return false
		return true
	for p in players:
		if not p.hero.is_alive():
			return true
	return false

## Returns the player_id of the winner (-1 if undecided).
## In co-op: returns 0 when allies win (boss dead), boss's player_id when boss wins.
## In team battle: returns the surviving team id (0 or 1), or -1 if undecided.
## In 2-player: returns the surviving player_id.
func winner() -> int:
	if team_battle:
		var team0_alive: bool = false
		var team1_alive: bool = false
		for i in range(players.size()):
			var t: int = player_teams[i] if i < player_teams.size() else 0
			if players[i].hero.is_alive():
				if t == 0:
					team0_alive = true
				else:
					team1_alive = true
		if team0_alive and not team1_alive:
			return 0
		if team1_alive and not team0_alive:
			return 1
		return -1
	if coop_battle:
		var boss_idx: int = players.size() - 1
		if not players[boss_idx].hero.is_alive():
			return 0  # party wins — convention: return ally-side index 0
		# All allies dead → boss wins.
		var all_dead: bool = true
		for i in range(boss_idx):
			if players[i].hero.is_alive():
				all_dead = false
				break
		if all_dead:
			return boss_idx
		return -1
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

## Sets battlefield context on this GameState and propagates to all PlayerStates.
## Call once after building a new GameState for a non-resumed battle.
func set_battlefield_context(biome: int, night: bool) -> void:
	battlefield_biome = biome
	is_night = night
	for p: PlayerState in players:
		p.battlefield_biome = biome
		p.is_night = night

## Initialises a co-op battle with n_allies allies and one shared boss (GID-099).
## Must be called on a freshly constructed GameState (replaces the default 2-player setup).
## ally_setup is a Callable(idx) → void (caller builds each ally's deck/stats).
## boss_setup is a Callable(PlayerState) → void (caller builds the boss).
func setup_coop_battle(n_allies: int, ally_setup: Callable, boss_setup: Callable) -> void:
	players.clear()
	player_turn_numbers.clear()
	coop_battle = true
	var n: int = maxi(2, mini(n_allies, 4))  # clamp 2..4 allies
	for i in range(n):
		var ally := PlayerState.new(i, false)
		players.append(ally)
		player_turn_numbers.append(0)
		ally_setup.call(i, ally)
	player_turn_numbers[0] = 1  # ally-0 starts first
	var boss_ps := PlayerState.new(n, true)
	players.append(boss_ps)
	player_turn_numbers.append(0)
	boss_setup.call(boss_ps)
	current_player_idx = 0

## Initialises a 2v2 team battle (GID-102 / TID-371). Must be called on a freshly
## constructed GameState (replaces the default 2-player setup). Players are laid out
## interleaved [teamA_0, teamB_0, teamA_1, teamB_1] so the existing (idx+1) % size
## turn rotation alternates teams every turn with no rotation changes.
## team_a_setup/team_b_setup: Callable(local_idx: int, ps: PlayerState) -> void,
## local_idx is 0 or 1 within that team (caller builds each member's deck/stats).
func setup_team_battle(team_a_setup: Callable, team_b_setup: Callable) -> void:
	players.clear()
	player_teams.clear()
	player_turn_numbers.clear()
	team_battle = true
	var setups: Array[Callable] = [team_a_setup, team_b_setup, team_a_setup, team_b_setup]
	var teams: Array[int] = [0, 1, 0, 1]
	var local_idxs: Array[int] = [0, 0, 1, 1]
	for i in range(4):
		var ps := PlayerState.new(i, false)
		players.append(ps)
		player_teams.append(teams[i])
		player_turn_numbers.append(0)
		setups[i].call(local_idxs[i], ps)
	player_turn_numbers[0] = 1  # players[0] starts first
	current_player_idx = 0

func to_dict() -> Dictionary:
	var player_arr: Array = []
	for p: PlayerState in players:
		player_arr.append(p.to_dict())
	var ptn_arr: Array = []
	for v: int in player_turn_numbers:
		ptn_arr.append(v)
	return {
		"current_player_idx": current_player_idx,
		"turn_number": turn_number,
		"player_turn_numbers": ptn_arr,
		"players": player_arr,
		"friendly_duel": friendly_duel,
		"wager_coins": wager_coins,
		"puzzle_mode": puzzle_mode,
		"puzzle_data_id": puzzle_data_id,
		"battlefield_biome": battlefield_biome,
		"is_night": is_night,
		"coop_battle": coop_battle,
		"team_battle": team_battle,
		"player_teams": player_teams.duplicate(),
	}

func from_dict(d: Dictionary) -> void:
	current_player_idx = int(d.get("current_player_idx", 0))
	turn_number = int(d.get("turn_number", 1))
	coop_battle = bool(d.get("coop_battle", false))
	team_battle = bool(d.get("team_battle", false))
	player_teams.clear()
	var pt: Variant = d.get("player_teams", [])
	if pt is Array:
		for v in pt:
			player_teams.append(int(v))
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
	# Restore player_turn_numbers — supports legacy 2-entry saves and new N-entry saves.
	var ptn = d.get("player_turn_numbers", null)
	player_turn_numbers.clear()
	if ptn is Array and ptn.size() >= players.size():
		for i in range(players.size()):
			player_turn_numbers.append(int(ptn[i]))
	elif ptn is Array and ptn.size() == 2 and players.size() >= 2:
		# Legacy 2-entry save: carry forward p0 and p1 values, zero the rest.
		player_turn_numbers.append(int(ptn[0]))
		player_turn_numbers.append(int(ptn[1]))
		for _i in range(players.size() - 2):
			player_turn_numbers.append(0)
	else:
		# Fallback: derive from turn_number.
		player_turn_numbers.append(int(ceil(float(turn_number) / 2.0)))
		player_turn_numbers.append(int(floor(float(turn_number) / 2.0)))
		for _i in range(players.size() - 2):
			player_turn_numbers.append(0)
	_propagate_emitter()
