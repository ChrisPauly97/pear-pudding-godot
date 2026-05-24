extends Node

const CardRegistry    = preload("res://autoloads/CardRegistry.gd")
const CraftingRecipe  = preload("res://data/CraftingRecipe.gd")

static var _recipes: Array = []
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

## Returns all craftable recipes (one per craftable template × rarity tier).
static func get_all_recipes() -> Array:
	_ensure_loaded()
	return _recipes

## Returns all recipes for a specific template_id.
static func get_recipes_for_template(template_id: String) -> Array:
	_ensure_loaded()
	var result: Array = []
	for r in _recipes:
		if (r as CraftingRecipe).template_id == template_id:
			result.append(r)
	return result

## Returns the recipe for a (template_id, rarity) pair, or null if not found.
static func get_recipe(template_id: String, rarity: String) -> CraftingRecipe:
	_ensure_loaded()
	for r in _recipes:
		var rec := r as CraftingRecipe
		if rec.template_id == template_id and rec.rarity == rarity:
			return rec
	return null
