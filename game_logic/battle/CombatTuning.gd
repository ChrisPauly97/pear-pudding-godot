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
	["player_gcd", "Your global cooldown (s)", 1.2, 0.5, 3.0, 0.1, "Global cooldown & casting"],
	["spell_queue", "Spell queue window (s)", 0.4, 0.0, 1.0, 0.05, "Global cooldown & casting"],
	["cast_base", "Cast time base (s)", 0.4, 0.0, 2.0, 0.05, "Global cooldown & casting"],
	["cast_per_cost", "Cast time per 100 mana (s)", 0.35, 0.0, 1.0, 0.05, "Global cooldown & casting"],
	["cast_max", "Longest cast (s)", 2.5, 0.5, 5.0, 0.1, "Global cooldown & casting"],
	["cast_pushback", "Pushback per hit while casting (s)", 0.3, 0.0, 1.0, 0.05, "Global cooldown & casting"],
	["pushback_max_hits", "Pushback hits per cast", 2.0, 0.0, 5.0, 1.0, "Global cooldown & casting"],
	["mana_regen", "Mana regen (points / s)", 20.0, 0.0, 100.0, 1.0, "Mana & cards"],
	["mana_regen_delay", "Regen pause after spending (s)", 1.0, 0.0, 6.0, 0.25, "Mana & cards"],
	["base_max_mana", "Max mana at level 1 (next fight)", 400.0, 100.0, 1000.0, 25.0, "Mana & cards"],
	["mana_per_level", "Max mana per level (next fight)", 35.0, 0.0, 100.0, 5.0, "Mana & cards"],
	["hp_per_level", "Your max HP per level (next fight)", 5.0, 0.0, 10.0, 0.5, "Mana & cards"],
	["draw_interval", "Draw a card every (s)", 9.0, 1.0, 20.0, 0.5, "Mana & cards"],
	["tech_recycle_mult", "Technique return-to-hand time (x)", 1.0, 0.1, 5.0, 0.1, "Mana & cards"],
	["hand_cap", "Hand size cap", 5.0, 3.0, 10.0, 1.0, "Mana & cards"],
	["hero_swing", "Unarmed swing speed (s)", 3.0, 1.0, 5.0, 0.1, "Auto-attack"],
	["offhand_swing", "Off-hand swing speed (s)", 2.0, 1.0, 5.0, 0.1, "Auto-attack"],
	["crit_chance", "Your crit chance per swing (heroes + Allies)", 0.05, 0.0, 1.0, 0.01, "Auto-attack"],
	["enemy_crit_chance", "Enemy crit chance per swing", 0.05, 0.0, 1.0, 0.01, "Auto-attack"],
	["crit_mult", "Crit damage multiplier", 1.5, 1.0, 3.0, 0.1, "Auto-attack"],
	["unarmed", "Your unarmed damage", 3.0, 0.0, 10.0, 1.0, "Auto-attack"],
	# Every swing time (fists and weapons) is scaled by swing_mult and each hit by
	# swing_damage; the player's hits then roll ± swing_spread.
	["swing_mult", "Auto-attack swing time (x)", 0.5, 0.25, 2.0, 0.05, "Auto-attack"],
	["swing_damage", "Auto-attack damage per swing (x)", 0.45, 0.1, 2.0, 0.01, "Auto-attack"],
	["swing_spread", "Your auto-attack damage spread (± x)", 0.75, 0.0, 1.0, 0.05, "Auto-attack"],
	["enemy_swing_delay", "Enemy hero's swings trail yours by (s)", 0.5, 0.0, 2.0, 0.05, "Auto-attack"],
	["enemy_unarmed", "Enemy hero base damage", 2.0, 0.0, 10.0, 1.0, "Auto-attack"],
	["ally_ready", "Ally ready every (s)", 3.0, 0.5, 8.0, 0.25, "Units"],
	["enemy_swing", "Enemy minion swing (s)", 4.5, 1.0, 10.0, 0.25, "Units"],
	["enemy_gcd", "Enemy global cooldown (s)", 3.5, 0.5, 8.0, 0.25, "Enemy"],
	["enemy_cast", "Enemy cast time (s)", 1.5, 0.25, 5.0, 0.25, "Enemy"],
	["heavy_every", "Heavy blow every (s)", 12.0, 4.0, 40.0, 0.5, "Enemy"],
	["heavy_windup", "Heavy blow wind-up (s)", 2.2, 0.5, 5.0, 0.1, "Enemy"],
	["heavy_frac", "Heavy blow damage (x your max HP)", 0.25, 0.05, 0.6, 0.01, "Enemy"],
	# GID-176 / TID-720: enemy behaviour scales with the enemy's level, never with what the player learned.
	["heavy_min_level", "Heavy blows from enemy level", 1.0, 1.0, 20.0, 1.0, "Enemy"],
	["enemy_full_level", "Enemy level at full heavy / spell strength", 15.0, 2.0, 30.0, 1.0, "Enemy"],
	["enemy_low_scale", "Heavy / spell strength at the lowest level", 0.3, 0.1, 1.0, 0.05, "Enemy"],
	["enemy_hp_per_level", "Extra enemy HP per level above 1 (x)", 0.18, 0.0, 0.5, 0.01, "Enemy"],
	["gap_hp", "Enemy HP per level it is above you (x)", 0.12, 0.0, 1.0, 0.05, "Enemy"],
	["gap_damage", "Enemy damage per level it is above you (x)", 0.1, 0.0, 1.0, 0.05, "Enemy"],
	["enemy_two_minions_level", "Enemy level fielding 2 minions", 5.0, 1.0, 20.0, 1.0, "Enemy"],
	["siphon_per_damage", "Mana siphoned per damage you deal", 15.0, 0.0, 60.0, 1.0, "Momentum"],
	["fighting_regen_mult", "Regen multiplier while fighting", 0.4, 0.0, 2.0, 0.05, "Momentum"],
	["combo_max", "Combo charges to fill", 3.0, 1.0, 5.0, 1.0, "Momentum"],
	["combo_refund", "Mana back per charge a card spends", 60.0, 0.0, 200.0, 5.0, "Momentum"],
	["proc_chance", "Free-cast chance per skill hit", 0.15, 0.0, 1.0, 0.01, "Momentum"],
	["auto_proc_chance", "Free-cast chance per auto-attack hit", 0.025, 0.0, 1.0, 0.01, "Momentum"],
	["round_seconds", "Status/upkeep pulse per side (s)", 6.0, 1.0, 15.0, 0.5, "Status effects"],
	["potion_cooldown", "Quick-slot potion cooldown (s)", 20.0, 0.0, 90.0, 1.0, "Consumables"],
	# GID-181 / TID-748: damage-school matchup multipliers (DamageSchools.mult). Read by
	# every damage event; the defaults are the starting tuning, not yet wired into fights.
	["resist_mult", "Damage multiplier vs a resisted school (x)", 0.5, 0.0, 1.0, 0.05, "Damage schools"],
	["weak_mult", "Damage multiplier vs a weak school (x)", 1.5, 1.0, 3.0, 0.1, "Damage schools"],
	["immune_mult", "Damage multiplier vs an immune school (x)", 0.0, 0.0, 1.0, 0.05, "Damage schools"],
	# GID-181 / TID-751: cap on a hero's resistance to one school (fraction of damage soaked).
	["max_player_resist", "Hero resistance cap per school (fraction)", 0.75, 0.0, 0.95, 0.05, "Damage schools"],
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

## 0..1 strength of an enemy's heavy blows / spells at `level`: `enemy_low_scale`
## at level 1 rising to 1 at `enemy_full_level` (GID-176 / TID-720).
func level_scale(level: int) -> float:
	var full: float = maxf(2.0, get_f("enemy_full_level"))
	var k: float = clampf((float(level) - 1.0) / (full - 1.0), 0.0, 1.0)
	return lerpf(get_f("enemy_low_scale"), 1.0, k)

## Damage multiplier for an enemy `enemy_level` hitting a `player_level` hero:
## +`gap_damage` per level above, less below (never under half) (TID-718).
func gap_mult(enemy_level: int, player_level: int) -> float:
	return maxf(0.5, 1.0 + get_f("gap_damage") * float(enemy_level - player_level))

static func row_for(key: String) -> Array:
	for row: Array in DEFS:
		if str(row[0]) == key:
			return row
	return []
