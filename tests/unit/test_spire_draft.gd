## Unit tests for SpireDraft — draft pick generation.
##
## All tests are pure: no CardRegistry dependency. The pool is passed as a
## {id: template_dict} Dictionary, and tiers are tested via card_tier_from_template.
extends "res://tests/framework/test_case.gd"

const SpireDraftScript = preload("res://game_logic/spire/SpireDraft.gd")

var _draft: RefCounted

# Minimal template helpers
func _minion(cost: int) -> Dictionary:
	return {"card_class": "minion", "cost": cost, "attack": 1, "health": 1}

func _spell(cost: int) -> Dictionary:
	return {"card_class": "spell", "cost": cost, "attack": 0, "health": 0}

func _legendary() -> Dictionary:
	return {"card_class": "legendary", "cost": 6, "attack": 4, "health": 4}

# Pool covering all four tiers:
#   tier0: ghost(minion,1), skeleton(minion,2)
#   tier1: zombie(minion,3), ghoul(minion,4), mend(spell,1), restore(spell,2)
#   tier2: scorch(spell,3), shadow_bolt(spell,4), soul_harvest(spell,5)
#   tier3: ancient_guardian(legendary)
var _POOL_TEMPLATES: Dictionary = {}

func before_all() -> void:
	_POOL_TEMPLATES = {
		"ghost":           _minion(1),
		"skeleton":        _minion(2),
		"zombie":          _minion(3),
		"ghoul":           _minion(4),
		"mend":            _spell(1),
		"restore":         _spell(2),
		"scorch":          _spell(3),
		"shadow_bolt":     _spell(4),
		"soul_harvest":    _spell(5),
		"ancient_guardian": _legendary(),
	}

func before_each() -> void:
	_draft = SpireDraftScript.new()

func after_each() -> void:
	_draft = null

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng

func _picks(floor: int, seed_val: int) -> Array[String]:
	return _draft.generate_picks(floor, _rng(seed_val), _POOL_TEMPLATES)

# ---------------------------------------------------------------------------
# generate_picks — basic shape
# ---------------------------------------------------------------------------

func test_generate_picks_returns_three_cards() -> void:
	assert_eq(_picks(1, 1234).size(), 3)

func test_generate_picks_all_ids_are_non_empty() -> void:
	for p: String in _picks(1, 42):
		assert_true(p != "", "pick should be non-empty string")

func test_generate_picks_all_ids_are_in_pool() -> void:
	for p: String in _picks(1, 7):
		assert_true(_POOL_TEMPLATES.has(p), "pick '%s' not in test pool" % p)

func test_generate_picks_no_duplicates_floor1() -> void:
	var picks := _picks(1, 999)
	assert_ne(picks[0], picks[1])
	assert_ne(picks[0], picks[2])
	assert_ne(picks[1], picks[2])

func test_generate_picks_no_duplicates_floor5() -> void:
	var picks := _picks(5, 555)
	assert_ne(picks[0], picks[1])
	assert_ne(picks[0], picks[2])
	assert_ne(picks[1], picks[2])

func test_generate_picks_no_duplicates_floor10() -> void:
	var picks := _picks(10, 1111)
	assert_ne(picks[0], picks[1])
	assert_ne(picks[0], picks[2])
	assert_ne(picks[1], picks[2])

# ---------------------------------------------------------------------------
# Determinism: same (seed, floor) → same picks
# ---------------------------------------------------------------------------

func test_determinism_floor1_same_seed() -> void:
	var a := _picks(1, 12345)
	var b := _picks(1, 12345)
	assert_eq(a[0], b[0])
	assert_eq(a[1], b[1])
	assert_eq(a[2], b[2])

func test_determinism_floor7_same_seed() -> void:
	var a := _picks(7, 99999)
	var b := _picks(7, 99999)
	assert_eq(a[0], b[0])
	assert_eq(a[1], b[1])
	assert_eq(a[2], b[2])

func test_different_floors_produce_different_picks_eventually() -> void:
	var any_diff := false
	for s in range(5):
		var a := _picks(1, s * 31 + 7)
		var b := _picks(8, s * 31 + 7)
		if a[0] != b[0] or a[1] != b[1] or a[2] != b[2]:
			any_diff = true
			break
	assert_true(any_diff, "floor 1 and floor 8 should differ at least once")

func test_different_seeds_produce_different_picks_eventually() -> void:
	var any_diff := false
	for s in range(5):
		var a := _picks(3, s)
		var b := _picks(3, s + 100)
		if a[0] != b[0] or a[1] != b[1] or a[2] != b[2]:
			any_diff = true
			break
	assert_true(any_diff, "different seeds should produce different picks at least once")

# ---------------------------------------------------------------------------
# card_tier_from_template — pure, no CardRegistry
# ---------------------------------------------------------------------------

func test_tier_from_template_minion_cost1_is_tier0() -> void:
	assert_eq(_draft.card_tier_from_template(_minion(1)), 0)

func test_tier_from_template_minion_cost2_is_tier0() -> void:
	assert_eq(_draft.card_tier_from_template(_minion(2)), 0)

func test_tier_from_template_minion_cost3_is_tier1() -> void:
	assert_eq(_draft.card_tier_from_template(_minion(3)), 1)

func test_tier_from_template_minion_cost4_is_tier1() -> void:
	assert_eq(_draft.card_tier_from_template(_minion(4)), 1)

func test_tier_from_template_minion_cost5_is_tier2() -> void:
	assert_eq(_draft.card_tier_from_template(_minion(5)), 2)

func test_tier_from_template_spell_cost2_is_tier1() -> void:
	assert_eq(_draft.card_tier_from_template(_spell(2)), 1)

func test_tier_from_template_spell_cost3_is_tier2() -> void:
	assert_eq(_draft.card_tier_from_template(_spell(3)), 2)

func test_tier_from_template_legendary_is_tier3() -> void:
	assert_eq(_draft.card_tier_from_template(_legendary()), 3)

func test_tier_from_template_empty_dict_is_tier0() -> void:
	assert_eq(_draft.card_tier_from_template({}), 0)

# ---------------------------------------------------------------------------
# tier_weights
# ---------------------------------------------------------------------------

func test_tier_weights_floor1_common_heaviest() -> void:
	var w: Array[int] = _draft.tier_weights(1)
	assert_gt(w[0], w[1], "floor 1: tier0 weight should exceed tier1")

func test_tier_weights_floor1_no_legendaries() -> void:
	assert_eq(_draft.tier_weights(1)[3], 0, "floor 1 should have zero legendary weight")

func test_tier_weights_floor4_mid_tier_rises() -> void:
	var w1: int = _draft.tier_weights(1)[1]
	var w4: int = _draft.tier_weights(4)[1]
	assert_gt(w4, w1, "tier1 weight should be higher at floor 4 than floor 1")

func test_tier_weights_floor7_has_legendaries() -> void:
	assert_gt(_draft.tier_weights(7)[3], 0, "floor 7+ should have positive legendary weight")

func test_tier_weights_floor7_premium_ge_basic() -> void:
	var w: Array[int] = _draft.tier_weights(7)
	assert_gte(w[2], w[0], "floor 7: tier2 weight should be >= tier0")

func test_tier_weights_returns_four_elements() -> void:
	assert_eq(_draft.tier_weights(1).size(), 4)
	assert_eq(_draft.tier_weights(5).size(), 4)
	assert_eq(_draft.tier_weights(10).size(), 4)

# ---------------------------------------------------------------------------
# Tier distribution
# ---------------------------------------------------------------------------

func test_floor10_includes_upper_tier_cards_eventually() -> void:
	var found_upper := false
	for s in range(20):
		for p: String in _picks(10, s * 17 + 1):
			if _draft.card_tier_from_template(_POOL_TEMPLATES.get(p, {})) >= 2:
				found_upper = true
				break
		if found_upper:
			break
	assert_true(found_upper, "floor 10 should sometimes offer tier 2+ cards")

func test_floor1_mostly_tier0_cards() -> void:
	var tier0_count: int = 0
	var total_count: int = 0
	for s in range(10):
		for p: String in _picks(1, s * 13 + 3):
			if _draft.card_tier_from_template(_POOL_TEMPLATES.get(p, {})) == 0:
				tier0_count += 1
			total_count += 1
	# Expect at least 40% tier 0 (well under the 60% weight)
	assert_true(tier0_count * 10 >= total_count * 4,
		"floor 1 should mostly pick tier0 cards (%d/%d)" % [tier0_count, total_count])
