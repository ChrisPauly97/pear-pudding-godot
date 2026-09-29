## RiftDefs — the Spire as D3-style rifts (GID-142 / TID-597).
##
## One rift per biome, each with its own tier ladder. A run is FLOORS_PER_TIER
## floors, no timer; the last floor holds the rift's guardian. Beating the
## guardian clears the tier and unlocks the next one (a player may start any
## tier up to their best + 1). Enemies come from the rift's biome pool and scale
## with tier through their level.
##
## Pure static data, no autoloads.
extends RefCounted

const FLOORS_PER_TIER: int = 5
const MAX_TIER: int = 60
## Level of a tier-1 floor-1 enemy (rifts unlock at level 15, UnlockLadder feat_spire).
const BASE_LEVEL: int = 14
## Enemy levels added per tier.
const LEVELS_PER_TIER: int = 2

## Rewards (TID-599). Runs are repeatable, so repeating them must not level a
## player: rift kills give no XP, a floor pays a few coins, and XP comes only from
## the *first* clear of each (rift, tier) and from one-time rift quests.
const COINS_PER_FLOOR: int = 5
const CLEAR_COINS_PER_TIER: int = 20

## The legacy single Spire becomes the Grasslands rift (save migration v45).
const DEFAULT_RIFT: String = "grasslands"

## {id, name, biome (BiomeDef index), pool (enemy types, from BiomeDef.ENEMY_POOLS), guardian}
const RIFTS: Array[Dictionary] = [
	{"id": "grasslands", "name": "Grasslands Rift", "biome": 0,
		"pool": ["undead_basic", "undead_horde", "wraith"], "guardian": "undead_elite"},
	{"id": "forest", "name": "Forest Rift", "biome": 1,
		"pool": ["forest_shade", "ghoul_pack", "undead_basic"], "guardian": "undead_elite"},
	{"id": "desert", "name": "Desert Rift", "biome": 2,
		"pool": ["sand_stalker", "undead_horde"], "guardian": "roaming_terror"},
	{"id": "scorched", "name": "Scorched Rift", "biome": 3,
		"pool": ["scorched_revenant", "undead_elite"], "guardian": "roaming_terror"},
	{"id": "mountains", "name": "Mountain Rift", "biome": 4,
		"pool": ["mountain_troll"], "guardian": "stone_golem"},
]


## Buff boons offered between floors (TID-598) beside temporary card picks. They
## last the run only. id → {name, desc, effect, value}.
const BOONS: Dictionary = {
	"boon_vigor": {"name": "Vigor", "desc": "+6 maximum health for the rest of this run (and heal 6).",
		"effect": "max_hp", "value": 6},
	"boon_bulwark": {"name": "Bulwark", "desc": "Start every fight this run with 4 armor.",
		"effect": "armor", "value": 4},
	"boon_edge": {"name": "Keen Edge", "desc": "Your minions enter with +1 attack this run.",
		"effect": "minion_attack", "value": 1},
}

static func is_boon(id: String) -> bool:
	return BOONS.has(id)

## Total value of every boon of `effect` in `boons` (a run's picked boon ids).
static func boon_total(boons: Array, effect: String) -> int:
	var total: int = 0
	for b: Variant in boons:
		var d: Dictionary = BOONS.get(str(b), {})
		if str(d.get("effect", "")) == effect:
			total += int(d.get("value", 0))
	return total


## One-time XP for the first clear of `tier` in any rift.
static func first_clear_xp(tier: int) -> int:
	return 300 + 100 * maxi(1, tier)

## Card drop tier (CardDropUtil 1..4) for a guardian beaten at `tier`.
static func clear_drop_tier(tier: int) -> int:
	return clampi(1 + tier / 3, 1, 4)

static func clear_key(rift_id: String, tier: int) -> String:
	return "%s:%d" % [rift_id, tier]

static func all() -> Array[Dictionary]:
	return RIFTS

static func def(rift_id: String) -> Dictionary:
	for r: Dictionary in RIFTS:
		if str(r["id"]) == rift_id:
			return r
	return {}

static func rift_name(rift_id: String) -> String:
	return str(def(rift_id).get("name", "Rift"))

static func is_guardian_floor(floor: int) -> bool:
	return floor >= FLOORS_PER_TIER

## Enemy type on `floor` of `rift_id` (guardian on the last floor, else cycling the pool).
static func enemy_type(rift_id: String, floor: int) -> String:
	var r: Dictionary = def(rift_id)
	if r.is_empty():
		r = def(DEFAULT_RIFT)
	if is_guardian_floor(floor):
		return str(r["guardian"])
	var pool: Array = r["pool"]
	return str(pool[(floor - 1) % pool.size()])

## Enemy level on `floor` of `tier`: +LEVELS_PER_TIER per tier, +1 on the guardian.
static func enemy_level(tier: int, floor: int) -> int:
	var lvl: int = BASE_LEVEL + (maxi(1, tier) - 1) * LEVELS_PER_TIER + (floor - 1) / 2
	return lvl + (1 if is_guardian_floor(floor) else 0)

## Highest tier a player may start in a rift whose best cleared tier is `best`.
static func max_start_tier(best: int) -> int:
	return clampi(best + 1, 1, MAX_TIER)

static func clamp_tier(tier: int, best: int) -> int:
	return clampi(tier, 1, max_start_tier(best))
