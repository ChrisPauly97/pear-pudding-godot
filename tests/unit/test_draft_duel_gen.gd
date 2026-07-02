## Unit tests for DraftDuelGen — sealed-pool round generation + wire helpers for
## Draft Duels (GID-104 / TID-385).
##
## All tests are pure: no CardRegistry dependency. The pool is passed as a
## {id: template_dict} Dictionary, mirroring tests/unit/test_spire_draft.gd.
extends "res://tests/framework/test_case.gd"

const DraftDuelGen = preload("res://game_logic/net/DraftDuelGen.gd")

func _minion(cost: int) -> Dictionary:
	return {"card_class": "minion", "cost": cost, "attack": 1, "health": 1}

func _spell(cost: int) -> Dictionary:
	return {"card_class": "spell", "cost": cost, "attack": 0, "health": 0}

func _legendary() -> Dictionary:
	return {"card_class": "legendary", "cost": 6, "attack": 4, "health": 4}

var _POOL_TEMPLATES: Dictionary = {}

func before_all() -> void:
	_POOL_TEMPLATES = {
		"ghost":            _minion(1),
		"skeleton":         _minion(2),
		"zombie":           _minion(3),
		"ghoul":            _minion(4),
		"mend":             _spell(1),
		"restore":          _spell(2),
		"scorch":           _spell(3),
		"shadow_bolt":      _spell(4),
		"soul_harvest":     _spell(5),
		"ancient_guardian": _legendary(),
	}

# ---------------------------------------------------------------------------
# generate_rounds — shape
# ---------------------------------------------------------------------------

func test_generate_rounds_returns_num_rounds_entries() -> void:
	var rounds: Array = DraftDuelGen.generate_rounds(1234, _POOL_TEMPLATES)
	assert_eq(rounds.size(), DraftDuelGen.NUM_ROUNDS)

func test_generate_rounds_each_round_has_options_per_round_picks() -> void:
	var rounds: Array = DraftDuelGen.generate_rounds(42, _POOL_TEMPLATES)
	for round_picks in rounds:
		assert_eq((round_picks as Array).size(), DraftDuelGen.OPTIONS_PER_ROUND)

func test_generate_rounds_all_ids_are_in_pool() -> void:
	var rounds: Array = DraftDuelGen.generate_rounds(7, _POOL_TEMPLATES)
	for round_picks in rounds:
		for pick: String in (round_picks as Array):
			assert_true(_POOL_TEMPLATES.has(pick), "pick '%s' not in test pool" % pick)

func test_generate_rounds_empty_pool_returns_empty() -> void:
	var rounds: Array = DraftDuelGen.generate_rounds(1, {})
	assert_eq(rounds.size(), 0)

func test_generate_rounds_no_duplicate_options_within_a_round() -> void:
	var rounds: Array = DraftDuelGen.generate_rounds(999, _POOL_TEMPLATES)
	for round_picks in rounds:
		var picks: Array = round_picks
		assert_ne(picks[0], picks[1])
		assert_ne(picks[0], picks[2])
		assert_ne(picks[1], picks[2])

# ---------------------------------------------------------------------------
# Determinism: same seed + pool ⇒ identical rounds (the whole fairness point)
# ---------------------------------------------------------------------------

func test_determinism_same_seed_same_rounds() -> void:
	var a: Array = DraftDuelGen.generate_rounds(55555, _POOL_TEMPLATES)
	var b: Array = DraftDuelGen.generate_rounds(55555, _POOL_TEMPLATES)
	assert_eq(a.size(), b.size())
	for i in range(a.size()):
		var pa: Array = a[i]
		var pb: Array = b[i]
		assert_eq(pa[0], pb[0], "round %d option 0" % i)
		assert_eq(pa[1], pb[1], "round %d option 1" % i)
		assert_eq(pa[2], pb[2], "round %d option 2" % i)

func test_different_seeds_produce_different_rounds_eventually() -> void:
	var any_diff := false
	for s in range(5):
		var a: Array = DraftDuelGen.generate_rounds(s * 31 + 1, _POOL_TEMPLATES)
		var b: Array = DraftDuelGen.generate_rounds(s * 31 + 999, _POOL_TEMPLATES)
		for i in range(a.size()):
			var pa: Array = a[i]
			var pb: Array = b[i]
			if pa[0] != pb[0] or pa[1] != pb[1] or pa[2] != pb[2]:
				any_diff = true
				break
		if any_diff:
			break
	assert_true(any_diff, "different seeds should produce different rounds at least once")

func test_later_rounds_can_offer_higher_tier_cards() -> void:
	var found_upper := false
	for s in range(20):
		var rounds: Array = DraftDuelGen.generate_rounds(s * 17 + 3, _POOL_TEMPLATES)
		var last_round: Array = rounds[rounds.size() - 1]
		for pick: String in last_round:
			if DraftDuelGen.tier_for_template(_POOL_TEMPLATES.get(pick, {})) >= 2:
				found_upper = true
				break
		if found_upper:
			break
	assert_true(found_upper, "the final round should sometimes offer tier 2+ cards")

# ---------------------------------------------------------------------------
# encode_seed / decode_seed — wire round trip
# ---------------------------------------------------------------------------

func test_encode_decode_seed_round_trip() -> void:
	var payload: Dictionary = DraftDuelGen.encode_seed(778899)
	var decoded: Dictionary = DraftDuelGen.decode_seed(payload)
	assert_true(bool(decoded["valid"]))
	assert_eq(int(decoded["seed"]), 778899)
	assert_eq(int(decoded["rounds"]), DraftDuelGen.NUM_ROUNDS)

func test_decode_seed_garbage_is_invalid() -> void:
	var decoded: Dictionary = DraftDuelGen.decode_seed("not a dict")
	assert_false(bool(decoded["valid"]))
	assert_eq(int(decoded["seed"]), 0)

func test_decode_seed_missing_seed_key_is_invalid() -> void:
	var decoded: Dictionary = DraftDuelGen.decode_seed({"v": 1})
	assert_false(bool(decoded["valid"]))

func test_decode_seed_null_is_invalid() -> void:
	var decoded: Dictionary = DraftDuelGen.decode_seed(null)
	assert_false(bool(decoded["valid"]))

# ---------------------------------------------------------------------------
# make_drafted_instance — transient card instance shape
# ---------------------------------------------------------------------------

func test_make_drafted_instance_shape() -> void:
	var inst: Dictionary = DraftDuelGen.make_drafted_instance("ghost", 0, 2, "abcd1234", _minion(1))
	assert_eq(str(inst.get("template_id", "")), "ghost")
	assert_eq(int(inst.get("attack", -1)), 1)
	assert_eq(int(inst.get("health", -1)), 1)
	assert_eq(int(inst.get("cost", -1)), 1)
	assert_eq(int(inst.get("kills", -1)), 0)
	assert_eq(int(inst.get("battles_survived", -1)), 0)

func test_make_drafted_instance_uid_is_namespaced() -> void:
	var inst: Dictionary = DraftDuelGen.make_drafted_instance("ghost", 0, 3, "tok123", _minion(1))
	var uid: String = str(inst.get("uid", ""))
	assert_true(uid.begins_with("draft_"), "uid should be draft-namespaced: %s" % uid)
	assert_has(uid, "tok123")
	assert_has(uid, "ghost")

func test_make_drafted_instance_uids_differ_per_round() -> void:
	var a: Dictionary = DraftDuelGen.make_drafted_instance("ghost", 0, 1, "tok", _minion(1))
	var b: Dictionary = DraftDuelGen.make_drafted_instance("ghost", 0, 2, "tok", _minion(1))
	assert_ne(str(a.get("uid", "")), str(b.get("uid", "")))

func test_make_drafted_instance_rarity_by_tier() -> void:
	var t0: Dictionary = DraftDuelGen.make_drafted_instance("ghost", 0, 0, "tok", _minion(1))
	var t3: Dictionary = DraftDuelGen.make_drafted_instance("ancient_guardian", 3, 0, "tok", _legendary())
	assert_eq(str(t0.get("rarity", "")), "common")
	assert_eq(str(t3.get("rarity", "")), "legendary")

func test_make_drafted_instance_rarity_clamps_out_of_range_tier() -> void:
	var inst: Dictionary = DraftDuelGen.make_drafted_instance("ghost", 99, 0, "tok", _minion(1))
	assert_eq(str(inst.get("rarity", "")), "legendary")

# ---------------------------------------------------------------------------
# tier_for_template — delegates to SpireDraft, no drift between draft modes
# ---------------------------------------------------------------------------

func test_tier_for_template_matches_expected_buckets() -> void:
	assert_eq(DraftDuelGen.tier_for_template(_minion(1)), 0)
	assert_eq(DraftDuelGen.tier_for_template(_minion(3)), 1)
	assert_eq(DraftDuelGen.tier_for_template(_minion(5)), 2)
	assert_eq(DraftDuelGen.tier_for_template(_legendary()), 3)
