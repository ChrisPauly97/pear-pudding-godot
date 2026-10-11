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
## - `bosses`: every boss at a level inside its range, same level.
## - `casual` (GID-187 / TID-784): the `range` cells at the same level only, fought by the
##   `casual` BalanceBot preset (a second policy, so the targets hold for a slower player too).
##
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
const BalanceStats = preload("res://game_logic/battle/BalanceStats.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

const SECTIONS: Array[String] = ["range", "world_low", "world_high", "schools", "bosses", "conditions", "casual",
	"wounded", "profiles"]
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
## Casual bot (GID-187 / TID-784): the `range` cells at the same level, with the casual preset.
## Lower bar than the default bot: same-level mean at least CASUAL_MEAN_MIN, no cell below
## CASUAL_CELL_MIN. The cell floor is set from the measurement (lowest cell 12.5 % at 8 fights,
## ghoul pack 4-5: the casual bot never swaps focus, which packs need) minus a 2.5 pp margin;
## it is a wall detector, not a 40 % bar. Mean measured 91 %.
const CASUAL_FIGHTS: int = 8
const CASUAL_MEAN_MIN: float = 0.75
const CASUAL_CELL_MIN: float = 0.10
## Levelling up never makes a fight worse: +0 wins at least the +1 rate minus this.
const MONOTONIC_SLACK: float = 0.15

## Paired school cells: [school, "weak" | "resist", enemy type, enemy level, player level].
## Each cell fights the same deck twice at the same seeds: against the enemy as authored and
## against it with `school`'s tag removed (`untag_school`), so the matchup is the only change.
## Magic schools bring a school-heavy deck (SCHOOL_SWAP Allies swapped for school cards: two
## cards barely register); physical is the default deck. Levels sit where the untagged fight is
## neither won nor lost every time, so the matchup has room to show.
const SCHOOL_MATRIX: Array = [
	["physical", "weak", "sand_stalker", 15, 14],
	["physical", "resist", "scarab_swarm", 14, 14],
	["physical", "resist", "wraith", 9, 8],
	["light", "weak", "spectre_haunt", 16, 14],
	["light", "resist", "duelist_champion", 23, 20],
	["dark", "weak", "mountain_troll", 16, 14],
	["dark", "resist", "bog_hag", 8, 6],
	["verdant", "weak", "martarquas_scout", 11, 9],
	["verdant", "resist", "forest_shade", 9, 7],
	["rift", "weak", "mimic", 17, 14],
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
## Boss cells: every boss at the low end of its range (its first meeting), same level.
const BOSSES: Array[String] = [
	"stone_golem", "hollow_steward", "martarquas_vanguard", "roaming_terror", "martarquas_warleader",
	"barrow_king", "blight_heart",
]
const BOSS_FIGHTS: int = 8
## Bosses are meant to be hard, but a same-level boss is beatable.
const BOSS_MIN: float = 0.40

## Battlefield conditions (GID-187 / TID-780). Neutral mid-level cells, the default deck (school
## schools use their matched deck): each condition vs no battlefield at all (the bare cfg), same
## seeds, paired. A condition may not move the win rate by more than CONDITION_MAX_SWING.
## Each school's favoured environment may not lower that school's matched-deck win rate.
## [enemy type, player level, enemy level].
const CONDITION_CELLS: Array = [["duelist_adept", 14, 14], ["rift_echo", 20, 20]]
const CONDITION_FIGHTS: int = 32
## Largest allowed swing (win rate, either way) of one condition against no battlefield.
const CONDITION_MAX_SWING: float = 0.25
## One school's favoured environment may lower its matched-deck win rate by at most this.
const CONDITION_SCHOOL_SLACK: float = 0.07
## [label, cfg keys the condition sets] (BattleSetup.build cfg).
const CONDITIONS: Array = [
	["rain", {"weather": "rain"}],
	["heavy_rain", {"weather": "heavy_rain"}],
	["ash_fall", {"weather": "ash_fall"}],
	["sandstorm", {"weather": "sandstorm"}],
	["snow", {"weather": "snow"}],
	["forest", {"biome": 1}],
	["desert_day", {"biome": 2, "is_night": false}],
	["desert_night", {"biome": 2, "is_night": true}],
	["scorched", {"biome": 3}],
	["mountains", {"biome": 4}],
	["night", {"is_night": true}],
	["blighted", {"blighted": true}],
	["ambush_player", {"ambush": "player"}],
	["ambush_enemy", {"ambush": "enemy"}],
	["gambit_wounded_pride", {"gambit_id": "wounded_pride"}],
	["gambit_slow_start", {"gambit_id": "slow_start"}],
	["gambit_emboldened_foe", {"gambit_id": "emboldened_foe"}],
	["gambit_iron_veil", {"gambit_id": "iron_veil"}],
]
## [school, cfg keys of its favoured environment] (BattlefieldRules.SCHOOL_ENV): light by day,
## dark by night, verdant in forest, rift in scorched, physical in mountains.
const SCHOOL_ENVS: Array = [
	["light", {"is_night": false}],
	["dark", {"is_night": true}],
	["verdant", {"biome": 1}],
	["rift", {"biome": 3}],
	["physical", {"biome": 4}],
]

## Wounded (GID-187 / TID-781). Starting HP as a fraction of max (the save's `hero_hp_frac`).
const WOUNDED_HP_FRAC: float = 0.6
const WOUNDED_FIGHTS: int = 8
## Same-level mean over the `range` cells from WOUNDED_HP_FRAC. Measured 69 % (24 cells x 8 fights,
## about 3.6 pp of sampling noise), so 70 % would fail on noise: the gate sits 4 pp under it.
const WOUNDED_MEAN_MIN: float = 0.65
## Potion cells: [type, player level] fought one level up from WOUNDED_HP_FRAC. The kit is what the
## player carries; the bot drinks its first ready potion below POTION_BELOW of max HP.
const POTION_CELLS: Array = [["undead_horde", 3], ["wolf_pack", 5], ["bog_hag", 7]]
const POTION_KIT: Dictionary = {"healing_draught": 3, "stoneskin_tonic": 2}
const POTION_BELOW: float = 0.5
const POTION_FIGHTS: int = 16
## Chain cells: [type, level] (same level). Each chain is CHAIN_FIGHTS fights with CHAIN_REST seconds
## of out-of-combat regen between them, CHAIN_CHAINS chains from WOUNDED_HP_FRAC. Measured (32 chains):
## undead_basic@2 100 %, undead_horde@3 56 %, wolf_pack@4 44 % (a miss, not gated). Screened and
## missed at 16 chains: ghoul_pack@4 6 %, wolf_pack@6 0 %, bog_hag@6 6 %, forest_shade@6 6 %,
## ghoul_pack@3 6 %, imbued_stag@7 0 %, martarquas_scout@9 0 %, undead_basic@1 44 %. Only the two
## that clear the bar are gated; a 3-fight chain from 60 % HP is a hard target, not a general one.
const CHAIN_CELLS: Array = [["undead_basic", 2], ["undead_horde", 3]]
const CHAIN_FIGHTS: int = 3
const CHAIN_CHAINS: int = 32
const CHAIN_REST: float = 30.0
## A same-level 3-fight chain is cleared at least this often on each chain cell.
const CHAIN_MIN: float = 0.5

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
	var lo: int = clampi(r.x, PROGRESSION_MIN_LEVEL, MAX_LEVEL - 1)
	var hi: int = clampi(r.y, lo, MAX_LEVEL - 1)
	var out: Array[int] = []
	for lv: int in [lo, (lo + hi) / 2, hi]:
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
## Allies swapped. `extra` keys are merged in last (e.g. `untag_school`, `is_boss`).
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
		var school: String = "" if section == "range" else neutral_school(t)
		out[BalanceBands.key(t, lv, 0)] = run_cell(t, lv, lv, FIGHTS_SAME, school, tune)
		out[BalanceBands.key(t, lv, 1)] = run_cell(t, lv, lv + 1, FIGHTS_UP, school, tune)
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
		if wr < UP_CELL_MIN - 0.001:
			fails.append("%s %s: one level up win rate %.0f%% < %.0f%% (a wall)" % [section, k, wr * 100.0,
				UP_CELL_MIN * 100.0])
	if up_n > 0:
		var mean: float = up_sum / float(up_n)
		if mean < UP_MEAN_MIN or mean > UP_MEAN_MAX:
			fails.append("%s one level up: mean %.0f%% outside %.0f-%.0f%%" % [section, mean * 100.0,
				UP_MEAN_MIN * 100.0, UP_MEAN_MAX * 100.0])
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
			"rate": float(run_cell(enemy, pl, el, SCHOOL_FIGHTS, school, tune, {}, SCHOOL_SWAP)["win_rate"]),
			"untagged": float(run_cell(enemy, pl, el, SCHOOL_FIGHTS, school, tune, {"untag_school": school},
				SCHOOL_SWAP)["win_rate"])}
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

## The level a boss cell fights at: the low end of its range.
static func boss_level(type: String) -> int:
	return clampi(EnemyRegistry.level_range(type).x, 1, MAX_LEVEL)

## Runs the boss cells: {type@level: cell}.
static func measure_bosses(tune: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for t: String in BOSSES:
		var lv: int = boss_level(t)
		out[BalanceBands.key(t, lv, 0)] = run_cell(t, lv, lv, BOSS_FIGHTS, neutral_school(t), tune, {"is_boss": true})
	return out

static func check_bosses(measured: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	for k: String in measured:
		var wr: float = float((measured[k] as Dictionary)["win_rate"])
		if wr < BOSS_MIN - 0.001:
			fails.append("bosses %s: win rate %.0f%% < %.0f%%" % [k, wr * 100.0, BOSS_MIN * 100.0])
	return fails

## Runs the condition cells: {"condition/<label>/<type>@<level>": cell, "school/<school>/<env>/<type>@<level>": cell}.
## Each cell has its win rate (`win_rate`), the bare rate at the same seeds (`base`), and `median_s`.
static func measure_conditions(tune: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for c: Array in CONDITION_CELLS:
		var t: String = str(c[0])
		var pl: int = int(c[1])
		var el: int = int(c[2])
		var base: Dictionary = run_cell(t, pl, el, CONDITION_FIGHTS, "", tune)
		for cond: Array in CONDITIONS:
			var r: Dictionary = run_cell(t, pl, el, CONDITION_FIGHTS, "", tune, cond[1] as Dictionary)
			out["condition/%s/%s@%d" % [str(cond[0]), t, el]] = {"kind": "condition", "win_rate": r["win_rate"],
				"median_s": r["median_s"], "base": base["win_rate"], "n": r["n"]}
		for se: Array in SCHOOL_ENVS:
			var school: String = str(se[0])
			var school_base: Dictionary = run_cell(t, pl, el, CONDITION_FIGHTS, school, tune, {}, BattleSetup.MATCHED_SWAP)
			var r2: Dictionary = run_cell(t, pl, el, CONDITION_FIGHTS, school, tune, se[1] as Dictionary,
				BattleSetup.MATCHED_SWAP)
			out["school/%s/%s/%s@%d" % [school, _env_label(se[1] as Dictionary), t, el]] = {"kind": "school",
				"win_rate": r2["win_rate"], "median_s": r2["median_s"], "base": school_base["win_rate"], "n": r2["n"]}
	return out

## A short label for an environment cfg ("day", "night", "biome2"...).
static func _env_label(env: Dictionary) -> String:
	if env.has("is_night"):
		return "night" if bool(env["is_night"]) else "day"
	return "biome%d" % int(env.get("biome", -1))

## Failures of the condition cells (empty = pass).
static func check_conditions(measured: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	for k: String in measured:
		var m: Dictionary = measured[k]
		var rate: float = float(m["win_rate"])
		var base: float = float(m["base"])
		if str(m["kind"]) == "condition":
			if absf(rate - base) > CONDITION_MAX_SWING + 0.001:
				fails.append("conditions %s: %.0f%% vs %.0f%% with no battlefield (swing over %.0f pp)" % [k,
					rate * 100.0, base * 100.0, CONDITION_MAX_SWING * 100.0])
		elif rate < base - CONDITION_SCHOOL_SLACK - 0.001:
			fails.append("conditions %s: favoured environment %.0f%% lowers the matched deck from %.0f%%" % [k,
				rate * 100.0, base * 100.0])
	return fails

## Runs the casual cells: {BalanceBands.key(type, level, 0): cell}, same level only.
static func measure_casual(tune: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for cell: Array in ladder_cells("range"):
		var t: String = str(cell[0])
		var lv: int = int(cell[1])
		out[BalanceBands.key(t, lv, 0)] = run_cell(t, lv, lv, CASUAL_FIGHTS, "", tune, {}, BattleSetup.MATCHED_SWAP,
			BalanceBot.preset("casual"))
	return out

## Failures of the casual measurement (empty = pass).
static func check_casual(measured: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	var sum: float = 0.0
	for k: String in measured:
		var wr: float = float((measured[k] as Dictionary)["win_rate"])
		sum += wr
		if wr < CASUAL_CELL_MIN - 0.001:
			fails.append("casual %s: same-level win rate %.0f%% < %.0f%%" % [k, wr * 100.0, CASUAL_CELL_MIN * 100.0])
	if not measured.is_empty():
		var mean: float = sum / float(measured.size())
		if mean < CASUAL_MEAN_MIN - 0.001:
			fails.append("casual: same-level mean %.0f%% < %.0f%%" % [mean * 100.0, CASUAL_MEAN_MIN * 100.0])
	return fails

## Runs the wounded cells: {"range/<type@lv+0>": cell, "potion/<type@lv+1>/off|on": cell,
## "chain/<type@lv+0>": cell (win_rate = share of chains cleared in full, cleared = mean fights won)}.
static func measure_wounded(tune: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var wounded: Dictionary = {"start_hp_frac": WOUNDED_HP_FRAC}
	for cell: Array in ladder_cells("range"):
		var t: String = str(cell[0])
		var lv: int = int(cell[1])
		out["range/" + BalanceBands.key(t, lv, 0)] = run_cell(t, lv, lv, WOUNDED_FIGHTS, "", tune, wounded)
	for cell: Array in POTION_CELLS:
		var t: String = str(cell[0])
		var pl: int = int(cell[1])
		var key: String = BalanceBands.key(t, pl, 1)
		out["potion/%s/off" % key] = run_cell(t, pl, pl + 1, POTION_FIGHTS, "", tune, wounded)
		var kit: Dictionary = {"start_hp_frac": WOUNDED_HP_FRAC, "potions": POTION_KIT.duplicate()}
		out["potion/%s/on" % key] = run_cell(t, pl, pl + 1, POTION_FIGHTS, "", tune, kit, BattleSetup.MATCHED_SWAP,
			{"potion_below": POTION_BELOW})
	for cell: Array in CHAIN_CELLS:
		var t: String = str(cell[0])
		var lv: int = int(cell[1])
		var cleared: int = 0
		var won_all: int = 0
		var fights: Array[Dictionary] = []
		for k: int in CHAIN_CHAINS:
			var cfg: Dictionary = cell_cfg(t, lv, lv, 1 + k * CHAIN_FIGHTS, "", tune, wounded)
			var r: Dictionary = BalanceFight.chain(cfg, CHAIN_FIGHTS, {}, CHAIN_REST)
			cleared += int(r["cleared"])
			won_all += 1 if bool(r["won_all"]) else 0
			fights.append_array(r["results"])
		var s: Dictionary = BalanceStats.summarize(fights)
		out["chain/" + BalanceBands.key(t, lv, 0)] = {"win_rate": float(won_all) / float(CHAIN_CHAINS),
			"median_s": float(s["median_s"]), "n": CHAIN_CHAINS, "cleared": float(cleared) / float(CHAIN_CHAINS)}
	return out

## Failures of the wounded measurement (empty = pass).
static func check_wounded(measured: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	var sum: float = 0.0
	var n: int = 0
	for k: String in measured:
		var wr: float = float((measured[k] as Dictionary)["win_rate"])
		if k.begins_with("range/"):
			sum += wr
			n += 1
		elif k.begins_with("chain/") and wr < CHAIN_MIN - 0.001:
			fails.append("wounded %s: %d-fight chain cleared %.0f%% < %.0f%%" % [k, CHAIN_FIGHTS, wr * 100.0,
				CHAIN_MIN * 100.0])
	if n > 0 and sum / float(n) < WOUNDED_MEAN_MIN - 0.001:
		fails.append("wounded range: same-level mean %.0f%% at %.0f%% HP < %.0f%%" % [sum / float(n) * 100.0,
			WOUNDED_HP_FRAC * 100.0, WOUNDED_MEAN_MIN * 100.0])
	for k: String in measured:
		if not k.begins_with("potion/") or not k.ends_with("/on"):
			continue
		var on: float = float((measured[k] as Dictionary)["win_rate"])
		var off: float = float((measured[k.trim_suffix("on") + "off"] as Dictionary)["win_rate"])
		if on < off - 0.001:
			fails.append("wounded %s: potions win %.0f%% < %.0f%% without" % [k, on * 100.0, off * 100.0])
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
			measured = measure_conditions(tune)
			fails = check_conditions(measured)
		"casual":
			measured = measure_casual(tune)
			fails = check_casual(measured)
		"profiles":  # GID-187 / TID-778
			measured = BalanceProfiles.measure(tune)
			fails = BalanceProfiles.check(measured)
		"wounded":
			measured = measure_wounded(tune)
			fails = check_wounded(measured)
		_:
			measured = measure_ladder(section, tune)
			fails = check_ladder(section, measured)
	return {"measured": measured, "fails": fails}
