## Enemy material drops (GID-182 / TID-761).
##
## Beasts drop game meat and rough hide; magical foes drop arcane cores. The
## roll is pure: it takes the RNG, so a fixed seed gives fixed loot. EnemyRegistry
## has no family field, so the family of each enemy type is listed here; an enemy
## not listed (humanoids, undead, bosses, rivals, training dummies) drops nothing.
## Pure static data and math, safe on any thread.
extends RefCounted

const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const HeroVitality = preload("res://game_logic/HeroVitality.gd")

const FAMILY_BEAST: String = "beast"
const FAMILY_MAGICAL: String = "magical"

## Enemy type id → family. Ids must exist in EnemyRegistry (tests/unit/test_material_drops.gd).
const FAMILY_BY_ENEMY: Dictionary = {
	"wolf_pack": FAMILY_BEAST,
	"imbued_stag": FAMILY_BEAST,
	"sand_stalker": FAMILY_BEAST,
	"scarab_swarm": FAMILY_BEAST,
	"cactus_worm": FAMILY_BEAST,
	"mountain_troll": FAMILY_BEAST,
	"frost_wendigo": FAMILY_BEAST,
	"forest_shade": FAMILY_MAGICAL,
	"bog_hag": FAMILY_MAGICAL,
	"spectre_wisp": FAMILY_MAGICAL,
	"spectre_haunt": FAMILY_MAGICAL,
	"spectre_dread": FAMILY_MAGICAL,
	"wraith": FAMILY_MAGICAL,
	"rift_echo": FAMILY_MAGICAL,
	"scorched_revenant": FAMILY_MAGICAL,
}

## Family → drop entries {material, chance, min, max}: `chance` at tier 1, then
## `min`..`max` pieces when the drop lands.
const TABLES: Dictionary = {
	FAMILY_BEAST: [
		{"material": "game_meat", "chance": 0.8, "min": 1, "max": 2},
		{"material": "rough_hide", "chance": 0.45, "min": 1, "max": 1},
	],
	FAMILY_MAGICAL: [
		{"material": "arcane_core", "chance": 0.6, "min": 1, "max": 1},
	],
}

## Difficulty tiers (1..4, as `GearRolls.TIER_WEIGHTS`). Each tier above 1 adds
## CHANCE_PER_TIER to a drop's chance, and every second tier adds one piece.
const TIER_MIN: int = 1
const TIER_MAX: int = 4
const CHANCE_PER_TIER: float = 0.1


## The drop family of an enemy type, or "" when it drops no materials.
static func family_of(enemy_type: String) -> String:
	return str(FAMILY_BY_ENEMY.get(enemy_type, ""))


## Rolls the materials one defeated enemy drops: {material_id: count}, empty
## when nothing drops. `allowed` is false for consequence-free fights (practice,
## friendly duels, puzzles), which never drop anything.
static func roll(enemy_type: String, tier: int, rng: RandomNumberGenerator, allowed: bool = true) -> Dictionary:
	var out: Dictionary = {}
	var family: String = family_of(enemy_type)
	if not allowed or family == "":
		return out
	var t: int = clampi(tier, TIER_MIN, TIER_MAX)
	var entries: Array = TABLES[family]
	for e: Variant in entries:
		var entry: Dictionary = e
		var chance: float = minf(1.0, float(entry["chance"]) + CHANCE_PER_TIER * float(t - TIER_MIN))
		if rng.randf() >= chance:
			continue
		var n: int = rng.randi_range(int(entry["min"]), int(entry["max"])) + floori(float(t - TIER_MIN) / 2.0)
		out[str(entry["material"])] = n
	return out


## Rolls one defeated enemy into `bag` ({material: count}). Consequence-free
## fights (practice, friendly duels) drop nothing, as `HeroVitality.carries_over`.
static func roll_into(bag: Dictionary, enemy_data: Dictionary, enemy_type: String, tier: int,
		rng: RandomNumberGenerator) -> void:
	var duel: bool = str(enemy_data.get("duel_npc_id", "")) != ""
	var allowed: bool = HeroVitality.carries_over(enemy_data, false, false, duel)
	var drops: Dictionary = roll(enemy_type, tier, rng, allowed)
	for id: String in drops:
		bag[id] = int(bag.get(id, 0)) + int(drops[id])


## Human-readable summary of a drop, e.g. "+2 Game Meat, +1 Rough Hide" ("" when empty).
static func describe(drops: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: String in drops:
		var display: String = str((ProfessionDefs.MATERIALS.get(id, {}) as Dictionary).get("display_name", id))
		parts.append("+%d %s" % [int(drops[id]), display])
	return ", ".join(parts)
