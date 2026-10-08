## What an ordinary solo PvE fight starts with (GID-176 / TID-714), pure so the
## balance simulator builds the same fight the game does. `BattleScene`,
## `BattleModifiers` and `BattleRealtime.maybe_start` call these pieces with
## values read from the save; `build()` assembles a whole real-time fight from
## a plain config for `tools/balance_sim.gd`.
##
## Not covered (scene-only, see BID-094): spire / siege HP carry-over, gambits,
## ambush, blight, weather, battlefield biome, companions, persistent hero HP.
extends RefCounted

const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const CombatOnboarding = preload("res://game_logic/battle/CombatOnboarding.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
const EnemyTraits = preload("res://game_logic/battle/EnemyTraits.gd")
const ZoneLevels = preload("res://game_logic/world/ZoneLevels.gd")
const UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const SkillRegistry = preload("res://autoloads/SkillRegistry.gd")
const SkillData = preload("res://data/SkillData.gd")

const OPENING_HAND: int = 4

# --- Player ---------------------------------------------------------------

## GID-141 / TID-588: Ally (minion) cards stay out of the battle deck until
## `feat_minions`, spells until `feat_spells`; technique cards (GID-175) always stay.
static func unlock_filter(deck: Array[CardInstance], learned: Array) -> Array[CardInstance]:
	var minions: bool = CombatOnboarding.shows_hand(learned)
	var spells: bool = CombatOnboarding.allows_spells(learned)
	if minions and spells:
		return deck
	var kept: Array[CardInstance] = []
	for c: CardInstance in deck:
		if TechniqueDefs.is_technique(c.template_id):
			kept.append(c)
		elif c.card_class == "spell" and spells:
			kept.append(c)
		elif c.card_class != "spell" and minions:
			kept.append(c)
	return kept

## Equipped items' battle effects. `items`: [{id, level (weapon upgrade), mult (gear roll)}].
## Off-hand attack gear swings on its own timer in real time (RealtimeCombat.offhand_damage,
## see `offhand_damage_for_item`); turn-based gets a smaller always-on attack bonus instead.
static func apply_gear(player: PlayerState, items: Array[Dictionary], realtime: bool) -> void:
	var injected_any: bool = false
	for item: Dictionary in items:
		var weapon: WeaponData = WeaponRegistry.get_weapon(str(item.get("id", "")))
		if weapon == null:
			continue
		var level: int = int(item.get("level", 0))
		var gm: float = float(item.get("mult", 1.0))
		match weapon.battle_effect_type:
			"deck_inject":
				var count: int = UpgradeDefs.effective_inject_count(weapon, level)
				for _i in count:
					var tmpl: Dictionary = CardRegistry.get_template(weapon.injected_card_id)
					if tmpl.is_empty():
						continue
					player.draw_deck.append(CardInstance.new(tmpl))
				injected_any = true
			"starting_mana":
				player.hero.bonus_mana += UpgradeDefs.effective_stat(weapon, level, gm)
			"starting_hp":
				var hp_bonus: int = UpgradeDefs.effective_stat(weapon, level, gm)
				player.hero.health += hp_bonus
				player.hero.max_health += hp_bonus
			"passive_atk":
				player.hero.attack += UpgradeDefs.effective_stat(weapon, level, gm)
			"starting_armor":
				player.hero.add_armor(UpgradeDefs.effective_stat(weapon, level, gm))
			"offhand_atk":
				if not realtime:
					var offhand_val: int = UpgradeDefs.effective_stat(weapon, level, gm)
					player.hero.attack += UpgradeDefs.offhand_turnbased_bonus(offhand_val)
	if injected_any:
		player.draw_deck.shuffle()

## Unlocked passive skills (SkillRegistry, skill_type "passive").
static func apply_passives(player: PlayerState, skill_ids: Array) -> void:
	for v: Variant in skill_ids:
		var skill: SkillData = SkillRegistry.get_skill(str(v))
		if skill == null or skill.skill_type != "passive":
			continue
		match skill.effect_type:
			"passive_hp":
				player.hero.health += skill.effect_value
				player.hero.max_health += skill.effect_value
			"passive_mana":
				player.hero.bonus_mana += skill.effect_value
			"passive_atk":
				player.hero.attack += skill.effect_value
			"passive_draw":
				player.bonus_draw += skill.effect_value

## Off-hand swing damage for an equipped item (TID-545): 0 for none or a
## non-attack off-hand.
static func offhand_damage_for_item(item_id: String, mult: float = 1.0) -> int:
	if item_id == "":
		return 0
	var weapon := WeaponRegistry.get_weapon(item_id)
	if weapon == null or weapon.battle_effect_type != "offhand_atk":
		return 0
	return UpgradeDefs.effective_stat(weapon, 0, mult)

## Main-hand swing speed for an equipped weapon (0 = unarmed).
static func weapon_speed_for_item(item_id: String) -> float:
	var w := WeaponRegistry.get_weapon(item_id)
	return w.swing_speed if w != null else 0.0

# --- Enemy ----------------------------------------------------------------

## A type's base fight tier. Types with an authored level range (Chapter 1)
## fight at tier 1 and take their strength from their level (GID-176 / TID-718);
## the rest keep their difficulty tier. Drops / bestiary still read the authored tier.
static func base_tier(enemy_type: String) -> int:
	if enemy_type == "" or EnemyRegistry.LEVEL_RANGES.has(enemy_type):
		return 1
	return EnemyRegistry.get_difficulty_tier(enemy_type)

## Enemy card tier: the type's base fight tier (boss → 4), raised by zone level.
static func enemy_tier(enemy_type: String, is_boss: bool, enemy_level: int) -> int:
	var tier: int = base_tier(enemy_type)
	if is_boss:
		tier = 4
	return ZoneLevels.scaled_tier(tier, enemy_level)

## Real-time enemy level-equivalent for mana (TID-536): tier 1 → 1, each tier +3.
static func enemy_level_for_tier(tier: int) -> int:
	return 1 + maxi(0, tier - 1) * 3

## Builds the enemy side: its (trait-shaped) deck scaled to `tier`, opening
## hand, the pack on the board, boss HP and zone-level HP. Set
## `enemy.minion_attack_bonus` (gambits) before calling.
static func setup_enemy(enemy: PlayerState, player: PlayerState, enemy_type: String, deck: Array[String],
		tier: int, enemy_level: int, boss_hp: int = 0) -> void:
	if not deck.is_empty():  # no deck given: keep GameState's default one
		enemy.build_deck(mirror_deck(enemy_type, deck, player), tier)
		enemy.draw_opening_hand(OPENING_HAND)
	place_pack(enemy, enemy_type, tier)
	if boss_hp > 0:
		enemy.hero.health = boss_hp
		enemy.hero.max_health = boss_hp
	if enemy_level > 1:
		var hp: int = ZoneLevels.scaled_hero_hp(enemy.hero.max_health, enemy_level)
		enemy.hero.health = hp
		enemy.hero.max_health = hp

## Enemy deck after deck-shaping traits (mirror: the player's own spells — GID-149).
static func mirror_deck(enemy_type: String, deck: Array[String], player: PlayerState) -> Array[String]:
	if not EnemyRegistry.get_traits(enemy_type).has("mirror"):
		return deck
	var spells: Array[String] = []
	for c: CardInstance in player.draw_deck + player.hand:
		if c.card_class == "spell" and not spells.has(c.template_id):
			spells.append(c.template_id)
	return EnemyTraits.mirror_deck(deck, spells)

## Puts `enemy_type`'s pack on the enemy board, scaled to `tier` (TID-541). A
## leaderless pack (BID-077) has no hero to hit: clear its board to win.
static func place_pack(enemy: PlayerState, enemy_type: String, tier: int) -> void:
	for cid: String in EnemyRegistry.get_pack(enemy_type):
		if not EnemyTraits.place(enemy, EnemyTraits.make_unit(cid, tier, enemy.minion_attack_bonus)):
			break
	enemy.hero.leaderless = EnemyRegistry.is_leaderless(enemy_type) and not enemy.board.get_cards().is_empty()

## Start of enemy round `round_n`: howl / brood / frenzy fight traits (GID-149).
## Returns the lines to show.
static func enemy_round(state: GameState, enemy_type: String, tier: int, round_n: int) -> Array[String]:
	var traits: Array[String] = EnemyRegistry.get_traits(enemy_type)
	if traits.is_empty() or state.players.size() < 2:
		return []
	return EnemyTraits.on_enemy_round(state, 1, traits, round_n, tier)

# --- Real time ------------------------------------------------------------

## Caps, opening hand and gear timers on a fresh `RealtimeCombat` (what
## `BattleRealtime.maybe_start` applies). Enemy behaviour depends only on the
## **enemy's** level (GID-176 / TID-720): heavy blows from `heavy_min_level` (and
## softer below `enemy_full_level`), a second minion from `enemy_two_minions_level`
## — never on what the player has learned. Player-side caps follow the player's level.
static func configure_realtime(rt: RealtimeCombat, player_level: int, enemy_type: String,
		weapon_speed: float, offhand_damage: int, puzzle: bool = false) -> void:
	rt.heavy_enabled = not puzzle
	var enemy_level: int = rt.side_levels[RealtimeCombat.ENEMY]
	var cap: int = 1 if enemy_level < rt.tune.get_i("enemy_two_minions_level") else RealtimeCombat.MAX_ENEMY_MINIONS
	# A leaderless horde is its units: it refills up to its pack size from its deck,
	# so it reinforces as you cut it down instead of being three free kills (BID-095).
	if EnemyRegistry.is_leaderless(enemy_type):
		cap = maxi(cap, EnemyRegistry.get_pack(enemy_type).size())
	rt.set_enemy_minion_cap(cap)
	# Early fights stay small: fewer Allies, a short opening hand.
	rt.set_ally_cap(CombatOnboarding.ally_cap(player_level))
	rt.trim_hand(RealtimeCombat.PLAYER, CombatOnboarding.opening_hand(player_level))
	techniques_to_hand(rt.state.players[RealtimeCombat.PLAYER])
	rt.weapon_speed[RealtimeCombat.PLAYER] = weapon_speed
	rt.offhand_damage[RealtimeCombat.PLAYER] = offhand_damage
	if EnemyRegistry.is_passive(enemy_type):
		rt.set_passive(RealtimeCombat.ENEMY)
	scale_enemy_hp(rt.state.players[RealtimeCombat.ENEMY], EnemyRegistry.rt_hp_mult(enemy_type))
	add_enemy_attack(rt.state.players[RealtimeCombat.ENEMY], EnemyRegistry.rt_attack_bonus(enemy_type))

## Adds `bonus` attack to every minion an enemy side has (board, hand, deck), so
## reinforcements hit as hard as the opening pack (per-type tuning, BID-095).
static func add_enemy_attack(p: PlayerState, bonus: int) -> void:
	if bonus == 0:
		return
	for c: CardInstance in p.board.get_cards() + p.hand + p.draw_deck:
		if c.card_class != "spell":
			c.attack = maxi(0, c.attack + bonus)

## Multiplies an enemy side's hero and board-unit HP by `mult` (per-type
## real-time tuning, `EnemyRegistry.rt_hp_mult` — BID-095). Health keeps its fraction.
static func scale_enemy_hp(p: PlayerState, mult: float) -> void:
	if is_equal_approx(mult, 1.0):
		return
	var h: HeroState = p.hero
	if h.max_health > 0:
		var frac: float = float(h.health) / float(h.max_health)
		h.max_health = maxi(1, roundi(float(h.max_health) * mult))
		h.health = clampi(roundi(frac * float(h.max_health)), 1 if h.health > 0 else 0, h.max_health)
	for c: CardInstance in p.board.get_cards():
		var hp: int = maxi(1, roundi(float(c.max_health) * mult))
		c.health = clampi(c.health + hp - c.max_health, 1, hp)
		c.max_health = hp

## Real time: every technique card starts in the opening hand (on top of the
## trimmed hand), like abilities on a bar; after use each returns on its own
## cooldown (PlayerCaster, GID-178).
static func techniques_to_hand(p: PlayerState) -> void:
	for c: CardInstance in p.draw_deck.duplicate():
		if TechniqueDefs.is_technique(c.template_id):
			p.draw_deck.erase(c)
			p.hand.append(c)

## How hard an enemy side's spells hit, by its level (weak enemies still cast,
## just softer — TID-720) and its level gap over the player (TID-718). Pass to `SpellEffectResolver.resolve_enemy_play`.
static func enemy_spell_scale(rt: RealtimeCombat, side: int) -> float:
	var level: int = rt.side_levels[side] if side < rt.side_levels.size() else 1
	return rt.tune.level_scale(level) * rt.tune.gap_mult(level, rt.side_levels[RealtimeCombat.PLAYER])

## Knobs RealtimeCombat caches rather than reads each tick (base damage).
static func apply_live_tuning(rt: RealtimeCombat, base_tier: int) -> void:
	rt.unarmed[RealtimeCombat.PLAYER] = rt.tune.get_i("unarmed")
	rt.unarmed[RealtimeCombat.ENEMY] = rt.tune.get_i("enemy_unarmed") + maxi(0, base_tier - 1)

# --- Whole fight (balance simulator) --------------------------------------

## A ready real-time solo PvE fight from a plain config, mirroring the game's
## setup order. Keys (all optional):
##   player_level (1), learned (Array of ladder ids), deck (Array of card ids;
##   default = `level_deck(learned)`), gear ([{id, level, mult}]), weapon /
##   offhand (item ids), skills (passive skill ids), enemy_type ("undead_basic"),
##   enemy_level (1 = no zone scaling), is_boss (false), tuning ({knob: value}),
##   seed (0 = leave the RNGs as they are).
## Returns {state: GameState, rt: RealtimeCombat, tier: int}.
static func build(cfg: Dictionary) -> Dictionary:
	var s: int = int(cfg.get("seed", 0))
	if s != 0:
		seed(s)
	var player_level: int = int(cfg.get("player_level", 1))
	var learned: Array = cfg.get("learned", [])
	var deck: Array[String] = []
	deck.assign(cfg.get("deck", level_deck(learned)))
	var enemy_type: String = str(cfg.get("enemy_type", "undead_basic"))
	var enemy_level: int = int(cfg.get("enemy_level", 1))
	var is_boss: bool = bool(cfg.get("is_boss", false))
	var state := GameState.new()
	var me: PlayerState = state.players[0]
	var foe: PlayerState = state.players[1]
	me.build_deck(deck)
	me.draw_deck = unlock_filter(me.draw_deck, learned)
	var gear: Array[Dictionary] = []
	gear.assign(cfg.get("gear", []))
	for key: String in ["weapon", "offhand"]:
		if str(cfg.get(key, "")) != "":
			gear.append({"id": str(cfg[key])})
	apply_gear(me, gear, true)
	apply_passives(me, cfg.get("skills", []))
	me.draw_opening_hand(OPENING_HAND)
	var tier: int = enemy_tier(enemy_type, is_boss, enemy_level)
	var boss_hp: int = EnemyRegistry.get_boss_hp(enemy_type) if is_boss else 0
	setup_enemy(foe, me, enemy_type, EnemyRegistry.get_deck(enemy_type), tier, enemy_level, boss_hp)
	me.start_turn(1)
	var type_tier: int = base_tier(enemy_type)
	var rt_enemy_level: int = enemy_level if cfg.has("enemy_level") else enemy_level_for_tier(type_tier)
	var tuning := CombatTuning.new(cfg.get("tuning", {}) as Dictionary)
	var rt := RealtimeCombat.new(state, [player_level, rt_enemy_level], tuning)
	if s != 0:
		rt.rng.seed = s
	configure_realtime(rt, player_level, enemy_type, weapon_speed_for_item(str(cfg.get("weapon", ""))),
			offhand_damage_for_item(str(cfg.get("offhand", ""))))
	apply_live_tuning(rt, type_tier)
	return {"state": state, "rt": rt, "tier": tier}

## The new-game starter deck (SaveManager.new_game) plus Strike.
static func starter_deck() -> Array[String]:
	return ["ghost", "skeleton", "zombie", "ghoul", "ghost", "skeleton", "zombie", "ghoul",
		"ghost", "skeleton", "zombie", "ghoul", "tech_strike"]

## What a player who knows `learned` fights with by default: the starter deck
## plus each known technique card in learn order, up to TechniqueDefs.DECK_MAX
## (as `SaveManager.learn_ability` deals them in).
static func level_deck(learned: Array) -> Array[String]:
	var deck: Array[String] = starter_deck()
	deck.erase("tech_strike")
	var known: Array[String] = TechniqueDefs.known_cards(learned)
	for i: int in mini(known.size(), TechniqueDefs.DECK_MAX):
		deck.append(known[i])
	return deck
