## Gear rarity and item level (GID-136 / TID-538).
##
## Every owned equipment item carries one roll — `{"rarity", "ilvl"}` — saved
## per item id in `SaveManager.gear_rolls` (a missing entry is common, item
## level 1, so old saves need no migration). Finding an item you already own
## keeps the better roll ("upgraded"). A roll scales the item's battle value:
## `mult()` = rarity multiplier × (1 + ILVL_STEP per item level above 1), fed to
## `UpgradeDefs.effective_stat(weapon, level, mult)`. Rarities and colours are
## the card ones (`UiUtil.rarity_color`).
extends RefCounted

const _DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const _MagicTypes = preload("res://game_logic/MagicTypes.gd")

const RARITIES: Array[String] = ["common", "rare", "epic", "legendary"]
const RARITY_MULT: Dictionary = {"common": 1.0, "rare": 1.25, "epic": 1.5, "legendary": 2.0}
const ILVL_STEP: float = 0.02
const MAX_ILVL: int = 60
## Rarity weights (common, rare, epic, legendary) by source tier 1..4 —
## chest tier, enemy difficulty tier (bosses 4).
const TIER_WEIGHTS: Array = [[70, 25, 5, 0], [50, 35, 13, 2], [30, 40, 25, 5], [10, 35, 40, 15]]
## Quest turn-in gear is always at least this good (WoW quest blues).
const QUEST_RARITY: String = "rare"
## School affixes (GID-181 / TID-754) sit ON TOP of the stat roll above, never replace it.
## Chance an affix rolls, by source tier 1..4.
const AFFIX_CHANCE: Array = [0.05, 0.12, 0.2, 0.3]
## Kinds and their weights: school_dmg, school_resist, convert. Convert (the weapon's
## auto-attack and Strike hit as that school) only rolls on a weapon.
const AFFIX_KINDS: Array[String] = ["school_dmg", "school_resist", "convert"]
const AFFIX_KIND_WEIGHTS: Array = [50, 35, 15]


static func default_roll() -> Dictionary:
	return {"rarity": "common", "ilvl": 1}


## A validated roll from saved or untrusted data (bad fields fall back to the default).
## A missing or malformed `affix` is dropped, so old saves read as "no affix".
static func normalize(v: Variant) -> Dictionary:
	var d: Dictionary = v if v is Dictionary else {}
	var r: String = str(d.get("rarity", "common"))
	var lv: Variant = d.get("ilvl", 1)
	var ilvl: int = int(lv) if (lv is int or lv is float) else 1
	var out: Dictionary = {"rarity": r if RARITY_MULT.has(r) else "common", "ilvl": clampi(ilvl, 1, MAX_ILVL)}
	var affix: Dictionary = clean_affix(d.get("affix", {}))
	if not affix.is_empty():
		out["affix"] = affix
	return out


## A school affix that is well formed (known kind and school, convert never physical), or {}.
static func clean_affix(v: Variant) -> Dictionary:
	if not (v is Dictionary):
		return {}
	var d: Dictionary = v
	var kind: String = str(d.get("kind", ""))
	var school: String = str(d.get("school", ""))
	if not AFFIX_KINDS.has(kind) or not _DamageSchools.is_school(school):
		return {}
	if kind == "convert" and school == _DamageSchools.PHYSICAL:
		return {}
	var pv: Variant = d.get("pct", 0.0)
	var pct: float = clampf(float(pv), 0.0, 1.0) if (pv is int or pv is float) else 0.0
	return {"kind": kind, "school": school, "pct": pct}


## A fresh drop from a source of `tier` (1..4) at `level` (enemy / zone level). `weapon`
## lets a convert affix roll. Rarity is drawn first, so the stat roll is unchanged by affixes.
static func roll(tier: int, level: int, rng: RandomNumberGenerator, weapon: bool = false) -> Dictionary:
	var t: int = clampi(tier, 1, 4)
	var weights: Array = TIER_WEIGHTS[t - 1]
	var total: int = 0
	for w: Variant in weights:
		total += int(w)
	var pick: int = rng.randi_range(0, total - 1)
	var rarity: String = "common"
	for i: int in weights.size():
		pick -= int(weights[i])
		if pick < 0:
			rarity = RARITIES[i]
			break
	var out: Dictionary = {"rarity": rarity, "ilvl": clampi(level, 1, MAX_ILVL)}
	if rng.randf() < float(AFFIX_CHANCE[t - 1]):
		out["affix"] = _roll_affix(t, weapon, rng)
	return out


## One school affix for a tier-`t` drop. Convert is weighted out unless `weapon`.
static func _roll_affix(t: int, weapon: bool, rng: RandomNumberGenerator) -> Dictionary:
	var weights: Array = AFFIX_KIND_WEIGHTS.duplicate()
	if not weapon:
		weights[2] = 0
	var total: int = 0
	for w: Variant in weights:
		total += int(w)
	var pick: int = rng.randi_range(0, total - 1)
	var kind: String = AFFIX_KINDS[0]
	for i: int in weights.size():
		pick -= int(weights[i])
		if pick < 0:
			kind = AFFIX_KINDS[i]
			break
	var schools: Array[String] = []
	if kind == "convert":
		schools.assign(_MagicTypes.all_types())
	else:
		schools.assign(_DamageSchools.all_schools())
	var school: String = schools[rng.randi_range(0, schools.size() - 1)]
	var pct: float = 0.0
	match kind:
		"school_dmg":
			pct = snappedf(0.05 + 0.05 * float(t), 0.01)
		"school_resist":
			pct = snappedf(0.03 + 0.03 * float(t), 0.01)
	return {"kind": kind, "school": school, "pct": pct}


## "+15% Dark damage", "+9% Light resist" or "Strikes as Dark"; "" without an affix.
static func affix_label(r: Dictionary) -> String:
	var affix: Dictionary = normalize(r).get("affix", {})
	if affix.is_empty():
		return ""
	var school: String = str(affix["school"]).capitalize()
	match str(affix["kind"]):
		"school_dmg":
			return "+%d%% %s damage" % [roundi(float(affix["pct"]) * 100.0), school]
		"school_resist":
			return "+%d%% %s resist" % [roundi(float(affix["pct"]) * 100.0), school]
	return "Strikes as %s" % school


static func mult(r: Dictionary) -> float:
	var n: Dictionary = normalize(r)
	return float(RARITY_MULT[n["rarity"]]) * (1.0 + ILVL_STEP * float(int(n["ilvl"]) - 1))


static func better(a: Dictionary, b: Dictionary) -> bool:
	return mult(a) > mult(b) + 0.0001


## "Rare · ilvl 7" — shown under the item name.
static func label(r: Dictionary) -> String:
	var n: Dictionary = normalize(r)
	return "%s · ilvl %d" % [str(n["rarity"]).capitalize(), int(n["ilvl"])]
