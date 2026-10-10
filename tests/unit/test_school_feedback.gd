## Unit tests for school combat feedback (GID-181 / TID-752): the damage-number text and
## colour rules, the enemy pip data, and the last-hit record the resolver leaves on a unit
## (which the battle UI reads, and which rides the state mirror to PvP / co-op viewers).
extends "res://tests/framework/test_case.gd"

const _SchoolFeedback = preload("res://game_logic/battle/SchoolFeedback.gd")
const _DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const _DamageResolver = preload("res://game_logic/battle/DamageResolver.gd")
const _MagicTypes = preload("res://game_logic/MagicTypes.gd")
const _HeroState = preload("res://game_logic/battle/HeroState.gd")
const _CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const _PlayerState = preload("res://game_logic/battle/PlayerState.gd")

func _side(profile: Dictionary = {}) -> _PlayerState:
	var p := _PlayerState.new(1, true)
	p.school_profile = profile
	return p

# ---------------------------------------------------------------------------
# Damage text
# ---------------------------------------------------------------------------

func test_outcome_words() -> void:
	assert_eq(_SchoolFeedback.outcome_word("weak"), "Weak!")
	assert_eq(_SchoolFeedback.outcome_word("resist"), "Resisted")
	assert_eq(_SchoolFeedback.outcome_word("immune"), "Immune")
	assert_eq(_SchoolFeedback.outcome_word(""), "")

func test_neutral_damage_text_is_just_the_number() -> void:
	assert_eq(_SchoolFeedback.damage_text(-7, ""), "-7")

func test_weak_and_resisted_text_carry_a_suffix() -> void:
	assert_eq(_SchoolFeedback.damage_text(-7, "weak"), "-7 Weak!")
	assert_eq(_SchoolFeedback.damage_text(-3, "resist"), "-3 Resisted")

func test_immune_reads_immune_alone() -> void:
	assert_eq(_SchoolFeedback.damage_text(0, "immune"), "Immune")

# ---------------------------------------------------------------------------
# Colour
# ---------------------------------------------------------------------------

func test_physical_is_neutral() -> void:
	assert_eq(_SchoolFeedback.school_color(_DamageSchools.PHYSICAL), _SchoolFeedback.NEUTRAL_COLOR)
	assert_eq(_SchoolFeedback.school_color("not_a_school"), _SchoolFeedback.NEUTRAL_COLOR)

func test_magic_schools_use_magic_type_colour() -> void:
	for school: String in _MagicTypes.all_types():
		assert_eq(_SchoolFeedback.school_color(school), _MagicTypes.type_color(school), school)

# ---------------------------------------------------------------------------
# Pips and tooltips
# ---------------------------------------------------------------------------

func test_pips_list_each_tagged_school_once() -> void:
	var pips: Array[Dictionary] = _SchoolFeedback.pips_for({"resist": {"dark": true}, "weak": {"light": true}})
	assert_eq(pips.size(), 2)
	assert_eq(str(pips[0]["school"]), "light")
	assert_eq(str(pips[0]["outcome"]), "weak")
	assert_eq(str(pips[1]["school"]), "dark")
	assert_eq(str(pips[1]["outcome"]), "resist")

func test_empty_profile_has_no_pips() -> void:
	assert_true(_SchoolFeedback.pips_for({}).is_empty())

func test_pip_tooltip_states_the_multiplier() -> void:
	assert_eq(_SchoolFeedback.pip_tooltip("light", "weak"), "Weak to %s: takes x1.5 damage"
			% _MagicTypes.display_name("light"))
	assert_true(_SchoolFeedback.pip_tooltip("dark", "resist").begins_with("Resists "))
	assert_true(_SchoolFeedback.pip_tooltip("rift", "immune").ends_with("takes no damage"))

# ---------------------------------------------------------------------------
# Last-hit record left by the resolver
# ---------------------------------------------------------------------------

func test_resolver_records_school_outcome_and_serial_on_hero() -> void:
	var h := _HeroState.new(1)
	h.health = 30
	_DamageResolver.deal(_side({"weak": {"light": true}}), h, 4, "light")
	assert_eq(h.hit_school, "light")
	assert_eq(h.hit_outcome, "weak")
	assert_eq(h.hit_serial, 1)
	_DamageResolver.deal(_side({"immune": {"light": true}}), h, 4, "light")
	assert_eq(h.hit_outcome, "immune")
	assert_eq(h.hit_serial, 2)
	assert_eq(h.health, 24, "the weak hit took 6; the immune hit took nothing")

func test_resolver_records_on_card() -> void:
	var c := _CardInstance.new({"id": "t", "name": "M", "attack": 1, "health": 8})
	_DamageResolver.deal(_side({"resist": {"dark": true}}), c, 2, "dark")
	assert_eq(c.hit_outcome, "resist")
	assert_eq(c.hit_serial, 1)

func test_hit_record_survives_state_round_trip() -> void:
	var c := _CardInstance.new({"id": "t", "name": "M", "attack": 1, "health": 8})
	_DamageResolver.deal(_side({"weak": {"dark": true}}), c, 2, "dark")
	var back := _CardInstance.new({})
	back.from_dict(c.to_dict())
	assert_eq(back.hit_school, "dark")
	assert_eq(back.hit_outcome, "weak")
	assert_eq(back.hit_serial, 1)

func test_neutral_hit_clears_outcome_but_advances_serial() -> void:
	var h := _HeroState.new(1)
	h.health = 30
	_DamageResolver.deal(_side({"weak": {"light": true}}), h, 4, "light")
	_DamageResolver.deal(_side(), h, 4, "light")
	assert_eq(h.hit_outcome, "")
	assert_eq(h.hit_serial, 2)
