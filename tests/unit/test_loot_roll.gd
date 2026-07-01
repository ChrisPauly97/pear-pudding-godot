## Unit tests for LootRoll (GID-102 / TID-381) — need/greed precedence, tie-break by
## rolled value, all-pass (no winner), encode/decode round-trips + garbage tolerance.
## Mirrors test_chat_sync.gd / test_world_sync.gd structurally.
extends "res://tests/framework/test_case.gd"

const LootRoll = preload("res://game_logic/net/LootRoll.gd")


## Deterministic RNG helper: seeds a RandomNumberGenerator so resolve_winner()'s rolled
## values are fully reproducible across test runs.
static func _seeded_rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng


# ---------------------------------------------------------------------------
# resolve_winner — need beats greed
# ---------------------------------------------------------------------------

func test_need_always_beats_greed_regardless_of_rolled_value() -> void:
	# Run many seeds — need must win every time even though rolls are random,
	# because tier comparison happens before value comparison.
	for seed_val in range(20):
		var choices: Dictionary = {"alice": LootRoll.CHOICE_NEED, "bob": LootRoll.CHOICE_GREED}
		var outcome: Dictionary = LootRoll.resolve_winner(choices, _seeded_rng(seed_val))
		assert_eq(str(outcome.get("winner_token", "")), "alice",
			"need should beat greed at seed %d" % seed_val)


func test_need_beats_multiple_greed_entrants() -> void:
	var choices: Dictionary = {
		"alice": LootRoll.CHOICE_GREED,
		"bob": LootRoll.CHOICE_NEED,
		"carol": LootRoll.CHOICE_GREED,
	}
	var outcome: Dictionary = LootRoll.resolve_winner(choices, _seeded_rng(1))
	assert_eq(str(outcome.get("winner_token", "")), "bob")


func test_greed_beats_pass() -> void:
	var choices: Dictionary = {"alice": LootRoll.CHOICE_GREED, "bob": LootRoll.CHOICE_PASS}
	var outcome: Dictionary = LootRoll.resolve_winner(choices, _seeded_rng(2))
	assert_eq(str(outcome.get("winner_token", "")), "alice")


# ---------------------------------------------------------------------------
# resolve_winner — tie-break by highest rolled value within the same tier
# ---------------------------------------------------------------------------

func test_tie_break_within_same_tier_picks_highest_rolled_value() -> void:
	# Force deterministic rolls by resolving with a fixed seed, then read back the
	# actual rolled values to confirm the winner truly had the max among same-tier entrants.
	var choices: Dictionary = {
		"alice": LootRoll.CHOICE_NEED,
		"bob": LootRoll.CHOICE_NEED,
		"carol": LootRoll.CHOICE_NEED,
	}
	var outcome: Dictionary = LootRoll.resolve_winner(choices, _seeded_rng(42))
	var rolls: Dictionary = outcome.get("rolls", {})
	var winner: String = str(outcome.get("winner_token", ""))
	assert_true(rolls.has(winner), "winner must have a recorded roll")
	var winner_value: int = int(rolls[winner])
	for token in rolls.keys():
		assert_true(int(rolls[token]) <= winner_value,
			"winner's rolled value must be >= every other same-tier entrant")


func test_tie_break_deterministic_across_repeated_calls_with_same_seed_sequence() -> void:
	# Same choices + a fresh RNG seeded identically must produce the same winner.
	var choices: Dictionary = {"alice": LootRoll.CHOICE_NEED, "bob": LootRoll.CHOICE_NEED}
	var outcome1: Dictionary = LootRoll.resolve_winner(choices, _seeded_rng(7))
	var outcome2: Dictionary = LootRoll.resolve_winner(choices, _seeded_rng(7))
	assert_eq(str(outcome1.get("winner_token", "")), str(outcome2.get("winner_token", "")))
	assert_eq(outcome1.get("rolls", {}), outcome2.get("rolls", {}))


# ---------------------------------------------------------------------------
# resolve_winner — all-pass has no winner
# ---------------------------------------------------------------------------

func test_all_pass_has_no_winner() -> void:
	var choices: Dictionary = {"alice": LootRoll.CHOICE_PASS, "bob": LootRoll.CHOICE_PASS}
	var outcome: Dictionary = LootRoll.resolve_winner(choices, _seeded_rng(3))
	assert_eq(str(outcome.get("winner_token", "")), "")
	assert_eq((outcome.get("rolls", {}) as Dictionary).size(), 0)


func test_empty_choices_has_no_winner() -> void:
	var outcome: Dictionary = LootRoll.resolve_winner({}, _seeded_rng(4))
	assert_eq(str(outcome.get("winner_token", "")), "")


func test_unrecognized_choice_string_treated_as_pass() -> void:
	var choices: Dictionary = {"alice": "unknown_choice", "bob": LootRoll.CHOICE_GREED}
	var outcome: Dictionary = LootRoll.resolve_winner(choices, _seeded_rng(5))
	assert_eq(str(outcome.get("winner_token", "")), "bob")


# ---------------------------------------------------------------------------
# resolve_winner — timeout-as-pass behaviour (caller pre-fills missing tokens as pass)
# ---------------------------------------------------------------------------

func test_timeout_as_pass_is_equivalent_to_explicit_pass() -> void:
	# The caller (WorldScene._settle_loot_roll) fills in "pass" for any participant
	# that never responded before the timeout. Verify that doing so explicitly
	# produces the identical result to what a caller who omitted the entry entirely
	# would get if resolve_winner treated missing participants as absent (it does
	# not iterate participants outside of `choices`, so the caller-side fill-in is
	# what makes timeout behave as pass).
	var choices_explicit_pass: Dictionary = {
		"alice": LootRoll.CHOICE_GREED,
		"bob": LootRoll.CHOICE_PASS,  # simulates bob timing out
	}
	var choices_omitted: Dictionary = {
		"alice": LootRoll.CHOICE_GREED,
		# bob omitted entirely
	}
	var outcome_a: Dictionary = LootRoll.resolve_winner(choices_explicit_pass, _seeded_rng(9))
	var outcome_b: Dictionary = LootRoll.resolve_winner(choices_omitted, _seeded_rng(9))
	assert_eq(str(outcome_a.get("winner_token", "")), str(outcome_b.get("winner_token", "")))
	assert_eq(outcome_a.get("rolls", {}), outcome_b.get("rolls", {}))


func test_normalize_choice_maps_unknown_to_pass() -> void:
	assert_eq(LootRoll.normalize_choice("need"), LootRoll.CHOICE_NEED)
	assert_eq(LootRoll.normalize_choice("greed"), LootRoll.CHOICE_GREED)
	assert_eq(LootRoll.normalize_choice("pass"), LootRoll.CHOICE_PASS)
	assert_eq(LootRoll.normalize_choice("bogus"), LootRoll.CHOICE_PASS)
	assert_eq(LootRoll.normalize_choice(""), LootRoll.CHOICE_PASS)


# ---------------------------------------------------------------------------
# encode_start / decode_start round-trip
# ---------------------------------------------------------------------------

func test_start_round_trip_preserves_roll_id_item_and_participants() -> void:
	var item: Dictionary = {"card_ids": ["ghost", "skeleton"], "tier": 2}
	var payload: Dictionary = LootRoll.encode_start("roll_1", item, ["tok_a", "tok_b"])
	var d: Dictionary = LootRoll.decode_start(payload)
	assert_eq(str(d.get("roll_id", "")), "roll_1")
	assert_eq((d.get("item", {}) as Dictionary).get("tier", 0), 2)
	assert_eq(d.get("participants", []), ["tok_a", "tok_b"])


func test_start_decode_garbage_returns_defaults() -> void:
	var d: Dictionary = LootRoll.decode_start({})
	assert_eq(str(d.get("roll_id", "x")), "")
	assert_eq((d.get("item", {}) as Dictionary).size(), 0)
	assert_eq((d.get("participants", []) as Array).size(), 0)


func test_start_decode_non_dictionary_payload_does_not_throw() -> void:
	var d: Dictionary = LootRoll.decode_start("not a dict")
	assert_eq(str(d.get("roll_id", "x")), "")


func test_start_decode_null_does_not_throw() -> void:
	var d: Dictionary = LootRoll.decode_start(null)
	assert_eq(str(d.get("roll_id", "x")), "")


# ---------------------------------------------------------------------------
# encode_choice / decode_choice round-trip
# ---------------------------------------------------------------------------

func test_choice_round_trip_preserves_roll_id_and_normalized_choice() -> void:
	var payload: Array = LootRoll.encode_choice("roll_2", "need")
	var d: Dictionary = LootRoll.decode_choice(payload)
	assert_eq(str(d.get("roll_id", "")), "roll_2")
	assert_eq(str(d.get("choice", "")), LootRoll.CHOICE_NEED)


func test_choice_encode_normalizes_unknown_choice_to_pass() -> void:
	var payload: Array = LootRoll.encode_choice("roll_3", "gibberish")
	var d: Dictionary = LootRoll.decode_choice(payload)
	assert_eq(str(d.get("choice", "")), LootRoll.CHOICE_PASS)


func test_choice_decode_short_array_returns_defaults() -> void:
	var d: Dictionary = LootRoll.decode_choice(["only_one"])
	assert_eq(str(d.get("roll_id", "x")), "")
	assert_eq(str(d.get("choice", "")), LootRoll.CHOICE_PASS)


func test_choice_decode_empty_array_returns_defaults() -> void:
	var d: Dictionary = LootRoll.decode_choice([])
	assert_eq(str(d.get("roll_id", "x")), "")


func test_choice_decode_non_array_does_not_throw() -> void:
	var d: Dictionary = LootRoll.decode_choice("not an array")
	assert_eq(str(d.get("roll_id", "x")), "")


# ---------------------------------------------------------------------------
# encode_result / decode_result round-trip
# ---------------------------------------------------------------------------

func test_result_round_trip_preserves_roll_id_winner_and_rolls() -> void:
	var payload: Dictionary = LootRoll.encode_result("roll_4", "tok_a", {"tok_a": 88, "tok_b": 40})
	var d: Dictionary = LootRoll.decode_result(payload)
	assert_eq(str(d.get("roll_id", "")), "roll_4")
	assert_eq(str(d.get("winner_token", "")), "tok_a")
	var rolls: Dictionary = d.get("rolls", {})
	assert_eq(int(rolls.get("tok_a", 0)), 88)
	assert_eq(int(rolls.get("tok_b", 0)), 40)


func test_result_round_trip_empty_winner_for_all_pass() -> void:
	var payload: Dictionary = LootRoll.encode_result("roll_5", "", {})
	var d: Dictionary = LootRoll.decode_result(payload)
	assert_eq(str(d.get("winner_token", "x")), "")
	assert_eq((d.get("rolls", {}) as Dictionary).size(), 0)


func test_result_decode_garbage_returns_defaults() -> void:
	var d: Dictionary = LootRoll.decode_result({})
	assert_eq(str(d.get("roll_id", "x")), "")
	assert_eq(str(d.get("winner_token", "x")), "")
	assert_eq((d.get("rolls", {}) as Dictionary).size(), 0)


func test_result_decode_non_dictionary_payload_does_not_throw() -> void:
	var d: Dictionary = LootRoll.decode_result("not a dict")
	assert_eq(str(d.get("roll_id", "x")), "")


func test_result_decode_null_does_not_throw() -> void:
	var d: Dictionary = LootRoll.decode_result(null)
	assert_eq(str(d.get("roll_id", "x")), "")
