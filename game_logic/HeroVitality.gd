## Persistent hero HP between fights (GID-136 / TID-543, decision 3 of TID-540).
##
## Saved as a fraction of max HP (`SaveManager.hero_hp_frac`, 1.0 = full), so a
## gear change that raises max HP never "wounds" the hero. Ordinary solo fights
## start at that fraction and write it back when they end; slow out-of-combat
## regen, food, a world healing draught, towns and the home bed restore it.
## Pure — the world module `HeroHealth.gd` and `BattleModifiers` drive it.
extends RefCounted

## Seconds for out-of-combat regen to go from empty to full (from REGEN_FULL_LEVEL on).
const REGEN_FULL_SECONDS: float = 240.0
## A level-1 hero refills this fast, so the starter zone never strands them (BID-085);
## the time grows linearly to REGEN_FULL_SECONDS at REGEN_FULL_LEVEL.
const REGEN_NEW_SECONDS: float = 45.0
const REGEN_FULL_LEVEL: int = 10
## Food every new character starts with (food id -> count).
const STARTER_FOODS: Dictionary = {"travel_bread": 3}
## HP fraction after a lost fight (respawn or retry).
const RESPAWN_FRAC: float = 0.5
## Dungeon rest site "Rest" (was a display-only +8 of 30 before TID-543).
const REST_SITE_HEAL: float = 8.0 / 30.0
## Healing draught drunk outside a fight: same +8 HP it gives in battle, of 30.
const WORLD_POTION_HEAL: Dictionary = {"healing_draught": 8.0 / 30.0}

## Food: eaten out of combat, heals `heal` (fraction of max) over `seconds`;
## taking damage or starting a fight interrupts the meal. Sold by merchants.
const FOODS: Dictionary = {
	"travel_bread": {"display_name": "Travel Bread", "price": 8, "heal": 0.4, "seconds": 10.0,
			"description": "Out of combat: eat to restore 40% HP over 10 s."},
	"roast_fowl": {"display_name": "Roast Fowl", "price": 20, "heal": 1.0, "seconds": 15.0,
			"description": "Out of combat: eat to restore all HP over 15 s."},
}

## Enemy types whose fights never touch persistent HP (practice).
const EXEMPT_ENEMY_TYPES: Array[String] = ["training_dummy"]


## Whether a solo fight reads and writes persistent HP. Spire runs and sieges
## keep their own HP, and duels, puzzles, scripted story fights and practice
## are consequence-free.
static func carries_over(enemy_data: Dictionary, spire_active: bool, siege_active: bool,
		friendly_duel: bool) -> bool:
	if spire_active or siege_active or friendly_duel:
		return false
	return not EXEMPT_ENEMY_TYPES.has(str(enemy_data.get("enemy_type", "")))


## Starting HP for a fight: the saved fraction of `max_hp`, at least 1.
static func battle_start_hp(max_hp: int, frac: float) -> int:
	return clampi(ceili(float(max_hp) * clampf(frac, 0.0, 1.0)), 1, maxi(1, max_hp))


## The fraction to save after a fight: what's left on a win, RESPAWN_FRAC on a loss.
static func frac_after(hp: int, max_hp: int, won: bool) -> float:
	if not won:
		return RESPAWN_FRAC
	return clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)


## Out-of-combat damage of `points` HP on the 30-HP base (dungeon events); never below 1 HP.
static func hurt(frac: float, points: int) -> float:
	return maxf(1.0 / 30.0, frac - float(points) / 30.0)


## Seconds for regen to go from empty to full at hero `level`.
static func regen_seconds(level: int) -> float:
	var t: float = clampf(float(level - 1) / float(REGEN_FULL_LEVEL - 1), 0.0, 1.0)
	return lerpf(REGEN_NEW_SECONDS, REGEN_FULL_SECONDS, t)


## Out-of-combat regen over `delta` seconds, plus `meal_rate` (fraction per second).
static func regen(frac: float, delta: float, meal_rate: float = 0.0,
		full_seconds: float = REGEN_FULL_SECONDS) -> float:
	return minf(1.0, frac + delta * (1.0 / full_seconds + meal_rate))


## Fraction per second a food heals while eaten.
static func meal_rate(food_id: String) -> float:
	var f: Dictionary = FOODS.get(food_id, {})
	if f.is_empty():
		return 0.0
	return float(f.get("heal", 0.0)) / maxf(0.1, float(f.get("seconds", 1.0)))


## What the world quick-use (Q) should consume when hurt: food first (cheaper,
## heals more), else a world-usable potion; "" when there is nothing to use.
static func best_world_item(foods: Dictionary, potions: Dictionary) -> String:
	for id: String in FOODS:
		if int(foods.get(id, 0)) > 0:
			return id
	for id: String in WORLD_POTION_HEAL:
		if int(potions.get(id, 0)) > 0:
			return id
	return ""
