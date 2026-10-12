## Gear supply (GID-187 / TID-793): does the drop flow keep a player near the gear curve? Enemy power
## follows level only (user, 2026-10-12), so the player has to be "close enough to geared"; this
## levels a simulated player from 1 to 60, handing out `drops_per_level` items per level through the
## game's own `GearDrops.pick` (behind slots first, unowned first) and wearing each one that beats
## the slot's item level. `coverage` per level = the worn loadout's item power over the curve's
## (`GearCurve.power_log` / `CombatTuning.item_power_log`), 1.0 = on curve.
##
## Pure: static registry data and a seeded rng.
extends RefCounted

const _GearDrops = preload("res://game_logic/items/GearDrops.gd")
const _GearCurve = preload("res://game_logic/items/GearCurve.gd")
const _CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const _WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const _WeaponData = preload("res://data/WeaponData.gd")
const _XpCurve = preload("res://game_logic/progression/XpCurve.gd")

## The drop rate the bands assume (gear drops per hour of play, every source): at this rate the
## worn loadout stays within ~10 % of the curve from level 20 (`tests/unit/test_gear_power.gd`), the
## gear `BalanceProfiles` and `CombatTuning.enemy_dmg_lag` take for granted.
const TARGET_DROPS_PER_HOUR: float = 4.0

## Drops a player of `level` sees before reaching the next: `drops_per_hour` × the XP curve's
## planned minutes at that level (`XpCurve.minutes_for`).
static func drops_at(level: int, drops_per_hour: float) -> float:
	return drops_per_hour * _XpCurve.minutes_for(level) / 60.0

## {level: coverage} for levels 1..`max_level`, measured halfway through each level (after half of
## its drops: the average moment a level-L fight happens). Fractional drops carry over.
static func simulate(drops_per_hour: float, seed: int = 1, max_level: int = 60,
		tune: _CombatTuning = null) -> Dictionary:
	var t: _CombatTuning = tune if tune != null else _CombatTuning.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var owned: Array[String] = []
	var equipped: Dictionary = {}
	var carry: float = 0.0
	var out: Dictionary = {}
	for lv: int in range(1, max_level + 1):
		var n: float = drops_at(lv, drops_per_hour)
		carry += n * 0.5
		_drop(lv, carry, owned, equipped, rng)
		carry -= floorf(carry)
		out[lv] = coverage(lv, equipped, t)
		carry += n * 0.5
		_drop(lv, carry, owned, equipped, rng)
		carry -= floorf(carry)
	return out

## Hands out floor(`count`) drops at `level` (`GearDrops.pick`), wearing each upgrade.
static func _drop(level: int, count: float, owned: Array[String], equipped: Dictionary,
		rng: RandomNumberGenerator) -> void:
	for _i: int in int(floorf(count)):
		var id: String = _GearDrops.pick(level, owned, equipped, rng)
		if id == "":
			continue
		if not owned.has(id):
			owned.append(id)
		var w: _WeaponData = _WeaponRegistry.get_weapon(id)
		var slot: String = _GearCurve.slot_of(w)
		var cur: _WeaponData = _WeaponRegistry.get_weapon(str(equipped.get(slot, "")))
		if cur == null or w.item_level > cur.item_level:
			equipped[slot] = id

## The worn loadout's item power at `level` over the curve's (1.0 when the curve has none yet).
static func coverage(level: int, equipped: Dictionary, tune: _CombatTuning) -> float:
	var curve: float = tune.item_power_log(level)
	if curve <= 0.0:
		return 1.0
	var worn: Array = []
	for s: Variant in equipped:
		worn.append([_WeaponRegistry.get_weapon(str(equipped[s])), 0])
	return _GearCurve.power_log(worn, tune) / curve
