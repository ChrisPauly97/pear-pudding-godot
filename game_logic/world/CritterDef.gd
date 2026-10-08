extends RefCounted
## Ambient wildlife (critters): per-species movement tuning and which species
## live in each biome. Pure data + helpers; `scenes/world/modules/Critters.gd`
## spawns and drives them. Critters are scenery: no health, no battles, no
## save state. Sprites come from scripts/gen_creature_sprites.py.

const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")

const _MOUSE_0 := preload("res://assets/textures/critters/mouse_0.png")
const _MOUSE_1 := preload("res://assets/textures/critters/mouse_1.png")
const _RAT_0 := preload("res://assets/textures/critters/rat_0.png")
const _RAT_1 := preload("res://assets/textures/critters/rat_1.png")
const _BUTTERFLY_0 := preload("res://assets/textures/critters/butterfly_0.png")
const _BUTTERFLY_1 := preload("res://assets/textures/critters/butterfly_1.png")
const _BEE_0 := preload("res://assets/textures/critters/bee_0.png")
const _BEE_1 := preload("res://assets/textures/critters/bee_1.png")
const _SCORCHED_LARVA_0 := preload("res://assets/textures/critters/scorched_larva_0.png")
const _SCORCHED_LARVA_1 := preload("res://assets/textures/critters/scorched_larva_1.png")
const _FAWN_0 := preload("res://assets/textures/critters/fawn_0.png")
const _FAWN_1 := preload("res://assets/textures/critters/fawn_1.png")
const _SNOW_RABBIT_0 := preload("res://assets/textures/critters/snow_rabbit_0.png")
const _SNOW_RABBIT_1 := preload("res://assets/textures/critters/snow_rabbit_1.png")
const _BLACKENED_ADDER_0 := preload("res://assets/textures/critters/blackened_adder_0.png")
const _BLACKENED_ADDER_1 := preload("res://assets/textures/critters/blackened_adder_1.png")
const _PIGEON_0 := preload("res://assets/textures/critters/pigeon_0.png")
const _PIGEON_1 := preload("res://assets/textures/critters/pigeon_1.png")
const _CHICKEN_0 := preload("res://assets/textures/critters/chicken_0.png")
const _CHICKEN_1 := preload("res://assets/textures/critters/chicken_1.png")
const _FROG_0 := preload("res://assets/textures/critters/frog_0.png")
const _FROG_1 := preload("res://assets/textures/critters/frog_1.png")
const _WISP_0 := preload("res://assets/textures/critters/wisp_0.png")
const _WISP_1 := preload("res://assets/textures/critters/wisp_1.png")
const _CAT_0 := preload("res://assets/textures/critters/cat_0.png")
const _CAT_1 := preload("res://assets/textures/critters/cat_1.png")

const FRAMES: Dictionary = {
	"mouse": [_MOUSE_0, _MOUSE_1],
	"rat": [_RAT_0, _RAT_1],
	"butterfly": [_BUTTERFLY_0, _BUTTERFLY_1],
	"bee": [_BEE_0, _BEE_1],
	"scorched_larva": [_SCORCHED_LARVA_0, _SCORCHED_LARVA_1],
	"fawn": [_FAWN_0, _FAWN_1],
	"snow_rabbit": [_SNOW_RABBIT_0, _SNOW_RABBIT_1],
	"blackened_adder": [_BLACKENED_ADDER_0, _BLACKENED_ADDER_1],
	"pigeon": [_PIGEON_0, _PIGEON_1],
	"chicken": [_CHICKEN_0, _CHICKEN_1],
	"cat": [_CAT_0, _CAT_1],
	"frog": [_FROG_0, _FROG_1],
	"wisp": [_WISP_0, _WISP_1],
}

## speed (units/s), wander radius around home, pause range (s) between moves,
## `fly` hovers above the ground, `hop` arcs while moving, `day_only` hides at night,
## optional `night_only` hides by day, `glow` (a modulate above 1) makes it shine, and
## `scale` multiplies the texel size (tiny flyers read as dots at 1x).
const SPECIES: Dictionary = {
	"mouse": {"speed": 2.2, "radius": 3.0, "pause": Vector2(0.6, 2.5), "fly": false, "hop": false, "day_only": false},
	"rat": {"speed": 2.6, "radius": 4.0, "pause": Vector2(0.5, 2.0), "fly": false, "hop": false, "day_only": false},
	"butterfly": {"speed": 1.3, "radius": 3.5, "pause": Vector2(0.0, 0.6), "fly": true, "hop": false,
			"day_only": true, "scale": 2.0},
	"bee": {"speed": 2.0, "radius": 2.5, "pause": Vector2(0.0, 0.4), "fly": true, "hop": false, "day_only": true,
			"scale": 2.0},
	"scorched_larva": {"speed": 0.45, "radius": 1.5, "pause": Vector2(1.5, 4.0), "fly": false, "hop": false,
			"day_only": false},
	"fawn": {"speed": 1.6, "radius": 5.0, "pause": Vector2(2.0, 5.0), "fly": false, "hop": false, "day_only": true},
	"snow_rabbit": {"speed": 3.0, "radius": 4.0, "pause": Vector2(1.0, 3.5), "fly": false, "hop": true,
			"day_only": false},
	"blackened_adder": {"speed": 0.9, "radius": 3.0, "pause": Vector2(1.5, 4.5), "fly": false, "hop": false,
			"day_only": false},
	"pigeon": {"speed": 1.8, "radius": 3.0, "pause": Vector2(0.4, 2.0), "fly": false, "hop": false, "day_only": true},
	"chicken": {"speed": 1.2, "radius": 2.5, "pause": Vector2(0.8, 2.5), "fly": false, "hop": false,
			"day_only": true},
	"cat": {"speed": 1.0, "radius": 4.0, "pause": Vector2(2.0, 6.0), "fly": false, "hop": false, "day_only": false},
	# GID-174 bog critters: frogs hop about the peat, will-o'-wisps drift over the pools at night.
	"frog": {"speed": 1.4, "radius": 2.5, "pause": Vector2(1.5, 4.0), "fly": false, "hop": true, "day_only": false},
	"wisp": {"speed": 0.7, "radius": 3.0, "pause": Vector2(0.0, 0.8), "fly": true, "hop": false, "day_only": false,
			"night_only": true, "scale": 1.6, "glow": Color(1.3, 1.8, 1.6)},
}

## Species per biome (repeats weight a species).
const BIOME_CRITTERS: Array = [
	["mouse", "mouse", "rat", "butterfly", "butterfly", "bee", "bee"],  # Grasslands
	["fawn", "butterfly", "rat", "mouse", "bee"],                       # Forest
	["blackened_adder", "mouse"],                                       # Desert
	["scorched_larva", "scorched_larva", "blackened_adder"],            # Scorched
	["snow_rabbit", "snow_rabbit", "mouse"],                            # Mountains
]

## Species in and round a bog (GID-174), whatever its biome.
const BOG_CRITTERS: Array[String] = ["frog", "frog", "wisp", "wisp"]
## The hero counts as in a bog (bog critters spawn) above this bog intensity at their feet.
const BOG_NEAR: float = 0.1

## Species in the stitched towns (GID-156), whatever the biome around them.
const TOWN_CRITTERS: Array[String] = ["pigeon", "pigeon", "pigeon", "chicken", "chicken", "cat", "mouse"]

## Butterflies take one of these wing tints (the sprite's wings are white).
const WING_TINTS: Array[Color] = [
	Color(1.0, 0.62, 0.22), Color(0.55, 0.75, 1.0), Color(1.0, 0.95, 0.45), Color(0.95, 0.6, 0.9),
]

## Flee when the hero comes this close (ground critters only).
const FLEE_DIST: float = 2.5


static func species_for(biome: int, day: bool, roll: int) -> String:
	if biome < 0 or biome >= BIOME_CRITTERS.size():
		return ""
	return _pick(BIOME_CRITTERS[biome] as Array, day, roll)


static func species_for_town(day: bool, roll: int) -> String:
	return _pick(TOWN_CRITTERS, day, roll)


static func species_for_bog(day: bool, roll: int) -> String:
	return _pick(BOG_CRITTERS, day, roll)


## Whether `key` belongs where the hero is: town species in towns, the biome's out of them,
## plus the bog's in a bog.
static func fits(key: String, biome: int, in_town: bool, in_bog: bool = false) -> bool:
	if in_town:
		return TOWN_CRITTERS.has(key)
	if in_bog and BOG_CRITTERS.has(key):
		return true
	return biome >= 0 and biome < BIOME_CRITTERS.size() and (BIOME_CRITTERS[biome] as Array).has(key)


static func _pick(species: Array, day: bool, roll: int) -> String:
	var pool: Array[String] = []
	for k: Variant in species:
		var key: String = str(k)
		if visible_now(key, day):
			pool.append(key)
	if pool.is_empty():
		return ""
	return pool[absi(roll) % pool.size()]


## Whether species `key` is out at this time of day (day_only / night_only).
static func visible_now(key: String, day: bool) -> bool:
	var p: Dictionary = SPECIES.get(key, {})
	return not (bool(p.get("day_only", false)) and not day) and not (bool(p.get("night_only", false)) and day)


static func params(key: String) -> Dictionary:
	return SPECIES.get(key, {}) as Dictionary


## Next wander target: a random point within the species radius of home.
static func wander_target(home: Vector3, key: String, rng: RandomNumberGenerator) -> Vector3:
	var r: float = float(params(key).get("radius", 2.0)) * sqrt(rng.randf())
	var a: float = rng.randf() * TAU
	return Vector3(home.x + cos(a) * r, home.y, home.z + sin(a) * r)


## Point FLEE_DIST * 2 away from the threat, directly away from it.
static func flee_target(pos: Vector3, threat: Vector3) -> Vector3:
	var d := Vector3(pos.x - threat.x, 0.0, pos.z - threat.z)
	if d.length_squared() < 0.0001:
		d = Vector3(1.0, 0.0, 0.0)
	return pos + d.normalized() * FLEE_DIST * 2.0


## Sprites face screen-right; flip when a move heads screen-left. The iso
## camera's screen-right axis is world (+1, 0, -1).
static func faces_left(move: Vector3) -> bool:
	return move.x - move.z < 0.0
