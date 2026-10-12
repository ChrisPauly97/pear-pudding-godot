## Hero state a solo PvE fight starts with (GID-187 / TID-781): the start HP fraction, the
## well-fed buff, the quick-slot potions and the companion's passive (TID-779). Pure, and the same
## calls the game makes: `BattleModifiers` (persistent HP, well fed, companion) and `BattleSetup.build`.
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

## GID-187 / TID-779: a companion passive at battle start (`BattleModifiers` and the sim):
## extra_mana / hero_armor once; draw_card draws `value` cards (the game repeats the draw at every
## turn start in turn-based fights, once in real time). `draw` false skips the draw part.
static func apply_companion(player: PlayerState, passive_type: String, value: int, draw: bool = true) -> void:
	match passive_type:
		"extra_mana":
			player.hero.gain_mana(value, true)
		"hero_armor":
			player.hero.add_armor(value)
		"draw_card":
			if draw:
				companion_draw(player, value)

## The companion's turn-start draw (`draw_card` passive).
static func companion_draw(player: PlayerState, value: int) -> void:
	for _i in range(value):
		player.draw_card(false)
