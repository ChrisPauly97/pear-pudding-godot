## GID-187 / TID-780: battlefield conditions (FightConditions) — the pure rules the game and the
## balance sim share, and the BattleSetup.build cfg keys that switch them on.
extends "res://tests/framework/test_case.gd"

const FightConditions = preload("res://game_logic/battle/FightConditions.gd")
const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")

func get_suite_name() -> String:
	return "FightConditions"

func _minion(id: String = "skeleton", atk: int = 2, hp: int = 3) -> CardInstance:
	return CardInstance.new({
		"id": id, "name": id.capitalize(), "cost": 1,
		"attack": atk, "health": hp, "card_class": "minion", "description": "",
	})

func _state() -> GameState:
	var st := GameState.new()
	for p: PlayerState in st.players:
		p.hero.health = 30
		p.hero.max_health = 30
	return st

# --- Weather -------------------------------------------------------------

func test_ash_fall_poisons_enemy_hero_at_start() -> void:
	var st := _state()
	FightConditions.apply_weather_start(st, "ash_fall")
	assert_eq(st.players[1].hero.get_status_value("poison"), FightConditions.ASH_POISON)
	assert_false(st.players[0].hero.has_status("poison"), "only the enemy is poisoned")

func test_clear_weather_does_nothing_at_start() -> void:
	var st := _state()
	FightConditions.apply_weather_start(st, "rain")
	assert_false(st.players[1].hero.has_status("poison"))

func test_rain_ghost_gains_hp_heavy_rain_more() -> void:
	var g := _minion("ghost", 1, 2)
	FightConditions.apply_summon_weather(g, "rain", 5)
	assert_eq(g.health, 3)
	assert_eq(g.max_health, 3)
	var h := _minion("ghost", 1, 2)
	FightConditions.apply_summon_weather(h, "heavy_rain", 5)
	assert_eq(h.health, 4)
	assert_eq(h.max_health, 4)

func test_rain_only_buffs_ghosts() -> void:
	var s := _minion("skeleton", 2, 3)
	FightConditions.apply_summon_weather(s, "rain", 5)
	assert_eq(s.health, 3)

func test_sandstorm_cuts_attack_only_early() -> void:
	var a := _minion("skeleton", 2, 3)
	FightConditions.apply_summon_weather(a, "sandstorm", FightConditions.SAND_TURNS)
	assert_eq(a.attack, 1)
	var b := _minion("skeleton", 2, 3)
	FightConditions.apply_summon_weather(b, "dust_devil", FightConditions.SAND_TURNS + 1)
	assert_eq(b.attack, 2, "after the sand turns the summon is untouched")

func test_sandstorm_attack_never_negative() -> void:
	var a := _minion("skeleton", 0, 3)
	FightConditions.apply_summon_weather(a, "sandstorm", 1)
	assert_eq(a.attack, 0)

# --- School environment ----------------------------------------------------

func test_school_environment_stamps_every_side() -> void:
	var st := _state()
	st.set_battlefield_context(BattlefieldRules.BIOME_FOREST, false)
	FightConditions.apply_school_environment(st, "")
	var want: Dictionary = BattlefieldRules.school_env_table(BattlefieldRules.BIOME_FOREST, "", false)
	assert_true(want.has("verdant"), "forest boosts verdant")
	for p: PlayerState in st.players:
		assert_eq(float(p.env_school_mult.get("verdant", 1.0)), float(want["verdant"]))
		assert_false(p.env_school_mult.has("rift"))

func test_school_environment_night_boosts_dark() -> void:
	var st := _state()
	st.set_battlefield_context(BattlefieldRules.BIOME_NONE, true)
	FightConditions.apply_school_environment(st, "")
	assert_true(st.players[0].env_school_mult.has("dark"))
	assert_false(st.players[0].env_school_mult.has("light"), "day light boost is off at night")

func test_school_environment_weather_row() -> void:
	var st := _state()
	st.set_battlefield_context(BattlefieldRules.BIOME_NONE, true)
	FightConditions.apply_school_environment(st, "ash_fall")
	assert_true(st.players[1].env_school_mult.has("rift"), "ash fall boosts rift")

# --- Blight / ambush -------------------------------------------------------

func test_blight_adds_five_hp_to_the_foe() -> void:
	var st := _state()
	FightConditions.apply_blight(st.players[1])
	assert_eq(st.players[1].hero.health, 30 + FightConditions.BLIGHT_HP)
	assert_eq(st.players[1].hero.max_health, 30 + FightConditions.BLIGHT_HP)
	assert_eq(st.players[0].hero.max_health, 30)

func test_ambush_side_reads_flags() -> void:
	assert_eq(FightConditions.ambush_side({"player_ambush": true}), FightConditions.AMBUSH_PLAYER)
	assert_eq(FightConditions.ambush_side({"enemy_ambush": true}), FightConditions.AMBUSH_ENEMY)
	assert_eq(FightConditions.ambush_side({}), "")

func test_player_ambush_hurts_the_enemy_hero() -> void:
	var st := _state()
	FightConditions.apply_ambush(st, FightConditions.AMBUSH_PLAYER)
	assert_eq(st.players[1].hero.max_health, 24, "80 % of 30")
	assert_eq(st.players[1].hero.health, 24)
	assert_eq(st.players[0].hero.max_health, 30)

func test_enemy_ambush_hurts_the_player_hero() -> void:
	var st := _state()
	FightConditions.apply_ambush(st, FightConditions.AMBUSH_ENEMY)
	assert_eq(st.players[0].hero.max_health, 24)
	assert_eq(st.players[0].hero.health, 24)
	assert_eq(st.players[1].hero.max_health, 30)

func test_ambush_has_a_floor() -> void:
	var st := _state()
	st.players[1].hero.health = 10
	st.players[1].hero.max_health = 10
	FightConditions.apply_ambush(st, FightConditions.AMBUSH_PLAYER)
	assert_eq(st.players[1].hero.max_health, FightConditions.AMBUSH_HP_MIN, "never under 10 HP")

func test_no_ambush_leaves_heroes_alone() -> void:
	var st := _state()
	FightConditions.apply_ambush(st, "")
	assert_eq(st.players[0].hero.max_health, 30)
	assert_eq(st.players[1].hero.max_health, 30)

# --- Gambits ---------------------------------------------------------------

func test_wounded_pride_sets_player_hp_to_25() -> void:
	var st := _state()
	FightConditions.apply_gambit_handicaps(st, FightConditions.GAMBIT_WOUNDED_PRIDE)
	assert_eq(st.players[0].hero.health, 25)
	assert_eq(st.players[0].hero.max_health, 25)

func test_slow_start_skips_the_first_draw() -> void:
	var st := _state()
	FightConditions.apply_gambit_handicaps(st, FightConditions.GAMBIT_SLOW_START)
	assert_true(st.players[0].skip_next_draw)

func test_iron_veil_gives_the_foe_armor() -> void:
	var st := _state()
	FightConditions.apply_gambit_handicaps(st, FightConditions.GAMBIT_IRON_VEIL)
	assert_eq(st.players[1].hero.get_status_value("armor"), FightConditions.IRON_VEIL_ARMOR)

func test_emboldened_foe_is_a_deck_bonus_not_a_handicap() -> void:
	var st := _state()
	FightConditions.apply_gambit_handicaps(st, FightConditions.GAMBIT_EMBOLDENED_FOE)
	assert_false(st.players[1].hero.has_status("armor"))
	assert_eq(FightConditions.enemy_minion_attack_bonus(FightConditions.GAMBIT_EMBOLDENED_FOE), 1)
	assert_eq(FightConditions.enemy_minion_attack_bonus(""), 0)

func test_unknown_gambit_is_a_no_op() -> void:
	var st := _state()
	FightConditions.apply_gambit_handicaps(st, "")
	FightConditions.apply_gambit_handicaps(st, "not_a_gambit")
	assert_eq(st.players[0].hero.max_health, 30)
	assert_false(st.players[0].skip_next_draw)

# --- Desert scorch ---------------------------------------------------------

func test_scorch_active_only_in_daytime_desert() -> void:
	var st := _state()
	st.set_battlefield_context(BattlefieldRules.BIOME_DESERT, false)
	assert_true(FightConditions.scorch_active(st))
	st.set_battlefield_context(BattlefieldRules.BIOME_DESERT, true)
	assert_false(FightConditions.scorch_active(st), "no scorch at night")
	st.set_battlefield_context(BattlefieldRules.BIOME_FOREST, false)
	assert_false(FightConditions.scorch_active(st), "no scorch outside the desert")

func test_scorch_hits_leftmost_minion_only() -> void:
	var p := PlayerState.new(0, false)
	var a := _minion("skeleton", 1, 3)
	var b := _minion("ghoul", 1, 3)
	p.board.add_card_at_slot(a, 2)
	p.board.add_card_at_slot(b, 4)
	var dead: CardInstance = FightConditions.scorch_leftmost(p)
	assert_null(dead, "3 HP minion survives one tick")
	assert_eq(a.health, 2)
	assert_eq(b.health, 3)

func test_scorch_kills_and_discards_a_one_hp_minion() -> void:
	var p := PlayerState.new(0, false)
	var a := _minion("skeleton", 1, 1)
	p.board.add_card_at_slot(a, 0)
	var dead: CardInstance = FightConditions.scorch_leftmost(p)
	assert_eq(dead, a)
	assert_false(p.board.get_cards().has(a), "removed from the board")
	assert_true(p.discard.has(a), "sent to the discard")

func test_scorch_on_empty_board_returns_null() -> void:
	var p := PlayerState.new(0, false)
	assert_null(FightConditions.scorch_leftmost(p))

func test_scorch_takes_the_tune_hook_without_changing_damage() -> void:
	var p := PlayerState.new(0, false)
	var a := _minion("skeleton", 1, 3)
	p.board.add_card_at_slot(a, 0)
	FightConditions.scorch_leftmost(p, CombatTuning.new({}))
	assert_eq(a.health, 2, "physical scorch is one point either way")

func test_turn_based_scorch_ticks_both_sides() -> void:
	var st := _state()
	st.players[0].board.add_card_at_slot(_minion("skeleton", 1, 3), 0)
	st.players[1].board.add_card_at_slot(_minion("ghoul", 1, 3), 0)
	FightConditions.apply_desert_scorch(st)
	assert_eq(st.players[0].board.get_cards()[0].health, 2)
	assert_eq(st.players[1].board.get_cards()[0].health, 2)
