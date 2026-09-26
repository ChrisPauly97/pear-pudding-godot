## GID-135 / TID-527: battle pacing budgets and the "no untracked delays" guard.
extends "res://tests/framework/test_case.gd"

const _BattlePacing = preload("res://game_logic/battle/BattlePacing.gd")
const _TransitionManager = preload("res://autoloads/TransitionManager.gd")

func test_ai_turn_within_budget() -> void:
	assert_true(_BattlePacing.ai_turn_dead_time(3) <= _BattlePacing.BUDGET_AI_TURN_3_ACTIONS + 0.001,
		"3-action AI turn dead time exceeds budget")

func test_fast_speed_scales_ai_turn() -> void:
	var normal: float = _BattlePacing.ai_turn_dead_time(3)
	var fast: float = _BattlePacing.ai_turn_dead_time(3, _BattlePacing.FAST_SPEED_SCALE)
	assert_true(fast < normal, "fast speed must shorten the AI turn")

func test_engage_within_budget() -> void:
	assert_true(_BattlePacing.engage_to_input() <= _BattlePacing.BUDGET_ENGAGE_TO_INPUT + 0.001,
		"engage-to-input exceeds budget")

func test_transition_mirror_matches() -> void:
	assert_eq(_BattlePacing.TRANSITION_HALF, _TransitionManager.FADE_DURATION,
		"BattlePacing.TRANSITION_HALF drifted from TransitionManager.FADE_DURATION")

func test_no_literal_battle_delays() -> void:
	var rx := RegEx.new()
	rx.compile("_battle_delay\\(\\s*[0-9]")
	for path: String in ["res://scenes/battle/BattleScene.gd"]:
		var src: String = FileAccess.get_file_as_string(path)
		assert_true(rx.search(src) == null,
			"%s: literal _battle_delay(<number>) — add a BattlePacing constant" % path)
