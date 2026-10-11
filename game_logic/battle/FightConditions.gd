## Battlefield conditions (GID-187 / TID-780): weather, biome and time-of-day school boosts,
## summon weather, desert scorch, blight, ambush and gambit handicaps. Pure: no autoloads, no
## scene tree. `BattleScene` / `BattleModifiers` / `BattleRealtime` / `BattleTargeting` /
## `BattleNet` / `RealtimeCombat` call these for the game, and `BattleSetup.build` calls them
## for the balance sim, so a condition means the same thing in both.
##
## The caller supplies the weather and the battlefield context: the game passes
## `WeatherManager`'s weather and the scene's biome / night, the sim passes its cfg keys
## (`weather`, `biome`, `is_night`, `blighted`, `ambush`, `gambit_id`).
extends RefCounted

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const DamageResolver = preload("res://game_logic/battle/DamageResolver.gd")
const DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")

## World-encounter ambush (GID-113 / TID-421, TID-422): the ambushed hero starts at
## (1 - AMBUSH_HP_PCT) of its max HP, never below AMBUSH_HP_MIN. Sets health and max_health both.
const AMBUSH_HP_PCT: float = 0.2
const AMBUSH_HP_MIN: int = 10
const AMBUSH_PLAYER: String = "player"
const AMBUSH_ENEMY: String = "enemy"
## Blighted zone buff: a non-blight-heart enemy gets this much HP.
const BLIGHT_HP: int = 5
## Ash fall / volcanic weather poisons the enemy hero at battle start.
const ASH_POISON: int = 2
## Desert scorch: physical damage to the leftmost minion each tick.
const SCORCH_DAMAGE: int = 1
## Summon weather: rain / heavy rain add this much HP to an enemy ghost; sand weather cuts
## attack from an enemy summon during the first SAND_TURNS turns.
const RAIN_GHOST_BONUS: Dictionary = {"rain": 1, "heavy_rain": 2}
const SAND_WEATHER: Array[String] = ["sandstorm", "dust_devil"]
const SAND_TURNS: int = 2
const SAND_ATTACK_CUT: int = 1

const GAMBIT_WOUNDED_PRIDE: String = "wounded_pride"
const GAMBIT_SLOW_START: String = "slow_start"
const GAMBIT_EMBOLDENED_FOE: String = "emboldened_foe"
const GAMBIT_IRON_VEIL: String = "iron_veil"
const WOUNDED_PRIDE_HP: int = 25
const IRON_VEIL_ARMOR: int = 5

# --- Battle start ---------------------------------------------------------

## Battle-start weather: ash fall / volcanic poisons the enemy hero.
static func apply_weather_start(state: GameState, weather: String) -> void:
	match weather:
		"ash_fall", "volcanic":
			state.players[1].hero.apply_status("poison", ASH_POISON)

## Stores this battlefield's school boosts (biome, weather, night) on every side. Call after
## `GameState.set_battlefield_context`, which stamps the biome and night.
static func apply_school_environment(state: GameState, weather: String) -> void:
	var table: Dictionary = BattlefieldRules.school_env_table(state.battlefield_biome, weather, state.is_night)
	for p: PlayerState in state.players:
		p.env_school_mult = table.duplicate()

## Blighted zone buff: +BLIGHT_HP on the foe's hero. The caller excludes blight hearts.
static func apply_blight(foe: PlayerState) -> void:
	foe.hero.health += BLIGHT_HP
	foe.hero.max_health += BLIGHT_HP

## Which side an enemy's ambush flag hits: AMBUSH_PLAYER (the enemy starts hurt), AMBUSH_ENEMY
## (the player starts hurt) or "". `player_ambush` wins if both are set (they never are).
static func ambush_side(enemy_data: Dictionary) -> String:
	if bool(enemy_data.get("player_ambush", false)):
		return AMBUSH_PLAYER
	if bool(enemy_data.get("enemy_ambush", false)):
		return AMBUSH_ENEMY
	return ""

## Applies an ambush side from `ambush_side` (no-op for ""). The hurt hero starts at
## (1 - AMBUSH_HP_PCT) of its max HP (min AMBUSH_HP_MIN), and that is its max from then on.
static func apply_ambush(state: GameState, side: String) -> void:
	if side == AMBUSH_PLAYER:
		_set_ambush_hp(state.players[1].hero)
	elif side == AMBUSH_ENEMY:
		_set_ambush_hp(state.players[0].hero)

static func _set_ambush_hp(hero: HeroState) -> void:
	var new_hp: int = maxi(AMBUSH_HP_MIN, int(round(hero.max_health * (1.0 - AMBUSH_HP_PCT))))
	hero.health = new_hp
	hero.max_health = new_hp

## Gambit handicaps on either side, applied once all decks and HP are set. Emboldened Foe is
## a deck bonus instead (`enemy_minion_attack_bonus`, set before the enemy deck is built).
static func apply_gambit_handicaps(state: GameState, gambit_id: String) -> void:
	match gambit_id:
		GAMBIT_WOUNDED_PRIDE:
			var hero: HeroState = state.players[0].hero
			hero.health = WOUNDED_PRIDE_HP
			hero.max_health = WOUNDED_PRIDE_HP
		GAMBIT_SLOW_START:
			state.players[0].skip_next_draw = true
		GAMBIT_IRON_VEIL:
			state.players[1].hero.apply_status("armor", IRON_VEIL_ARMOR)

## Attack added to every enemy minion (Emboldened Foe), else 0.
static func enemy_minion_attack_bonus(gambit_id: String) -> int:
	return 1 if gambit_id == GAMBIT_EMBOLDENED_FOE else 0

# --- During the fight -----------------------------------------------------

## Weather on a minion an enemy side just summoned: rain ghosts gain HP, sand weather cuts
## attack in the first turns. Call for minions only (not spells).
static func apply_summon_weather(card: CardInstance, weather: String, turn_number: int) -> void:
	if card.template_id == "ghost" and RAIN_GHOST_BONUS.has(weather):
		var bonus: int = int(RAIN_GHOST_BONUS[weather])
		card.health += bonus
		card.max_health += bonus
	elif SAND_WEATHER.has(weather) and turn_number <= SAND_TURNS:
		card.attack = maxi(0, card.attack - SAND_ATTACK_CUT)

## Desert scorch applies: the battle is in the desert and it is daytime.
static func scorch_active(state: GameState) -> bool:
	return state.battlefield_biome == BattlefieldRules.BIOME_DESERT and not state.is_night

## One scorch tick on `p`: SCORCH_DAMAGE physical damage to its leftmost minion. A minion it
## kills goes to the discard and is returned (null otherwise, or on an empty board).
static func scorch_leftmost(p: PlayerState, tune: CombatTuning = null) -> CardInstance:
	for si in range(5):
		var c: CardInstance = p.board.slots[si]
		if c != null:
			DamageResolver.deal(p, c, SCORCH_DAMAGE, DamageSchools.PHYSICAL, tune)
			if c.is_alive():
				return null
			p.board.remove_card(c)
			p.discard.append(c)
			return c
	return null

## Turn-based turn start: scorch the leftmost minion of each of the first two sides.
static func apply_desert_scorch(state: GameState) -> void:
	for pid in mini(2, state.players.size()):
		scorch_leftmost(state.players[pid])
