## Real-time co-op bands (GID-187 / TID-786): a party of 2-4 typical heroes against a same-level-ish boss
## or elite, each hero played by its own `BalanceBot` (`BalanceFight` cfg `party`), the enemy scaled by
## `CoopBattleScaling.realtime_*` (HP, damage, cadence per extra hero). Target (TID-786): a party clears at
## about the solo rate, so co-op is neither a carry nor a wall.
##
## Party fights swing on interrupt coverage (a Kick per hero), so single cells are noisy; the gate is per
## party size, on the mean over the cells. `BalanceCoverage` section `coop`. Pure except `measure`.
extends RefCounted

const BalanceProfiles = preload("res://game_logic/battle/BalanceProfiles.gd")
const BalanceFight = preload("res://game_logic/battle/BalanceFight.gd")
const MagicTypes = preload("res://game_logic/MagicTypes.gd")

## [enemy type, player level, enemy level, is boss]: the solo typical player wins about 25-75 %.
const CELLS: Array = [
	["barrow_king", 30, 31, true], ["frost_wendigo", 36, 38, false], ["duelist_champion", 26, 28, false],
	["spectre_haunt", 16, 17, false], ["undead_elite", 44, 46, false],
]
const PARTY_SIZES: Array[int] = [1, 2, 3, 4]
const FIGHTS: int = 16
## Per party size, the mean win rate over the cells stays within this of the solo mean.
const PARTY_BAND: float = 0.25

## The cfg of fight `f` with a party of `n`: hero k plays magic type (f + k) % 4, so every party mixes types.
static func party_cfg(cell: Array, n: int, f: int, tune: Dictionary = {}) -> Dictionary:
	var types: Array[String] = MagicTypes.all_types()
	var lv: int = int(cell[1])
	var c: Dictionary = BalanceProfiles.cfg(lv, types[f % types.size()], "typical")
	var party: Array = []
	for k: int in range(1, n):
		party.append(BalanceProfiles.cfg(lv, types[(f + k) % types.size()], "typical"))
	c.merge({"seed": 1 + f, "enemy_type": str(cell[0]), "enemy_level": int(cell[2]), "is_boss": bool(cell[3]),
		"party": party}, true)
	if not tune.is_empty():
		c["tuning"] = tune
	return c

## {"<enemy>@<level>/n<n>": {n, win_rate, median_s}}.
static func measure(tune: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for cell: Array in CELLS:
		for n: int in PARTY_SIZES:
			var won: int = 0
			var secs: Array[float] = []
			for f: int in FIGHTS:
				var r: Dictionary = BalanceFight.run(party_cfg(cell, n, f, tune))
				if str(r["result"]) == "win":
					won += 1
				secs.append(float(r["seconds"]))
			secs.sort()
			out["%s@%d/n%d" % [str(cell[0]), int(cell[1]), n]] = {"n": n, "win_rate": float(won) / float(FIGHTS),
				"median_s": secs[secs.size() / 2]}
	return out

## Mean win rate per party size: {n: rate}.
static func means(measured: Dictionary) -> Dictionary:
	var sums: Dictionary = {}
	for k: String in measured:
		var m: Dictionary = measured[k]
		var acc: Array = sums.get(int(m["n"]), [0.0, 0])
		sums[int(m["n"])] = [float(acc[0]) + float(m["win_rate"]), int(acc[1]) + 1]
	var out: Dictionary = {}
	for n: Variant in sums:
		var acc: Array = sums[n]
		out[n] = float(acc[0]) / float(maxi(1, int(acc[1])))
	return out

## Failures (empty = pass): a party size whose mean leaves the solo mean ± PARTY_BAND.
static func check(measured: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	var m: Dictionary = means(measured)
	if not m.has(1):
		return ["coop: no solo cells"]
	var solo: float = float(m[1])
	for n: Variant in m:
		var rate: float = float(m[n])
		if absf(rate - solo) > PARTY_BAND + 0.001:
			fails.append("coop party of %d: mean %.0f%% vs solo %.0f%% (%s)" % [int(n), 100.0 * rate, 100.0 * solo,
				"a carry" if rate > solo else "a wall"])
	return fails
