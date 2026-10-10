# gdlint: disable=max-public-methods
# Test suite: every test_* case is a public method, so max-public-methods doesn't apply.
## Unit tests for crafting stations and the profession panel (GID-182 / TID-762):
## the StationSites placement data, the station → profession map, and the
## ProfessionPanel building headless and crafting through its handler.
extends "res://tests/framework/test_case.gd"

const IsoConst = preload("res://autoloads/IsoConst.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const StationSites = preload("res://game_logic/professions/StationSites.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const TownDecor = preload("res://game_logic/world/TownDecor.gd")
const WorldMap = preload("res://game_logic/world/WorldMap.gd")
const ProfessionPanel = preload("res://scenes/ui/ProfessionPanel.gd")
const CraftingStation = preload("res://scenes/world/entities/CraftingStation.gd")
const _PLAYER_HOME = preload("res://assets/maps/player_home.tres")

var _sm: SaveManagerScript
var _panel: ProfessionPanel


func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.profession_xp = {}
	_sm.materials = {}
	_sm.plants = {}
	_sm.potions = {}
	_sm.foods = {}


func after_each() -> void:
	if _panel != null:
		_panel.free()
		_panel = null
	_sm.free()


## Every entity list on a map, as {x, z} dicts in world units.
func _entities_of(wm: WorldMap) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for list: Array in [wm.npcs, wm.doors, wm.chests, wm.scrolls, wm.shrines, wm.enemies, wm.waystones]:
		for e: Variant in list:
			out.append(e as Dictionary)
	return out


## Whether any entity on `wm` stands on `tile`.
func _occupied(wm: WorldMap, tile: Vector2i) -> bool:
	for e: Dictionary in _entities_of(wm):
		var et: Vector2i = IsoConst.world_to_tile(float(e.get("x", 0.0)), float(e.get("z", 0.0)))
		if et == tile:
			return true
	return false


## Open ground a station can stand on: not a wall, not on an entity.
func _open_tile(wm: WorldMap, tile: Vector2i) -> bool:
	var t: int = wm.get_tile(tile.x, tile.y)
	if t == WorldMap.TILE_WALL or t == WorldMap.TILE_CRACKED:
		return false
	return not _occupied(wm, tile)


func _buttons(root: Node, out: Array[Button] = []) -> Array[Button]:
	for c: Node in root.get_children():
		if c is Button:
			out.append(c as Button)
		_buttons(c, out)
	return out


func _labels(root: Node, out: Array[Label] = []) -> Array[Label]:
	for c: Node in root.get_children():
		if c is Label:
			out.append(c as Label)
		_labels(c, out)
	return out


func _build_panel(profession: String) -> ProfessionPanel:
	_panel = ProfessionPanel.new()
	_panel.setup(profession, _sm)
	_panel._build_ui()
	return _panel


# ---- Placement data ----

func test_every_station_kind_maps_to_one_profession() -> void:
	var kinds: Array[String] = StationSites.kinds()
	assert_eq(kinds.size(), ProfessionDefs.PROFESSIONS.size(), "one station kind per profession")
	for prof: String in ProfessionDefs.PROFESSIONS:
		var kind: String = str((ProfessionDefs.PROFESSIONS[prof] as Dictionary)["station"])
		assert_eq(StationSites.profession_for(kind), prof, "kind " + kind + " crafts " + prof)
	assert_eq(StationSites.profession_for("no_such_station"), "", "unknown kind has no profession")


func test_site_ids_are_unique_and_kinds_are_valid() -> void:
	var seen: Dictionary = {}
	for s: Dictionary in StationSites.SITES:
		var id: String = str(s["id"])
		assert_false(seen.has(id), "duplicate site id " + id)
		seen[id] = true
		assert_true(StationSites.kinds().has(str(s["kind"])), id + " has a valid kind")


func test_every_profession_has_a_station_somewhere() -> void:
	for prof: String in ProfessionDefs.PROFESSIONS:
		var kind: String = str((ProfessionDefs.PROFESSIONS[prof] as Dictionary)["station"])
		var placed: bool = false
		for s: Dictionary in StationSites.SITES:
			placed = placed or str(s["kind"]) == kind
		assert_true(placed, prof + " has a station site")


func test_madrian_sites_are_open_ground_in_the_square() -> void:
	var wm: WorldMap = RealmLayout.town_map("madrian")
	assert_not_null(wm, "madrian map loads")
	var crop: Rect2i = RealmLayout.crop_of("madrian")
	var blocked: Dictionary = TownDecor.blocked_local("madrian")
	var sites: Array[Dictionary] = StationSites.sites_in("madrian")
	assert_eq(sites.size(), 3, "madrian has three stations")
	for s: Dictionary in sites:
		var tile: Vector2i = s["tile"] as Vector2i
		var id: String = str(s["id"])
		assert_true(crop.has_point(tile), id + " is inside the town crop")
		assert_false(blocked.has(tile), id + " is not on a set piece")
		assert_true(_open_tile(wm, tile), id + " stands on open ground")


func test_home_sites_are_open_ground_clear_of_home_fixtures() -> void:
	var wm := WorldMap.new("player_home", true)
	wm.load_from_resource(_PLAYER_HOME)
	# Bed, trophy pedestals and the three garden plots (BED_TILE, TROPHY_TILES, HOME_PLOT_TILES).
	var fixtures: Array[Vector2i] = [Vector2i(50, 53), Vector2i(44, 49), Vector2i(47, 49), Vector2i(50, 49),
		Vector2i(52, 54), Vector2i(55, 54), Vector2i(58, 54)]
	var sites: Array[Dictionary] = StationSites.sites_in("")
	assert_eq(sites.size(), 3, "home has three stations")
	var used: Array[Vector2i] = []
	for s: Dictionary in sites:
		var tile: Vector2i = s["tile"] as Vector2i
		var id: String = str(s["id"])
		assert_true(_open_tile(wm, tile), id + " stands on open ground")
		assert_false(fixtures.has(tile), id + " is not on a home fixture")
		assert_false(used.has(tile), id + " has its own tile")
		used.append(tile)


# ---- Panel ----

func test_panel_builds_headless_and_lists_the_profession_recipes() -> void:
	var panel: ProfessionPanel = _build_panel(ProfessionDefs.ALCHEMY)
	var recipes: Array[String] = ProfessionDefs.recipes_for(ProfessionDefs.ALCHEMY)
	var buttons: Array[Button] = _buttons(panel)
	var craft_x1: int = 0
	var craft_all: int = 0
	for b: Button in buttons:
		if b.text == "Craft x1":
			craft_x1 += 1
		elif b.text == "Craft x All":
			craft_all += 1
	assert_eq(craft_x1, recipes.size(), "one Craft x1 per alchemy recipe")
	assert_eq(craft_all, recipes.size(), "one Craft x All per alchemy recipe")
	var names: Array[String] = []
	for l: Label in _labels(panel):
		names.append(l.text)
	var joined: String = "\n".join(names)
	for id: String in recipes:
		var rname: String = str(ProfessionDefs.def(id)["display_name"])
		assert_true(joined.contains(rname), "panel lists " + rname)
	assert_false(joined.contains("Roast Fowl"), "panel does not list another profession's recipe")


func test_panel_disables_craft_without_inputs() -> void:
	var panel: ProfessionPanel = _build_panel(ProfessionDefs.ALCHEMY)
	for b: Button in _buttons(panel):
		if b.text.begins_with("Craft"):
			assert_true(b.disabled, "no materials, so every craft button is disabled")


func test_craft_all_through_the_panel_updates_the_save() -> void:
	_sm.materials = {"silverleaf": 5}
	var panel: ProfessionPanel = _build_panel(ProfessionDefs.ALCHEMY)
	var made: int = panel.craft_recipe("brew_healing_draught", true)
	assert_eq(made, 2, "5 silverleaf makes two Healing Draughts (2 each)")
	assert_eq(_sm.professions.count("silverleaf"), 1, "the spare silverleaf is kept")
	assert_eq(int(_sm.potions.get("healing_draught", 0)), 2, "the potions reach the save")
	assert_gt(_sm.professions.xp(ProfessionDefs.ALCHEMY), 0, "crafting grants alchemy XP")


func test_craft_once_through_the_panel_makes_one() -> void:
	_sm.materials = {"silverleaf": 4}
	var panel: ProfessionPanel = _build_panel(ProfessionDefs.ALCHEMY)
	assert_eq(panel.craft_recipe("brew_healing_draught", false), 1, "Craft x1 makes one")
	assert_eq(_sm.professions.count("silverleaf"), 2, "one craft consumes two silverleaf")


func test_craft_without_inputs_makes_nothing() -> void:
	var panel: ProfessionPanel = _build_panel(ProfessionDefs.COOKING)
	assert_eq(panel.craft_recipe("cook_travel_bread", true), 0, "no wild grain, no bread")
	assert_true(_sm.foods.is_empty(), "the save is untouched")


func test_crafting_station_entity_resolves_its_profession() -> void:
	var node: CraftingStation = CraftingStation.new()
	node.init_from_data({"id": "t", "kind": "workbench"})
	assert_eq(node.profession, ProfessionDefs.CRAFTING, "a workbench crafts Crafting")
	node.free()
