## TownSigns — a named signpost outside every building door in the stitched towns
## (GID-168 / TID-689). The TownSigns world module draws them and pops the name up
## when the player walks near.
##
## Names come from NAMES (town → door gap tile → name, town-local), else from the
## role of an NPC standing in or right outside the building (merchant → "General
## Goods"…), else "House". Each sign stands one tile out from the doorway and one
## to the side, on open ground clear of streets, set pieces, walls and entities.
## Pure static logic over RealmLayout's cached plans; no scene tree.
extends RefCounted

const IsoConst = preload("res://autoloads/IsoConst.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _TownDecor = preload("res://game_logic/world/TownDecor.gd")
const _WorldMap = preload("res://game_logic/world/WorldMap.gd")

const DEFAULT_NAME: String = "House"

## town → {door gap tile (local) → building name}.
const NAMES: Dictionary = {
	"madrian": {
		Vector2i(13, 15): "The Master's House",
		Vector2i(25, 15): "The Rusty Tankard Inn",
		Vector2i(35, 14): "General Goods",
		Vector2i(44, 14): "Madrian Smithy",
		Vector2i(44, 21): "Ivy's Candles",
		Vector2i(44, 29): "Hilda's Bakery",
		Vector2i(16, 22): "Wenna's Herbs",
		Vector2i(17, 30): "Chapel of the Dawn",
		Vector2i(23, 37): "Cottage",
		Vector2i(36, 38): "Madrian Stables",
	},
	"maykalene": {
		Vector2i(59, 15): "Harbour Goods",
		Vector2i(40, 17): "The White Gull Inn",
		Vector2i(40, 23): "Cottage",
		Vector2i(69, 23): "Harbourmaster's House",
		Vector2i(41, 31): "Maykalene Archive",
		Vector2i(63, 31): "Cottage",
		Vector2i(41, 38): "Fisher's Cottage",
		Vector2i(61, 38): "Weaver's Cottage",
		Vector2i(71, 39): "Fishmonger's",
		Vector2i(51, 46): "Farsyth Mansion",
	},
	"blancogov": {
		Vector2i(37, 13): "Guard House",
		Vector2i(63, 13): "Townhouse",
		Vector2i(39, 25): "Duellists' Hall",
		Vector2i(61, 25): "Royal Library",
		Vector2i(63, 35): "Townhouse",
		Vector2i(37, 36): "The Golden Lyre",
		Vector2i(50, 45): "Temple of Blancogov",
	},
	"larik": {
		Vector2i(47, 42): "Cottage",
		Vector2i(39, 43): "Odd's Farmhouse",
		Vector2i(58, 43): "Old Neighbour's House",
		Vector2i(58, 55): "Saimtar's House",
		Vector2i(42, 54): "Larik Stables",
		Vector2i(48, 56): "Cottage",
	},
	"marsax_hold": {
		Vector2i(50, 46): "The Keep",
		Vector2i(41, 55): "Barracks",
		Vector2i(59, 55): "Armoury",
		Vector2i(59, 64): "Storehouse",
	},
}

## NPC role (MapNpc.npc_type) → the building it gives its name to.
const ROLE_NAMES: Dictionary = {
	"merchant": "General Goods",
	"blacksmith": "Smithy",
	"stable": "Stables",
	"trainer": "Training Hall",
}

## How far outside a doorway (tiles) an NPC still names the building.
const ROLE_REACH: int = 2


## Every sign of `town`: [{"tile": Vector2i (town-local), "name": String}].
static func signs(town: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wm: _WorldMap = _RealmLayout.town_map(town)
	if wm == null:
		return out
	var crop: Rect2i = _RealmLayout.crop_of(town)
	var streets: Dictionary = _RealmLayout.street_plan(town)["tiles"]
	var blocked: Dictionary = _TownDecor.blocked_local(town)
	var taken: Dictionary = _entity_tiles(wm)
	var names: Dictionary = NAMES.get(town, {})
	for b: Dictionary in _RealmLayout.building_plan(town)["buildings"]:
		var doors: Array = b["doors"]
		if doors.is_empty():
			continue
		var rect: Rect2i = b["rect"]
		var door: Vector2i = doors[0]
		var n: Vector2i = outward(rect, door)
		var spot: Vector2i = _free_spot(wm, crop, door, n, streets, blocked, taken)
		if spot.x == -9999:
			continue
		taken[spot] = true
		var label: String = str(names.get(door, _role_name(wm, rect, door, n)))
		out.append({"tile": spot, "name": label})
	return out


## The unit step from a door gap on `rect`'s border to the outside.
static func outward(rect: Rect2i, door: Vector2i) -> Vector2i:
	if door.y == rect.position.y:
		return Vector2i(0, -1)
	if door.y == rect.end.y - 1:
		return Vector2i(0, 1)
	if door.x == rect.position.x:
		return Vector2i(-1, 0)
	return Vector2i(1, 0)


## First open tile beside the doorway: one out and one to either side, then two out.
static func _free_spot(wm: _WorldMap, crop: Rect2i, door: Vector2i, n: Vector2i, streets: Dictionary,
		blocked: Dictionary, taken: Dictionary) -> Vector2i:
	var side := Vector2i(n.y, n.x)
	var out1: Vector2i = door + n
	for c: Vector2i in [out1 + side, out1 - side, out1 + n + side, out1 + n - side, out1 + side * 2]:
		if not crop.has_point(c) or streets.has(c) or blocked.has(c) or taken.has(c):
			continue
		var t: int = wm.get_tile(c.x, c.y)
		if t == IsoConst.TILE_GRASS or t == IsoConst.TILE_PATH:
			return c
	return Vector2i(-9999, -9999)


## A role-derived name when an NPC with a known npc_type stands in or by the building.
static func _role_name(wm: _WorldMap, rect: Rect2i, door: Vector2i, n: Vector2i) -> String:
	var porch := Rect2i(door + n * ROLE_REACH - Vector2i(ROLE_REACH, ROLE_REACH), Vector2i.ONE * (ROLE_REACH * 2 + 1))
	for v: Variant in wm.npcs:
		var npc: Dictionary = v
		var role: String = str(npc.get("npc_type", ""))
		if not ROLE_NAMES.has(role):
			continue
		var t := IsoConst.entity_tile(npc)
		if rect.has_point(t) or porch.has_point(t):
			return str(ROLE_NAMES[role])
	return DEFAULT_NAME


static func _entity_tiles(wm: _WorldMap) -> Dictionary:
	var out: Dictionary = {}
	for list: Array in [wm.npcs, wm.doors, wm.chests, wm.scrolls, wm.shrines, wm.waystones]:
		for v: Variant in list:
			out[IsoConst.entity_tile(v as Dictionary)] = true
	return out
