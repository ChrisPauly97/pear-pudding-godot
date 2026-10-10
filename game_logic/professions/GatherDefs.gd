## Gathering nodes (GID-182 / TID-760): herb patches, ore veins and fishing spots.
##
## Pure static data and math, no autoloads: `plan_chunk` runs inside chunk
## generation on the worker threads, so it must stay deterministic per chunk seed
## (co-op joiners regenerate the same world). Material ids come from
## `ProfessionDefs.MATERIALS`; nothing here re-lists them as names.
extends RefCounted

const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")

const HERB: String = "herb"
const ORE: String = "ore"
const FISH: String = "fish"

## Node kind → placeholder look, harvest XP, respawn delay (real seconds).
const KINDS: Dictionary = {
	HERB: {"display_name": "Herb Patch", "color": Color(0.45, 0.8, 0.35), "xp": 2, "respawn_seconds": 240.0},
	ORE: {"display_name": "Ore Vein", "color": Color(0.62, 0.56, 0.5), "xp": 3, "respawn_seconds": 360.0},
	FISH: {"display_name": "Fishing Spot", "color": Color(0.35, 0.6, 0.95), "xp": 2, "respawn_seconds": 180.0},
}

## Per-chunk chance that each kind is planted (rolled independently, only where
## the biome / water rules allow it).
const CHANCE: Dictionary = {HERB: 0.35, ORE: 0.3, FISH: 0.4}

## Biome index → kind → materials a node of that kind yields there. The first
## entry is the common yield; the rest are picked uniformly. A biome missing a
## kind never plants that kind. Fishing needs water beside the chunk (see plan_chunk).
const YIELDS: Array = [
	# GRASSLANDS
	{HERB: ["silverleaf", "wild_grain", "ironbark"], FISH: ["river_trout"]},
	# FOREST
	{HERB: ["duskbloom", "silverleaf", "starsage"], FISH: ["river_trout"]},
	# DESERT
	{HERB: ["wild_grain", "emberwort"]},
	# SCORCHED
	{ORE: ["copper_ore"]},
	# MOUNTAINS
	{ORE: ["copper_ore", "iron_ore"]},
]

## Herbs that feed Cooking rather than Alchemy. Any other material takes its
## profession from its source (herb → Alchemy, ore → Crafting, fish → Cooking).
const COOKING_HERBS: Array[String] = ["wild_grain"]

const _SALT: int = 41  # keeps this rng stream apart from the chunk's other spawns


## Nodes for one chunk: an Array of {kind, material, pick}. `pick` is a raw
## random int; the caller maps it onto one of its grass tiles (`pick % size`).
## Deterministic in (chunk_seed, biome, water_near).
static func plan_chunk(chunk_seed: int, biome: int, water_near: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if biome < 0 or biome >= YIELDS.size():
		return out
	var yields: Dictionary = YIELDS[biome]
	var rng := RandomNumberGenerator.new()
	rng.seed = (chunk_seed + _SALT) & 0x7FFFFFFF
	for kind: String in [HERB, ORE, FISH]:
		if not yields.has(kind):
			rng.randf()  # keep the stream shape stable across biomes
			continue
		if kind == FISH and not water_near:
			rng.randf()
			continue
		var roll: float = rng.randf()
		var pick: int = rng.randi()
		var mats: Array = yields[kind]
		var mat: String = str(mats[rng.randi_range(0, mats.size() - 1)])
		if roll < float(CHANCE[kind]):
			out.append({"kind": kind, "material": mat, "pick": pick})
	return out


static func _kind(kind: String) -> Dictionary:
	var d: Dictionary = KINDS.get(kind, {})
	return d


static func display_name(kind: String) -> String:
	return str(_kind(kind).get("display_name", kind))


static func color(kind: String) -> Color:
	var c: Variant = _kind(kind).get("color", Color.WHITE)
	return c as Color


static func xp(kind: String) -> int:
	return int(_kind(kind).get("xp", 0))


static func respawn_seconds(kind: String) -> float:
	return float(_kind(kind).get("respawn_seconds", 0.0))


## Profession that levels when this material is gathered ("" if unknown).
static func profession_for(material: String) -> String:
	if COOKING_HERBS.has(material):
		return ProfessionDefs.COOKING
	var mat: Dictionary = ProfessionDefs.MATERIALS.get(material, {})
	match str(mat.get("source", "")):
		"herb":
			return ProfessionDefs.ALCHEMY
		"ore":
			return ProfessionDefs.CRAFTING
		"fish":
			return ProfessionDefs.COOKING
	return ""
