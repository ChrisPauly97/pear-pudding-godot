## GID-186: hero damage growth past Chapter 1, the milder physical matchup knobs,
## every type taking its fight tier from its level, and the sim's untag option.
extends "res://tests/framework/test_case.gd"

const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const DamageResolver = preload("res://game_logic/battle/DamageResolver.gd")
const DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const ZoneLevels = preload("res://game_logic/world/ZoneLevels.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")

func test_hero_power_flat_through_from_level() -> void:
	var t := CombatTuning.new()
	for lv: int in range(1, t.get_i("power_from_level") + 1):
		assert_almost_eq(t.hero_level_power(lv), 1.0, 0.0001, "level %d" % lv)

func test_hero_power_tracks_enemy_hp_growth() -> void:
	var t := CombatTuning.new({"power_track": 1.0})
	var from: int = t.get_i("power_from_level")
	assert_almost_eq(t.hero_level_power(30), t.enemy_hp_growth(30) / t.enemy_hp_growth(from), 0.0001)
	var d := CombatTuning.new()
	var last: float = 1.0
	for lv: int in range(from + 1, 61):
		assert_gt(d.hero_level_power(lv), last, "grows at %d" % lv)
		last = d.hero_level_power(lv)
	assert_almost_eq(CombatTuning.new({"power_track": 0.0}).hero_level_power(40), 1.0, 0.0001, "track 0 = off")

func test_enemy_hp_growth_matches_zone_and_level_scaling() -> void:
	var t := CombatTuning.new()
	var zone: float = float(ZoneLevels.scaled_hero_hp(10000, 20)) / 10000.0
	assert_almost_eq(t.enemy_hp_growth(20), zone * (1.0 + t.get_f("enemy_hp_per_level") * 19.0), 0.0001)
	assert_almost_eq(t.enemy_hp_growth(1), 1.0, 0.0001)

func test_realtime_sets_player_level_power_only() -> void:
	var gs := GameState.new()
	var rt := RealtimeCombat.new(gs, [30, 30])
	assert_almost_eq(gs.players[0].level_power, rt.tune.hero_level_power(30), 0.0001)
	assert_almost_eq(gs.players[1].level_power, 1.0, 0.0001, "enemies never get it")

func test_level_power_scales_outgoing_hits() -> void:
	var attacker := PlayerState.new(0, false)
	attacker.level_power = 2.0
	var defender := PlayerState.new(1, true)
	var h := HeroState.new(1)
	h.health = 50
	h.max_health = 50
	DamageResolver.deal(defender, h, 5, DamageSchools.PHYSICAL, null, attacker)
	assert_eq(h.health, 40)
	attacker.school_power = {"light": 0.5}
	assert_almost_eq(DamageResolver.power_mult(attacker, "light"), 3.0, 0.0001, "school power x level power")

func test_physical_has_its_own_matchup_knobs() -> void:
	var t := CombatTuning.new()
	var resist: Dictionary = {"resist": {"physical": true, "light": true}}
	var weak: Dictionary = {"weak": {"physical": true, "light": true}}
	assert_almost_eq(DamageSchools.mult("physical", resist, t), t.get_f("physical_resist_mult"))
	assert_almost_eq(DamageSchools.mult("physical", weak, t), t.get_f("physical_weak_mult"))
	assert_almost_eq(DamageSchools.mult("light", resist, t), t.get_f("resist_mult"), 0.0001, "magic unchanged")
	assert_almost_eq(DamageSchools.mult("light", weak, t), t.get_f("weak_mult"))
	assert_lt(t.get_f("resist_mult"), t.get_f("physical_resist_mult"), "physical tags are milder")
	assert_lt(t.get_f("physical_weak_mult"), t.get_f("weak_mult"))

func test_every_type_fights_at_tier_from_level() -> void:
	assert_eq(BattleSetup.base_tier("mountain_troll"), 1, "authored tier 3")
	assert_eq(BattleSetup.enemy_tier("mountain_troll", false, 12), ZoneLevels.scaled_tier(1, 12))
	assert_eq(BattleSetup.enemy_tier("mountain_troll", true, 12), ZoneLevels.scaled_tier(4, 12), "boss")

func test_default_enemy_level_reads_authored_tier() -> void:
	var tier: int = EnemyRegistry.get_difficulty_tier("mountain_troll")
	assert_eq(BattleSetup.default_enemy_level("mountain_troll"), BattleSetup.enemy_level_for_tier(tier))
	assert_eq(BattleSetup.default_enemy_level(""), 1)

func test_untag_school_drops_only_that_school() -> void:
	var built: Dictionary = BattleSetup.build({"seed": 3, "enemy_type": "scarab_swarm", "enemy_level": 5,
		"untag_school": "physical"})
	var prof: Dictionary = (built["state"] as GameState).players[1].school_profile
	assert_false((prof["resist"] as Dictionary).has("physical"))
	assert_true((prof["weak"] as Dictionary).has("verdant"), "other tags stay")
	var plain: Dictionary = BattleSetup.build({"seed": 3, "enemy_type": "scarab_swarm", "enemy_level": 5})
	assert_true(((plain["state"] as GameState).players[1].school_profile["resist"] as Dictionary).has("physical"))

func test_spell_hits_read_the_fight_tuning() -> void:
	for rm: float in [0.5, 1.0]:
		var gs := GameState.new()
		var foe: PlayerState = gs.players[1]
		foe.school_profile = {"resist": {"light": true}, "weak": {}, "immune": {}}
		foe.hero.health = 30
		foe.hero.max_health = 30
		var r := SpellEffectResolver.new()
		SpellEffectResolver.silent = true
		r.setup(gs)
		r.tune = CombatTuning.new({"resist_mult": rm})
		var spell := CardInstance.new({"id": "bolt", "name": "Bolt", "cost": 1, "attack": 0, "health": 0,
			"card_class": "spell", "description": "", "spell_effect": "deal_damage_single", "spell_power": 4,
			"magic_type": "light"})
		r.resolve_spell(spell, 0, {"type": "hero"})
		SpellEffectResolver.silent = false
		assert_eq(foe.hero.health, 30 - roundi(4.0 * rm), "resist_mult %.1f" % rm)
