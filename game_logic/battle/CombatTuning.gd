## Every tunable real-time combat number in one table (GID-135 / TID-549).
##
## `RealtimeCombat` reads its timings from an instance of this; the in-battle
## tuning panel (`CombatTuningPanel`) edits one live, and the overrides persist
## in the "combat_tuning" setting (per device — a design tool, not save data).
## Add a knob: one DEFS row + read `tune.get_f(key)` / `get_i(key)` where used.
extends RefCounted

## key → [label, default, min, max, step, group]. Ints are rows whose step is 1.0
## and whose default is whole; read them with get_i.
const DEFS: Array = [
	["player_gcd", "Your global cooldown (s)", 1.5, 0.5, 3.0, 0.1, "Global cooldown & casting"],
	["spell_queue", "Spell queue window (s)", 0.4, 0.0, 1.0, 0.05, "Global cooldown & casting"],
	["cast_base", "Cast time base (s)", 0.4, 0.0, 2.0, 0.05, "Global cooldown & casting"],
	["cast_per_cost", "Cast time per 100 mana (s)", 0.35, 0.0, 1.0, 0.05, "Global cooldown & casting"],
	["cast_max", "Longest cast (s)", 2.5, 0.5, 5.0, 0.1, "Global cooldown & casting"],
	["cast_pushback", "Pushback per hit while casting (s)", 0.3, 0.0, 1.0, 0.05, "Global cooldown & casting"],
	["pushback_max_hits", "Pushback hits per cast", 2.0, 0.0, 5.0, 1.0, "Global cooldown & casting"],
	["mana_regen", "Mana regen (points / s)", 20.0, 0.0, 100.0, 1.0, "Mana & cards"],
	["mana_regen_delay", "Regen pause after spending (s)", 2.0, 0.0, 6.0, 0.25, "Mana & cards"],
	["base_max_mana", "Max mana at level 1 (next fight)", 400.0, 100.0, 1000.0, 25.0, "Mana & cards"],
	["mana_per_level", "Max mana per level (next fight)", 35.0, 0.0, 100.0, 5.0, "Mana & cards"],
	["draw_interval", "Draw a card every (s)", 6.0, 1.0, 20.0, 0.5, "Mana & cards"],
	["hand_cap", "Hand size cap", 7.0, 3.0, 10.0, 1.0, "Mana & cards"],
	["hero_swing", "Unarmed swing speed (s)", 3.0, 1.0, 5.0, 0.1, "Auto-attack"],
	["offhand_swing", "Off-hand swing speed (s)", 2.0, 1.0, 5.0, 0.1, "Auto-attack"],
	["unarmed", "Your unarmed damage", 3.0, 0.0, 10.0, 1.0, "Auto-attack"],
	["enemy_unarmed", "Enemy hero base damage", 2.0, 0.0, 10.0, 1.0, "Auto-attack"],
	["skill_cooldown", "Skill bar cooldown multiplier", 1.0, 0.25, 3.0, 0.05, "Skill bar"],
	["ally_ready", "Ally ready every (s)", 3.0, 0.5, 8.0, 0.25, "Units"],
	["enemy_swing", "Enemy minion swing (s)", 4.5, 1.0, 10.0, 0.25, "Units"],
	["enemy_gcd", "Enemy global cooldown (s)", 3.5, 0.5, 8.0, 0.25, "Enemy"],
	["enemy_cast", "Enemy cast time (s)", 1.5, 0.25, 5.0, 0.25, "Enemy"],
]

var _values: Dictionary = {}

func _init(overrides: Dictionary = {}) -> void:
	reset()
	apply(overrides)

## All knobs back to their defaults.
func reset() -> void:
	_values.clear()
	for row: Array in DEFS:
		_values[str(row[0])] = float(row[2])

## Merges `overrides` (key → number); unknown keys are ignored, values clamped.
func apply(overrides: Dictionary) -> void:
	for k: Variant in overrides.keys():
		set_value(str(k), float(overrides[k]))

func has_key(key: String) -> bool:
	return _values.has(key)

func get_f(key: String) -> float:
	return float(_values.get(key, 0.0))

func get_i(key: String) -> int:
	return roundi(get_f(key))

## Sets a knob, clamped to its range and snapped to its step. Unknown keys are ignored.
func set_value(key: String, v: float) -> void:
	var row: Array = row_for(key)
	if row.is_empty():
		return
	_values[key] = snappedf(clampf(v, float(row[3]), float(row[4])), float(row[5]))

## Moves a knob by `steps` of its step size.
func nudge(key: String, steps: int) -> void:
	var row: Array = row_for(key)
	if not row.is_empty():
		set_value(key, get_f(key) + float(row[5]) * float(steps))

## Only the knobs that differ from their defaults (what gets persisted).
func overrides() -> Dictionary:
	var out: Dictionary = {}
	for row: Array in DEFS:
		var k: String = str(row[0])
		if not is_equal_approx(get_f(k), float(row[2])):
			out[k] = get_f(k)
	return out

static func row_for(key: String) -> Array:
	for row: Array in DEFS:
		if str(row[0]) == key:
			return row
	return []
