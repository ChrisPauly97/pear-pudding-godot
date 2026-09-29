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

const RARITIES: Array[String] = ["common", "rare", "epic", "legendary"]
const RARITY_MULT: Dictionary = {"common": 1.0, "rare": 1.25, "epic": 1.5, "legendary": 2.0}
const ILVL_STEP: float = 0.02
const MAX_ILVL: int = 60
## Rarity weights (common, rare, epic, legendary) by source tier 1..4 —
## chest tier, enemy difficulty tier (bosses 4).
const TIER_WEIGHTS: Array = [[70, 25, 5, 0], [50, 35, 13, 2], [30, 40, 25, 5], [10, 35, 40, 15]]
## Quest turn-in gear is always at least this good (WoW quest blues).
const QUEST_RARITY: String = "rare"


static func default_roll() -> Dictionary:
	return {"rarity": "common", "ilvl": 1}


## A validated roll from saved or untrusted data (bad fields fall back to the default).
static func normalize(v: Variant) -> Dictionary:
	var d: Dictionary = v if v is Dictionary else {}
	var r: String = str(d.get("rarity", "common"))
	var lv: Variant = d.get("ilvl", 1)
	var ilvl: int = int(lv) if (lv is int or lv is float) else 1
	return {"rarity": r if RARITY_MULT.has(r) else "common", "ilvl": clampi(ilvl, 1, MAX_ILVL)}


## A fresh drop from a source of `tier` (1..4) at `level` (enemy / zone level).
static func roll(tier: int, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var weights: Array = TIER_WEIGHTS[clampi(tier, 1, 4) - 1]
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
	return {"rarity": rarity, "ilvl": clampi(level, 1, MAX_ILVL)}


static func mult(r: Dictionary) -> float:
	var n: Dictionary = normalize(r)
	return float(RARITY_MULT[n["rarity"]]) * (1.0 + ILVL_STEP * float(int(n["ilvl"]) - 1))


static func better(a: Dictionary, b: Dictionary) -> bool:
	return mult(a) > mult(b) + 0.0001


## "Rare · ilvl 7" — shown under the item name.
static func label(r: Dictionary) -> String:
	var n: Dictionary = normalize(r)
	return "%s · ilvl %d" % [str(n["rarity"]).capitalize(), int(n["ilvl"])]
