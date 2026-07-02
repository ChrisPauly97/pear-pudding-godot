## Unit tests for TournamentSync (GID-104 / TID-386) — the pure round-robin
## bracket scheduling/advancement/payout math + encode/decode round trip.
## Mirrors test_rating_math.gd (pure, scene-free).
extends "res://tests/framework/test_case.gd"

const TournamentSync = preload("res://game_logic/net/TournamentSync.gd")


# ---------------------------------------------------------------------------
# Scheduling
# ---------------------------------------------------------------------------

func test_round_robin_match_count_3_players() -> void:
	var matches: Array = TournamentSync.build_round_robin_matches(3)
	assert_eq(matches.size(), 3)
	assert_eq(TournamentSync.match_count(3), 3)


func test_round_robin_match_count_4_players() -> void:
	var matches: Array = TournamentSync.build_round_robin_matches(4)
	assert_eq(matches.size(), 6)
	assert_eq(TournamentSync.match_count(4), 6)


func test_round_robin_every_pair_appears_exactly_once() -> void:
	var matches: Array = TournamentSync.build_round_robin_matches(4)
	var seen: Dictionary = {}
	for m: Dictionary in matches:
		var key: String = "%d-%d" % [m["a"], m["b"]]
		assert_false(seen.has(key), "duplicate pairing %s" % key)
		seen[key] = true
		assert_lt(int(m["a"]), int(m["b"]))
	assert_eq(seen.size(), 6)


func test_round_robin_matches_start_undecided() -> void:
	for m: Dictionary in TournamentSync.build_round_robin_matches(3):
		assert_eq(int(m["winner"]), -1)
		assert_false(bool(m["done"]))


func test_payout_pot_is_ante_times_players() -> void:
	assert_eq(TournamentSync.payout_pot(50, 4), 200)
	assert_eq(TournamentSync.payout_pot(50, 3), 150)
	assert_eq(TournamentSync.payout_pot(0, 4), 0)


# ---------------------------------------------------------------------------
# new_bracket
# ---------------------------------------------------------------------------

func test_new_bracket_builds_expected_shape_for_4_players() -> void:
	var tokens: Array = ["t0", "t1", "t2", "t3"]
	var names: Array = ["Alice", "Bob", "Cara", "Dan"]
	var b: Dictionary = TournamentSync.new_bracket(tokens, names, 50)
	assert_false(b.is_empty())
	assert_eq((b["matches"] as Array).size(), 6)
	assert_eq(int(b["current_match"]), 0)
	assert_eq(int(b["ante"]), 50)
	assert_eq(int(b["pot"]), 200)
	assert_eq(int(b["winner_idx"]), -1)
	assert_false(bool(b["finished"]))


func test_new_bracket_rejects_too_few_players() -> void:
	assert_true(TournamentSync.new_bracket(["a", "b"], ["A", "B"], 10).is_empty())


func test_new_bracket_rejects_too_many_players() -> void:
	assert_true(TournamentSync.new_bracket(
		["a", "b", "c", "d", "e"], ["A", "B", "C", "D", "E"], 10).is_empty())


func test_new_bracket_rejects_mismatched_names_array() -> void:
	assert_true(TournamentSync.new_bracket(["a", "b", "c"], ["A", "B"], 10).is_empty())


func test_new_bracket_accepts_3_players() -> void:
	var b: Dictionary = TournamentSync.new_bracket(["a", "b", "c"], ["A", "B", "C"], 25)
	assert_false(b.is_empty())
	assert_eq((b["matches"] as Array).size(), 3)


# ---------------------------------------------------------------------------
# get_current_match / record_match_result — advancement
# ---------------------------------------------------------------------------

func _make_3p_bracket() -> Dictionary:
	return TournamentSync.new_bracket(["t0", "t1", "t2"], ["A", "B", "C"], 10)


func test_get_current_match_starts_at_first_match() -> void:
	var b: Dictionary = _make_3p_bracket()
	var m: Dictionary = TournamentSync.get_current_match(b)
	assert_eq(int(m["a"]), 0)
	assert_eq(int(m["b"]), 1)


func test_record_match_result_advances_current_match() -> void:
	var b: Dictionary = _make_3p_bracket()
	b = TournamentSync.record_match_result(b, 0)
	assert_eq(int(b["current_match"]), 1)
	var m0: Dictionary = (b["matches"] as Array)[0]
	assert_true(bool(m0["done"]))
	assert_eq(int(m0["winner"]), 0)


func test_record_match_result_full_bracket_finishes() -> void:
	var b: Dictionary = _make_3p_bracket()
	# Matches in order: (0,1) (0,2) (1,2). Player 0 wins both its matches.
	b = TournamentSync.record_match_result(b, 0)  # 0 beats 1
	b = TournamentSync.record_match_result(b, 0)  # 0 beats 2
	assert_false(bool(b["finished"]))
	b = TournamentSync.record_match_result(b, 1)  # 1 beats 2 (irrelevant to standings)
	assert_true(bool(b["finished"]))
	assert_eq(int(b["winner_idx"]), 0)


func test_record_match_result_rejects_winner_not_in_current_match() -> void:
	var b: Dictionary = _make_3p_bracket()
	var before: Dictionary = b.duplicate(true)
	var after: Dictionary = TournamentSync.record_match_result(b, 2)  # match 0 is (0,1)
	assert_eq(int(after["current_match"]), int(before["current_match"]))
	assert_eq(int(after["winner_idx"]), -1)


func test_record_match_result_on_finished_bracket_is_noop() -> void:
	var b: Dictionary = _make_3p_bracket()
	b = TournamentSync.record_match_result(b, 0)
	b = TournamentSync.record_match_result(b, 0)
	b = TournamentSync.record_match_result(b, 1)
	assert_true(bool(b["finished"]))
	var again: Dictionary = TournamentSync.record_match_result(b, 0)
	assert_eq(int(again["current_match"]), int(b["current_match"]))
	assert_eq(int(again["winner_idx"]), int(b["winner_idx"]))


func test_get_current_match_empty_once_finished() -> void:
	var b: Dictionary = _make_3p_bracket()
	b = TournamentSync.record_match_result(b, 0)
	b = TournamentSync.record_match_result(b, 0)
	b = TournamentSync.record_match_result(b, 1)
	assert_true(TournamentSync.get_current_match(b).is_empty())


func test_is_finished_reflects_bracket_state() -> void:
	var b: Dictionary = _make_3p_bracket()
	assert_false(TournamentSync.is_finished(b))
	b = TournamentSync.record_match_result(b, 0)
	b = TournamentSync.record_match_result(b, 0)
	b = TournamentSync.record_match_result(b, 1)
	assert_true(TournamentSync.is_finished(b))


# ---------------------------------------------------------------------------
# Standings — wins / head-to-head / compute_winner
# ---------------------------------------------------------------------------

func test_wins_by_participant_tally() -> void:
	var b: Dictionary = _make_3p_bracket()
	b = TournamentSync.record_match_result(b, 0)  # 0 beats 1
	b = TournamentSync.record_match_result(b, 2)  # 2 beats 0
	b = TournamentSync.record_match_result(b, 1)  # 1 beats 2
	var wins: Array = TournamentSync.wins_by_participant(b)
	assert_eq(int(wins[0]), 1)
	assert_eq(int(wins[1]), 1)
	assert_eq(int(wins[2]), 1)


func test_head_to_head_winner_resolves_pair() -> void:
	var b: Dictionary = _make_3p_bracket()
	b = TournamentSync.record_match_result(b, 1)  # match (0,1): 1 wins
	assert_eq(TournamentSync.head_to_head_winner(b, 0, 1), 1)
	assert_eq(TournamentSync.head_to_head_winner(b, 1, 0), 1)


func test_head_to_head_winner_unplayed_pair_is_negative_one() -> void:
	var b: Dictionary = _make_3p_bracket()
	assert_eq(TournamentSync.head_to_head_winner(b, 1, 2), -1)


func test_compute_winner_clear_leader() -> void:
	var b: Dictionary = TournamentSync.new_bracket(
		["t0", "t1", "t2", "t3"], ["A", "B", "C", "D"], 0)
	# Player 0 wins all 3 of its matches: (0,1)(0,2)(0,3)(1,2)(1,3)(2,3)
	b = TournamentSync.record_match_result(b, 0)  # 0 beats 1
	b = TournamentSync.record_match_result(b, 0)  # 0 beats 2
	b = TournamentSync.record_match_result(b, 0)  # 0 beats 3
	b = TournamentSync.record_match_result(b, 1)  # 1 beats 2
	b = TournamentSync.record_match_result(b, 1)  # 1 beats 3
	b = TournamentSync.record_match_result(b, 2)  # 2 beats 3
	assert_true(bool(b["finished"]))
	assert_eq(int(b["winner_idx"]), 0)


func test_compute_winner_two_way_tie_broken_by_head_to_head() -> void:
	var b: Dictionary = TournamentSync.new_bracket(
		["t0", "t1", "t2", "t3"], ["A", "B", "C", "D"], 0)
	# Order: (0,1)(0,2)(0,3)(1,2)(1,3)(2,3). Players 0 and 1 both finish 2-1;
	# their head-to-head match (0,1) was won by 0, so 0 should be the winner.
	b = TournamentSync.record_match_result(b, 0)  # (0,1): 0 wins
	b = TournamentSync.record_match_result(b, 2)  # (0,2): 2 wins
	b = TournamentSync.record_match_result(b, 0)  # (0,3): 0 wins
	b = TournamentSync.record_match_result(b, 1)  # (1,2): 1 wins
	b = TournamentSync.record_match_result(b, 1)  # (1,3): 1 wins
	b = TournamentSync.record_match_result(b, 3)  # (2,3): 3 wins
	var wins: Array = TournamentSync.wins_by_participant(b)
	assert_eq(int(wins[0]), 2)
	assert_eq(int(wins[1]), 2)
	assert_eq(int(b["winner_idx"]), 0)


func test_compute_winner_three_way_tie_falls_back_to_lowest_index() -> void:
	var b: Dictionary = _make_3p_bracket()
	# (0,1): 0 wins. (0,2): 2 wins. (1,2): 1 wins. All 1-1-1 tied on wins;
	# head-to-head only resolves pairs, so with a 3-way tie it falls to lowest idx.
	b = TournamentSync.record_match_result(b, 0)
	b = TournamentSync.record_match_result(b, 2)
	b = TournamentSync.record_match_result(b, 1)
	assert_eq(int(b["winner_idx"]), 0)  # 3-way tie -> lowest participant idx


func test_compute_winner_before_finished_is_negative_one() -> void:
	var b: Dictionary = _make_3p_bracket()
	assert_eq(TournamentSync.compute_winner(b), -1)
	b = TournamentSync.record_match_result(b, 0)
	assert_eq(TournamentSync.compute_winner(b), -1)  # still 2 matches pending


func test_compute_winner_empty_bracket_is_negative_one() -> void:
	assert_eq(TournamentSync.compute_winner({}), -1)


# ---------------------------------------------------------------------------
# Wire format — encode/decode round trip
# ---------------------------------------------------------------------------

func test_encode_decode_round_trip() -> void:
	var b: Dictionary = _make_3p_bracket()
	b = TournamentSync.record_match_result(b, 0)
	var wire: Dictionary = TournamentSync.encode_bracket(b)
	var decoded: Dictionary = TournamentSync.decode_bracket(wire)
	assert_eq(decoded["players"], b["players"])
	assert_eq(decoded["names"], b["names"])
	assert_eq(int(decoded["current_match"]), int(b["current_match"]))
	assert_eq(int(decoded["ante"]), int(b["ante"]))
	assert_eq(int(decoded["pot"]), int(b["pot"]))
	assert_eq(bool(decoded["finished"]), bool(b["finished"]))


func test_decode_bracket_tolerates_garbage() -> void:
	var decoded: Dictionary = TournamentSync.decode_bracket("not a dictionary")
	assert_eq((decoded["players"] as Array).size(), 0)
	assert_eq(int(decoded["current_match"]), 0)
	assert_eq(int(decoded["winner_idx"]), -1)
	assert_false(bool(decoded["finished"]))


func test_decode_bracket_tolerates_null() -> void:
	var decoded: Dictionary = TournamentSync.decode_bracket(null)
	assert_false(decoded.is_empty())
	assert_eq((decoded["matches"] as Array).size(), 0)


func test_decode_bracket_fills_missing_keys() -> void:
	var decoded: Dictionary = TournamentSync.decode_bracket({"players": ["a", "b", "c"]})
	assert_eq((decoded["players"] as Array).size(), 3)
	assert_eq((decoded["names"] as Array).size(), 0)
	assert_eq(int(decoded["pot"]), 0)


func test_encode_bracket_does_not_alias_input_arrays() -> void:
	var b: Dictionary = _make_3p_bracket()
	var wire: Dictionary = TournamentSync.encode_bracket(b)
	(wire["matches"] as Array).clear()
	assert_eq((b["matches"] as Array).size(), 3)  # original bracket untouched
