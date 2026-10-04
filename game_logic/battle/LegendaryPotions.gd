## Legendary potions (GID-153): never consumed, one sip per battle.
##
## Pure rules shared by the local drink (BattleConsumables) and the host applying a
## PvP client's drink (BattleNet). A fresh instance per battle is the "refill".
extends RefCounted

const HeroState = preload("res://game_logic/battle/HeroState.gd")
const StatusEffects = preload("res://game_logic/battle/StatusEffects.gd")

const PEAR_PUDDING: String = "pear_pudding"

var _sipped: Dictionary = {}


func can_sip(potion_id: String) -> bool:
	return not _sipped.has(potion_id)


func mark_sipped(potion_id: String) -> void:
	_sipped[potion_id] = true


## Perrine's Bottomless Pudding: full HP, ailments cleared, +1 mana.
static func apply_pear_pudding(hero: HeroState) -> void:
	hero.health = hero.max_health
	StatusEffects.clear_ailments(hero.status_effects)
	hero.gain_mana(1)
