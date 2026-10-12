## Wide balance coverage (GID-186): the targets of `BalanceBands` (same level ~always,
## one level up about 75 %) checked over every level 1-60, every regular enemy type,
## every damage school against weak / resisted enemies, and the bosses.
##
## Sections (each measured on its own, so CI can run them side by side):
## - `range`: every Chapter 1 type at **every** level of its range (BalanceBands.CELLS
##   samples one), at +0 and +1.
## - `world_low` / `world_high`: every regular type beyond Chapter 1 at the low, middle
##   and high end of its level range (from PROGRESSION_MIN_LEVEL), at +0 and +1. The player
##   brings a deck the enemy is neutral to (`neutral_school`): a physical-resistant type is
##   met with a magic school, as a player picks a fight's deck.
## - `schools`: per school, a paired cell vs an enemy weak to it and one that resists it,
##   each against the same enemy with that school's tag removed, same seeds (`SCHOOL_MATRIX`).
## - `bosses`: every boss at the low, middle and high level of its range, same level, with
##   its phase 2 (GID-187 / TID-782).
## - `joiners` (GID-187 / TID-782): a few Chapter 1 and world cells, same level, with a second
##   enemy of the same type joining at 10 s; the joined win rate must clear a floor and never
##   beat the solo rate.
## - `casual` (GID-187 / TID-784): the `range` cells at the same level only, fought by the
##   `casual` BalanceBot preset (a second policy, so the targets hold for a slower player too).
##
## - `runs` (GID-187 / TID-783): rift tier ladders and siege gauntlets with HP carried (`BalanceRuns`).
## - `rewards` (GID-187 / TID-779): each progression reward helps, none dominates (`BalanceRewards`).
## - `wounded` (GID-187 / TID-781): a real player often starts wounded. (a) the `range` cells at the
##   same level from 60 % HP (mean gate); (b) potions: `POTION_CELLS` at +1 from 60 % HP, with and
##   without a quick-slot kit drunk below half HP; (c) `CHAIN_CELLS`: a 3-fight chain at the same
##   level, HP carried between fights with some rest, cleared in full at least `CHAIN_MIN` of the time.
##
## Pure except the `measure_*` functions running fights. `tests/balance_coverage.gd` drives
## it; `tests/unit/test_balance_coverage.gd` covers the checks and the cell tables.
extends RefCounted

const BalanceBands = preload("res://game_logic/battle/BalanceBands.gd")
const BalanceBot = preload("res://game_logic/battle/BalanceBot.gd")
const BalanceFight = preload("res://game_logic/battle/BalanceFight.gd")
const BalanceProfiles = preload("res://game_logic/battle/BalanceProfiles.gd")
const BalanceRewards = preload("res://game_logic/battle/BalanceRewards.gd")
const BalanceRuns = preload("res://game_logic/battle/BalanceRuns.gd")
const BalanceScenarios = preload("res://game_logic/battle/BalanceScenarios.gd")
const BalanceStats = preload("res://game_logic/battle/BalanceStats.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

const SECTIONS: Array[String] = ["range", "world_low", "world_high", "schools", "bosses", "conditions", "casual",
	"wounded", "profiles", "joiners", "rewards", "runs"]
## Regular world types past Chapter 1 (no bosses, no training dummy), by authored tier:
## `world_low` = tiers 1-2, `world_high` = tiers 3-4.
const WORLD_LOW: Array[String] = [
	"wraith", "cactus_worm", "duelist_novice", "martarquas_raider_1", "rival_isfig_1", "spectre_wisp",
	"sand_stalker", "scarab_swarm", "duelist_adept", "martarquas_raider_2", "rival_isfig_2",
	"spectre_haunt", "mimic",
]
const WORLD_HIGH: Array[String] = [
	"scorched_revenant", "mountain_troll", "duelist_champion", "martarquas_raider_3", "ember_cultist",
	"rift_echo", "rival_isfig_3", "spectre_dread", "undead_elite", "frost_wendigo",
]
## World cells start here: spells (and so a school deck) unlock at level 5, and below it the
## Chapter 1 types are what the player meets.
const PROGRESSION_MIN_LEVEL: int = 5
const MAX_LEVEL: int = 60
## Fights per cell: same level / one level up (fixed seeds 1..n).
const FIGHTS_SAME: int = 8
const FIGHTS_UP: int = 16
## Same-level floor per cell: at 8 fights, at most one loss.
const SAME_MIN: float = 0.87
## One level up: no cell is a wall or a walkover on average per section, and no single cell
## is a wall.
const UP_MEAN_MIN: float = 0.65
const UP_MEAN_MAX: float = 0.90
const UP_CELL_MIN: float = 0.25
## GID-187 / TID-787 (user, 2026-10-11: "split the difference"): world cells fight as the typical
## player (UP_MEAN_* above); the `range` section is the bare hero, a floor: it must still win at the
## same level, and one level up only its mean is held (no per-cell wall check).
const BARE_UP_MEAN_MIN: float = 0.45
const BARE_UP_MEAN_MAX: float = 0.80
## Levelling up never makes a fight worse: +0 wins at least the +1 rate minus this.
const MONOTONIC_SLACK: float = 0.15

## Paired school cells: [school, "weak" | "resist", enemy type, enemy level, player level].
## Each cell fights the same deck twice at the same seeds: against the enemy as authored and
## against it with `school`'s tag removed (`untag_school`), so the matchup is the only change.
## Magic schools bring a school-heavy deck (SCHOOL_SWAP Allies swapped for school cards: two
## cards barely register); physical is the default deck. Levels sit where the untagged fight is
## neither won nor lost every time, so the matchup has room to show. Cells wear the level's expected
## gear (`geared`, TID-793).
const SCHOOL_MATRIX: Array = [  # levels re-picked for geared cells (TID-793, 8-fight screen)
	["physical", "weak", "sand_stalker", 13, 12],
	["physical", "resist", "scarab_swarm", 18, 17],
	["physical", "resist", "wraith", 13, 11],
	["light", "weak", "spectre_haunt", 22, 20],
	["light", "resist", "duelist_champion", 20, 18],
	["dark", "weak", "mountain_troll", 19, 17],
	["dark", "resist", "bog_hag", 13, 11],
	["verdant", "weak", "martarquas_scout", 10, 8],
	["verdant", "resist", "forest_shade", 9, 8],
	["rift", "weak", "mimic", 16, 14],
	["rift", "resist", "duelist_novice", 10, 8],
]
const SCHOOL_SWAP: int = 6
const SCHOOL_FIGHTS: int = 16
## Per cell, a weak school wins at least the untagged rate minus this and a resisted school at
## most the untagged rate plus this (one 16-fight cell moves in 6 pp steps).
const SCHOOL_SLACK: float = 0.07
## On average over the matrix, a weakness gains and a resistance costs at least this much.
const SCHOOL_MEAN_GAP: float = 0.05
## A same-level resisted matchup is a handicap, not a wall.
const RESIST_FLOOR: float = 0.40
## Boss cells: every boss at the low, middle and high level of its range, same level.
const BOSSES: Array[String] = [
	"stone_golem", "hollow_steward", "martarquas_vanguard", "roaming_terror", "martarquas_warleader",
	"barrow_king", "blight_heart",
]
const BOSS_FIGHTS: int = 8
## Bosses are meant to be hard, but a same-level boss is beatable.
const BOSS_MIN: float = 0.40
## The top of a boss's range (TID-782) is held to a measured floor where the boss is a wall for the
## sim's player (no gear, no skills): its 8-fight win rate less 2.5 pp, not BOSS_MIN. Not retuned.
## Phase 2 changes none of these cells (the hero dies before the boss reaches half HP).
const BOSS_HIGH_FLOORS: Dictionary = {
	"stone_golem": 0.0, "martarquas_vanguard": 0.0, "roaming_terror": 0.10, "barrow_king": 0.0,
	"blight_heart": 0.0, "martarquas_warleader": 0.10,
}

## [enemy type, player level] for `section` ("range", "world_low", "world_high").
static func ladder_cells(section: String) -> Array:
	var out: Array = []
	if section == "range":
		for t: String in EnemyRegistry.LEVEL_RANGES:
			var r: Vector2i = EnemyRegistry.level_range(t)
			for lv: int in range(r.x, r.y + 1):
				out.append([t, lv])
		return out
	var types: Array[String] = WORLD_LOW if section == "world_low" else WORLD_HIGH
	for t: String in types:
		for lv: int in world_levels(t):
			out.append([t, lv])
	return out

## Low, middle and high level of `type`'s range, clamped to PROGRESSION_MIN_LEVEL..MAX_LEVEL - 1
## (so +1 stays a real level); duplicates dropped.
static func world_levels(type: String) -> Array[int]:
	var r: Vector2i = EnemyRegistry.level_range(type)
	return _low_mid_high(clampi(r.x, PROGRESSION_MIN_LEVEL, MAX_LEVEL - 1), clampi(r.y, 1, MAX_LEVEL - 1))

## The low, middle and high level of a range `lo`..`hi` (duplicates dropped).
static func _low_mid_high(lo: int, hi: int) -> Array[int]:
	var top: int = maxi(lo, hi)
	var out: Array[int] = []
	for lv: int in [lo, (lo + top) / 2, top]:
		if not out.has(lv):
			out.append(lv)
	return out

## The school a player brings against `type`: "" (the default, physical deck) when the type
## is neutral to physical, else the first magic school it neither resists, is weak to nor is
## immune to ("" when there is none).
static func neutral_school(type: String) -> String:
	var prof: Dictionary = EnemyRegistry.get_school_profile(type, 1)
	for s: String in DamageSchools.all_schools():
		var tagged: bool = false
		for kind: String in ["resist", "weak", "immune"]:
			if (prof.get(kind, {}) as Dictionary).has(s):
				tagged = true
		if not tagged:
			return "" if s == DamageSchools.PHYSICAL else s
	return ""

## One fight's config. `school` "" = the default deck, else the school-matched deck with `swap`
## Allies swapped. `extra` keys are merged in last (e.g. `untag_school`, `is_boss`); `geared: true`
## adds the level's expected gear (`BalanceProfiles.gear_cfg`, TID-793).
static func cell_cfg(type: String, player_level: int, enemy_level: int, fight_seed: int, school: String = "",
		tune: Dictionary = {}, extra: Dictionary = {}, swap: int = BattleSetup.MATCHED_SWAP) -> Dictionary:
	var learned: Array = BalanceBands.ladder_learned(player_level)
	var cfg: Dictionary = {"seed": fight_seed, "player_level": player_level, "enemy_type": type,
		"enemy_level": enemy_level, "learned": learned}
	if school != "" and school != DamageSchools.PHYSICAL:
		cfg["deck"] = BattleSetup.school_matched_deck(school, learned, swap)
	if not tune.is_empty():
		cfg["tuning"] = tune
	cfg.merge(extra, true)
	if bool(cfg.get("geared", false)):  # TID-793: the curve's expected gear, deck unchanged
		cfg.erase("geared")
		cfg.merge(BalanceProfiles.gear_cfg(player_level), true)
	return cfg

## {win_rate, median_s, n} over `fights` seeded fights of one cell (`cell_cfg` arguments).
static func run_cell(type: String, player_level: int, enemy_level: int, fights: int, school: String = "",
		tune: Dictionary = {}, extra: Dictionary = {}, swap: int = BattleSetup.MATCHED_SWAP,
		policy: Dictionary = {}) -> Dictionary:
	var results: Array[Dictionary] = []
	for f: int in fights:
		results.append(BalanceFight.run(cell_cfg(type, player_level, enemy_level, 1 + f, school, tune, extra, swap),
			policy))
	var s: Dictionary = BalanceStats.summarize(results)
	return {"win_rate": float(s["win_rate"]), "median_s": float(s["median_s"]), "n": int(s["n"])}

## Runs a ladder section: {BalanceBands.key(type, level, offset): cell}.
static func measure_ladder(section: String, tune: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for cell: Array in ladder_cells(section):
		var t: String = str(cell[0])
		var lv: int = int(cell[1])
		if section == "range":  # the bare hero: the floor (TID-787)
			out[BalanceBands.key(t, lv, 0)] = run_cell(t, lv, lv, FIGHTS_SAME, "", tune)
			out[BalanceBands.key(t, lv, 1)] = run_cell(t, lv, lv + 1, FIGHTS_UP, "", tune)
		else:  # GID-187 / TID-787: world cells fight as the typical player of their level
			out[BalanceBands.key(t, lv, 0)] = BalanceProfiles.run_cell(t, lv, lv, FIGHTS_SAME, "typical", tune)
			out[BalanceBands.key(t, lv, 1)] = BalanceProfiles.run_cell(t, lv, lv + 1, FIGHTS_UP, "typical", tune)
	return out

## Failures of a ladder section's measurement (empty = pass).
static func check_ladder(section: String, measured: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	var up_sum: float = 0.0
	var up_n: int = 0
	for k: String in measured:
		var wr: float = float((measured[k] as Dictionary)["win_rate"])
		if k.ends_with("+0"):
			if wr < SAME_MIN:
				fails.append("%s %s: same-level win rate %.0f%% < %.0f%%" % [section, k, wr * 100.0, SAME_MIN * 100.0])
			var up_key: String = k.trim_suffix("+0") + "+1"
			if measured.has(up_key):
				var up: float = float((measured[up_key] as Dictionary)["win_rate"])
				if up > wr + MONOTONIC_SLACK + 0.001:
					fails.append("%s %s: one level up wins more (%.0f%%) than same level (%.0f%%)" % [section,
						k, up * 100.0, wr * 100.0])
			continue
		up_sum += wr
		up_n += 1
		if section != "range" and wr < UP_CELL_MIN - 0.001:
			fails.append("%s %s: one level up win rate %.0f%% < %.0f%% (a wall)" % [section, k, wr * 100.0,
				UP_CELL_MIN * 100.0])
	if up_n > 0:
		var mean: float = up_sum / float(up_n)
		var lo: float = BARE_UP_MEAN_MIN if section == "range" else UP_MEAN_MIN
		var hi: float = BARE_UP_MEAN_MAX if section == "range" else UP_MEAN_MAX
		if mean < lo or mean > hi:
			fails.append("%s one level up: mean %.0f%% outside %.0f-%.0f%%" % [section, mean * 100.0,
				lo * 100.0, hi * 100.0])
	return fails

## Runs the school matrix: {"school/kind/enemy@level": {school, kind, enemy, same, rate, untagged}}.
## `same` is true when the enemy fights at the player's level (the resist floor applies).
static func measure_schools(tune: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for row: Array in SCHOOL_MATRIX:
		var school: String = str(row[0])
		var enemy: String = str(row[2])
		var el: int = int(row[3])
		var pl: int = int(row[4])
		out["%s/%s/%s@%d" % [school, str(row[1]), enemy, el]] = {"school": school, "kind": str(row[1]),
			"enemy": enemy, "same": el == pl,
			"rate": float(run_cell(enemy, pl, el, SCHOOL_FIGHTS, school, tune, {"geared": true},
				SCHOOL_SWAP)["win_rate"]),
			"untagged": float(run_cell(enemy, pl, el, SCHOOL_FIGHTS, school, tune, {"untag_school": school,
				"geared": true}, SCHOOL_SWAP)["win_rate"])}
	return out

## Failures of the school matrix (empty = pass).
static func check_schools(measured: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	var gaps: Dictionary = {"weak": [0.0, 0], "resist": [0.0, 0]}
	for k: String in measured:
		var m: Dictionary = measured[k]
		var kind: String = str(m["kind"])
		var rate: float = float(m["rate"])
		var untagged: float = float(m["untagged"])
		var gap: float = rate - untagged if kind == "weak" else untagged - rate
		var g: Array = gaps[kind]
		g[0] = float(g[0]) + gap
		g[1] = int(g[1]) + 1
		if gap < -SCHOOL_SLACK - 0.001:
			fails.append("schools %s: %s matchup %.0f%% vs untagged %.0f%% goes the wrong way" % [k, kind,
				rate * 100.0, untagged * 100.0])
		if kind == "resist" and bool(m["same"]) and rate < RESIST_FLOOR - 0.001:
			fails.append("schools %s: same-level resisted %.0f%% < %.0f%% (a wall)" % [k, rate * 100.0,
				RESIST_FLOOR * 100.0])
	for kind: String in gaps:
		var g: Array = gaps[kind]
		if int(g[1]) > 0 and float(g[0]) / float(g[1]) < SCHOOL_MEAN_GAP - 0.001:
			fails.append("schools: %s matchups move the win rate %.0f pp on average, need %.0f pp" % [kind,
				100.0 * float(g[0]) / float(g[1]), SCHOOL_MEAN_GAP * 100.0])
	return fails

## The levels a boss cell fights at: the low, middle and high end of its range.
static func boss_levels(type: String) -> Array[int]:
	var r: Vector2i = EnemyRegistry.level_range(type)
	return _low_mid_high(clampi(r.x, 1, MAX_LEVEL), clampi(r.y, 1, MAX_LEVEL))

## Runs the boss cells: {type@level: cell}.
## Each cell carries its `floor`: BOSS_MIN, or the measured BOSS_HIGH_FLOORS entry at the top level.
static func measure_bosses(tune: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for t: String in BOSSES:
		var levels: Array[int] = boss_levels(t)
		for lv: int in levels:
			var cell: Dictionary = BalanceProfiles.run_cell(t, lv, lv, BOSS_FIGHTS, "typical", tune, {"is_boss": true})
			var top: bool = lv > levels[0] and lv == levels[levels.size() - 1]
			cell["floor"] = float(BOSS_HIGH_FLOORS[t]) if top and BOSS_HIGH_FLOORS.has(t) else BOSS_MIN
			out[BalanceBands.key(t, lv, 0)] = cell
	return out

static func check_bosses(measured: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	for k: String in measured:
		var m: Dictionary = measured[k]
		var wr: float = float(m["win_rate"])
		var gate: float = float(m.get("floor", BOSS_MIN))
		if wr < gate - 0.001:
			fails.append("bosses %s: win rate %.0f%% < %.0f%%" % [k, wr * 100.0, gate * 100.0])
	return fails


## Measures and checks one section: {"measured": Dictionary, "fails": Array[String]}.
static func run_section(section: String, tune: Dictionary = {}) -> Dictionary:
	var measured: Dictionary = {}
	var fails: Array[String] = []
	match section:
		"schools":
			measured = measure_schools(tune)
			fails = check_schools(measured)
		"bosses":
			measured = measure_bosses(tune)
			fails = check_bosses(measured)
		"conditions":
			measured = BalanceScenarios.measure_conditions(tune)
			fails = BalanceScenarios.check_conditions(measured)
		"casual":
			measured = BalanceScenarios.measure_casual(tune)
			fails = BalanceScenarios.check_casual(measured)
		"profiles":  # GID-187 / TID-778
			measured = BalanceProfiles.measure(tune)
			fails = BalanceProfiles.check(measured)
		"wounded":
			measured = BalanceScenarios.measure_wounded(tune)
			fails = BalanceScenarios.check_wounded(measured)
		"joiners":
			measured = BalanceScenarios.measure_joiners(tune)
			fails = BalanceScenarios.check_joiners(measured)
		"rewards":  # GID-187 / TID-779
			measured = BalanceRewards.measure(tune)
			fails = BalanceRewards.check(measured)
		"runs":  # GID-187 / TID-783
			measured = BalanceRuns.measure(tune)
			fails = BalanceRuns.check(measured)
		_:
			measured = measure_ladder(section, tune)
			fails = check_ladder(section, measured)
	return {"measured": measured, "fails": fails}
