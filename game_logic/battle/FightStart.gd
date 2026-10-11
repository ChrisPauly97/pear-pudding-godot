## Hero state a solo PvE fight starts with (GID-187 / TID-781): the start HP fraction, the
## well-fed buff and the quick-slot potions. Pure, and the same calls the game makes:
## `BattleModifiers` (persistent HP, well fed) and `BattleSetup.build` (balance sim).
extends RefCounted

const HeroVitality = preload("res://game_logic/HeroVitality.gd")
const WellFed = preload("res://game_logic/professions/WellFed.gd")
const QuickSlots = preload("res://game_logic/battle/QuickSlots.gd")
const GardenDefs = preload("res://game_logic/GardenDefs.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

## Solo fight start HP (TID-543): the hero starts at `frac` of max HP, after every max-HP
## modifier. Never raises health.
static func apply_start_hp(player: PlayerState, frac: float) -> void:
	var hero := player.hero
	hero.health = mini(hero.health, HeroVitality.battle_start_hp(hero.max_health, frac))

## Well fed (TID-763): an active buff adds its max HP to the hero (and to current HP). Returns the
## buff after this fight took its charge (`{}` once spent); an inactive buff comes back unchanged.
static func apply_well_fed(player: PlayerState, buff: Dictionary) -> Dictionary:
	if not WellFed.active(buff):
		return buff
	var bonus: int = WellFed.hp_bonus(buff)
	player.hero.max_health += bonus
	player.hero.health += bonus
	return WellFed.after_fight(buff)

## A well-fed buff from a config value: a food id (its ProfessionDefs.WELL_FED buff, `{}` if none)
## or a buff dict as returned by an earlier fight.
static func well_fed_buff(v: Variant) -> Dictionary:
	if v is Dictionary:
		return v
	return WellFed.make(str(v))

## The quick-slot potions a fight can drink: the ids the two slots show for `potions` ({id: count},
## `QuickSlots.resolve`, the game's own top-up), legendary ones left out (they are never consumed).
static func potion_ids(potions: Dictionary, quick_slots: Array) -> Array[String]:
	var out: Array[String] = []
	for id: String in QuickSlots.resolve(quick_slots, potions):
		if id != "" and not GardenDefs.is_legendary(id):
			out.append(id)
	return out
