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
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

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

## TID-757 school bands. Decks are the shape-matched decks (`BattleSetup.school_matched_deck`):
## the default deck with its last two Allies swapped for the school's own cards. Every deck is
## measured with the whole unlock ladder learned, at the same seeds.
## Roster cells: [biome, [[enemy type, enemy level, player level], ...]]. TID-771: one cell per
## biome, chosen from a 60-fight grid where the default deck is neither saturated nor dead (the old
## pooled cells paired a 100 % cell with a 0 % cell, so a pooled rate said nothing). Each is the
## biome's most informative enemy at its level gap.
const BIOME_ROSTERS: Array = [
	["grasslands", [["martarquas_scout", 9, 7]]],
	["forest", [["bog_hag", 8, 6]]],
	["desert", [["cactus_worm", 5, 4]]],
	["scorched", [["scorched_revenant", 6, 5]]],
	["mountains", [["mountain_troll", 8, 6]]],
]
## Matchup cells: [enemy type, enemy level, player level, weak school, resisted school]
## (EnemyRegistry profile: cactus worm is weak to dark and resists verdant).
const MATCHUPS: Array = [
	["cactus_worm", 6, 4, "dark", "verdant"],
]
## Fights per roster enemy / per matchup side (fixed seeds 1..n, same for every deck).
const SCHOOL_FIGHTS: int = 14
const MATCHUP_FIGHTS: int = 20
## Band (a): a school deck's biome win rate within this many points of the default deck, in neutral
## matchups only (GID-184 / TID-773; see `neutral_school_fails`).
const SCHOOL_BAND: float = 0.25
## Band (b): the weak school beats the resisted school by at least this many points.
const MATCHUP_MIN: float = 0.20

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

## Every school deck of TID-757 is measured with the whole unlock ladder learned
## (spells and Allies both open, so a school's cards are playable), same seeds.
static func all_learned() -> Array:
	return UnlockLadder.all_ids()

## One school cell: win rate over `fights` seeded fights. `school` "" = the default deck
## (`BattleSetup.level_deck`); otherwise the school-matched deck.
static func school_win_rate(enemy: String, enemy_level: int, player_level: int, school: String,
		fights: int) -> float:
	var learned: Array = all_learned()
	var wins: int = 0
	for f: int in fights:
		var cfg: Dictionary = {"seed": 1 + f, "player_level": player_level, "enemy_type": enemy,
			"enemy_level": enemy_level, "learned": learned}
		if school != "":
			cfg["deck"] = BattleSetup.school_matched_deck(school, learned)
		var r: Dictionary = BalanceFight.run(cfg)
		if str(r["result"]) == "win":
			wins += 1
	return float(wins) / float(maxi(1, fights))

## Runs the school cells: {"roster": {biome: {"default": wr, school: wr, ...}},
## "matchup": {"enemy@level": {"weak": wr, "resist": wr}}}. A roster win rate pools
## every enemy of its biome (the same seeds for each deck, so the comparison is paired).
static func measure_schools() -> Dictionary:
	var roster: Dictionary = {}
	var profiles: Dictionary = {}
	var decks: Array[String] = ["default"]
	decks.append_array(DamageSchools.all_schools())
	for biome: Array in BIOME_ROSTERS:
		var rates: Dictionary = {}
		for deck: String in decks:
			if deck == DamageSchools.PHYSICAL:
				rates[deck] = rates["default"]  # the physical matched deck IS the default deck
				continue
			var wins: float = 0.0
			var n: int = 0
			for cell: Array in biome[1]:
				var level: int = int(cell[1])
				var wr: float = school_win_rate(str(cell[0]), level, int(cell[2]),
					"" if deck == "default" else deck, SCHOOL_FIGHTS)
				wins += wr * float(SCHOOL_FIGHTS)
				n += SCHOOL_FIGHTS
			rates[deck] = wins / float(maxi(1, n))
		roster[str(biome[0])] = rates
		profiles[str(biome[0])] = _profiled_schools(biome[1] as Array)
	var matchup: Dictionary = {}
	for m: Array in MATCHUPS:
		var level: int = int(m[1])
		var player: int = int(m[2])
		matchup["%s@%d/%d" % [str(m[0]), level, player]] = {
			"weak": school_win_rate(str(m[0]), level, player, str(m[3]), MATCHUP_FIGHTS),
			"resist": school_win_rate(str(m[0]), level, player, str(m[4]), MATCHUP_FIGHTS),
		}
	return {"roster": roster, "matchup": matchup, "profiles": profiles}

## Every school any enemy of `cells` resists, is weak to or is immune to: {school: true}.
static func _profiled_schools(cells: Array) -> Dictionary:
	var out: Dictionary = {}
	for cell: Array in cells:
		var prof: Dictionary = EnemyRegistry.get_school_profile(str(cell[0]), 1)
		for kind: String in ["resist", "weak", "immune"]:
			for school: String in (prof.get(kind, {}) as Dictionary):
				out[school] = true
	return out

## GATING failures (empty = pass) of `measured` (from `measure_schools`): band (a) in neutral
## matchups (`neutral_school_fails`); band (b), each matchup's
## weak school beats its resisted school by MATCHUP_MIN; band (c), no school is the best (within
## 2 points of the biome's top) in every biome.
static func check_schools(measured: Dictionary) -> Array[String]:
	var fails: Array[String] = neutral_school_fails(measured)
	var matchup: Dictionary = measured.get("matchup", {}) as Dictionary
	for k: String in matchup:
		var m: Dictionary = matchup[k] as Dictionary
		var gap: float = float(m.get("weak", 0.0)) - float(m.get("resist", 0.0))
		if gap < MATCHUP_MIN - 0.001:
			fails.append("%s: weak school +%.0f pp over resisted, need +%.0f pp" % [k, gap * 100.0,
				MATCHUP_MIN * 100.0])
	var best: Array[String] = best_everywhere(measured.get("roster", {}) as Dictionary)
	if not (measured.get("roster", {}) as Dictionary).is_empty() and not best.is_empty():
		fails.append("(c) school %s is best in every biome" % ", ".join(PackedStringArray(best)))
	return fails

## Band (c) helper: the schools within 2 points of the top in every biome of `roster` ({biome: {school: wr}}).
static func best_everywhere(roster: Dictionary) -> Array[String]:
	var best: Array[String] = DamageSchools.all_schools()
	for biome: String in roster:
		var rates: Dictionary = roster[biome] as Dictionary
		var top: float = 0.0
		for s: String in DamageSchools.all_schools():
			top = maxf(top, float(rates.get(s, 0.0)))
		var kept: Array[String] = []
		for s: String in best:
			if float(rates.get(s, 0.0)) >= top - 0.02 - 0.001:
				kept.append(s)
		best = kept
	return best

## GATING band (a) (GID-184 / TID-773): in a neutral matchup every school-matched deck is within
## SCHOOL_BAND of the default deck. A school the biome's enemy resists, is weak to or is immune to
## is a matchup (band (b)'s job), so it is skipped; a biome whose enemy profiles physical is skipped
## whole, because the default deck itself is then not neutral (desert's cactus worm resists physical,
## the mountain troll is weak to it). `measured.profiles` = {biome: {school: true}}.
static func neutral_school_fails(measured: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	var roster: Dictionary = measured.get("roster", {}) as Dictionary
	var profiles: Dictionary = measured.get("profiles", {}) as Dictionary
	for biome: String in roster:
		var profiled: Dictionary = profiles.get(biome, {}) as Dictionary
		if profiled.has(DamageSchools.PHYSICAL):
			continue
		var rates: Dictionary = roster[biome] as Dictionary
		var base: float = float(rates.get("default", 0.0))
		for s: String in DamageSchools.all_schools():
			if profiled.has(s):
				continue
			var wr: float = float(rates.get(s, 0.0))
			if absf(wr - base) > SCHOOL_BAND + 0.001:
				fails.append("(a) %s: %s deck %.0f%% vs default %.0f%% in a neutral matchup (band +-%.0f pp)"
					% [biome, s, wr * 100.0, base * 100.0, SCHOOL_BAND * 100.0])
	return fails

## REPORT ONLY: every school deck outside SCHOOL_BAND of the default, matchups included (the profiled
## ones are expected: a weakness should win more, a resistance less). Returns the messages; never fails.
static func report_schools(measured: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var roster: Dictionary = measured.get("roster", {}) as Dictionary
	for biome: String in roster:
		var rates: Dictionary = roster[biome] as Dictionary
		var base: float = float(rates.get("default", 0.0))
		for s: String in DamageSchools.all_schools():
			var wr: float = float(rates.get(s, 0.0))
			if absf(wr - base) > SCHOOL_BAND + 0.001:
				notes.append("(a) %s: %s deck %.0f%% vs default %.0f%% (band +-%.0f pp)" % [biome, s,
					wr * 100.0, base * 100.0, SCHOOL_BAND * 100.0])
	return notes
