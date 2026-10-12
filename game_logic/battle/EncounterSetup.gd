## Encounter shapes shared by the game and the balance sim (GID-187 / TID-782): an enemy joining a
## live real-time fight, a boss's phase 2, and (TID-786) a co-op hero joining the party. Split out of
## `BattleSetup`. Pure: no scene tree.
extends RefCounted

const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const SchoolSources = preload("res://game_logic/battle/SchoolSources.gd")
const DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const CombatOnboarding = preload("res://game_logic/battle/CombatOnboarding.gd")

## GID-187 / TID-782: a second enemy joins a live real-time fight (team battle). The pure
## setup `BattleRealtime.join_enemy` and the balance sim's joiner share: its deck built at its
## tier, a short opening hand, boss HP, the per-type real-time HP multiplier, then added to `rt`
## at its level, with its unarmed damage. `enemy_data` keys (all optional): enemy_type,
## enemy_level (default: its authored tier's level), is_boss, boss_hp, enemy_deck (default: the
## type's deck). Returns the new side, or -1 when `rt` refuses (full, or the fight is over).
## The scene adds the token and toasts; those stay out of here.
static func make_joiner(rt: RealtimeCombat, enemy_data: Dictionary) -> int:
	var etype: String = str(enemy_data.get("enemy_type", "undead_basic"))
	var is_boss: bool = bool(enemy_data.get("is_boss", false))
	var level: int = int(enemy_data.get("enemy_level", BattleSetup.default_enemy_level(etype)))
	var tier: int = BattleSetup.enemy_tier(etype, is_boss, level)
	var ps := PlayerState.new(rt.state.players.size(), true)
	var deck: Array[String] = []
	deck.assign(enemy_data.get("enemy_deck", EnemyRegistry.get_deck(etype)))
	ps.build_deck(deck, tier)
	ps.draw_opening_hand(BattleSetup.JOINER_OPENING_HAND)
	var bhp: int = int(enemy_data.get("boss_hp", 0))
	if is_boss and bhp > 0:
		ps.hero.health = bhp
		ps.hero.max_health = bhp
	BattleSetup.scale_enemy_hp(ps, EnemyRegistry.rt_hp_mult(etype))  # BID-095 per-type tuning
	var side: int = rt.add_enemy(ps, level)
	if side < 0:
		return -1
	rt.unarmed[side] = rt.tune.get_i("enemy_unarmed") + maxi(0, tier - 1)
	return side

## GID-187 / TID-786: a co-op hero joins `rt`'s party before the fight starts, built from a player cfg
## (the `BattleSetup.build` hero keys: player_level, learned, deck, gear / weapon / offhand, skills) the
## way the solo hero is: deck through the unlock filter, gear, school power and resists, skill mods,
## opening hand, then the real-time trim, techniques to hand and weapon timers. Returns its side.
static func make_party_member(rt: RealtimeCombat, cfg: Dictionary) -> int:
	var level: int = int(cfg.get("player_level", 1))
	var learned: Array = cfg.get("learned", [])
	var ps := PlayerState.new(rt.state.players.size(), false)
	var deck: Array[String] = []
	deck.assign(cfg.get("deck", BattleSetup.level_deck(learned)))
	ps.build_deck(deck)
	ps.draw_deck = BattleSetup.unlock_filter(ps.draw_deck, learned)
	var gear: Array[Dictionary] = BattleSetup.gear_items(cfg)
	BattleSetup.apply_gear(ps, gear, true, level, rt.tune)
	var skills: Array = cfg.get("skills", [])
	SchoolSources.apply_school_power(ps, gear, skills)
	ps.hero.school_resist = DamageSchools.capped_resists(SchoolSources.resist_sources(gear, skills, ps.gear))
	BattleSetup.apply_skill_mods(ps, skills)
	ps.draw_opening_hand(BattleSetup.OPENING_HAND)
	ps.start_turn(1)
	var side: int = rt.add_ally(ps, level)
	rt.trim_hand(side, CombatOnboarding.opening_hand(level))
	BattleSetup.techniques_to_hand(ps)
	rt.weapon_speed[side] = BattleSetup.weapon_speed_for_item(str(cfg.get("weapon", "")))
	rt.offhand_damage[side] = BattleSetup.offhand_damage_for_item(str(cfg.get("offhand", "")))
	return side

## GID-187 / TID-782: a boss swaps to its phase 2 once its hero is at half health or less.
## True when `foe` (the boss's side) should swap now. Shared by `BattleScene` (turn and
## real-time fights) and the balance sim; the caller keeps its once-only flag.
static func boss_phase2_due(foe: PlayerState, is_boss: bool, phase2_deck: Array) -> bool:
	if not is_boss or phase2_deck.is_empty():
		return false
	return foe.hero.health <= foe.hero.max_health / 2

## GID-187 / TID-782: the boss's phase 2 on `foe`: its phase 2 deck at boss tier, its phase 2
## school profile (`schools_phase2`), and a fresh opening hand. The board is left as it is.
static func enter_boss_phase2(foe: PlayerState, enemy_type: String, phase2_deck: Array) -> void:
	var deck: Array[String] = []
	deck.assign(phase2_deck)
	foe.build_deck(deck, BattleSetup.BOSS_TIER)
	foe.school_profile = EnemyRegistry.get_school_profile(enemy_type, 2)  # TID-751
	foe.draw_opening_hand(BattleSetup.OPENING_HAND)
