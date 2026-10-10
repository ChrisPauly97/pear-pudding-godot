## Profession skill and the material bag (GID-182 / TID-759).
##
## Owned by SaveManager (`SaveManager.professions`), created in its `_init`. The
## state (`profession_xp`, `materials`) stays on SaveManager because
## PERSISTED_FIELDS walks its properties. Recipes come from `ProfessionDefs`.
extends RefCounted

const _SaveManager = preload("res://autoloads/SaveManager.gd")
const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const GardenDefs = preload("res://game_logic/GardenDefs.gd")
const CraftedGear = preload("res://game_logic/professions/CraftedGear.gd")

var _save: _SaveManager


func _init(save_manager: _SaveManager) -> void:
	_save = save_manager


func xp(profession: String) -> int:
	return int(_save.profession_xp.get(profession, 0))


func level(profession: String) -> int:
	return ProfessionDefs.level_for_xp(xp(profession))


## Owned count of a recipe input: a material, or a garden plant.
func count(id: String) -> int:
	if GardenDefs.PLANTS.has(id):
		return int(_save.plants.get(id, 0))
	return int(_save.materials.get(id, 0))


func add_material(id: String, n: int) -> void:
	if n <= 0 or not ProfessionDefs.MATERIALS.has(id):
		return
	_save.materials[id] = int(_save.materials.get(id, 0)) + n
	_save._dirty = true
	GameBus.inventory_changed.emit()


func remove_material(id: String, n: int) -> bool:
	var have: int = int(_save.materials.get(id, 0))
	if n <= 0 or have < n:
		return false
	if have == n:
		_save.materials.erase(id)
	else:
		_save.materials[id] = have - n
	_save._dirty = true
	return true


## The input set a craft of `recipe_id` would use now: the first set the recipe
## accepts (primary, then `alt_inputs`) that is fully owned, else the primary set.
func inputs_for(recipe_id: String) -> Dictionary:
	var sets: Array[Dictionary] = ProfessionDefs.input_sets(ProfessionDefs.def(recipe_id))
	for input_set: Dictionary in sets:
		if _can_pay(input_set):
			return input_set
	return sets[0]


func _can_pay(inputs: Dictionary) -> bool:
	for id: String in inputs:
		if count(id) < int(inputs[id]):
			return false
	return true


## "" when `recipe_id` can be crafted now, else the reason it can't:
## "unknown", "unsupported" (an output that names no real item), "skill" or "inputs".
func craft_block(recipe_id: String) -> String:
	var r: Dictionary = ProfessionDefs.def(recipe_id)
	if r.is_empty():
		return "unknown"
	if not ProfessionDefs.output_valid(r["output"]):
		return "unsupported"
	if level(str(r["profession"])) < int(r["skill_req"]):
		return "skill"
	if not _can_pay(inputs_for(recipe_id)):
		return "inputs"
	return ""


## Crafts one `recipe_id`: consumes inputs, grants the output and XP. Gear is
## rolled from the crafter's skill (CraftedGear) and granted like a drop, so a
## duplicate keeps the better roll. `rng` is optional (tests pass a seeded one).
## Returns {ok, reason, id, count, xp, level, roll, grant} (level is the new
## level, or 0 when unchanged; roll / grant are set for gear only).
func craft(recipe_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var reason: String = craft_block(recipe_id)
	if reason != "":
		return {"ok": false, "reason": reason}
	var r: Dictionary = ProfessionDefs.def(recipe_id)
	var prof: String = str(r["profession"])
	var inputs: Dictionary = inputs_for(recipe_id)
	for id: String in inputs:
		if GardenDefs.PLANTS.has(id):
			_save.garden.remove_plants(id, int(inputs[id]))
		else:
			remove_material(id, int(inputs[id]))
	var out: Dictionary = r["output"]
	var out_id: String = str(out["id"])
	var n: int = int(out.get("count", 1))
	var before: int = level(prof)
	var roll: Dictionary = {}
	var grant: String = ""
	if str(out["kind"]) == "food":
		_save.foods[out_id] = int(_save.foods.get(out_id, 0)) + n
	elif str(out["kind"]) == "gear":
		var gen: RandomNumberGenerator = rng
		if gen == null:
			gen = RandomNumberGenerator.new()
			gen.randomize()
		for _i: int in n:
			roll = CraftedGear.roll(before, int(r["skill_req"]), gen)
			grant = _save.gear.grant(out_id, roll)
			if grant == "new" or grant == "upgraded":
				GameBus.equipment_dropped.emit(out_id)
	else:
		_save.garden.add_potions(out_id, n)
		GameBus.potion_crafted.emit(out_id)
	var gained: int = ProfessionDefs.recipe_xp(recipe_id, before)
	_save.profession_xp[prof] = xp(prof) + gained
	_save._dirty = true
	var after: int = level(prof)
	if after > before:
		GameBus.profession_level_up.emit(prof, after)
	GameBus.inventory_changed.emit()
	return {"ok": true, "reason": "", "id": out_id, "count": n, "xp": gained,
			"level": after if after > before else 0, "roll": roll, "grant": grant}


## Grants raw profession XP (gathering, TID-760). Returns the new level when it
## rose, else 0; emits `profession_level_up` on a level-up like `craft` does.
func add_xp(profession: String, n: int) -> int:
	if n <= 0 or not ProfessionDefs.PROFESSIONS.has(profession):
		return 0
	var before: int = level(profession)
	_save.profession_xp[profession] = xp(profession) + n
	_save._dirty = true
	var after: int = level(profession)
	if after > before:
		GameBus.profession_level_up.emit(profession, after)
		return after
	return 0
