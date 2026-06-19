extends Node

const CardRegistry    = preload("res://autoloads/CardRegistry.gd")
const CraftingRecipe  = preload("res://data/CraftingRecipe.gd")
const GardenDefs      = preload("res://game_logic/GardenDefs.gd")

static var _recipes: Array = []
static var _recipe_index: Dictionary = {}   # "tid|rarity" -> CraftingRecipe
static var _template_index: Dictionary = {} # tid -> Array of CraftingRecipe
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for tid: String in CardRegistry.get_all_ids():
		if not CardRegistry.is_craftable(tid):
			continue
		for rarity: String in IsoConst.RARITY_ORDER:
			var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
			var recipe := CraftingRecipe.new()
			recipe.template_id = tid
			recipe.rarity = rarity
			recipe.essence_cost = int(cfg.get("craft_essence", 0))
			_recipes.append(recipe)
			_recipe_index[tid + "|" + rarity] = recipe
			if not _template_index.has(tid):
				_template_index[tid] = []
			(_template_index[tid] as Array).append(recipe)

## Returns all craftable recipes (one per craftable template × rarity tier).
static func get_all_recipes() -> Array:
	_ensure_loaded()
	return _recipes

## Returns all recipes for a specific template_id.
static func get_recipes_for_template(template_id: String) -> Array:
	_ensure_loaded()
	return _template_index.get(template_id, [])

## Returns the recipe for a (template_id, rarity) pair, or null if not found.
static func get_recipe(template_id: String, rarity: String) -> CraftingRecipe:
	_ensure_loaded()
	return _recipe_index.get(template_id + "|" + rarity, null) as CraftingRecipe

## Returns potion recipe dicts keyed by potion_id. Each dict has display_name, essence_cost, ingredients.
static func get_potion_recipes() -> Dictionary:
	return GardenDefs.POTION_RECIPES
