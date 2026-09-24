## Town siege gauntlet: start, stage advance, hero HP, victory / defeat, and town
## discounts.
##
## Owned by SaveManager (`SaveManager.town_siege`), created in its `_init`. The state
## stays on SaveManager because PERSISTED_FIELDS walks its properties, so this
## reads and writes it through `_save.<field>`.
extends RefCounted

var _save: Node


func _init(save_manager: Node) -> void:
	_save = save_manager


## Starts a new siege for the given town. Initialises stage 0, hero_hp 30.
func start_siege(town: String) -> void:
	_save.siege = {"town": town, "stage": 0, "hero_hp": 30, "day_started": _save.days_elapsed}
	_save._dirty = true

## Returns the active siege dict, or {} when no siege is in progress.
func get_active_siege() -> Dictionary:
	return _save.siege

## Advances the siege stage by 1 (0 → 1 → 2). No-op if siege is empty.
func advance_siege_stage() -> void:
	if _save.siege.is_empty():
		return
	_save.siege["stage"] = int(_save.siege.get("stage", 0)) + 1
	_save._dirty = true

## Stores the player's hero HP so it carries over to the next gauntlet stage.
func set_siege_hero_hp(hp: int) -> void:
	if _save.siege.is_empty():
		return
	_save.siege["hero_hp"] = hp
	_save._dirty = true

## Records a siege win: updates last_siege_day, applies town discount, clears active siege.
func end_siege_victory() -> void:
	var town: String = str(_save.siege.get("town", ""))
	_save.last_siege_day = _save.days_elapsed
	if town != "":
		apply_town_discount(town)
	_save.siege = {}
	_save._dirty = true

## Records a siege loss: updates last_siege_day, clears active siege (no discount).
func end_siege_defeat() -> void:
	_save.last_siege_day = _save.days_elapsed
	_save.siege = {}
	_save._dirty = true

## Applies a 3-day gratitude discount to the named town.
func apply_town_discount(town: String) -> void:
	_save.town_discounts[town] = _save.days_elapsed + 3
	_save._dirty = true

## Returns true if the named town currently has an active gratitude discount.
func is_town_discounted(town: String) -> bool:
	return int(_save.town_discounts.get(town, -1)) >= _save.days_elapsed
