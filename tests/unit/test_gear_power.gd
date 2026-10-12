## GID-187 / TID-793: item-level gear power, level-only enemy threat, the heavy-blow base, the
## catalogue's density and the drop supply that keeps a player near the curve.
extends "res://tests/framework/test_case.gd"

const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const GearCurve = preload("res://game_logic/items/GearCurve.gd")
const GearDrops = preload("res://game_logic/items/GearDrops.gd")
const GearSupply = preload("res://game_logic/items/GearSupply.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const BalanceProfiles = preload("res://game_logic/battle/BalanceProfiles.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const LootRoll = preload("res://game_logic/net/LootRoll.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")

## A full loadout: one stat item of `item_level` in every slot.
func _full(item_level: int, upgrade: int = 0) -> Array:
	var worn: Array = []
	for slot: String in GearCurve.SLOT_WEIGHT:
		var w := WeaponData.new()
		w.slot = slot
		w.item_level = item_level
		w.stats = {"stamina": 10}
		worn.append([w, upgrade])
	return worn

func test_no_gear_or_track_off_is_neutral() -> void:
	var t := CombatTuning.new()
	assert_almost_eq(GearCurve.gear_power([], t), 1.0, 0.0001)
	assert_almost_eq(GearCurve.gear_power(_full(40), CombatTuning.new({"gear_track": 0.0})), 1.0, 0.0001)

func test_full_on_curve_loadout_is_growth_to_the_track() -> void:
	var t := CombatTuning.new()
	var from: int = t.get_i("power_from_level")
	var expect: float = pow(t.enemy_hp_growth(30) / t.enemy_hp_growth(from), t.get_f("gear_track"))
	assert_almost_eq(GearCurve.gear_power(_full(30), t), expect, 0.001)
	assert_almost_eq(GearCurve.gear_power(_full(from), t), 1.0, 0.0001, "items at or below the start add nothing")
	assert_gt(GearCurve.gear_power(_full(30, 3), t), GearCurve.gear_power(_full(30), t), "upgrades add power")

func test_items_without_stats_add_nothing() -> void:
	var w := WeaponData.new()
	w.slot = "armor"
	w.item_level = 40
	assert_almost_eq(GearCurve.gear_power([[w, 0]], CombatTuning.new()), 1.0, 0.0001)

func test_build_applies_gear_power_and_hp() -> void:
	var bare: Dictionary = BattleSetup.build({"seed": 2, "player_level": 30, "enemy_level": 30})
	var cfg: Dictionary = BalanceProfiles.gear_cfg(30)
	cfg.merge({"seed": 2, "player_level": 30, "enemy_level": 30}, true)
	var geared: Dictionary = BattleSetup.build(cfg)
	var bp: PlayerState = (bare["state"] as GameState).players[0]
	var gp: PlayerState = (geared["state"] as GameState).players[0]
	assert_almost_eq(bp.gear_power, 1.0, 0.0001)
	assert_gt(gp.gear_power, 2.0, "an on-curve level-30 loadout multiplies damage")
	assert_gt(gp.hero.max_health, roundi(float(bp.hero.max_health) * 2.0), "and max HP")

func test_enemy_threat_follows_level_with_a_lag() -> void:
	var t := CombatTuning.new()
	var lag: int = t.get_i("enemy_dmg_lag")
	var expect: float = exp(t.get_f("enemy_dmg_track") * t.item_power_log(40 - lag))
	assert_almost_eq(t.enemy_dmg_growth(40), expect, 0.001)
	assert_almost_eq(t.enemy_dmg_growth(t.get_i("power_from_level") + lag), 1.0, 0.0001, "flat through Chapter 1")
	assert_almost_eq(CombatTuning.new({"enemy_dmg_track": 0.0}).enemy_dmg_growth(40), 1.0, 0.0001)

func test_heavy_blow_ignores_gear_hp() -> void:
	var t := CombatTuning.new({"gap_damage": 0.0})
	var a := RealtimeCombat.new(GameState.new(), [30, 30], t)
	var gs := GameState.new()
	gs.players[0].gear_hp_power = 3.0
	var b := RealtimeCombat.new(gs, [30, 30], t)
	assert_gt(gs.players[0].hero.max_health, a.state.players[0].hero.max_health * 2, "gear HP applied")
	assert_eq(b.heavy_damage(), a.heavy_damage(), "a heavy is a share of the pre-gear HP")

func test_every_slot_has_an_item_near_every_level() -> void:
	for slot: String in GearDrops.SLOTS:
		for lv: int in range(12, 61):
			var w: WeaponData = WeaponRegistry.get_weapon(GearDrops.best_for(slot, lv))
			assert_true(w != null and w.item_level >= lv - GearDrops.DROP_BELOW, "%s at %d" % [slot, lv])

func test_behind_slots_by_item_level() -> void:
	var lv: int = 30
	var equipped: Dictionary = GearDrops.expected_loadout(lv)
	assert_eq(GearDrops.behind_slots(lv, equipped), [] as Array[String])
	equipped["ring"] = GearDrops.best_for("ring", lv - GearDrops.PITY_BEHIND - 3)
	assert_eq(GearDrops.behind_slots(lv, equipped), ["ring"] as Array[String])

func test_catch_up_raises_the_chest_chance() -> void:
	assert_almost_eq(LootRoll.equipment_chance(1), LootRoll.EQUIPMENT_CHANCE_DEFAULT, 0.0001)
	assert_almost_eq(LootRoll.equipment_chance(1, true),
		LootRoll.EQUIPMENT_CHANCE_DEFAULT * LootRoll.EQUIPMENT_CATCHUP_MULT, 0.0001)
	assert_lt(LootRoll.equipment_chance(3, true), 1.0001, "capped at 1")

func test_supply_keeps_a_player_near_the_curve() -> void:
	# At the target drop rate, from level 20 the worn loadout stays within 15 % of the curve.
	for seed: int in [1, 2, 3]:
		var cov: Dictionary = GearSupply.simulate(GearSupply.TARGET_DROPS_PER_HOUR, seed)
		for lv: int in range(20, 61):
			assert_gt(float(cov[lv]), 0.85, "seed %d level %d" % [seed, lv])
