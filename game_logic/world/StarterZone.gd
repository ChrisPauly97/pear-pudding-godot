## StarterZone — Madrian's outskirts as an authored level 1–9 starter zone
## (GID-141 / TID-591).
##
## Camps are fixed groups of enemies with an authored level, placed in rings
## that step outward from town so the starter quests (TID-592) can send a new
## player a little further each level. Camp enemies are transient: killing one
## never enters `SaveManager.defeated_enemies`; the `StarterCamps` world module
## refills a slot CAMP_RESPAWN_S seconds after it falls, so a "slay three" quest
## can never be stranded. The graveyard holds the Gravedigger's burial mounds.
##
## Tiles are overworld tiles (Madrian local tile − (37, 33), see RealmLayout).
## Pure static data, no autoloads.
extends RefCounted

## Seconds before a fallen camp slot refills.
const CAMP_RESPAWN_S: float = 45.0
## Camps further than this (world units) from the player are not topped up.
const ACTIVE_RANGE: float = 90.0
## Enemy ids of camp members start with this (never saved as defeated).
const ID_PREFIX: String = "camp_"

## {id, name, tile, enemy_type, count, level, tracking}. `tracking` = chases the
## player; the first two rings wait to be attacked, WoW-style passive critters.
const CAMPS: Array[Dictionary] = [
	{"id": "grain_store", "name": "Grain-Store Field", "tile": Vector2i(21, 17), "enemy_type": "undead_basic",
		"count": 3, "level": 1, "tracking": false},
	{"id": "south_field", "name": "South Field", "tile": Vector2i(-7, 21), "enemy_type": "undead_basic",
		"count": 4, "level": 2, "tracking": false},
	{"id": "old_orchard", "name": "The Old Orchard", "tile": Vector2i(47, 19), "enemy_type": "undead_horde",
		"count": 4, "level": 3, "tracking": true},
	{"id": "north_barrow", "name": "North Barrow", "tile": Vector2i(33, -21), "enemy_type": "undead_horde",
		"count": 4, "level": 4, "tracking": true},
	{"id": "hedge_ruins", "name": "Hedge Ruins", "tile": Vector2i(53, -27), "enemy_type": "ghoul_pack",
		"count": 3, "level": 5, "tracking": true},
	{"id": "east_copse", "name": "East Copse", "tile": Vector2i(76, -2), "enemy_type": "ghoul_pack",
		"count": 4, "level": 6, "tracking": true},
	{"id": "west_crossing", "name": "West Crossing", "tile": Vector2i(-55, 4), "enemy_type": "undead_horde",
		"count": 5, "level": 7, "tracking": true},
	{"id": "north_tor", "name": "North Tor", "tile": Vector2i(10, -62), "enemy_type": "ghoul_pack",
		"count": 4, "level": 8, "tracking": true},
	{"id": "south_road", "name": "South Road Wreck", "tile": Vector2i(40, 45), "enemy_type": "ghoul_pack",
		"count": 5, "level": 9, "tracking": true},
]

## The old graveyard west of the south field: the Gravedigger stands here and
## its mounds are the first Skeleton Dig targets.
const GRAVEYARD_TILE := Vector2i(-25, 19)
const GRAVEYARD_MOUNDS: Array[Vector2i] = [Vector2i(-28, 17), Vector2i(-24, 22), Vector2i(-21, 16)]

## Where a camp's member `slot` stands (a small ring around the camp tile).
static func slot_tile(camp: Dictionary, slot: int) -> Vector2i:
	var centre: Vector2i = camp["tile"]
	var n: int = maxi(1, int(camp.get("count", 1)))
	var a: float = TAU * float(slot) / float(n)
	return centre + Vector2i(roundi(cos(a) * 3.0), roundi(sin(a) * 3.0))

static func member_id(camp: Dictionary, slot: int) -> String:
	return "%s%s_%d" % [ID_PREFIX, str(camp["id"]), slot]

static func is_camp_enemy(enemy_id: String) -> bool:
	return enemy_id.begins_with(ID_PREFIX)

static func camp(id: String) -> Dictionary:
	for c: Dictionary in CAMPS:
		if str(c["id"]) == id:
			return c
	return {}

## The camp nearest `level` (for quests / hints: "try the Old Orchard").
static func camp_for_level(level: int) -> Dictionary:
	var best: Dictionary = {}
	var best_gap: int = 999
	for c: Dictionary in CAMPS:
		var gap: int = absi(int(c["level"]) - level)
		if gap < best_gap:
			best_gap = gap
			best = c
	return best

## Burial-mound entity dicts for the graveyard mounds inside chunk (cx, cz).
static func mounds_in_chunk(cx: int, cz: int, chunk_size: int, tile_size: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(GRAVEYARD_MOUNDS.size()):
		var t: Vector2i = GRAVEYARD_MOUNDS[i]
		if int(floor(float(t.x) / float(chunk_size))) != cx or int(floor(float(t.y) / float(chunk_size))) != cz:
			continue
		out.append({"id": "mound_graveyard_%d" % i,
			"x": float(t.x) * tile_size + tile_size * 0.5, "z": float(t.y) * tile_size + tile_size * 0.5})
	return out
