## GID-177 / TID-723: Chapter 1 levelling pace — a scripted player on the real
## save API (quest rewards, camp levels, kill XP, XpCurve, trainer costs) with the
## time model in tests/support/pacing_sim.gd. Targets (user, 2026-10-08): level 1
## about 10 minutes, each later level longer, a few quests per level from 3.
extends "res://tests/framework/test_case.gd"

const PacingSim = preload("res://tests/support/pacing_sim.gd")
const XpCurve = preload("res://game_logic/progression/XpCurve.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")

## Allowed relative miss per level (the time model is coarse).
const TOLERANCE: float = 0.3

var _sim: PacingSim

func before_all() -> void:
	_sim = PacingSim.new()
	_sim.run(10)

func test_reaches_level_ten() -> void:
	assert_eq(_sim.sm.level, 10)
	var hours: float = _sim.t / 3600.0
	assert_true(hours > 3.5 and hours < 5.5, "about 4.5 h to level 10 (%.2f h)" % hours)

func test_each_level_takes_its_target_time() -> void:
	for l: int in range(1, 10):
		var want: float = XpCurve.minutes_for(l)
		var got: float = _sim.minutes(l)
		assert_lte(absf(got - want) / want, TOLERANCE, "level %d: %.1f min (target %.0f)" % [l, got, want])

func test_a_few_quests_per_level_from_three() -> void:
	for l: int in range(3, 10):
		assert_gte(int(_sim.quests_at.get(l, 0)), 2, "quests finished at level %d" % l)

func test_trainings_learned_on_time() -> void:
	for id: String in UnlockLadder.all_ids():
		var req: int = UnlockLadder.level_req(id)
		if req > 9:
			continue
		assert_true(_sim.learned_at.has(id), "%s learned" % id)
		assert_lte(int(_sim.learned_at.get(id, 99)) - req, 1, "%s learned within a level of %d" % [id, req])
