## CI balance bands (GID-176 / TID-717): the user's targets turned into checks.
## With full HP / mana and average play (default `BalanceBot`), a level-L player
## beats a same-level enemy ~always and a one-level-up enemy about 75 % of the
## time. `measure()` runs one cell per Chapter 1 enemy type at a level inside its
## range, at +0 and +1; `check()` compares a measurement with the targets and the
## committed baseline (`tests/data/balance_baseline.json`). Pure except `measure`
## running fights; `tests/balance_bands.gd` (CI) and `tools/balance_sim.gd
## --write-baseline` drive it.
extends RefCounted

const BalanceFight = preload("res://game_logic/battle/BalanceFight.gd")
const BalanceStats = preload("res://game_logic/battle/BalanceStats.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")

const BASELINE_PATH: String = "res://tests/data/balance_baseline.json"
## [enemy type, player level]: each Chapter 1 type mid-range (EnemyRegistry.LEVEL_RANGES).
const CELLS: Array = [
	["undead_basic", 1], ["undead_horde", 3], ["ghoul_pack", 4], ["wolf_pack", 5],
	["forest_shade", 6], ["bog_hag", 7], ["imbued_stag", 8], ["martarquas_scout", 9],
]
## Fights per cell (fixed seeds 1..n): same level / one level up.
const FIGHTS_SAME: int = 20
const FIGHTS_UP: int = 40
## Targets (user, 2026-10-08).
const SAME_MIN: float = 0.97
const UP_MEAN_MIN: float = 0.65
const UP_MEAN_MAX: float = 0.85
## Drift guards against the baseline: win rate ± points, median length ± fraction.
const DRIFT_WIN: float = 0.10
const DRIFT_SECONDS: float = 0.25

## The cell key, e.g. "wolf_pack@5+1".
static func key(enemy: String, level: int, offset: int) -> String:
	return "%s@%d+%d" % [enemy, level, offset]

## Ladder ids a level-`level` player knows (rows with level_req <= level).
static func ladder_learned(level: int) -> Array:
	var out: Array = []
	for id: String in UnlockLadder.all_ids():
		if UnlockLadder.level_req(id) <= level:
			out.append(id)
	return out

## Runs every cell: {key: {win_rate, median_s, n}}.
static func measure() -> Dictionary:
	var out: Dictionary = {}
	for cell: Array in CELLS:
		var enemy: String = str(cell[0])
		var level: int = int(cell[1])
		for offset: int in [0, 1]:
			var results: Array[Dictionary] = []
			for f: int in (FIGHTS_SAME if offset == 0 else FIGHTS_UP):
				results.append(BalanceFight.run({"seed": 1 + f, "player_level": level, "enemy_type": enemy,
					"enemy_level": level + offset, "learned": ladder_learned(level)}))
			var s: Dictionary = BalanceStats.summarize(results)
			out[key(enemy, level, offset)] = {"win_rate": float(s["win_rate"]), "median_s": float(s["median_s"]),
				"n": int(s["n"])}
	return out

## Failures (empty = pass) of `measured` against the targets and `baseline`
## (same shape; a cell missing from the baseline is only target-checked).
static func check(measured: Dictionary, baseline: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	var up_sum: float = 0.0
	var up_n: int = 0
	for k: String in measured:
		var m: Dictionary = measured[k]
		var wr: float = float(m["win_rate"])
		if k.ends_with("+0") and wr < SAME_MIN:
			fails.append("%s: same-level win rate %.0f%% < %.0f%%" % [k, wr * 100.0, SAME_MIN * 100.0])
		if k.ends_with("+1"):
			up_sum += wr
			up_n += 1
		if not baseline.has(k):
			continue
		var b: Dictionary = baseline[k]
		if absf(wr - float(b["win_rate"])) > DRIFT_WIN + 0.001:
			fails.append("%s: win rate %.0f%% drifted from baseline %.0f%%" % [k, wr * 100.0,
				float(b["win_rate"]) * 100.0])
		var bs: float = float(b["median_s"])
		if bs > 0.0 and absf(float(m["median_s"]) - bs) / bs > DRIFT_SECONDS:
			fails.append("%s: median %.1f s drifted from baseline %.1f s" % [k, float(m["median_s"]), bs])
	if up_n > 0:
		var mean: float = up_sum / float(up_n)
		if mean < UP_MEAN_MIN or mean > UP_MEAN_MAX:
			fails.append("one level up: mean win rate %.0f%% outside %.0f-%.0f%%" % [mean * 100.0,
				UP_MEAN_MIN * 100.0, UP_MEAN_MAX * 100.0])
	return fails

## The committed baseline's cells ({} when missing).
static func load_baseline() -> Dictionary:
	var f := FileAccess.open(BASELINE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return {}
	var cells: Variant = (data as Dictionary).get("cells", {})
	return cells as Dictionary if cells is Dictionary else {}
