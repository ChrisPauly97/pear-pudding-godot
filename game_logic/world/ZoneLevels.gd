## Zone level ranges and enemy levels (GID-136 / TID-536), WoW style.
##
## The overworld gets harder the further you walk from Madrian (where every new
## game starts): the starter ring around town is level 1, then roughly one level
## per LEVEL_STEP_TILES tiles. Story towns sit on that ramp in story order —
## Maykalene ~L8, Marsax Hold ~L15, Blancogov / Larik ~L22.
##
## An enemy's level colours its tag relative to the player (grey / green /
## yellow / orange / red), scales its hero HP and card tier in battle, and scales
## the XP it gives — grey enemies give none.
##
## Pure static logic, no autoloads.
extends RefCounted

## Madrian's centre in overworld tiles (RealmLayout offset + half its crop).
const ORIGIN_TILE := Vector2i(8, -5)
## Radius (tiles) of the level-1 starter ring around Madrian.
const STARTER_RADIUS: float = 30.0
const LEVEL_STEP_TILES: float = 12.0
const MAX_LEVEL: int = 60

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


## Zone level of an overworld tile.
static func level_at_tile(tx: int, tz: int) -> int:
	var d: float = Vector2(float(tx - ORIGIN_TILE.x), float(tz - ORIGIN_TILE.y)).length()
	if d <= STARTER_RADIUS:
		return 1
	return clampi(1 + int((d - STARTER_RADIUS) / LEVEL_STEP_TILES), 1, MAX_LEVEL)

## Zone level at an overworld position (world units).
static func level_at_world(pos: Vector3, tile_size: float) -> int:
	return level_at_tile(int(floor(pos.x / tile_size)), int(floor(pos.z / tile_size)))

## Level range shown for a zone: "Lv 3–5" style bounds around a tile.
static func range_at_tile(tx: int, tz: int) -> Vector2i:
	var lvl: int = level_at_tile(tx, tz)
	return Vector2i(maxi(1, lvl - 1), lvl + 1)

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
