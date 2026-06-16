## Static helpers for weapon upgrade levels: cost curve, stat scaling, display strings.
extends RefCounted

const WeaponData = preload("res://data/WeaponData.gd")

## Coin cost to upgrade from level N to N+1 (index = current level, 0-based).
const UPGRADE_COST_COINS: Array[int] = [100, 200, 300, 400, 500]
## Essence cost to upgrade from level N to N+1.
const UPGRADE_COST_ESSENCE: Array[int] = [5, 10, 15, 20, 25]

const MAX_LEVEL: int = 5

## Salvage return values (flat amounts; not affected by upgrade level).
const SALVAGE_COINS: int = 30
const SALVAGE_ESSENCE: int = 3

## Returns the scaled battle_effect_value for starting_mana / starting_hp / passive_atk.
static func effective_stat(weapon: WeaponData, level: int) -> int:
	if weapon == null:
		return 0
	return int(weapon.battle_effect_value * (1.0 + 0.10 * level))

## Returns the scaled injected_card_count for deck_inject weapons (base + level extra copies).
static func effective_inject_count(weapon: WeaponData, level: int) -> int:
	if weapon == null:
		return 0
	return weapon.injected_card_count + level

## Returns true if coins and essence cover the next upgrade from current_level to current_level+1.
static func can_afford_upgrade(current_level: int, coins: int, essence: int) -> bool:
	if current_level < 0 or current_level >= UPGRADE_COST_COINS.size():
		return false
	return coins >= UPGRADE_COST_COINS[current_level] and essence >= UPGRADE_COST_ESSENCE[current_level]

## Coin cost to go from current_level to current_level+1 (0 if already max).
static func cost_coins(current_level: int) -> int:
	if current_level < 0 or current_level >= UPGRADE_COST_COINS.size():
		return 0
	return UPGRADE_COST_COINS[current_level]

## Essence cost to go from current_level to current_level+1 (0 if already max).
static func cost_essence(current_level: int) -> int:
	if current_level < 0 or current_level >= UPGRADE_COST_ESSENCE.size():
		return 0
	return UPGRADE_COST_ESSENCE[current_level]

## Human-readable stats line for a weapon at the given upgrade level.
## Used by BlacksmithScene and CharacterScene for consistent display.
static func get_display_string(weapon: WeaponData, level: int) -> String:
	if weapon == null:
		return ""
	match weapon.battle_effect_type:
		"deck_inject":
			return "Inject %d× %s" % [effective_inject_count(weapon, level), weapon.injected_card_id]
		"starting_mana":
			return "+%d starting mana" % effective_stat(weapon, level)
		"starting_hp":
			return "+%d starting HP" % effective_stat(weapon, level)
		"passive_atk":
			return "+%d hero ATK" % effective_stat(weapon, level)
	return weapon.battle_effect_type
