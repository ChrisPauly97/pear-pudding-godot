## GID-187 / TID-782: encounter shapes shared by the game and the balance sim. A joiner
## (`EncounterSetup.make_joiner`, the setup `BattleRealtime.join_enemy` runs), boss phase 2
## (`boss_phase2_due` / `enter_boss_phase2`, the swap `BattleScene` runs) and the sim's
## joiner / phase 2 config keys (`BalanceFight`).
extends "res://tests/framework/test_case.gd"

const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const EncounterSetup = preload("res://game_logic/battle/EncounterSetup.gd")
const BalanceFight = preload("res://game_logic/battle/BalanceFight.gd")
const BalanceCoverage = preload("res://game_logic/battle/BalanceCoverage.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

## A boss with a phase 2 deck and a phase 2 school profile (schools_phase2).
const BOSS: String = "barrow_king"

## A fresh real-time fight against `enemy_type` (sides: 0 = player, 1 = enemy).
func _fight(enemy_type: String, level: int) -> Dictionary:
	return BattleSetup.build({"seed": 3, "enemy_type": enemy_type, "enemy_level": level})

func test_make_joiner_adds_a_second_enemy_at_its_level() -> void:
	var built: Dictionary = _fight("undead_basic", 2)
	var rt: RealtimeCombat = built["rt"]
	var state: GameState = built["state"]
	assert_eq(state.players.size(), 2, "one enemy to start")
	var side: int = EncounterSetup.make_joiner(rt, {"enemy_type": "undead_basic", "enemy_level": 2})
	assert_eq(side, 2, "the joiner takes the next side")
	assert_eq(state.players.size(), 3, "the joiner is a third player")
	assert_eq(rt.side_levels[side], 2, "it fights at its level")
	assert_eq(rt.enemy_sides().size(), 2, "both enemy sides are live")
	assert_true(state.team_battle, "a joined fight is a team battle")
	assert_eq(state.players[side].hand.size(), BattleSetup.JOINER_OPENING_HAND,
		"a joiner opens with its short hand")

func test_make_joiner_refused_past_the_enemy_cap() -> void:
	var built: Dictionary = _fight("undead_basic", 2)
	var rt: RealtimeCombat = built["rt"]
	assert_gte(EncounterSetup.make_joiner(rt, {"enemy_type": "undead_basic", "enemy_level": 2}), 0)
	assert_eq(EncounterSetup.make_joiner(rt, {"enemy_type": "undead_basic", "enemy_level": 2}), -1,
		"no third enemy side (RealtimeCombat.MAX_ENEMIES)")

func test_make_joiner_boss_starts_at_boss_hp() -> void:
	var built: Dictionary = _fight("undead_basic", 1)
	var rt: RealtimeCombat = built["rt"]
	var state: GameState = built["state"]
	var boss_hp: int = EnemyRegistry.get_boss_hp(BOSS)
	var side: int = EncounterSetup.make_joiner(rt, {"enemy_type": BOSS, "is_boss": true, "boss_hp": boss_hp})
	assert_gte(side, 0)
	# Per-type real-time HP tuning (rt_hp_mult) scales the boss HP, as in join_enemy; add_enemy's level
	# gap over the player (_gap_enemy_hp) can raise it further, so this is a floor.
	var want: int = maxi(1, roundi(float(boss_hp) * EnemyRegistry.rt_hp_mult(BOSS)))
	assert_gte(state.players[side].hero.max_health, want, "a boss joiner starts at boss HP times rt_hp_mult")

func test_make_joiner_defaults_to_the_authored_level() -> void:
	# No level given: the joiner fights at its authored tier's level-equivalent (GID-186).
	var built: Dictionary = _fight("undead_basic", 1)
	var rt: RealtimeCombat = built["rt"]
	var side: int = EncounterSetup.make_joiner(rt, {"enemy_type": "undead_basic"})
	assert_eq(rt.side_levels[side], BattleSetup.default_enemy_level("undead_basic"))

func test_boss_phase2_due_at_half_health() -> void:
	var foe := PlayerState.new(1, true)
	var max_hp: int = foe.hero.max_health
	var deck: Array = [1]
	foe.hero.health = max_hp
	assert_false(EncounterSetup.boss_phase2_due(foe, true, deck), "full health: no swap")
	foe.hero.health = max_hp / 2 + 1
	assert_false(EncounterSetup.boss_phase2_due(foe, true, deck), "just above half: no swap")
	foe.hero.health = max_hp / 2
	assert_true(EncounterSetup.boss_phase2_due(foe, true, deck), "at half: swap")

func test_boss_phase2_needs_a_boss_and_a_deck() -> void:
	var foe := PlayerState.new(1, true)
	foe.hero.health = 1
	assert_false(EncounterSetup.boss_phase2_due(foe, false, [1]), "not a boss")
	assert_false(EncounterSetup.boss_phase2_due(foe, true, []), "no phase 2 deck")

func test_enter_boss_phase2_swaps_deck_and_school_profile() -> void:
	var foe := PlayerState.new(1, true)
	var deck: Array[String] = EnemyRegistry.get_phase2_deck(BOSS)
	assert_gt(deck.size(), 0, "%s has a phase 2 deck" % BOSS)
	EncounterSetup.enter_boss_phase2(foe, BOSS, deck)
	assert_eq(foe.hand.size(), BattleSetup.OPENING_HAND, "a fresh opening hand")
	assert_eq(foe.hand.size() + foe.draw_deck.size(), deck.size(), "the whole phase 2 deck is in play")
	var want: Dictionary = EnemyRegistry.get_school_profile(BOSS, 2)
	assert_eq(foe.school_profile, want, "phase 2 school profile")
	assert_true((foe.school_profile["immune"] as Dictionary).has("dark"), "phase 2 is immune to dark")

func test_joiner_fight_reports_the_join() -> void:
	var stats: Dictionary = BalanceFight.run({"seed": 2, "enemy_type": "undead_basic", "enemy_level": 1,
		"max_seconds": 3.0, "joiner": {"enemy_type": "undead_basic", "enemy_level": 1, "at_seconds": 0.0}})
	assert_eq(int(stats["joins"]), 1, "a joiner due at 0 s arrives on the first tick")

func test_joiner_not_due_is_not_joined() -> void:
	var stats: Dictionary = BalanceFight.run({"seed": 2, "enemy_type": "undead_basic", "enemy_level": 1,
		"max_seconds": 3.0, "joiner": {"enemy_type": "undead_basic", "enemy_level": 1, "at_seconds": 10.0}})
	assert_eq(int(stats["joins"]), 0, "a fight that ends before the joiner's time never joins")

func test_boss_fight_swaps_to_phase2_at_half_hp() -> void:
	# barrow_king at its low end, same level, the coverage cell's player (seed 1 wins; the boss
	# is worn below half health before the fight ends, so it swaps). Geared: past level 8 a naked
	# hero no longer keeps pace (TID-793).
	var cfg: Dictionary = BalanceCoverage.cell_cfg(BOSS, 20, 20, 1, "", {}, {"is_boss": true, "geared": true})
	var stats: Dictionary = BalanceFight.run(cfg)
	assert_eq(int(stats["phase2"]), 1, "a boss fight that reaches half health swaps to phase 2")

func test_boss_fight_without_phase2_never_swaps() -> void:
	var cfg: Dictionary = BalanceCoverage.cell_cfg(BOSS, 20, 20, 1, "", {}, {"is_boss": true, "boss_phase2": false})
	var stats: Dictionary = BalanceFight.run(cfg)
	assert_eq(int(stats["phase2"]), 0, "boss_phase2 off: no swap")

func test_non_boss_fight_never_swaps() -> void:
	var cfg: Dictionary = BalanceCoverage.cell_cfg(BOSS, 20, 20, 1)
	var stats: Dictionary = BalanceFight.run(cfg)
	assert_eq(int(stats["phase2"]), 0, "only bosses swap")
