## Unit tests for the damage-school module (GID-181 / TID-748).
##
## DamageSchools is the one pure table every damage event will call for matchup
## multipliers. These tests pin the school of a card, the precedence of the
## immune / resist / weak tags, and the knobs it reads from CombatTuning.
extends "res://tests/framework/test_case.gd"

const _DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const _CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const _MagicTypes = preload("res://game_logic/MagicTypes.gd")
const _CardInstance = preload("res://game_logic/battle/CardInstance.gd")

# ---------------------------------------------------------------------------
# Schools
# ---------------------------------------------------------------------------

func test_all_schools_is_physical_plus_magic_types() -> void:
	var schools: Array[String] = _DamageSchools.all_schools()
	assert_eq(schools.size(), 1 + _MagicTypes.all_types().size())
	assert_eq(schools[0], _DamageSchools.PHYSICAL)
	for mt: String in _MagicTypes.all_types():
		assert_has(schools, mt, "magic type %s missing from schools" % mt)

func test_school_of_card_instance_uses_magic_type() -> void:
	var card := _CardInstance.new({"id": "t_light", "name": "L", "magic_type": "light"})
	assert_eq(_DamageSchools.school_of(card), "light")

func test_school_of_plain_minion_is_physical() -> void:
	var card := _CardInstance.new({"id": "t_ghoul", "name": "G"})
	assert_eq(_DamageSchools.school_of(card), _DamageSchools.PHYSICAL)

func test_school_of_dictionary_template() -> void:
	assert_eq(_DamageSchools.school_of({"magic_type": "rift"}), "rift")
	assert_eq(_DamageSchools.school_of({}), _DamageSchools.PHYSICAL)

func test_school_of_unknown_magic_type_is_physical() -> void:
	assert_eq(_DamageSchools.school_of({"magic_type": "fire"}), _DamageSchools.PHYSICAL)

func test_school_of_null_is_physical() -> void:
	assert_eq(_DamageSchools.school_of(null), _DamageSchools.PHYSICAL)

# ---------------------------------------------------------------------------
# Outcome precedence
# ---------------------------------------------------------------------------

func test_untagged_school_is_neutral() -> void:
	assert_eq(_DamageSchools.outcome("dark", {}), "")
	assert_almost_eq(_DamageSchools.mult("dark", {}, _CombatTuning.new()), 1.0)

func test_each_tag_maps_to_its_outcome() -> void:
	assert_eq(_DamageSchools.outcome("light", {"weak": {"light": true}}), "weak")
	assert_eq(_DamageSchools.outcome("light", {"resist": {"light": true}}), "resist")
	assert_eq(_DamageSchools.outcome("light", {"immune": {"light": true}}), "immune")

func test_immune_beats_resist_beats_weak() -> void:
	var p: Dictionary = {"weak": {"dark": true}, "resist": {"dark": true}, "immune": {"dark": true}}
	assert_eq(_DamageSchools.outcome("dark", p), "immune")
	p.erase("immune")
	assert_eq(_DamageSchools.outcome("dark", p), "resist")
	p.erase("resist")
	assert_eq(_DamageSchools.outcome("dark", p), "weak")

func test_tag_only_applies_to_its_own_school() -> void:
	var p: Dictionary = {"resist": {"verdant": true}}
	assert_eq(_DamageSchools.outcome("light", p), "")
	assert_almost_eq(_DamageSchools.mult("light", p, _CombatTuning.new()), 1.0)

func test_false_tag_is_ignored() -> void:
	assert_eq(_DamageSchools.outcome("rift", {"weak": {"rift": false}}), "")

# ---------------------------------------------------------------------------
# Multipliers and knobs
# ---------------------------------------------------------------------------

func test_default_knobs_give_starting_multipliers() -> void:
	var t := _CombatTuning.new()
	assert_almost_eq(_DamageSchools.mult("light", {"resist": {"light": true}}, t), 0.5)
	assert_almost_eq(_DamageSchools.mult("light", {"weak": {"light": true}}, t), 1.5)
	assert_almost_eq(_DamageSchools.mult("light", {"immune": {"light": true}}, t), 0.0)

func test_mult_reads_overridden_knobs() -> void:
	var t := _CombatTuning.new({"resist_mult": 0.25, "weak_mult": 2.0, "immune_mult": 0.1})
	assert_almost_eq(_DamageSchools.mult("light", {"resist": {"light": true}}, t), 0.25)
	assert_almost_eq(_DamageSchools.mult("light", {"weak": {"light": true}}, t), 2.0)
	assert_almost_eq(_DamageSchools.mult("light", {"immune": {"light": true}}, t), 0.1)

func test_mult_defaults_tune_when_null() -> void:
	assert_almost_eq(_DamageSchools.mult("light", {"weak": {"light": true}}), 1.5)

func test_knobs_are_registered_in_combat_tuning() -> void:
	for key: String in ["resist_mult", "weak_mult", "immune_mult"]:
		assert_true(_CombatTuning.row_for(key).size() > 0, "%s missing from CombatTuning.DEFS" % key)

# ---------------------------------------------------------------------------
# Scaled damage
# ---------------------------------------------------------------------------

func test_scale_weak_rounds_to_nearest() -> void:
	var p: Dictionary = {"weak": {"dark": true}}
	assert_eq(_DamageSchools.scale(10, "dark", p), 15)

func test_scale_resist_rounds_half_up_and_never_below_one() -> void:
	var p: Dictionary = {"resist": {"dark": true}}
	assert_eq(_DamageSchools.scale(3, "dark", p), 2)
	assert_eq(_DamageSchools.scale(1, "dark", p), 1)

func test_scale_immune_deals_nothing() -> void:
	assert_eq(_DamageSchools.scale(10, "dark", {"immune": {"dark": true}}), 0)

func test_scale_zero_or_negative_damage_stays_zero() -> void:
	assert_eq(_DamageSchools.scale(0, "dark", {"weak": {"dark": true}}), 0)
	assert_eq(_DamageSchools.scale(-4, "dark", {}), 0)

func test_scale_neutral_is_unchanged() -> void:
	assert_eq(_DamageSchools.scale(7, "physical", {}), 7)
