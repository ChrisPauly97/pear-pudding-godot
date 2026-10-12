## Progression rewards bands (GID-187 / TID-779): every reward a player earns must measurably help, and
## none may be a must-have. Paired cells: the typical profile (`BalanceProfiles`) against a harder enemy
## (`CELLS`), with and without one reward at a time, at the same seeds over the enemy's neutral magic types.
##
## Axes (`AXES`): `skills` (the level's skill build and its technique cards vs none), `weapon_upgrade`
## (blacksmith +`WEAPON_UPGRADE` on the weapon), `card_rank` (deck Allies at veterancy rank
## `CARD_RANK`), `companion` (Maiteln, `COMPANION`), `gear_step` (the loadout of the level vs that of
## `GEAR_STEP` levels lower: one catalogue step) and `tech_slot` (the fourth technique slot,
## `UnlockLadder.FEAT_TECH_SLOT`, only where it is learned: BID-103). Plus `builds`: within a magic
## type, its default skill build (first branch first) vs the second branch first.
##
## Pure except the `measure` call running fights. `BalanceCoverage` section `rewards`.
extends RefCounted

const BalanceProfiles = preload("res://game_logic/battle/BalanceProfiles.gd")
const BalanceFight = preload("res://game_logic/battle/BalanceFight.gd")
const BalanceStats = preload("res://game_logic/battle/BalanceStats.gd")
const GearDrops = preload("res://game_logic/items/GearDrops.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const XpCurve = preload("res://game_logic/progression/XpCurve.gd")
const MagicTypes = preload("res://game_logic/MagicTypes.gd")
const BalanceBands = preload("res://game_logic/battle/BalanceBands.gd")

const AXES: Array[String] = ["skills", "weapon_upgrade", "card_rank", "companion", "gear_step", "tech_slot"]
## [enemy type, player level, enemy levels above]: picked from a 12-fight screen where the typical
## player wins about 25-75 %, so a reward has room to show either way.
const CELLS: Array = [
	["duelist_adept", 14, 2], ["spectre_haunt", 16, 1], ["duelist_champion", 26, 2], ["frost_wendigo", 36, 2],
	["undead_elite", 40, 2],
]
const FIGHTS: int = 24
const WEAPON_UPGRADE: int = 3
const CARD_RANK: int = 2
## Maiteln's passive (`CompanionRegistry`, `test_balance_rewards` keeps them equal).
const COMPANION: Dictionary = {"passive_type": "draw_card", "passive_value": 1}
const GEAR_STEP: int = 4
## Gates (measured first; see `docs/agent/balance-sim.md` → Rewards). Mean gain of an axis over the
## cells (win-rate points): at least AXIS_MIN (it helps), at most AXIS_MAX (no must-have). A single cell
## may go the wrong way by up to CELL_SLACK (24 fights move in ~4 pp steps; seeds decorrelate).
const AXIS_MIN: float = 0.03
const AXIS_MAX: float = 0.40
const CELL_SLACK: float = 0.15
## Axes exempt from AXIS_MAX: gear is meant to carry most of a player's growth (TID-793), so one
## catalogue step is reported, not capped.
const UNCAPPED: Array[String] = ["gear_step"]
## Axes exempt from AXIS_MIN: the fourth technique slot is a deck rule, not a power reward; BID-103
## asked that it stop being a big step, so only the cap applies (measured ~0 pp).
const NO_MIN: Array[String] = ["tech_slot"]
## Two skill builds of a magic type (pooled over the types): at most BUILD_CELL_MAX apart in any cell
## and BUILD_MEAN_MAX on average. The low cells sit on a cliff where one recycle node flips a fight
## (TID-779 measurement), so a single cell gets the wider bound.
const BUILD_CELL_MAX: float = 0.40
const BUILD_MEAN_MAX: float = 0.15

## A typical level-`level` cfg of `magic_type` with `axis` on (`with`) or off. Axes the profile already
## has (skills, gear, the fourth slot) are taken away for "off"; the rest are added for "on".
static func axis_cfg(axis: String, with: bool, level: int, magic_type: String) -> Dictionary:
	var c: Dictionary = BalanceProfiles.cfg(level, magic_type, "typical")
	match axis:
		"skills":
			if not with:
				var none: Array[String] = []
				c["skills"] = none
				c["deck"] = BalanceProfiles.deck(magic_type, c["learned"] as Array, none)
		"weapon_upgrade":
			if with:
				c["weapon_upgrade"] = WEAPON_UPGRADE
		"card_rank":
			if with:
				c["card_rank"] = CARD_RANK
		"companion":
			if with:
				c["companion"] = COMPANION
		"gear_step":
			if not with:
				c.merge(_loadout_cfg(level - GEAR_STEP, magic_type), true)
		"tech_slot":
			if not with:
				var learned: Array = (c["learned"] as Array).duplicate()
				learned.erase(UnlockLadder.FEAT_TECH_SLOT)
				c["learned"] = learned
				c["deck"] = BalanceProfiles.deck(magic_type, learned, c["skills"] as Array[String])
	return c

## The gear keys of the `magic_type` loadout of `level`.
static func _loadout_cfg(level: int, magic_type: String) -> Dictionary:
	var out: Dictionary = {}
	var gear: Array = []
	var loadout: Dictionary = GearDrops.expected_loadout(maxi(1, level), magic_type)
	for slot: String in loadout:
		if slot == "weapon" or slot == "offhand":
			out[slot] = str(loadout[slot])
		else:
			gear.append({"id": str(loadout[slot])})
	out["gear"] = gear
	return out

## The second skill build of `magic_type` at `level`: the same points, second branch first.
static func alt_build(magic_type: String, level: int) -> Array[String]:
	var branches: Array = MagicTypes.branches_for(magic_type)
	var reversed: Array[String] = []
	for i: int in range(branches.size() - 1, -1, -1):
		reversed.append(str(branches[i]))
	return BalanceProfiles.skill_build(magic_type, XpCurve.skill_points_at(level), reversed)

## Whether `axis` applies at `level` (the fourth slot only once it is learned).
static func applies(axis: String, level: int) -> bool:
	return axis != "tech_slot" or BalanceBands.ladder_learned(level).has(UnlockLadder.FEAT_TECH_SLOT)

## Win rate over `FIGHTS` seeded fights, rotating the enemy's neutral magic types; `make(mt)` gives
## the cfg fragment.
static func _rate(enemy: String, level: int, up: int, make: Callable, tune: Dictionary) -> float:
	var types: Array[String] = BalanceProfiles.neutral_types(enemy)
	var results: Array[Dictionary] = []
	for f: int in FIGHTS:
		var c: Dictionary = make.call(types[f % types.size()])
		c.merge({"seed": 1 + f, "enemy_type": enemy, "enemy_level": level + up}, true)
		if not tune.is_empty():
			c["tuning"] = tune
		results.append(BalanceFight.run(c))
	return float(BalanceStats.summarize(results)["win_rate"])

## {"<axis>/<enemy>@<level>": {axis, with, without}, "builds/<type>@<level>": {axis: "builds", with
## (default build), without (second branch first)}}.
static func measure(tune: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for cell: Array in CELLS:
		var enemy: String = str(cell[0])
		var lv: int = int(cell[1])
		var up: int = int(cell[2])
		for axis: String in AXES:
			if not applies(axis, lv):
				continue
			var on: float = _rate(enemy, lv, up, func(mt: String) -> Dictionary: return axis_cfg(axis, true, lv, mt), tune)
			var off: float = _rate(enemy, lv, up, func(mt: String) -> Dictionary: return axis_cfg(axis, false, lv, mt),
				tune)
			out["%s/%s@%d" % [axis, enemy, lv]] = {"axis": axis, "with": on, "without": off}
		var alt: float = _rate(enemy, lv, up, func(mt: String) -> Dictionary:
			var c: Dictionary = BalanceProfiles.cfg(lv, mt, "typical")
			var sk: Array[String] = alt_build(mt, lv)
			c["skills"] = sk
			c["deck"] = BalanceProfiles.deck(mt, c["learned"] as Array, sk)
			return c, tune)
		var std: float = _rate(enemy, lv, up, func(mt: String) -> Dictionary:
			return BalanceProfiles.cfg(lv, mt, "typical"), tune)
		out["builds/%s@%d" % [enemy, lv]] = {"axis": "builds", "with": std, "without": alt}
	return out

## Failures of a `rewards` measurement (empty = pass).
static func check(measured: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	var sums: Dictionary = {}
	var build_sum: float = 0.0
	var build_n: int = 0
	for k: String in measured:
		var m: Dictionary = measured[k]
		var axis: String = str(m["axis"])
		var gain: float = float(m["with"]) - float(m["without"])
		if axis == "builds":
			build_sum += absf(gain)
			build_n += 1
			if absf(gain) > BUILD_CELL_MAX + 0.001:
				fails.append("rewards %s: skill builds differ by %.0f pp (max %.0f)" % [k, 100.0 * absf(gain),
					100.0 * BUILD_CELL_MAX])
			continue
		if gain < -CELL_SLACK - 0.001:
			fails.append("rewards %s: the reward lowers the win rate %.0f pp" % [k, -100.0 * gain])
		var acc: Array = sums.get(axis, [0.0, 0])
		sums[axis] = [float(acc[0]) + gain, int(acc[1]) + 1]
	for axis: String in sums:
		var acc: Array = sums[axis]
		var mean: float = float(acc[0]) / float(maxi(1, int(acc[1])))
		if not NO_MIN.has(axis) and mean < AXIS_MIN - 0.001:
			fails.append("rewards %s: mean gain %.0f pp < %.0f pp (does not help)" % [axis, 100.0 * mean,
				100.0 * AXIS_MIN])
		if not UNCAPPED.has(axis) and mean > AXIS_MAX + 0.001:
			fails.append("rewards %s: mean gain %.0f pp > %.0f pp (a must-have)" % [axis, 100.0 * mean,
				100.0 * AXIS_MAX])
	if build_n > 0 and build_sum / float(build_n) > BUILD_MEAN_MAX + 0.001:
		fails.append("rewards: skill builds differ by %.0f pp on average (max %.0f)" % [100.0 * build_sum
			/ float(build_n), 100.0 * BUILD_MEAN_MAX])
	return fails
