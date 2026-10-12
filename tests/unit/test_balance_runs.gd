## GID-187 / TID-783: rift tiers, boons, the run / siege breathers, siege stage levels, the v52 tier migration
## and the runs section's checks (its fights run in tests/balance_coverage.gd).
extends "res://tests/framework/test_case.gd"

const RiftDefs = preload("res://game_logic/spire/RiftDefs.gd")
const SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
const BalanceRuns = preload("res://game_logic/battle/BalanceRuns.gd")
const SaveMigrations = preload("res://game_logic/save/SaveMigrations.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")

func test_tiers_are_half_a_level() -> void:
	assert_eq(RiftDefs.enemy_level(1), RiftDefs.BASE_LEVEL)
	assert_eq(RiftDefs.enemy_level(2), RiftDefs.BASE_LEVEL, "the second tier of a level steps HP, not level")
	assert_almost_eq(RiftDefs.hp_mult(2), RiftDefs.HALF_TIER_HP, 0.0001)
	assert_almost_eq(RiftDefs.hp_mult(3), 1.0, 0.0001)
	assert_eq(RiftDefs.enemy_level(3), RiftDefs.BASE_LEVEL + 1)
	assert_eq(RiftDefs.enemy_level(RiftDefs.MAX_TIER), 60, "the top tier is level 60")
	assert_eq(RiftDefs.enemy_level(4, RiftDefs.FLOORS_PER_TIER), RiftDefs.enemy_level(4, 1), "floors share a level")

func test_rewards_per_level_stay_close_to_the_old_tiers() -> void:
	# Old: one tier per two levels paying 300 + 100·tier XP; new: four tiers in the same span.
	var old_tier: int = 5
	var span: int = 0
	for t: int in range(RiftDefs.migrate_tier(old_tier), RiftDefs.migrate_tier(old_tier + 1)):
		span += RiftDefs.first_clear_xp(t)
	assert_almost_eq(float(span), float(300 + 100 * old_tier), 150.0)

func test_breathers_and_vigor_heal() -> void:
	assert_almost_eq(RiftDefs.after_floor(0.4), 0.4 + RiftDefs.FLOOR_HEAL, 0.0001)
	assert_almost_eq(RiftDefs.after_floor(0.95), 1.0, 0.0001)
	assert_almost_eq(SiegeDefs.after_wave(0.3), 0.3 + SiegeDefs.WAVE_HEAL, 0.0001)
	assert_almost_eq(RiftDefs.vigor_heal(0.5, 15), 0.65, 0.0001)

func test_siege_stages_fight_at_the_siege_level() -> void:
	for stage: int in 3:
		assert_eq(SiegeDefs.stage_level(20, stage), 20 + SiegeDefs.STAGE_LEVELS[stage])

func test_boons_scale_with_the_hero() -> void:
	var a: Dictionary = BattleSetup.build({"seed": 3, "player_level": 30, "enemy_level": 30})
	var b: Dictionary = BattleSetup.build({"seed": 3, "player_level": 30, "enemy_level": 30,
		"boons": ["boon_vigor", "boon_bulwark"]})
	var pa: PlayerState = (a["state"] as GameState).players[0]
	var pb: PlayerState = (b["state"] as GameState).players[0]
	assert_eq(pb.hero.max_health, roundi(float(pa.hero.max_health) * 1.15), "Vigor: +15 % max HP")
	assert_eq(pb.hero.get_status_value("armor"), roundi(float(pb.hero.max_health) * 0.1), "Bulwark: 10 % as armor")
	assert_eq((b["rt"] as RealtimeCombat).heavy_damage(), (a["rt"] as RealtimeCombat).heavy_damage(),
		"heavies stay a share of the pre-boon HP")

func test_v52_moves_tiers_to_the_same_level() -> void:
	var d: Dictionary = {"version": 51, "rift_best_tiers": {"forest": 3, "desert": 0},
		"rift_first_clears": ["forest:1", "forest:3"], "spire_run": {"active": true, "tier": 2}}
	SaveMigrations.apply(d, 52)
	assert_eq(int((d["rift_best_tiers"] as Dictionary)["forest"]), 9)
	assert_eq(RiftDefs.enemy_level(9), 14 + 2 * (3 - 1), "old tier 3 was level 18")
	assert_eq(int((d["rift_best_tiers"] as Dictionary)["desert"]), 0)
	assert_eq(d["rift_first_clears"], ["forest:1", "forest:9"])
	assert_eq(int((d["spire_run"] as Dictionary)["tier"]), 5)

func test_own_tier_matches_the_level() -> void:
	for lv: int in [16, 30, 54]:
		assert_eq(RiftDefs.enemy_level(BalanceRuns.own_tier(lv)), lv)

func test_check_gates() -> void:
	var ok: Dictionary = {
		"rift@20+0": {"kind": "rift", "level": 20, "above": 0, "rate": 0.9},
		"rift@20+1": {"kind": "rift", "level": 20, "above": 1, "rate": 0.6},
		"siege@20": {"kind": "siege", "level": 20, "rate": 0.8},
	}
	assert_true(BalanceRuns.check(ok).is_empty())
	var cliff: Dictionary = ok.duplicate(true)
	(cliff["rift@20+1"] as Dictionary)["rate"] = 0.0
	assert_eq(BalanceRuns.check(cliff).size(), 1, "a cliff fails")
	var weak: Dictionary = ok.duplicate(true)
	(weak["siege@20"] as Dictionary)["rate"] = 0.2
	(weak["rift@20+0"] as Dictionary)["rate"] = 0.3
	(weak["rift@20+1"] as Dictionary)["rate"] = 0.1
	assert_eq(BalanceRuns.check(weak).size(), 2, "own tier and siege floors")
