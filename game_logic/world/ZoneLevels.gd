## Zone level ranges and enemy levels (GID-136 / TID-536; story-route zones
## GID-176 / TID-719), WoW style.
##
## Levels follow the **story route**, not the distance from Madrian: Chapter 1
## (Madrian → the south road → Maykalene / Farsyth → the Isfig road →
## Blancogov) spans levels 1–10, Chapter 2 continues west (Larik → Marsax Hold).
## ROUTE is a polyline of anchors, each with a level; a tile takes the level of
## its nearest point on the route (lerped between the two anchors), plus a ramp
## of one level per LEVEL_STEP_TILES once it is more than CORRIDOR tiles off the
## route (wild land). Each route segment belongs to a named ZONE with a level
## range; an enemy's level is the tile level clamped into its zone's range and
## its type's own sub-range (`enemy_level_at`).
##
## An enemy's level colours its tag relative to the player (grey / green /
## yellow / orange / red), scales its hero HP and card tier in battle, and scales
## the XP it gives — grey enemies give none.
##
## Pure static logic, no autoloads; safe on chunk worker threads.
extends RefCounted

## Madrian's centre in overworld tiles (centre of RealmLayout.world_rect).
const ORIGIN_TILE := Vector2i(-7, -1)
## Tiles off the route before the wild-land ramp starts, and tiles per extra level.
const CORRIDOR: float = 30.0
const LEVEL_STEP_TILES: float = 12.0
const MAX_LEVEL: int = 60
## Inverse-distance blend sharpness between route segments (higher = closer to nearest-only).
const BLEND_POWER: float = 6.0

## Named zones in story order: id → {name, min, max}.
const ZONES: Dictionary = {
	"madrian_outskirts": {"name": "Madrian Outskirts", "min": 1, "max": 5},
	"south_road": {"name": "The South Road", "min": 4, "max": 7},
	"farsyth_lands": {"name": "Farsyth Lands", "min": 6, "max": 9},
	"blancogov_approach": {"name": "Blancogov Approach", "min": 8, "max": 10},
	"larik": {"name": "Larik", "min": 10, "max": 14},
	"marsax_reach": {"name": "Marsax Reach", "min": 13, "max": 17},
}

## The story route: [tile, level, zone of the segment that *ends* here]. Town
## anchors are town centres (centre of RealmLayout.world_rect; checked by
## test_zone_levels), the rest are RealmLayout.STORY_SITES.
const ROUTE: Array = [
	[Vector2i(-7, -1), 1, "madrian_outskirts"],       # Madrian
	[Vector2i(13, 30), 1, "madrian_outskirts"],       # madrian_south_road
	[Vector2i(17, 42), 3, "madrian_outskirts"],       # wilderness_camp
	[Vector2i(18, 95), 7, "south_road"],              # Maykalene (Farsyth's door)
	[Vector2i(80, 180), 8, "farsyth_lands"],          # isfig_road
	[Vector2i(94, 252), 10, "blancogov_approach"],    # Blancogov — end of Chapter 1
	[Vector2i(-118, 281), 12, "larik"],               # Larik (Chapter 2)
	[Vector2i(-114, 222), 14, "marsax_reach"],        # scout_ambush
	[Vector2i(-118, 154), 16, "marsax_reach"],        # Marsax Hold
]

## Grey at or below this many levels under the player.
const GREY_GAP: int = 5

const CON_COLORS: Dictionary = {
	"grey": Color(0.62, 0.62, 0.62),
	"green": Color(0.35, 0.9, 0.35),
	"yellow": Color(1.0, 0.92, 0.3),
	"orange": Color(1.0, 0.55, 0.15),
	"red": Color(1.0, 0.25, 0.2),
}
const XP_FACTORS: Dictionary = {"grey": 0.0, "green": 0.75, "yellow": 1.0, "orange": 1.2, "red": 1.4}


## {level (float, before rounding), zone (id), off (tiles off the route)} for a tile.
## The route level is an inverse-distance blend (power BLEND_POWER) of each
## segment's lerped level, so it changes smoothly where two parts of the route
## pass near each other (Chapter 2 doubles back west of Chapter 1); the zone is
## the nearest segment's.
static func _locate(tx: int, tz: int) -> Dictionary:
	var p := Vector2(float(tx), float(tz))
	var best_d: float = INF
	var best_zone: String = str(ROUTE[0][2])
	var wsum: float = 0.0
	var lsum: float = 0.0
	for i: int in range(1, ROUTE.size()):
		var a := Vector2(ROUTE[i - 1][0] as Vector2i)
		var b := Vector2(ROUTE[i][0] as Vector2i)
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d: float = p.distance_to(a + ab * t)
		var w: float = 1.0 / pow(d + 1.0, BLEND_POWER)
		wsum += w
		lsum += w * lerpf(float(ROUTE[i - 1][1]), float(ROUTE[i][1]), t)
		if d < best_d:
			best_d = d
			best_zone = str(ROUTE[i][2])
	var off: float = maxf(0.0, best_d - CORRIDOR)
	return {"level": lsum / wsum + off / LEVEL_STEP_TILES, "zone": best_zone, "off": off}

## Level of an overworld tile (the spot's base level, before an enemy's type).
static func level_at_tile(tx: int, tz: int) -> int:
	return clampi(roundi(float(_locate(tx, tz)["level"])), 1, MAX_LEVEL)

## Zone level at an overworld position (world units).
static func level_at_world(pos: Vector3, tile_size: float) -> int:
	return level_at_tile(int(floor(pos.x / tile_size)), int(floor(pos.z / tile_size)))

## Zone id a tile belongs to (its nearest route segment's zone).
static func zone_at_tile(tx: int, tz: int) -> String:
	return str(_locate(tx, tz)["zone"])

## Level range [min, max] at a tile: its zone's range, stretched upward in wild
## land off the route so the ramp still applies there.
static func range_at_tile(tx: int, tz: int) -> Vector2i:
	var z: Dictionary = ZONES[zone_at_tile(tx, tz)]
	var lvl: int = level_at_tile(tx, tz)
	return Vector2i(int(z["min"]), maxi(int(z["max"]), lvl))

## An enemy's level at a tile: the tile level clamped into the zone range ∩ the
## type's own sub-range (`type_range`, e.g. EnemyRegistry.level_range). When the
## two don't overlap, the zone range wins.
static func enemy_level_at(tx: int, tz: int, type_range: Vector2i) -> int:
	var zr: Vector2i = range_at_tile(tx, tz)
	var lo: int = maxi(zr.x, type_range.x)
	var hi: int = mini(zr.y, type_range.y)
	if lo > hi:
		lo = zr.x
		hi = zr.y
	return clampi(level_at_tile(tx, tz), lo, hi)

## WoW "con" colour name for an enemy of `enemy_level` seen by `player_level`.
static func con(enemy_level: int, player_level: int) -> String:
	var gap: int = enemy_level - player_level
	if gap <= -GREY_GAP:
		return "grey"
	if gap <= -2:
		return "green"
	if gap <= 2:
		return "yellow"
	if gap <= 4:
		return "orange"
	return "red"

static func con_color(enemy_level: int, player_level: int) -> Color:
	var c: Color = CON_COLORS[con(enemy_level, player_level)]
	return c

## XP for defeating an enemy: its base XP grows 10% per level above 1, times the
## con factor (grey = 0).
static func scaled_xp(base_xp: int, enemy_level: int, player_level: int) -> int:
	var f: float = float(XP_FACTORS[con(enemy_level, player_level)])
	return roundi(float(base_xp) * (1.0 + 0.1 * float(maxi(0, enemy_level - 1))) * f)

## Enemy hero HP at `level`: +6% per level above 1.
static func scaled_hero_hp(base_hp: int, level: int) -> int:
	return roundi(float(base_hp) * (1.0 + 0.06 * float(maxi(0, level - 1))))

## Enemy card tier at `level`: one tier up per 10 levels, capped at 4.
static func scaled_tier(base_tier: int, level: int) -> int:
	return clampi(base_tier + maxi(0, level - 1) / 10, 1, 4)
