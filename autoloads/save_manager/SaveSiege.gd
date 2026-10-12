## Town siege gauntlet: start, stage advance, hero HP, victory / defeat, and town
## discounts.
##
## Owned by SaveManager (`SaveManager.town_siege`), created in its `_init`. The state
## stays on SaveManager because PERSISTED_FIELDS walks its properties, so this
## reads and writes it through `_save.<field>`.
extends RefCounted

const _SaveManager = preload("res://autoloads/SaveManager.gd")
const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")

var _save: _SaveManager


func _init(save_manager: _SaveManager) -> void:
	_save = save_manager


## Starts a new siege for the given town at stage 0, full health (TID-783: HP carried as a fraction).
## Its raiders fight at `level` (default: the hero's level now) plus the stage's step (`SiegeDefs.stage_level`).
func start_siege(town: String, level: int = 0) -> void:
	_save.siege = {"town": town, "stage": 0, "hero_hp_frac": 1.0, "day_started": _save.days_elapsed,
		"level": level if level > 0 else _save.level}

## Enemy level of the current stage's raiders (TID-783). A siege saved before it uses the hero's level.
func stage_level() -> int:
	return _SiegeDefs.stage_level(int(_save.siege.get("level", _save.level)), int(_save.siege.get("stage", 0)))
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

## The siege's carried HP fraction (a siege saved before TID-783, with an absolute "hero_hp", reads 1.0).
func hp_frac() -> float:
	return clampf(float(_save.siege.get("hero_hp_frac", 1.0)), 0.0, 1.0)

## Stores the hero's HP fraction so it carries over to the next gauntlet stage.
func set_hp_frac(frac: float) -> void:
	if _save.siege.is_empty():
		return
	_save.siege["hero_hp_frac"] = clampf(frac, 0.0, 1.0)
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
