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

## Potion id → {display_name, description}. Brewed by the Alchemy profession
## (`ProfessionDefs.RECIPES`, TID-764); the battle effects live in
## `game_logic/battle/PotionEffects.gd` (hero-only) and `BattleConsumables`.
const POTIONS: Dictionary = {
	"healing_draught": {"display_name": "Healing Draught", "description": "Battle: restore 8 HP."},
	"clarity_brew": {"display_name": "Clarity Brew", "description": "Battle: draw 2 cards."},
	"ember_tonic": {"display_name": "Ember Tonic", "description": "Battle: gain 1 mana."},
	"stoneskin_tonic": {"display_name": "Stoneskin Tonic",
		"description": "Battle: gain 4 armor, soaking the next 4 damage."},
	"cleansing_salve": {"display_name": "Cleansing Salve",
		"description": "Battle: cure poison, freeze and stun."},
	"mana_draught": {"display_name": "Mana Draught", "description": "Battle: gain 2 mana."},
	# GID-153: the one legendary potion, from the secret Pear Pudding legend. Never brewed
	# here (no recipe), never consumed — refills every battle, one sip each (LegendaryPotions).
	"pear_pudding": {"display_name": "Perrine's Bottomless Pudding", "essence_cost": 0, "legendary": true,
		"description": "Legendary. Never empties: one sip per battle restores full HP, clears ailments, +1 mana."},
}

## True for a potion that is never consumed (GID-153).
static func is_legendary(potion_id: String) -> bool:
	var info: Dictionary = POTIONS.get(potion_id, {})
	return bool(info.get("legendary", false))


## Returns the growth stage for a planted plot.
## 0 is never returned here — callers should check plot emptiness before calling.
## 1 = early growth, 2 = mid growth, 3 = mature (ready to harvest).
static func growth_stage(planted_day: int, growth_days: int, current_days_elapsed: int) -> int:
	var age: int = current_days_elapsed - planted_day
	if age >= growth_days:
		return 3
	return 1 + age / max(1, growth_days - 1)
