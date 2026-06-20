## Tracks whether a soulbind capture condition was satisfied during a battle.
## Pure logic — no rendering dependency. Constructed by BattleScene in _ready().
##
## Supported condition keys (set via init()):
##   spell_final_blow       — a player-cast spell killed the enemy's last minion
##   hero_hp_at_most        — player hero HP <= capture_param at game-over
##   no_minion_hero_attacks — player never attacked enemy hero with a minion
##   win_by_turn            — turn_number <= capture_param when game ends
##
## Usage:
##   var tracker := CaptureTracker.new("no_minion_hero_attacks", 0)
##   tracker.note_minion_attacked_hero(0)   # player attacked enemy hero
##   tracker.note_spell_resolved(0, 2, 0)   # player spell cleared enemy board
##   var ok := tracker.is_satisfied(state)  # call at game-over
extends RefCounted

var _condition: String = ""
var _param: int = 0

# Accumulated event flags
var _spell_killed_last_minion: bool = false
var _minion_hero_attack_happened: bool = false  # player minion hit enemy hero

func _init(condition: String, param: int) -> void:
	_condition = condition
	_param = param

## Call when a minion attack on the enemy hero resolves.
## attacker_pid must be 0 (player) for no_minion_hero_attacks to apply.
func note_minion_attacked_hero(attacker_pid: int) -> void:
	if attacker_pid == 0:
		_minion_hero_attack_happened = true

## Call after a spell resolves that was cast by caster_pid.
## enemy_board_count_before and after are the occupied slot counts on the enemy board.
func note_spell_resolved(caster_pid: int, enemy_board_count_before: int, enemy_board_count_after: int) -> void:
	if caster_pid == 0 and enemy_board_count_before >= 1 and enemy_board_count_after == 0:
		_spell_killed_last_minion = true

## Returns true if the capture condition is satisfied given the final game state.
## Call this only when the player has won (winner == 0).
func is_satisfied(state: Object) -> bool:
	match _condition:
		"spell_final_blow":
			return _spell_killed_last_minion
		"no_minion_hero_attacks":
			return not _minion_hero_attack_happened
		"hero_hp_at_most":
			if state == null:
				return false
			var hp: int = int(state.players[0].hero.health)
			return hp <= _param
		"win_by_turn":
			if state == null:
				return false
			return int(state.turn_number) <= _param
		_:
			return false

## Returns a human-readable description of the condition for the UI.
func condition_text() -> String:
	match _condition:
		"spell_final_blow":
			return "Win with a spell landing the final blow on the enemy's last minion"
		"no_minion_hero_attacks":
			return "Win without attacking the enemy hero with a minion"
		"hero_hp_at_most":
			return "Win with your hero at %d HP or below" % _param
		"win_by_turn":
			return "Win by turn %d" % _param
		_:
			return ""
