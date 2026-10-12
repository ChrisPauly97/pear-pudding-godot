## Balance coverage scenarios (GID-187): the `joiners` (TID-782), `conditions` (TID-780), `casual`
## (TID-784) and `wounded` (TID-781) sections of `BalanceCoverage`, split out of it to keep both files
## readable. Cells run through `BalanceCoverage.run_cell` / `cell_cfg`; `BalanceCoverage.run_section`
## dispatches here. Pure except the `measure_*` functions running fights.
extends RefCounted

const BalanceBands = preload("res://game_logic/battle/BalanceBands.gd")
const BalanceBot = preload("res://game_logic/battle/BalanceBot.gd")
const BalanceFight = preload("res://game_logic/battle/BalanceFight.gd")
const BalanceProfiles = preload("res://game_logic/battle/BalanceProfiles.gd")
const BalanceStats = preload("res://game_logic/battle/BalanceStats.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const BalanceCoverage = preload("res://game_logic/battle/BalanceCoverage.gd")

## Casual bot (GID-187 / TID-784): the `range` cells at the same level, with the casual preset.
## Lower bar than the default bot: same-level mean at least CASUAL_MEAN_MIN, no cell below
## CASUAL_CELL_MIN. The cell floor is set from the measurement (lowest cell 12.5 % at 8 fights,
## ghoul pack 4-5: the casual bot never swaps focus, which packs need) minus a 2.5 pp margin;
## it is a wall detector, not a 40 % bar. Mean measured 91 %.
const CASUAL_FIGHTS: int = 8
const CASUAL_MEAN_MIN: float = 0.75
const CASUAL_CELL_MIN: float = 0.10

## Joiner cells (GID-187 / TID-782): [enemy type, level], a few Chapter 1 and world cells. The
## player is at the enemy's level; a second enemy of the same type joins at JOINER_AT seconds.
## Chosen after measuring 24 candidate cells (16 fights each, solo 100 % at every one): these five
## clear the 40 % gate (undead_horde 2 = 88 %, undead_horde 4 = 100 %, wolf_pack 4 = 69 %,
## wraith 5 = 94 %, wraith 7 = 44 %). The rest are walls and are NOT in the gate: undead_basic 1-2
## (0 %), ghoul_pack 3 and 5 (0 %), forest_shade 8, bog_hag 8, imbued_stag 9, spectre_wisp 10,
## mimic 14, duelist_adept 14, spectre_haunt 12, mountain_troll 20 (0 %), and the rest 0-25 %
## (see the TID-782 task file). A same-type joiner doubles the swing rate for the rest of the fight.
const JOINER_CELLS: Array = [
	["undead_horde", 2], ["undead_horde", 4], ["wolf_pack", 4], ["wraith", 5], ["wraith", 7],
]
const JOINER_AT: float = 10.0
const JOINER_FIGHTS: int = 16
## A joined fight is harder but winnable: at least this win rate.
const JOINER_MIN: float = 0.40
## A joined fight is never easier than the solo one at the same seeds (a small slack: the joiner's
## draws shift the later random stream, so a cell can move a little either way).
const JOINER_SLACK: float = 0.07

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

## Runs the joiner cells: {type@level+0: {win_rate (joined), base (solo), median_s, n}}.
static func measure_joiners(tune: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for cell: Array in JOINER_CELLS:
		var t: String = str(cell[0])
		var lv: int = int(cell[1])
		var school: String = BalanceCoverage.neutral_school(t)
		var solo: Dictionary = _cell(t, lv, lv, JOINER_FIGHTS, school, tune)
		var joined: Dictionary = _cell(t, lv, lv, JOINER_FIGHTS, school, tune,
			{"joiner": {"enemy_type": t, "enemy_level": lv, "at_seconds": JOINER_AT}})
		out[BalanceBands.key(t, lv, 0)] = {"win_rate": joined["win_rate"], "base": solo["win_rate"],
			"median_s": joined["median_s"], "n": joined["n"]}
	return out

## Failures of the joiner measurement (empty = pass).
static func check_joiners(measured: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	for k: String in measured:
		var m: Dictionary = measured[k]
		var wr: float = float(m["win_rate"])
		var base: float = float(m["base"])
		if wr < JOINER_MIN - 0.001:
			fails.append("joiners %s: joined win rate %.0f%% < %.0f%%" % [k, wr * 100.0, JOINER_MIN * 100.0])
		if wr > base + JOINER_SLACK + 0.001:
			fails.append("joiners %s: joined %.0f%% is easier than solo %.0f%%" % [k, wr * 100.0, base * 100.0])
	return fails

## Runs the condition cells: {"condition/<label>/<type>@<level>": cell, "school/<school>/<env>/<type>@<level>": cell}.
## Each cell has its win rate (`win_rate`), the bare rate at the same seeds (`base`), and `median_s`.
static func measure_conditions(tune: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for c: Array in CONDITION_CELLS:
		var t: String = str(c[0])
		var pl: int = int(c[1])
		var el: int = int(c[2])
		var base: Dictionary = _cell(t, pl, el, CONDITION_FIGHTS, "", tune)
		for cond: Array in CONDITIONS:
			var r: Dictionary = _cell(t, pl, el, CONDITION_FIGHTS, "", tune, cond[1] as Dictionary)
			out["condition/%s/%s@%d" % [str(cond[0]), t, el]] = {"kind": "condition", "win_rate": r["win_rate"],
				"median_s": r["median_s"], "base": base["win_rate"], "n": r["n"]}
		for se: Array in SCHOOL_ENVS:
			var school: String = str(se[0])
			var school_base: Dictionary = _cell(t, pl, el, CONDITION_FIGHTS, school, tune, {}, BattleSetup.MATCHED_SWAP)
			var r2: Dictionary = _cell(t, pl, el, CONDITION_FIGHTS, school, tune, se[1] as Dictionary,
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
	for cell: Array in BalanceCoverage.ladder_cells("range"):
		var t: String = str(cell[0])
		var lv: int = int(cell[1])
		out[BalanceBands.key(t, lv, 0)] = _cell(t, lv, lv, CASUAL_FIGHTS, "", tune, {}, BattleSetup.MATCHED_SWAP,
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
	for cell: Array in BalanceCoverage.ladder_cells("range"):
		var t: String = str(cell[0])
		var lv: int = int(cell[1])
		out["range/" + BalanceBands.key(t, lv, 0)] = _cell(t, lv, lv, WOUNDED_FIGHTS, "", tune, wounded)
	for cell: Array in POTION_CELLS:
		var t: String = str(cell[0])
		var pl: int = int(cell[1])
		var key: String = BalanceBands.key(t, pl, 1)
		out["potion/%s/off" % key] = _cell(t, pl, pl + 1, POTION_FIGHTS, "", tune, wounded)
		var kit: Dictionary = {"start_hp_frac": WOUNDED_HP_FRAC, "potions": POTION_KIT.duplicate()}
		out["potion/%s/on" % key] = _cell(t, pl, pl + 1, POTION_FIGHTS, "", tune, kit, BattleSetup.MATCHED_SWAP,
			{"potion_below": POTION_BELOW})
	for cell: Array in CHAIN_CELLS:
		var t: String = str(cell[0])
		var lv: int = int(cell[1])
		var cleared: int = 0
		var won_all: int = 0
		var fights: Array[Dictionary] = []
		for k: int in CHAIN_CHAINS:
			var cfg: Dictionary = BalanceCoverage.cell_cfg(t, lv, lv, 1 + k * CHAIN_FIGHTS, "", tune, wounded)
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

## `BalanceCoverage.run_cell`, shortened.
static func _cell(type: String, player_level: int, enemy_level: int, fights: int, school: String = "",
		tune: Dictionary = {}, extra: Dictionary = {}, swap: int = BattleSetup.MATCHED_SWAP,
		policy: Dictionary = {}) -> Dictionary:
	return BalanceCoverage.run_cell(type, player_level, enemy_level, fights, school, tune, extra, swap, policy)
