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
## Level of a tier-1 floor-1 enemy (rifts unlock at level 15, UnlockLadder feat_spire).
const BASE_LEVEL: int = 14
## GID-187 / TID-783: a tier is half a level. Tiers alternate between a level step and an enemy HP step
## (`HALF_TIER_HP` on the second tier of each level), D3-style. With a whole level (and before, two) per
## tier, the clear rate fell from ~95 % to 5-40 % in one tier: a run is five fights ending in a boss.
const TIERS_PER_LEVEL: int = 2
const HALF_TIER_HP: float = 1.3
## The top tier's enemies are level 60.
const MAX_TIER: int = 1 + (60 - BASE_LEVEL) * TIERS_PER_LEVEL
## GID-187 / TID-783: share of max HP a hero recovers walking to the next floor (a run carries its HP; with
## none, five fights in a row wore any hero down before the guardian).
const FLOOR_HEAL: float = 0.25

## Rewards (TID-599). Runs are repeatable, so repeating them must not level a
## player: rift kills give no XP, a floor pays a few coins, and XP comes only from
## the *first* clear of each (rift, tier) and from one-time rift quests.
const COINS_PER_FLOOR: int = 5

## One portal chunk in PORTAL_RARITY outside the starter region (Chebyshev chunk
## distance ≥ PORTAL_MIN_CHUNK) opens onto its biome's rift (TID-600).
const PORTAL_RARITY: int = 40
const PORTAL_MIN_CHUNK: int = 5

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
## last the run only. id → {name, desc, effect, value}. GID-187 / TID-783: health and armor boons are a
## percent of the hero's max HP (a flat +6 meant nothing once gear grew HP into the hundreds).
const BOONS: Dictionary = {
	"boon_vigor": {"name": "Vigor", "desc": "+15% maximum health for the rest of this run (and heal that much).",
		"effect": "max_hp_pct", "value": 15},
	"boon_bulwark": {"name": "Bulwark", "desc": "Start every fight this run with armor worth 10% of your health.",
		"effect": "armor_pct", "value": 10},
	"boon_edge": {"name": "Keen Edge", "desc": "Your allies enter with +1 attack this run.",
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


## Applies a run's `boons` to the hero's side at fight setup (the game's `BattleModifiers._build_rift_deck`
## and the balance sim): Keen Edge on the deck's Allies now; Vigor and Bulwark as `PlayerState.boon_hp_mult` /
## `start_armor_frac`, which `RealtimeCombat` applies after the level and gear HP growth. `player` is a
## PlayerState (untyped: RiftDefs stays free of battle preloads).
static func apply_boons(player: Object, boons: Array) -> void:
	var edge: int = boon_total(boons, "minion_attack")
	if edge > 0:
		for c: Variant in player.get("draw_deck") as Array:
			var card: Object = c as Object
			if str(card.get("card_class")) == "minion":
				card.set("attack", int(card.get("attack")) + edge)
	player.set("boon_hp_mult", 1.0 + float(boon_total(boons, "max_hp_pct")) / 100.0)
	player.set("start_armor_frac", float(boon_total(boons, "armor_pct")) / 100.0)

## A run's HP fraction carried from a won floor to the next: `frac` + FLOOR_HEAL, at most full.
static func after_floor(frac: float) -> float:
	return clampf(frac + FLOOR_HEAL, 0.0, 1.0)

## A run's HP fraction after Vigor's heal of `pct` percent (TID-783: runs carry HP as a fraction).
static func vigor_heal(frac: float, pct: int) -> float:
	return clampf(frac + float(pct) / 100.0, 0.0, 1.0)

## One-time XP for the first clear of `tier` in any rift.
## TID-783: tiers are a quarter of their old size (half a level, was two), so a level's worth of tiers
## pays what one old tier paid per level.
static func first_clear_xp(tier: int) -> int:
	return 100 + 25 * (maxi(1, tier) - 1) / 4

## Coins for clearing `tier`'s guardian (every time).
static func clear_coins(tier: int) -> int:
	return 5 + 5 * (maxi(1, tier) - 1) / 4

## Card drop tier (CardDropUtil 1..4) for a guardian beaten at `tier`.
static func clear_drop_tier(tier: int) -> int:
	return clampi(1 + (tier + 3) / 12, 1, 4)

static func clear_key(rift_id: String, tier: int) -> String:
	return "%s:%d" % [rift_id, tier]

static func all() -> Array[Dictionary]:
	return RIFTS

static func def(rift_id: String) -> Dictionary:
	for r: Dictionary in RIFTS:
		if str(r["id"]) == rift_id:
			return r
	return {}

## The rift of BiomeDef biome index `biome` ("" if none).
static func rift_for_biome(biome: int) -> String:
	for r: Dictionary in RIFTS:
		if int(r["biome"]) == biome:
			return str(r["id"])
	return ""

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

## Enemy level on `floor` of `tier`: one level per TIERS_PER_LEVEL tiers, every floor the same. GID-187 /
## TID-783: the floors no longer climb within a tier (+1 every two floors and +1 on the guardian made it a
## boss three levels up, a wall even from full health); the guardian is tougher by being a boss.
static func enemy_level(tier: int, _floor: int = 1) -> int:
	return BASE_LEVEL + (maxi(1, tier) - 1) / TIERS_PER_LEVEL

## Enemy HP multiplier of `tier` (TID-783): HALF_TIER_HP on a level's second tier, else 1.
static func hp_mult(tier: int) -> float:
	return HALF_TIER_HP if (maxi(1, tier) - 1) % TIERS_PER_LEVEL == 1 else 1.0

## Highest tier a player may start in a rift whose best cleared tier is `best`.
static func max_start_tier(best: int) -> int:
	return clampi(best + 1, 1, MAX_TIER)

static func clamp_tier(tier: int, best: int) -> int:
	return clampi(tier, 1, max_start_tier(best))

## TID-783 (save v52): the tier a save from before half-level tiers means by `old` (two levels per tier).
static func migrate_tier(old: int) -> int:
	return clampi((maxi(1, old) - 1) * 4 + 1, 1, MAX_TIER)
