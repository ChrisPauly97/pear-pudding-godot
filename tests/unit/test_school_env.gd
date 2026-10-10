## Unit tests for the battlefield school boosts (GID-181 / TID-755).
##
## BattlefieldRules.school_env_mult / school_env_table decide which school the biome,
## weather and time of day boost (x1.1–1.15 per knob). GameState.set_school_environment
## stores the table on each side; DamageResolver multiplies the hit's school by it,
## together with the matchup, rounding once. Neutral (no table) must change nothing.
extends "res://tests/framework/test_case.gd"

const _BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")
const _CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const _DamageResolver = preload("res://game_logic/battle/DamageResolver.gd")
const _DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const _HeroState = preload("res://game_logic/battle/HeroState.gd")
const _PlayerState = preload("res://game_logic/battle/PlayerState.gd")

const _GRASS: int = 0
const _FOREST: int = 1
const _SCORCHED: int = 3

func _side(profile: Dictionary = {}, env: Dictionary = {}) -> _PlayerState:
	var p := _PlayerState.new(1, true)
	p.school_profile = profile
	p.env_school_mult = env
	return p

func _hero(hp: int = 30) -> _HeroState:
	var h := _HeroState.new(1)
	h.health = hp
	h.max_health = hp
	return h

# ---------------------------------------------------------------------------
# school_env_mult
# ---------------------------------------------------------------------------

func test_night_boosts_dark_only() -> void:
	assert_almost_eq(_BattlefieldRules.school_env_mult("dark", _GRASS, "", true), 1.15)
	assert_almost_eq(_BattlefieldRules.school_env_mult("light", _GRASS, "", true), 1.0)

func test_day_boosts_light_only() -> void:
	assert_almost_eq(_BattlefieldRules.school_env_mult("light", _GRASS, "", false), 1.15)
	assert_almost_eq(_BattlefieldRules.school_env_mult("dark", _GRASS, "", false), 1.0)

func test_forest_boosts_verdant() -> void:
	assert_almost_eq(_BattlefieldRules.school_env_mult("verdant", _FOREST, "", false), 1.1)
	assert_almost_eq(_BattlefieldRules.school_env_mult("verdant", _GRASS, "", false), 1.0)

func test_scorched_boosts_rift_and_mountains_boosts_physical() -> void:
	assert_almost_eq(_BattlefieldRules.school_env_mult("rift", _SCORCHED, "", false), 1.1)
	assert_almost_eq(_BattlefieldRules.school_env_mult("physical", _BattlefieldRules.BIOME_MOUNTAINS,
			"", false), 1.1)

func test_rain_boosts_verdant_and_stacks_with_forest() -> void:
	assert_almost_eq(_BattlefieldRules.school_env_mult("verdant", _FOREST, "rain", false), 1.21)
	assert_almost_eq(_BattlefieldRules.school_env_mult("verdant", -1, "heavy_rain", false), 1.1)

func test_weather_rows_map_their_school() -> void:
	# Night, so the day-light row does not add to the weather rows under test.
	assert_almost_eq(_BattlefieldRules.school_env_mult("rift", -1, "ash_fall", true), 1.1)
	assert_almost_eq(_BattlefieldRules.school_env_mult("light", -1, "snow", true), 1.1)
	assert_almost_eq(_BattlefieldRules.school_env_mult("physical", -1, "dust_devil", true), 1.1)
	assert_almost_eq(_BattlefieldRules.school_env_mult("rift", -1, "snow", true), 1.0)

func test_knob_overrides_are_read() -> void:
	var tune := _CombatTuning.new({"env_time_mult": 1.3})
	assert_almost_eq(_BattlefieldRules.school_env_mult("dark", _GRASS, "", true, tune), 1.3)

# ---------------------------------------------------------------------------
# school_env_table / text
# ---------------------------------------------------------------------------

func test_day_without_terrain_or_weather_only_boosts_light() -> void:
	# Day always lights up light; there is no neutral daytime battlefield by design.
	var t: Dictionary = _BattlefieldRules.school_env_table(-1, "", false)
	assert_eq(t.size(), 1)
	assert_almost_eq(float(t["light"]), 1.15)
	assert_eq(_BattlefieldRules.school_env_text(-1, "", false), "Light x1.15")

func test_night_grassland_table() -> void:
	var t: Dictionary = _BattlefieldRules.school_env_table(_GRASS, "", true)
	assert_eq(t.size(), 1)
	assert_almost_eq(float(t["dark"]), 1.15)

func test_table_lists_every_boosted_school_once() -> void:
	var t: Dictionary = _BattlefieldRules.school_env_table(_FOREST, "rain", false)
	assert_eq(t.size(), 2)
	assert_almost_eq(float(t["verdant"]), 1.21)
	assert_almost_eq(float(t["light"]), 1.15)

func test_banner_text_names_the_boost() -> void:
	var txt: String = _BattlefieldRules.school_env_text(_GRASS, "", true)
	assert_true(txt.contains("Dark"), "banner text names the boosted school")
	assert_true(txt.contains("1.15"), "banner text shows the multiplier")

func test_branch_affinity_unchanged_by_shared_condition() -> void:
	assert_true(_BattlefieldRules.branch_affinity_active("dusk", _GRASS, true))
	assert_false(_BattlefieldRules.branch_affinity_active("dawn", _GRASS, true))
	assert_true(_BattlefieldRules.branch_affinity_active("bloom", _FOREST, false))

# ---------------------------------------------------------------------------
# Resolver and state wiring
# ---------------------------------------------------------------------------

func test_new_side_is_neutral() -> void:
	assert_true(_PlayerState.new(0, false).env_school_mult.is_empty())

func test_resolver_applies_attacker_school_boost() -> void:
	var h := _hero(30)
	var r: Dictionary = _DamageResolver.deal(_side({}, {"dark": 1.15}), h, 20, "dark")
	assert_eq(int(r["dealt"]), 23)
	assert_eq(h.health, 7)

func test_resolver_leaves_other_schools_alone() -> void:
	var h := _hero(30)
	_DamageResolver.deal(_side({}, {"dark": 1.15}), h, 10, "light")
	assert_eq(h.health, 20)

func test_boost_and_weakness_multiply_then_round_once() -> void:
	# 10 x 1.5 (weak) x 1.15 (night) = 17.25 -> 17
	var side := _side({"weak": {"dark": true}}, {"dark": 1.15})
	assert_eq(_DamageResolver.scaled_amount(side, 10, "dark"), 17)

func test_boost_does_not_revive_an_immune_hit() -> void:
	var side := _side({"immune": {"dark": true}}, {"dark": 1.15})
	assert_eq(_DamageResolver.scaled_amount(side, 10, "dark"), 0)

func test_null_defender_has_no_boost() -> void:
	assert_almost_eq(_DamageResolver.env_mult(null, "dark"), 1.0)
	assert_eq(_DamageResolver.scaled_amount(null, 10, "dark"), 10)

func test_disabled_knobs_are_neutral() -> void:
	var tune := _CombatTuning.new({"env_time_mult": 1.0, "env_biome_mult": 1.0, "env_weather_mult": 1.0})
	assert_true(_BattlefieldRules.school_env_table(_FOREST, "rain", true, tune).is_empty())
	assert_eq(_DamageSchools.apply_mult(10, 1.0), 10)
