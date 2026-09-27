## GID-135 / TID-558: pure bark rate-limit + line-selection rules.
extends "res://tests/framework/test_case.gd"

const BarkRules = preload("res://game_logic/battle/BarkRules.gd")

func test_eligible_only_for_maiteln() -> void:
	assert_true(BarkRules.is_eligible("maiteln", 0))
	assert_false(BarkRules.is_eligible("", 0))
	assert_false(BarkRules.is_eligible("other_companion", 0))

func test_eligible_only_while_on_the_onboarding_ramp() -> void:
	assert_true(BarkRules.is_eligible("maiteln", 0))
	assert_true(BarkRules.is_eligible("maiteln", 2))
	assert_false(BarkRules.is_eligible("maiteln", -1), "graduated (full fight) is not eligible")

func test_no_bark_before_start_delay() -> void:
	assert_false(BarkRules.can_bark_now(BarkRules.START_DELAY_S - 0.1, -1.0))
	assert_true(BarkRules.can_bark_now(BarkRules.START_DELAY_S + 0.1, -1.0))

func test_no_bark_within_min_interval() -> void:
	var last: float = 10.0
	assert_false(BarkRules.can_bark_now(last + BarkRules.MIN_INTERVAL_S - 0.1, last))
	assert_true(BarkRules.can_bark_now(last + BarkRules.MIN_INTERVAL_S, last))

func test_pick_line_skips_lines_at_cap() -> void:
	var counts: Dictionary = {"low_hp": BarkRules.MAX_PER_LINE}
	var id: String = BarkRules.pick_line(["low_hp", "mana_empty"], counts)
	assert_eq(id, "mana_empty")

func test_pick_line_empty_when_all_capped() -> void:
	var counts: Dictionary = {"low_hp": BarkRules.MAX_PER_LINE, "mana_empty": BarkRules.MAX_PER_LINE}
	assert_eq(BarkRules.pick_line(["low_hp", "mana_empty"], counts), "")

func test_next_bark_empty_candidates() -> void:
	assert_eq(BarkRules.next_bark([], 100.0, -1.0, {}), "")

func test_next_bark_respects_rate_limit_then_fires() -> void:
	var counts: Dictionary = {}
	assert_eq(BarkRules.next_bark(["cast_bar"], 5.0, 3.0, counts), "", "still inside min interval")
	assert_eq(BarkRules.next_bark(["cast_bar"], 20.0, 3.0, counts), "cast_bar")

func test_next_bark_priority_order_is_preserved() -> void:
	var id: String = BarkRules.next_bark(["interrupt", "low_hp"], 100.0, -1.0, {})
	assert_eq(id, "interrupt")

func test_every_line_has_text() -> void:
	for id: String in BarkRules.LINES.keys():
		assert_true(BarkRules.text_for(id) != "", "line %s has no text" % id)
	assert_eq(BarkRules.text_for("not_a_real_line"), "")
