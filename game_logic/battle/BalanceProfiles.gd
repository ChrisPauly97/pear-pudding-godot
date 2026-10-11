## Balance player profiles (GID-187 / TID-778): who the balance bands fight as. Every earlier band
## measured a bare hero (starter deck, no gear, no skills). A profile is the player a level
## implies: the ladder rows learned by then, a deck of their magic type, the gear curve's expected
## loadout (`GearDrops.expected_loadout`) and a skill build spending that level's points.
##
## - `typical`: average expected — on-curve gear, every skill point spent.
## - `modest`: the floor — gear one band behind (the loadout of level − 10), half the skill points.
##
## `cfg(level, magic_type, kind)` returns a `BattleSetup.build` config fragment; merge in the
## enemy keys and a seed. Pure: static data only.
extends RefCounted

const BalanceBands = preload("res://game_logic/battle/BalanceBands.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const XpCurve = preload("res://game_logic/progression/XpCurve.gd")
const MagicTypes = preload("res://game_logic/MagicTypes.gd")
const GearDrops = preload("res://game_logic/items/GearDrops.gd")
const SkillRegistry = preload("res://autoloads/SkillRegistry.gd")
const SkillData = preload("res://data/SkillData.gd")
const BalanceFight = preload("res://game_logic/battle/BalanceFight.gd")

const KINDS: Array[String] = ["typical", "modest", "bare"]
## The modest profile's gear is the expected loadout of this many levels lower (one band).
const MODEST_GEAR_LAG: int = 10
## `profiles` coverage cells: [enemy type, level] from Chapter 1 to the level cap, one neutral-ish
## type per stretch. Every magic type and kind fights each at +0 and +1.
const CELLS: Array = [
	["undead_basic", 2], ["wolf_pack", 5], ["martarquas_scout", 9], ["duelist_adept", 14], ["rift_echo", 20],
	["duelist_champion", 26], ["rival_isfig_3", 35], ["undead_elite", 45], ["undead_elite", 59],
]
const FIGHTS: int = 8
## Progression never makes a player worse: typical ≥ modest ≥ bare, minus this slack, per cell (mean
## over the magic types, one level up).
const ORDER_SLACK: float = 0.15

## A `BattleSetup.build` cfg fragment for a level-`level` player of `magic_type`. `kind` "bare" is
## the old bare hero (default deck, no gear, no skills), kept as the floor check.
static func cfg(level: int, magic_type: String, kind: String = "typical") -> Dictionary:
	var learned: Array = BalanceBands.ladder_learned(level)
	var out: Dictionary = {"player_level": level, "learned": learned}
	if kind == "bare":
		return out
	var points: int = XpCurve.skill_points_at(level)
	var gear_level: int = level
	if kind == "modest":
		points /= 2
		gear_level = maxi(1, level - MODEST_GEAR_LAG)
	var skills: Array[String] = skill_build(magic_type, points)
	out["skills"] = skills
	out["deck"] = deck(magic_type, learned, skills)
	var loadout: Dictionary = GearDrops.expected_loadout(gear_level)
	var gear: Array = []
	for slot: String in loadout:
		var id: String = str(loadout[slot])
		if slot == "weapon":
			out["weapon"] = id  # swing speed + stats (build adds it to the gear list)
		elif slot == "offhand":
			out["offhand"] = id
		else:
			gear.append({"id": id})
	out["gear"] = gear
	return out

## The skill nodes a player of `magic_type` with `points` takes: their first branch row by row
## (prerequisites first), then the second; nodes that cost the other magic's currency are skipped.
static func skill_build(magic_type: String, points: int) -> Array[String]:
	var out: Array[String] = []
	if points <= 0 or not MagicTypes.is_valid_type(magic_type):
		return out
	for branch: String in MagicTypes.branches_for(magic_type):
		var nodes: Array[SkillData] = []
		for id: String in SkillRegistry.get_by_branch(branch):
			var sk: SkillData = SkillRegistry.get_skill(id)
			if sk != null and sk.alt_cost <= 0:
				nodes.append(sk)
		nodes.sort_custom(func(a: SkillData, b: SkillData) -> bool:
			if a.tree_row != b.tree_row:
				return a.tree_row < b.tree_row
			if a.tree_col != b.tree_col:
				return a.tree_col < b.tree_col
			return a.id < b.id)
		var progress: bool = true
		while progress and out.size() < points:
			progress = false
			for sk: SkillData in nodes:
				if out.size() >= points:
					break
				if out.has(sk.id):
					continue
				var ready: bool = true
				for pre: String in sk.prerequisites:
					if not out.has(pre):
						ready = false
				if ready:
					out.append(sk.id)
					progress = true
	return out

## The profile's deck: the magic type's matched deck plus the technique cards its skill nodes
## grant, while the deck still has technique slots (`UnlockLadder.technique_slots`).
static func deck(magic_type: String, learned: Array, skills: Array[String]) -> Array[String]:
	var out: Array[String] = BattleSetup.school_matched_deck(magic_type, learned)
	var techs: int = 0
	for id: String in out:
		if TechniqueDefs.is_technique(id):
			techs += 1
	var slots: int = UnlockLadder.technique_slots(learned)
	for sid: String in skills:
		var sk: SkillData = SkillRegistry.get_skill(sid)
		if sk == null or sk.grants_card == "" or out.has(sk.grants_card):
			continue
		if TechniqueDefs.is_technique(sk.grants_card) and techs >= slots:
			continue
		out.append(sk.grants_card)
		if TechniqueDefs.is_technique(sk.grants_card):
			techs += 1
	return out

## Runs the `profiles` section: {"<type>@<level>+<offset>/<kind>": {win_rate, n}} (mean over magic types).
static func measure(tune: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for cell: Array in CELLS:
		var t: String = str(cell[0])
		var lv: int = int(cell[1])
		for kind: String in KINDS:
			for off: int in [0, 1]:
				var wins: int = 0
				var n: int = 0
				for mt: String in MagicTypes.all_types():
					for f: int in FIGHTS:
						var c: Dictionary = cfg(lv, mt, kind)
						c.merge({"seed": 1 + f, "enemy_type": t, "enemy_level": lv + off}, true)
						if not tune.is_empty():
							c["tuning"] = tune
						if str(BalanceFight.run(c)["result"]) == "win":
							wins += 1
						n += 1
				out["%s@%d+%d/%s" % [t, lv, off, kind]] = {"win_rate": float(wins) / float(maxi(1, n)), "n": n}
	return out

## Failures of a `profiles` measurement (empty = pass): progression order only for now; the level
## targets on the typical profile are TID-787's retune.
static func check(measured: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	for cell: Array in CELLS:
		var key: String = "%s@%d+1" % [str(cell[0]), int(cell[1])]
		var rates: Dictionary = {}
		for kind: String in KINDS:
			rates[kind] = float((measured.get(key + "/" + kind, {"win_rate": 0.0}) as Dictionary)["win_rate"])
		if float(rates["typical"]) < float(rates["modest"]) - ORDER_SLACK - 0.001:
			fails.append("profiles %s: typical %.0f%% below modest %.0f%%" % [key, 100.0 * float(rates["typical"]),
				100.0 * float(rates["modest"])])
		if float(rates["modest"]) < float(rates["bare"]) - ORDER_SLACK - 0.001:
			fails.append("profiles %s: modest %.0f%% below bare %.0f%%" % [key, 100.0 * float(rates["modest"]),
				100.0 * float(rates["bare"])])
	return fails
