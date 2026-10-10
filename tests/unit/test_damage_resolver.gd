## Unit tests for the single damage resolver (GID-181 / TID-749).
##
## DamageResolver.deal is the one entry every damage event goes through. With an empty
## school profile (the default until TID-750 / TID-751 fill them) it must change nothing:
## the target takes exactly the amount it was dealt, after armor and shroud. These tests
## pin that, plus the resist / weak / immune scaling and the {dealt, outcome} report.
extends "res://tests/framework/test_case.gd"

const _DamageResolver = preload("res://game_logic/battle/DamageResolver.gd")
const _DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const _CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const _HeroState = preload("res://game_logic/battle/HeroState.gd")
const _CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const _PlayerState = preload("res://game_logic/battle/PlayerState.gd")

func _side(profile: Dictionary = {}) -> _PlayerState:
	var p := _PlayerState.new(1, true)
	p.school_profile = profile
	return p

func _hero(hp: int = 30) -> _HeroState:
	var h := _HeroState.new(1)
	h.health = hp
	h.max_health = hp
	return h

func _minion(hp: int = 8) -> _CardInstance:
	return _CardInstance.new({"id": "t_minion", "name": "M", "attack": 1, "health": hp})

# ---------------------------------------------------------------------------
# Neutral (empty profile) behaviour is unchanged
# ---------------------------------------------------------------------------

func test_empty_profile_hero_takes_exact_amount() -> void:
	var h := _hero(30)
	var r: Dictionary = _DamageResolver.deal(_side(), h, 5, _DamageSchools.PHYSICAL)
	assert_eq(h.health, 25)
	assert_eq(int(r["dealt"]), 5)
	assert_eq(str(r["outcome"]), "")

func test_empty_profile_minion_takes_exact_amount() -> void:
	var c := _minion(8)
	var r: Dictionary = _DamageResolver.deal(_side(), c, 3, "dark")
	assert_eq(c.health, 5)
	assert_eq(int(r["dealt"]), 3)

func test_non_positive_damage_is_a_no_op() -> void:
	var h := _hero(30)
	var r: Dictionary = _DamageResolver.deal(_side(), h, 0, _DamageSchools.PHYSICAL)
	assert_eq(h.health, 30)
	assert_eq(int(r["dealt"]), 0)
	r = _DamageResolver.deal(_side(), h, -4, _DamageSchools.PHYSICAL)
	assert_eq(h.health, 30)
	assert_eq(int(r["dealt"]), 0)

func test_null_defender_is_neutral() -> void:
	var h := _hero(30)
	var r: Dictionary = _DamageResolver.deal(null, h, 4, _DamageSchools.PHYSICAL)
	assert_eq(h.health, 26)
	assert_eq(int(r["dealt"]), 4)

func test_armor_still_soaks_before_health() -> void:
	var h := _hero(30)
	h.add_armor(3)
	var r: Dictionary = _DamageResolver.deal(_side(), h, 5, _DamageSchools.PHYSICAL)
	assert_eq(h.health, 28)
	assert_eq(int(r["dealt"]), 2)

func test_shroud_absorbs_the_hit() -> void:
	var c := _minion(8)
	c.shroud_active = true
	var r: Dictionary = _DamageResolver.deal(_side(), c, 5, "light")
	assert_eq(c.health, 8)
	assert_eq(int(r["dealt"]), 0)

func test_profile_defaults_to_empty_on_a_new_side() -> void:
	assert_true(_PlayerState.new(0, false).school_profile.is_empty())

# ---------------------------------------------------------------------------
# Matchup scaling and the reported outcome
# ---------------------------------------------------------------------------

func test_resisted_school_halves_damage() -> void:
	var h := _hero(30)
	var r: Dictionary = _DamageResolver.deal(_side({"resist": {"dark": true}}), h, 10, "dark")
	assert_eq(h.health, 25)
	assert_eq(int(r["dealt"]), 5)
	assert_eq(str(r["outcome"]), "resist")

func test_weak_school_adds_half_again() -> void:
	var c := _minion(30)
	var r: Dictionary = _DamageResolver.deal(_side({"weak": {"light": true}}), c, 10, "light")
	assert_eq(c.health, 15)
	assert_eq(int(r["dealt"]), 15)
	assert_eq(str(r["outcome"]), "weak")

func test_immune_school_deals_nothing() -> void:
	var c := _minion(8)
	var r: Dictionary = _DamageResolver.deal(_side({"immune": {"rift": true}}), c, 10, "rift")
	assert_eq(c.health, 8)
	assert_eq(int(r["dealt"]), 0)
	assert_eq(str(r["outcome"]), "immune")

func test_untagged_school_is_neutral_against_a_profile() -> void:
	var h := _hero(30)
	var r: Dictionary = _DamageResolver.deal(_side({"resist": {"dark": true}}), h, 6, "verdant")
	assert_eq(h.health, 24)
	assert_eq(str(r["outcome"]), "")

func test_knob_overrides_are_read() -> void:
	var tune := _CombatTuning.new({"resist_mult": 0.2})
	var h := _hero(30)
	var r: Dictionary = _DamageResolver.deal(_side({"resist": {"dark": true}}), h, 10, "dark", tune)
	assert_eq(int(r["dealt"]), 2)

func test_scaled_amount_matches_deal_scaling() -> void:
	var side := _side({"weak": {"dark": true}})
	assert_eq(_DamageResolver.scaled_amount(side, 10, "dark"), 15)
	assert_eq(_DamageResolver.scaled_amount(side, 10, "rift"), 10)
	assert_eq(_DamageResolver.scaled_amount(null, 10, "dark"), 10)

# ---------------------------------------------------------------------------
# Hero school resistance (TID-751): a fraction soaked on top of the profile
# ---------------------------------------------------------------------------

func _resisting_side(resists: Dictionary) -> _PlayerState:
	var p := _PlayerState.new(0, false)
	p.hero.school_resist = resists
	return p

func test_hero_resist_soaks_a_fraction_and_reads_resisted() -> void:
	var h := _hero(30)
	var r: Dictionary = _DamageResolver.deal(_resisting_side({"dark": 0.5}), h, 10, "dark")
	assert_eq(int(r["dealt"]), 5)
	assert_eq(str(r["outcome"]), "resist")

func test_hero_resist_stacks_with_a_weak_profile() -> void:
	var p := _resisting_side({"dark": 0.5})
	p.school_profile = {"weak": {"dark": true}}
	# 10 × weak 1.5 = 15, then × (1 - 0.5) = 7.5 → 8
	assert_eq(_DamageResolver.scaled_amount(p, 10, "dark"), 8)
	assert_eq(str(_DamageResolver.deal(p, _hero(30), 10, "dark")["outcome"]), "weak")

func test_hero_resist_only_affects_its_school() -> void:
	var p := _resisting_side({"dark": 0.5})
	assert_eq(_DamageResolver.scaled_amount(p, 10, "verdant"), 10)
	assert_eq(_DamageResolver.resist_fraction(p, "dark"), 0.5)
	assert_eq(_DamageResolver.resist_fraction(null, "dark"), 0.0)

func test_capped_resists_clamps_and_drops_unknown_schools() -> void:
	var out: Dictionary = _DamageSchools.capped_resists({"dark": 0.9, "verdant": 0.2, "nope": 0.5, "rift": 0.0})
	assert_eq(float(out.get("dark", -1.0)), _CombatTuning.new().get_f("max_player_resist"))
	assert_eq(float(out.get("verdant", -1.0)), 0.2)
	assert_false(out.has("nope"))
	assert_false(out.has("rift"))

func test_hero_school_resist_round_trips_through_to_dict() -> void:
	var h := _hero(30)
	h.school_resist = {"dark": 0.25}
	var restored := _HeroState.new(0)
	restored.from_dict(h.to_dict())
	assert_eq(float(restored.school_resist.get("dark", 0.0)), 0.25)
