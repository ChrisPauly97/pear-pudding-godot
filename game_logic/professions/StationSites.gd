## Crafting station placement (GID-182 / TID-762): which profession station stands
## where. Pure static data, no autoloads.
##
## A station's kind comes from `ProfessionDefs.PROFESSIONS` (profession → station),
## so the kind→profession map is never re-listed here. Town sites use town-local
## tiles (translated by `RealmLayout.to_world_tile()` when spawned); home sites use
## tiles of the player-home interior map.
extends RefCounted

const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")

## Each site: {id, kind (a station kind), town (stitched town) or "" for the home,
## tile (town-local or home-interior tile)}. Tiles are open ground on the authored
## map, clear of its NPCs, doors, chests and the square's set pieces
## (test_crafting_stations pins these).
const SITES: Array[Dictionary] = [
	{"id": "madrian_cooking_fire", "kind": "cooking_fire", "town": "madrian", "tile": Vector2i(26, 26)},
	{"id": "madrian_alchemy_table", "kind": "alchemy_table", "town": "madrian", "tile": Vector2i(34, 26)},
	{"id": "madrian_workbench", "kind": "workbench", "town": "madrian", "tile": Vector2i(26, 32)},
	{"id": "home_cooking_fire", "kind": "cooking_fire", "town": "", "tile": Vector2i(45, 52)},
	{"id": "home_alchemy_table", "kind": "alchemy_table", "town": "", "tile": Vector2i(55, 46)},
	{"id": "home_workbench", "kind": "workbench", "town": "", "tile": Vector2i(44, 45)},
]


## Station kinds, one per profession, in PROFESSIONS order.
static func kinds() -> Array[String]:
	var out: Array[String] = []
	for prof: String in ProfessionDefs.PROFESSIONS:
		out.append(str((ProfessionDefs.PROFESSIONS[prof] as Dictionary)["station"]))
	return out


## The profession a station kind crafts, or "" for an unknown kind.
static func profession_for(kind: String) -> String:
	for prof: String in ProfessionDefs.PROFESSIONS:
		if str((ProfessionDefs.PROFESSIONS[prof] as Dictionary)["station"]) == kind:
			return prof
	return ""


## Sites in a stitched town (`town` = "madrian") or, with "", in the player home.
static func sites_in(town: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in SITES:
		if str(s["town"]) == town:
			out.append(s)
	return out
