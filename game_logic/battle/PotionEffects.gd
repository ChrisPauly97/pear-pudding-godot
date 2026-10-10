## Hero-only potion effects (GID-182 / TID-764), shared by the local drink
## (BattleConsumables) and the PvP host applying a client's drink (BattleNet).
##
## Pure: no scene, no autoloads. Clarity Brew (draws cards) and Pear Pudding
## (legendary gate) stay in their callers because they touch the deck / the
## per-battle sip gate.
extends RefCounted

const HeroState = preload("res://game_logic/battle/HeroState.gd")
const StatusEffects = preload("res://game_logic/battle/StatusEffects.gd")

const HEAL_HP: int = 8
const EMBER_MANA: int = 1
const STONESKIN_ARMOR: int = 4
const MANA_DRAUGHT_MANA: int = 2

## Potion id → floating label text and colour in the battle view.
const FLOATS: Dictionary = {
	"healing_draught": {"text": "+8 HP", "color": Color(0.267, 1.0, 0.533)},
	"ember_tonic": {"text": "+1 Mana", "color": Color(0.4, 0.8, 1.0)},
	"stoneskin_tonic": {"text": "+4 Armor", "color": Color(0.8, 0.82, 0.92)},
	"cleansing_salve": {"text": "Cured", "color": Color(0.6, 1.0, 0.6)},
	"mana_draught": {"text": "+2 Mana", "color": Color(0.4, 0.8, 1.0)},
}


## Applies a hero-only potion to `hero`. Returns false (and changes nothing) for
## an id this module does not own, so callers can handle the rest themselves.
static func apply_hero(potion_id: String, hero: HeroState) -> bool:
	match potion_id:
		"healing_draught":
			hero.health = mini(hero.health + HEAL_HP, hero.max_health)
		"ember_tonic":
			hero.gain_mana(EMBER_MANA)
		"stoneskin_tonic":
			hero.add_armor(STONESKIN_ARMOR)
		"cleansing_salve":
			StatusEffects.clear_ailments(hero.status_effects)
		"mana_draught":
			hero.gain_mana(MANA_DRAUGHT_MANA)
		_:
			return false
	return true
