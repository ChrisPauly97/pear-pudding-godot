## Professions: Alchemy, Cooking, Crafting (GID-182 / TID-759).
##
## The single source of truth for every profession, gatherable / dropped
## material and recipe. Stations, the crafting panel, gathering nodes and enemy
## drops all read these tables. Garden plants (`GardenDefs.PLANTS`) are valid
## recipe inputs too, so they are referenced, never re-listed here.
##
## Pure static data and math, no autoloads: gathering nodes read it from the
## chunk-generation worker threads.
extends RefCounted

const GardenDefs = preload("res://game_logic/GardenDefs.gd")
const HeroVitality = preload("res://game_logic/HeroVitality.gd")

const ALCHEMY: String = "alchemy"
const COOKING: String = "cooking"
const CRAFTING: String = "crafting"

## Profession id → display name, colour and the station kind that crafts it.
const PROFESSIONS: Dictionary = {
	ALCHEMY: {"display_name": "Alchemy", "color": Color(0.55, 0.85, 0.45), "station": "alchemy_table"},
	COOKING: {"display_name": "Cooking", "color": Color(0.95, 0.6, 0.3), "station": "cooking_fire"},
	CRAFTING: {"display_name": "Crafting", "color": Color(0.7, 0.75, 0.85), "station": "workbench"},
}

## Material sources. herb / ore / fish come from gathering nodes (TID-760),
## meat / hide / core from enemy drops (TID-761).
const SOURCES: Array[String] = ["herb", "ore", "fish", "meat", "hide", "core"]

## Material id → {display_name, sell_value, source, description}.
const MATERIALS: Dictionary = {
	"silverleaf": {"display_name": "Silverleaf", "sell_value": 6, "source": "herb",
			"description": "A common meadow herb with a cool, minty sap."},
	"duskbloom": {"display_name": "Duskbloom", "sell_value": 10, "source": "herb",
			"description": "Opens only in shade; prized by alchemists."},
	"bogmoss": {"display_name": "Bog Moss", "sell_value": 8, "source": "herb",
			"description": "Spongy moss from the bogs. Smells worse than it brews."},
	"wild_grain": {"display_name": "Wild Grain", "sell_value": 3, "source": "herb",
			"description": "Tough grass heads that grind into coarse flour."},
	"copper_ore": {"display_name": "Copper Ore", "sell_value": 6, "source": "ore",
			"description": "Soft green-streaked ore."},
	"iron_ore": {"display_name": "Iron Ore", "sell_value": 12, "source": "ore",
			"description": "Heavy, dark ore from the mountains."},
	"river_trout": {"display_name": "River Trout", "sell_value": 6, "source": "fish",
			"description": "A speckled trout from the rivers."},
	"game_meat": {"display_name": "Game Meat", "sell_value": 5, "source": "meat",
			"description": "Raw meat from a wild beast."},
	"rough_hide": {"display_name": "Rough Hide", "sell_value": 5, "source": "hide",
			"description": "A scraped animal hide, ready for tanning."},
	"arcane_core": {"display_name": "Arcane Core", "sell_value": 20, "source": "core",
			"description": "A humming crystal left behind by magical foes."},
}

## Recipe id → {profession, display_name, skill_req, inputs {material/plant id: n},
## output {kind: food|potion|gear, id, count}, xp}. Food outputs are
## `HeroVitality.FOODS` ids, potion outputs `GardenDefs.POTIONS` ids.
## Starter set; Cooking (TID-763), Alchemy (TID-764) and Crafting (TID-765) extend it.
const RECIPES: Dictionary = {
	"brew_healing_draught": {"profession": ALCHEMY, "display_name": "Healing Draught", "skill_req": 1,
			"inputs": {"silverleaf": 2}, "output": {"kind": "potion", "id": "healing_draught", "count": 1},
			"xp": 10},
	"brew_clarity_brew": {"profession": ALCHEMY, "display_name": "Clarity Brew", "skill_req": 5,
			"inputs": {"duskbloom": 2}, "output": {"kind": "potion", "id": "clarity_brew", "count": 1},
			"xp": 14},
	"cook_travel_bread": {"profession": COOKING, "display_name": "Travel Bread", "skill_req": 1,
			"inputs": {"wild_grain": 3}, "output": {"kind": "food", "id": "travel_bread", "count": 2},
			"xp": 8},
	"cook_roast_fowl": {"profession": COOKING, "display_name": "Roast Fowl", "skill_req": 5,
			"inputs": {"game_meat": 2, "wild_grain": 1}, "output": {"kind": "food", "id": "roast_fowl", "count": 1},
			"xp": 14},
	# Cooking (TID-763)
	"cook_trout_fillet": {"profession": COOKING, "display_name": "Trout Fillet", "skill_req": 1,
			"inputs": {"river_trout": 2}, "output": {"kind": "food", "id": "trout_fillet", "count": 2},
			"xp": 8},
	"cook_herb_stew": {"profession": COOKING, "display_name": "Herb Stew", "skill_req": 3,
			"inputs": {"game_meat": 1, "wild_grain": 1, "silverleaf": 2},
			"output": {"kind": "food", "id": "herb_stew", "count": 1}, "xp": 12},
	"cook_bog_pie": {"profession": COOKING, "display_name": "Bog Pie", "skill_req": 8,
			"inputs": {"game_meat": 2, "bogmoss": 2, "wild_grain": 2},
			"output": {"kind": "food", "id": "bog_pie", "count": 1}, "xp": 18},
}

const MAX_LEVEL: int = 50
## XP for level 1 → 2; each later level costs XP_STEP more.
const XP_BASE: int = 20
const XP_STEP: int = 10

## Difficulty bands by (level - skill_req), as in WoW: orange/yellow give full
## XP, green half, grey none. A recipe above your level is "locked".
const BAND_YELLOW: int = 5
const BAND_GREEN: int = 10
const BAND_GREY: int = 15
const BAND_COLORS: Dictionary = {
	"locked": Color(0.9, 0.3, 0.3), "orange": Color(1.0, 0.55, 0.2), "yellow": Color(1.0, 0.9, 0.3),
	"green": Color(0.4, 0.9, 0.4), "grey": Color(0.6, 0.6, 0.6),
}


## Cooked food → the well-fed buff it sets when eaten (WellFed.gd, TID-763).
## `amount` max HP for `fights` ordinary solo fights. Foods not listed give none.
const WELL_FED: Dictionary = {
	"roast_fowl": {"stat": "max_hp", "amount": 4, "fights": 3},
	"trout_fillet": {"stat": "max_hp", "amount": 3, "fights": 2},
	"herb_stew": {"stat": "max_hp", "amount": 5, "fights": 3},
	"bog_pie": {"stat": "max_hp", "amount": 8, "fights": 4},
}


## Total XP needed to reach `level` (level 1 = 0).
static func xp_for_level(level: int) -> int:
	var n: int = clampi(level, 1, MAX_LEVEL) - 1
	return n * XP_BASE + XP_STEP * n * (n - 1) / 2


static func level_for_xp(xp: int) -> int:
	var lv: int = 1
	while lv < MAX_LEVEL and xp >= xp_for_level(lv + 1):
		lv += 1
	return lv


static func band(recipe_id: String, level: int) -> String:
	var gap: int = level - int(def(recipe_id).get("skill_req", 1))
	if gap < 0:
		return "locked"
	if gap < BAND_YELLOW:
		return "orange"
	if gap < BAND_GREEN:
		return "yellow"
	if gap < BAND_GREY:
		return "green"
	return "grey"


## XP one craft of `recipe_id` gives at `level` (0 when locked or grey).
static func recipe_xp(recipe_id: String, level: int) -> int:
	var base: int = int(def(recipe_id).get("xp", 0))
	match band(recipe_id, level):
		"orange", "yellow":
			return base
		"green":
			return base / 2
	return 0


static func def(recipe_id: String) -> Dictionary:
	return RECIPES.get(recipe_id, {})


static func recipes_for(profession: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in RECIPES:
		if str((RECIPES[id] as Dictionary)["profession"]) == profession:
			out.append(id)
	return out


## A recipe input may be a material or a garden plant.
static func is_input(id: String) -> bool:
	return MATERIALS.has(id) or GardenDefs.PLANTS.has(id)


static func input_name(id: String) -> String:
	var d: Dictionary = MATERIALS.get(id, GardenDefs.PLANTS.get(id, {}))
	return str(d.get("display_name", id))


## Whether an output `{kind, id}` names a real item.
static func output_valid(output: Dictionary) -> bool:
	var id: String = str(output.get("id", ""))
	match str(output.get("kind", "")):
		"food":
			return HeroVitality.FOODS.has(id)
		"potion":
			return GardenDefs.POTIONS.has(id)
	return false
