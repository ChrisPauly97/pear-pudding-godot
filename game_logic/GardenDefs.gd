## Static definitions for the garden system (GID-056 TID-203).
## Seed → plant → potion pipeline constants and growth-stage math.
extends Object

const SEEDS: Dictionary = {
	"sunpetal": {
		"display_name": "Sunpetal",
		"growth_days": 2,
		"yield": 1,
		"plant_id": "sunpetal_plant",
	},
	"moonroot": {
		"display_name": "Moonroot",
		"growth_days": 3,
		"yield": 2,
		"plant_id": "moonroot_plant",
	},
	"embercap": {
		"display_name": "Embercap",
		"growth_days": 2,
		"yield": 2,
		"plant_id": "embercap_plant",
	},
}

const PLANTS: Dictionary = {
	"sunpetal_plant": {"display_name": "Sunpetal",  "sell_value": 20, "description": "A warm golden bloom."},
	"moonroot_plant": {"display_name": "Moonroot",  "sell_value": 25, "description": "A pale, cool-glowing root."},
	"embercap_plant": {"display_name": "Embercap",  "sell_value": 25, "description": "A mushroom that smoulders."},
}

const POTIONS: Dictionary = {
	"healing_draught": {"display_name": "Healing Draught", "essence_cost": 0, "description": "Battle: restore 8 HP."},
	"clarity_brew":    {"display_name": "Clarity Brew",    "essence_cost": 0, "description": "Battle: draw 2 cards."},
	"ember_tonic":     {"display_name": "Ember Tonic",     "essence_cost": 0, "description": "Battle: gain 1 mana."},
}

const POTION_RECIPES: Dictionary = {
	"healing_draught": {
		"display_name": "Healing Draught",
		"essence_cost": 5,
		"ingredients": {"sunpetal_plant": 2},
	},
	"clarity_brew": {
		"display_name": "Clarity Brew",
		"essence_cost": 5,
		"ingredients": {"moonroot_plant": 2},
	},
	"ember_tonic": {
		"display_name": "Ember Tonic",
		"essence_cost": 5,
		"ingredients": {"embercap_plant": 2},
	},
}

## Returns the growth stage for a planted plot.
## 0 is never returned here — callers should check plot emptiness before calling.
## 1 = early growth, 2 = mid growth, 3 = mature (ready to harvest).
static func growth_stage(planted_day: int, growth_days: int, current_days_elapsed: int) -> int:
	var age: int = current_days_elapsed - planted_day
	if age >= growth_days:
		return 3
	return 1 + age / max(1, growth_days - 1)
