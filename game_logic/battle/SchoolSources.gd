## A hero's school power and school resistance sources (GID-181 / TID-754), from equipped items'
## school affixes, gear resist stats and skill nodes. Split out of `BattleSetup` (TID-779); the game
## (`BattleModifiers`) and the sim (`BattleSetup.build`) both call it. Pure.
extends RefCounted

const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const SkillMods = preload("res://game_logic/battle/SkillMods.gd")
const DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const GearStats = preload("res://game_logic/items/GearStats.gd")

## GID-181 / TID-754: the player's outgoing school power and weapon convert, from the
## equipped items' school affixes (`items[i].affix`, see GearRolls) and the unlocked
## school_power nodes. Any fight mode. Sets `player.school_power` (school → fraction)
## and `player.convert_school`. Affixes add on top of the stat rolls.
static func apply_school_power(player: PlayerState, items: Array[Dictionary], skill_ids: Array) -> void:
	for item: Dictionary in items:
		var affix: Dictionary = _affix_of(item)
		match str(affix.get("kind", "")):
			"school_dmg":
				_add_school(player.school_power, str(affix["school"]), float(affix.get("pct", 0.0)))
			"convert":
				player.convert_school = str(affix["school"])
	var nodes: Dictionary = SkillMods.school_nodes(skill_ids, "school_power")
	for k: Variant in nodes.keys():
		_add_school(player.school_power, str(k), float(int(nodes[k])) / 100.0)

## GID-181 / TID-754: the hero's school resistance sources, uncapped: school → summed
## fraction from equipped school_resist affixes and school_resist nodes. Pass the result
## through `DamageSchools.capped_resists`, which clamps it to `max_player_resist`.
static func resist_sources(items: Array[Dictionary], skill_ids: Array, gear_conv: Dictionary = {}) -> Dictionary:
	var out: Dictionary = GearStats.resist_sources(gear_conv)  # GID-187 / TID-788: resist:<school> stats
	for item: Dictionary in items:
		var affix: Dictionary = _affix_of(item)
		if str(affix.get("kind", "")) == "school_resist":
			_add_school(out, str(affix["school"]), float(affix.get("pct", 0.0)))
	var nodes: Dictionary = SkillMods.school_nodes(skill_ids, "school_resist")
	for k: Variant in nodes.keys():
		_add_school(out, str(k), float(int(nodes[k])) / 100.0)
	return out

static func _affix_of(item: Dictionary) -> Dictionary:
	var v: Variant = item.get("affix", {})
	if v is Dictionary:
		return v
	return {}

static func _add_school(table: Dictionary, school: String, amount: float) -> void:
	if not DamageSchools.is_school(school):
		return
	table[school] = float(table.get(school, 0.0)) + amount
