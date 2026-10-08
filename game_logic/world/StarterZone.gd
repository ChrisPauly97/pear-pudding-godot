## StarterZone — Madrian's outskirts as the level 1–5 starter zone (zone levels: ZoneLevels),
## plus the Chapter 1 road camps (levels 5–10, GID-177 / TID-722)
## (GID-141 / TID-591).
##
## Camps are fixed groups of enemies, placed in rings
## that step outward from town so the starter quests (TID-592) can send a new
## player a little further each level. Camp enemies are transient: killing one
## never enters `SaveManager.defeated_enemies`; the `StarterCamps` world module
## refills a slot CAMP_RESPAWN_S seconds after it falls, so a "slay three" quest
## can never be stranded. The graveyard holds the Gravedigger's burial mounds.
##
## Tiles are overworld tiles (Madrian local tile − (37, 33), see RealmLayout).
## Pure static data, no autoloads.
extends RefCounted

const _ZoneLevels = preload("res://game_logic/world/ZoneLevels.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

## Seconds before a fallen camp slot refills.
const CAMP_RESPAWN_S: float = 45.0
## Camps further than this (world units) from the player are not topped up.
const ACTIVE_RANGE: float = 90.0
## Enemy ids of camp members start with this (never saved as defeated).
const ID_PREFIX: String = "camp_"

## {id, name, tile, enemy_type, count, tracking}. A camp's level is not authored:
## it comes from its tile's zone and its enemy type (`camp_level`, GID-176 / TID-719).
## `tracking` = chases the
## player; the first two rings wait to be attacked, WoW-style passive critters.
const CAMPS: Array[Dictionary] = [
	{"id": "grain_store", "name": "Grain-Store Field", "tile": Vector2i(21, 17), "enemy_type": "undead_basic",
		"count": 3, "tracking": false},
	{"id": "south_field", "name": "South Field", "tile": Vector2i(-7, 21), "enemy_type": "undead_basic",
		"count": 4, "tracking": false},
	{"id": "old_orchard", "name": "The Old Orchard", "tile": Vector2i(47, 19), "enemy_type": "undead_horde",
		"count": 4, "tracking": true},
	{"id": "north_barrow", "name": "North Barrow", "tile": Vector2i(33, -21), "enemy_type": "undead_horde",
		"count": 4, "tracking": true},
	{"id": "hedge_ruins", "name": "Hedge Ruins", "tile": Vector2i(53, -27), "enemy_type": "ghoul_pack",
		"count": 3, "tracking": true},
	{"id": "east_copse", "name": "East Copse", "tile": Vector2i(76, -2), "enemy_type": "ghoul_pack",
		"count": 4, "tracking": true},
	{"id": "west_crossing", "name": "West Crossing", "tile": Vector2i(-55, 4), "enemy_type": "undead_horde",
		"count": 5, "tracking": true},
	{"id": "north_tor", "name": "North Tor", "tile": Vector2i(10, -62), "enemy_type": "ghoul_pack",
		"count": 4, "tracking": true},
	{"id": "south_road", "name": "South Road Wreck", "tile": Vector2i(40, 45), "enemy_type": "ghoul_pack",
		"count": 5, "tracking": true},
	# ── GID-177 / TID-722: Chapter 1 road camps (levels 5–10 come from their zone, TID-719).
	# Sited 10–30 tiles off the route on clear ground (tools probe: reserved distance, rivers, coast).
	# `dress` reuses a Madrian camp's set dressing (CampDressing.LAYOUTS).
	{"id": "wolf_hollow", "name": "Wolf Hollow", "tile": Vector2i(-16, 68), "enemy_type": "wolf_pack",
		"count": 4, "tracking": true, "dress": "north_tor"},
	{"id": "shade_thicket", "name": "Shade Thicket", "tile": Vector2i(-15, 83), "enemy_type": "forest_shade",
		"count": 4, "tracking": true, "dress": "east_copse"},
	{"id": "mire_edge", "name": "Mire Edge", "tile": Vector2i(56, 128), "enemy_type": "bog_hag",
		"count": 4, "tracking": true, "dress": "hedge_ruins"},
	{"id": "stag_glade", "name": "Stag Glade", "tile": Vector2i(32, 146), "enemy_type": "imbued_stag",
		"count": 4, "tracking": true, "dress": "east_copse"},
	{"id": "old_watchtower", "name": "Old Watchtower", "tile": Vector2i(92, 168), "enemy_type": "forest_shade",
		"count": 5, "tracking": true, "dress": "hedge_ruins"},
	{"id": "martarquas_outpost", "name": "Martarquas Outpost", "tile": Vector2i(78, 206),
		"enemy_type": "martarquas_scout", "count": 4, "tracking": true, "dress": "west_crossing"},
	{"id": "scout_ridge", "name": "Scout Ridge", "tile": Vector2i(122, 212), "enemy_type": "martarquas_scout",
		"count": 5, "tracking": true, "dress": "north_tor"},
]

## GID-166: each camp sits in a clearing this many tiles in radius for its set
## dressing (CampDressing) — RealmLayout treats it as reserved ground: flat, no
## random trees, water or spawns. Inside it the distance stays at CAMP_SITE_PAD
## (never 0, which would pave it). Must stay 1-Lipschitz (hill SAT skip).
const CAMP_CLEAR_RADIUS: float = 6.0
const CAMP_SITE_PAD: float = 0.5

## The old graveyard west of the south field: the Gravedigger stands here and
## its mounds are the first Skeleton Dig targets.
const GRAVEYARD_TILE := Vector2i(-25, 19)
const GRAVEYARD_MOUNDS: Array[Vector2i] = [Vector2i(-28, 17), Vector2i(-24, 22), Vector2i(-21, 16)]

## GID-143 / TID-605: graveyard dressing, Madrian-local tiles → prop texture key
## (SpriteRegistry.graveyard_prop). The graveyard's edge is a low iron fence
## (decor, not a wall); the sealed crypt keeps real walls — Ghost Phase needs them.
const GRAVEYARD_LOCAL_RECT := Rect2i(8, 47, 11, 10)
const CRYPT_DOOR_LOCAL := Vector2i(24, 53)

## GID-149: the Barrow King wakes outside his crypt once "The Sealed Crypt" is
## done. Unique (no ID_PREFIX), so beating him is saved like any named enemy.
const BARROW_KING := {"id": "barrow_king_madrian", "enemy_type": "barrow_king", "tile": Vector2i(-13, 22),
	"level": 10, "requires_quest": "sealed_crypt"}  # top of Chapter 1 (L1–10)

## True when the Barrow King should stand at his crypt.
static func barrow_king_awake(completed_quests: Array, defeated: Array) -> bool:
	return completed_quests.has(str(BARROW_KING["requires_quest"])) and not defeated.has(str(BARROW_KING["id"]))

## [key, Madrian-local tile, axis, offset] for every graveyard prop. `axis` "" =
## camera-facing billboard (headstones); "x" / "z" = a flat panel running along
## that world axis, so the fence and the crypt door follow the isometric lines
## instead of all turning to face the camera. `offset` shifts it within the tile
## (tile units) — onto the tile edge the fence runs along.
static func graveyard_props() -> Array:
	var out: Array = []
	var r: Rect2i = GRAVEYARD_LOCAL_RECT
	var gate: Array[int] = [13, 14]
	# One 1-tile segment per edge tile, on the outer edge of the ring; gate left open.
	for x: int in range(r.position.x, r.end.x):
		if not gate.has(x):
			out.append(["iron_fence", Vector2i(x, r.position.y), "x", Vector2(0.0, -0.5)])
		out.append(["iron_fence", Vector2i(x, r.end.y - 1), "x", Vector2(0.0, 0.5)])
	for z: int in range(r.position.y, r.end.y):
		out.append(["iron_fence", Vector2i(r.position.x, z), "z", Vector2(-0.5, 0.0)])
		out.append(["iron_fence", Vector2i(r.end.x - 1, z), "z", Vector2(0.5, 0.0)])
	var i: int = 0
	for z: int in [49, 51, 53]:
		for x: int in [10, 12, 15, 17]:
			if Vector2i(x, z) in [Vector2i(14, 50)]:
				continue
			out.append(["headstone_%d" % (i % 3), Vector2i(x, z), "", Vector2.ZERO])
			i += 1
	# Flat against the crypt's south wall face.
	out.append(["crypt_door", CRYPT_DOOR_LOCAL, "x", Vector2(0.0, -0.45)])
	return out

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

## A camp's level: its tile's zone level clamped to its enemy type's sub-range.
static func camp_level(c: Dictionary) -> int:
	var t: Vector2i = c["tile"]
	return _ZoneLevels.enemy_level_at(t.x, t.y, _EnemyRegistry.level_range(str(c["enemy_type"])))

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
		var gap: int = absi(camp_level(c) - level)
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

## Reserved-distance contribution of the nearest camp clearing to a tile.
static func camp_site_distance(wtx: int, wtz: int) -> float:
	var best: float = INF
	for camp: Dictionary in CAMPS:
		var t: Vector2i = camp["tile"]
		best = minf(best, maxf(CAMP_SITE_PAD, Vector2(wtx - t.x, wtz - t.y).length() - CAMP_CLEAR_RADIUS))
	return best

## `camp_site_distance` over a pre-filtered list of camp tiles (RealmLayout stamp context).
static func camp_distance_in(tiles: Array[Vector2i], wtx: int, wtz: int) -> float:
	var best: float = INF
	for t: Vector2i in tiles:
		best = minf(best, maxf(CAMP_SITE_PAD, Vector2(wtx - t.x, wtz - t.y).length() - CAMP_CLEAR_RADIUS))
	return best

## True when a camp's clearing can reach `area` (tiles).
static func camp_in_rect(area: Rect2i) -> bool:
	var grown: Rect2i = area.grow(int(ceil(CAMP_CLEAR_RADIUS)))
	for camp: Dictionary in CAMPS:
		if grown.has_point(camp["tile"] as Vector2i):
			return true
	return false

## Camp tiles whose clearing can reach within `reach` of `centre` (all of them when not `filtered`).
static func camps_near(centre: Vector2, reach: float, filtered: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for camp: Dictionary in CAMPS:
		var t: Vector2i = camp["tile"]
		if not filtered or centre.distance_to(Vector2(t)) <= reach + CAMP_CLEAR_RADIUS:
			out.append(t)
	return out
