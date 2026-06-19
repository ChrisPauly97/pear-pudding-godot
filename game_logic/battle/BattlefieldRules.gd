extends RefCounted

## Biome id constants (mirrors BiomeDef — kept here so callers need no extra preload).
const BIOME_NONE:       int = -1
const BIOME_GRASSLANDS: int = 0
const BIOME_FOREST:     int = 1
const BIOME_DESERT:     int = 2
const BIOME_SCORCHED:   int = 3
const BIOME_MOUNTAINS:  int = 4

## Rule key strings used to identify each rule in code.
const RULE_NONE:       String = "none"
const RULE_GRASSLANDS: String = "grasslands"
const RULE_FOREST:     String = "forest"
const RULE_DESERT:     String = "desert"
const RULE_SCORCHED:   String = "scorched"
const RULE_MOUNTAINS:  String = "mountains"

const _Keywords = preload("res://game_logic/battle/Keywords.gd")

## Data-driven rules table keyed by biome id.
## -1 = dungeon / named map (no rule).
## slot_highlights: slot indices to mark in the BattleScene UI.
const RULES: Dictionary = {
	-1: {
		"name": "Dungeon",
		"rule_key": RULE_NONE,
		"rule_text": "No battlefield rule.",
		"slot_highlights": [],
	},
	0: {
		"name": "Grasslands",
		"rule_key": RULE_GRASSLANDS,
		"rule_text": "First card played each turn costs 1 less (min 0).",
		"slot_highlights": [],
	},
	1: {
		"name": "Forest",
		"rule_key": RULE_FOREST,
		"rule_text": "Minions in edge slots (0 and 4) gain Shroud.",
		"slot_highlights": [0, 4],
	},
	2: {
		"name": "Desert",
		"rule_key": RULE_DESERT,
		"rule_text": "At turn start (daytime only), the leftmost minion on each board takes 1 damage.",
		"slot_highlights": [],
	},
	3: {
		"name": "Scorched",
		"rule_key": RULE_SCORCHED,
		"rule_text": "All combat and spell damage is increased by 1.",
		"slot_highlights": [],
	},
	4: {
		"name": "Mountains",
		"rule_key": RULE_MOUNTAINS,
		"rule_text": "Minions in the center slot (2) gain Ward.",
		"slot_highlights": [2],
	},
}

## Returns the biome display name.
static func get_biome_name(biome_id: int) -> String:
	var entry: Dictionary = RULES.get(biome_id, RULES[BIOME_NONE]) as Dictionary
	return str(entry.get("name", "Unknown"))

## Returns the rule key string.
static func get_rule_key(biome_id: int) -> String:
	var entry: Dictionary = RULES.get(biome_id, RULES[BIOME_NONE]) as Dictionary
	return str(entry.get("rule_key", RULE_NONE))

## Returns the human-readable rule description.
static func get_rule_text(biome_id: int) -> String:
	var entry: Dictionary = RULES.get(biome_id, RULES[BIOME_NONE]) as Dictionary
	return str(entry.get("rule_text", ""))

## Returns slot indices that should be highlighted in the UI for this biome.
static func get_slot_highlights(biome_id: int) -> Array[int]:
	var entry: Dictionary = RULES.get(biome_id, RULES[BIOME_NONE]) as Dictionary
	var raw: Array = entry.get("slot_highlights", []) as Array
	var result: Array[int] = []
	for v in raw:
		result.append(int(v))
	return result

## Applies the Scorched +1 damage modifier.
## Use at every combat / spell damage call site.
## Status ticks (poison, Desert scorch, fatigue) are intentionally excluded.
static func modify_damage(base_dmg: int, biome_id: int) -> int:
	if biome_id == BIOME_SCORCHED:
		return base_dmg + 1
	return base_dmg

## Computes the effective mana cost of a card, applying biome and time-of-day rules.
## Stacking order: branch discount (dawn/dusk) first, then Grasslands first-card discount.
## Floor is 0.
static func effective_cost(card_cost: int, card_branch: String, biome_id: int, is_night: bool, grasslands_card_played: bool) -> int:
	var cost: int = card_cost
	if is_night and card_branch == "dusk":
		cost -= 1
	elif not is_night and card_branch == "dawn":
		cost -= 1
	if biome_id == BIOME_GRASSLANDS and not grasslands_card_played:
		cost -= 1
	return maxi(0, cost)

## Grants slot-based keywords for Forest (edge slots → Shroud) and Mountains (center slot → Ward).
## Call after a minion is placed on the board; slot_idx is the index in ZoneState.slots.
## No-op for other biomes or non-matching slots.
static func apply_slot_rule(card: Object, slot_idx: int, biome_id: int) -> void:
	match biome_id:
		BIOME_FOREST:
			if slot_idx == 0 or slot_idx == 4:
				var kw: Array = card.get("keywords") as Array
				if not kw.has(_Keywords.SHROUD):
					kw.append(_Keywords.SHROUD)
				card.set("shroud_active", true)
		BIOME_MOUNTAINS:
			if slot_idx == 2:
				var kw: Array = card.get("keywords") as Array
				if not kw.has(_Keywords.WARD):
					kw.append(_Keywords.WARD)

## Night predicate: sin((time_of_day − 0.25) × TAU) < 0
## i.e. time_of_day < 0.25 or time_of_day > 0.75.
static func compute_is_night(time_of_day: float) -> bool:
	return sin((time_of_day - 0.25) * TAU) < 0.0
