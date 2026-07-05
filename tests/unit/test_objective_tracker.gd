## Unit tests for ObjectiveTracker.current_objective() flag logic.
extends "res://tests/framework/test_case.gd"

const ObjectiveTracker = preload("res://game_logic/ObjectiveTracker.gd")

# Helper: build a flags dict with only the listed keys set to true.
func _flags(keys: Array) -> Dictionary:
	var d: Dictionary = {}
	for k: String in keys:
		d[k] = true
	return d


# ── No flags ──────────────────────────────────────────────────────────────────

func test_no_flags_returns_speak_to_maiteln() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective({})
	assert_eq(obj.get("label", ""), "Speak to Maiteln", "First objective should point to Maiteln")
	assert_eq(obj.get("map", ""), "madrian", "Objective should be in madrian")
	assert_eq(int(obj.get("tx", -99)), 45, "Maiteln tx should be 45")
	assert_eq(int(obj.get("tz", -99)), 36, "Maiteln tz should be 36")


# ── story_intro_complete ──────────────────────────────────────────────────────

func test_intro_complete_returns_leave_madrian() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(["story_intro_complete"]))
	assert_eq(obj.get("label", ""), "Leave Madrian", "After intro, objective is to leave madrian")
	assert_eq(obj.get("map", ""), "madrian", "Still in madrian map")


# ── chapter1_left_madrian ─────────────────────────────────────────────────────

func test_left_madrian_returns_make_camp() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(["story_intro_complete", "chapter1_left_madrian"]))
	assert_eq(obj.get("label", ""), "Make camp for the night", "After leaving madrian, make camp")
	assert_eq(obj.get("map", ""), "main")
	assert_eq(int(obj.get("tx", 0)), -1, "Camp wildcard: tx should be -1")
	assert_eq(int(obj.get("tz", 0)), -1, "Camp wildcard: tz should be -1")


# ── chapter1_camp_night ───────────────────────────────────────────────────────

func test_camp_night_returns_learn_fire() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(["story_intro_complete", "chapter1_left_madrian", "chapter1_camp_night"]))
	assert_eq(obj.get("label", ""), "Learn to make fire", "After the rabbit hunt, learn fire-making")
	assert_eq(obj.get("map", ""), "main")
	assert_eq(int(obj.get("tx", 0)), -1, "Fire wildcard: tx should be -1")
	assert_eq(int(obj.get("tz", 0)), -1, "Fire wildcard: tz should be -1")


# ── chapter1_learned_fire ─────────────────────────────────────────────────────

func test_learned_fire_returns_find_lord_farsyth() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(["story_intro_complete", "chapter1_left_madrian",
			"chapter1_camp_night", "chapter1_learned_fire"]))
	assert_eq(obj.get("label", ""), "Find Lord Farsyth", "After learning fire, go to Farsyth")
	assert_eq(obj.get("map", ""), "farsyth_mansion")
	assert_eq(int(obj.get("tx", -99)), 49)
	assert_eq(int(obj.get("tz", -99)), 20)


# ── chapter1_warned_farsyth ───────────────────────────────────────────────────

func test_warned_farsyth_returns_encounter_isfig() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(["story_intro_complete", "chapter1_left_madrian", "chapter1_camp_night",
			"chapter1_learned_fire", "chapter1_warned_farsyth"]))
	assert_eq(obj.get("label", ""), "Encounter Isfig", "After warning Farsyth, encounter Isfig")
	assert_eq(int(obj.get("tx", 0)), -1, "Isfig wildcard: tx should be -1")
	assert_eq(int(obj.get("tz", 0)), -1, "Isfig wildcard: tz should be -1")


# ── chapter1_received_letter ──────────────────────────────────────────────────

func test_received_letter_returns_reach_blancogov() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(["story_intro_complete", "chapter1_left_madrian", "chapter1_camp_night",
			"chapter1_learned_fire", "chapter1_warned_farsyth", "chapter1_received_letter"]))
	assert_eq(obj.get("label", ""), "Reach Blancogov")
	assert_eq(obj.get("map", ""), "blancogov")
	assert_eq(int(obj.get("tx", -99)), 49)
	assert_eq(int(obj.get("tz", -99)), 9)


# ── chapter1_reached_blancogov ────────────────────────────────────────────────

func test_reached_blancogov_returns_enter_temple() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(["story_intro_complete", "chapter1_left_madrian", "chapter1_camp_night",
			"chapter1_learned_fire", "chapter1_warned_farsyth", "chapter1_received_letter",
			"chapter1_reached_blancogov"]))
	assert_eq(obj.get("label", ""), "Enter the Temple")
	assert_eq(obj.get("map", ""), "blancogov_temple")
	assert_eq(int(obj.get("tx", -99)), 42)
	assert_eq(int(obj.get("tz", -99)), 15)


# ── chapter1_temple_council ───────────────────────────────────────────────────

func test_temple_council_returns_empty() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(["story_intro_complete", "chapter1_left_madrian", "chapter1_camp_night",
			"chapter1_learned_fire", "chapter1_warned_farsyth", "chapter1_received_letter",
			"chapter1_reached_blancogov", "chapter1_temple_council"]))
	assert_true(obj.is_empty(), "After speaking to King Eldar, no further objective")


# ── chapter1_complete ─────────────────────────────────────────────────────────

func test_chapter1_complete_returns_empty() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(["story_intro_complete", "chapter1_left_madrian", "chapter1_camp_night",
			"chapter1_learned_fire", "chapter1_warned_farsyth", "chapter1_received_letter",
			"chapter1_reached_blancogov", "chapter1_temple_council",
			"chapter1_complete"]))
	assert_true(obj.is_empty(), "After chapter1_complete, objective should be empty")


# ── Robustness: chapter1_complete alone ──────────────────────────────────────

func test_chapter1_complete_alone_returns_empty() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(["chapter1_complete"]))
	assert_true(obj.is_empty(), "chapter1_complete overrides all other missing flags")
