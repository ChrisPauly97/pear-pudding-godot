## Well-fed buffs from cooked food (GID-182 / TID-763). Pure static math, no autoloads.
##
## A buff is `{food, stat, amount, fights}`, or `{}` for none, stored in
## `SaveManager.well_fed`. Eating a food with a `ProfessionDefs.WELL_FED` entry sets
## it. Each ordinary solo fight that starts while it is active takes one charge and
## adds `amount` max HP (`BattleModifiers._apply_well_fed`). The balance sim and
## the balance bands never apply it.
extends RefCounted

const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")

const STAT_MAX_HP: String = "max_hp"


## The buff a food sets when eaten, or `{}` for a food that gives none.
static func make(food_id: String) -> Dictionary:
	var spec: Dictionary = ProfessionDefs.WELL_FED.get(food_id, {})
	if spec.is_empty():
		return {}
	return {"food": food_id, "stat": str(spec.get("stat", "")), "amount": int(spec.get("amount", 0)),
			"fights": int(spec.get("fights", 0))}


static func active(buff: Dictionary) -> bool:
	return int(buff.get("amount", 0)) > 0 and int(buff.get("fights", 0)) > 0


## Max HP the buff adds to a fight that starts now (0 when inactive or another stat).
static func hp_bonus(buff: Dictionary) -> int:
	if not active(buff) or str(buff.get("stat", "")) != STAT_MAX_HP:
		return 0
	return int(buff.get("amount", 0))


## The buff after one fight consumed a charge; `{}` once the last charge is spent.
static func after_fight(buff: Dictionary) -> Dictionary:
	if not active(buff):
		return {}
	var left: int = int(buff.get("fights", 0)) - 1
	if left <= 0:
		return {}
	var out: Dictionary = buff.duplicate()
	out["fights"] = left
	return out


## HUD text for the active buff, "" when none.
static func describe(buff: Dictionary) -> String:
	if not active(buff):
		return ""
	var fights: int = int(buff.get("fights", 0))
	return "Well fed: +%d max HP, %d %s left" % [int(buff.get("amount", 0)), fights,
			"fight" if fights == 1 else "fights"]
