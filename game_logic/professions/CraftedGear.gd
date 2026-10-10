## Crafted gear rolls (GID-182 / TID-765).
##
## A crafted item's roll comes from the crafter's skill, not the enemy's tier:
## skill → source tier (`SKILL_TIERS`), then that tier's GearRolls weights with
## legendary folded into epic, so crafting tops out at epic. Legendary stays
## drop-only. The item level is the recipe's level. Granting and the better-roll
## rule are GearRolls / SaveGear, shared with drops.
##
## Pure static data and math, no autoloads.
extends RefCounted

const _GearRolls = preload("res://game_logic/items/GearRolls.gd")

## Crafting skill (min level) → source tier 1..4, ascending.
const SKILL_TIERS: Array = [[1, 1], [15, 2], [30, 3], [45, 4]]


static func tier_for_skill(skill: int) -> int:
	var tier: int = 1
	for row: Array in SKILL_TIERS:
		if skill >= int(row[0]):
			tier = int(row[1])
	return tier


## Rarity weights (common, rare, epic) for a crafter at `skill`: the tier's
## GearRolls weights with the legendary weight added to epic (the cap).
static func weights_for_skill(skill: int) -> Array[int]:
	var src: Array = _GearRolls.TIER_WEIGHTS[tier_for_skill(skill) - 1]
	var out: Array[int] = [int(src[0]), int(src[1]), int(src[2]) + int(src[3])]
	return out


## A crafted roll `{rarity, ilvl}` at crafter `skill`; never legendary.
static func roll(skill: int, item_level: int, rng: RandomNumberGenerator) -> Dictionary:
	var weights: Array[int] = weights_for_skill(skill)
	var total: int = 0
	for w: int in weights:
		total += w
	var pick: int = rng.randi_range(0, total - 1)
	var rarity: String = _GearRolls.RARITIES[0]
	for i: int in weights.size():
		pick -= weights[i]
		if pick < 0:
			rarity = _GearRolls.RARITIES[i]
			break
	return {"rarity": rarity, "ilvl": clampi(item_level, 1, _GearRolls.MAX_ILVL)}
