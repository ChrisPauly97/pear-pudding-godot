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

func test_temple_council_returns_speak_with_queen_and_scargroth() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(["story_intro_complete", "chapter1_left_madrian", "chapter1_camp_night",
			"chapter1_learned_fire", "chapter1_warned_farsyth", "chapter1_received_letter",
			"chapter1_reached_blancogov", "chapter1_temple_council"]))
	assert_eq(obj.get("label", ""), "Speak with the Queen and Scargroth, then the King")
	assert_eq(obj.get("map", ""), "blancogov_temple")
	assert_eq(int(obj.get("tx", -99)), 42)
	assert_eq(int(obj.get("tz", -99)), 15)


# ── chapter1_complete ─────────────────────────────────────────────────────────

func test_chapter1_complete_returns_speak_to_king_eldar() -> void:
	# Chapter 2 continues from here (GID-108 / TID-407) — chapter1_complete no
	# longer means "the end"; it means "go get charged for the westward ride."
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(["story_intro_complete", "chapter1_left_madrian", "chapter1_camp_night",
			"chapter1_learned_fire", "chapter1_warned_farsyth", "chapter1_received_letter",
			"chapter1_reached_blancogov", "chapter1_temple_council",
			"chapter1_complete"]))
	assert_eq(obj.get("label", ""), "Speak to King Eldar")
	assert_eq(obj.get("map", ""), "blancogov_temple")


# ── Robustness: chapter1_complete alone ──────────────────────────────────────

func test_chapter1_complete_alone_returns_speak_to_king_eldar() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(["chapter1_complete"]))
	assert_eq(obj.get("label", ""), "Speak to King Eldar",
		"chapter1_complete overrides all other missing Chapter 1 flags")


# ── Chapter 2 (GID-108 / TID-407) ─────────────────────────────────────────────

func _ch2_flags(extra: Array) -> Array:
	var base: Array = ["story_intro_complete", "chapter1_left_madrian", "chapter1_camp_night",
		"chapter1_learned_fire", "chapter1_warned_farsyth", "chapter1_received_letter",
		"chapter1_reached_blancogov", "chapter1_temple_council", "chapter1_complete"]
	return base + extra


func test_chapter2_charged_returns_travel_to_larik() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(_ch2_flags(["chapter2_charged"])))
	assert_eq(obj.get("label", ""), "Travel west to Larik")
	assert_eq(obj.get("map", ""), "larik")
	assert_eq(int(obj.get("tx", -99)), 50)
	assert_eq(int(obj.get("tz", -99)), 90)


func test_chapter2_reached_larik_returns_search_larik() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(_ch2_flags(["chapter2_charged", "chapter2_reached_larik"])))
	assert_eq(obj.get("label", ""), "Search Larik for answers")
	assert_eq(obj.get("map", ""), "larik")


func test_chapter2_found_letter_returns_continue_west() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(_ch2_flags(["chapter2_charged", "chapter2_reached_larik", "chapter2_found_letter"])))
	assert_eq(obj.get("label", ""), "Continue west toward Marsax Hold")
	assert_eq(int(obj.get("tx", 0)), -1, "Ambush wildcard: tx should be -1")
	assert_eq(int(obj.get("tz", 0)), -1, "Ambush wildcard: tz should be -1")


func test_chapter2_ambush_survived_returns_defend_hold() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(_ch2_flags(["chapter2_charged", "chapter2_reached_larik", "chapter2_found_letter",
			"chapter2_ambush_survived"])))
	assert_eq(obj.get("label", ""), "Defend Marsax Hold")
	assert_eq(obj.get("map", ""), "marsax_hold")


func test_chapter2_siege_won_returns_search_hold() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(_ch2_flags(["chapter2_charged", "chapter2_reached_larik", "chapter2_found_letter",
			"chapter2_ambush_survived", "chapter2_siege_won"])))
	assert_eq(obj.get("label", ""), "Search the hold for clues")


func test_chapter2_traitor_seal_returns_infiltrate_warcamp() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(_ch2_flags(["chapter2_charged", "chapter2_reached_larik", "chapter2_found_letter",
			"chapter2_ambush_survived", "chapter2_siege_won", "chapter2_traitor_seal"])))
	assert_eq(obj.get("label", ""), "Infiltrate the war-camp")
	assert_eq(obj.get("map", ""), "marsax_hold")


func test_chapter2_warcamp_cleared_returns_empty() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(_ch2_flags(["chapter2_charged", "chapter2_reached_larik", "chapter2_found_letter",
			"chapter2_ambush_survived", "chapter2_siege_won", "chapter2_traitor_seal",
			"chapter2_warcamp_cleared"])))
	assert_true(obj.is_empty(), "Cliffhanger fires automatically; no next objective yet")


func test_chapter2_complete_returns_empty() -> void:
	var obj: Dictionary = ObjectiveTracker.current_objective(
		_flags(_ch2_flags(["chapter2_charged", "chapter2_reached_larik", "chapter2_found_letter",
			"chapter2_ambush_survived", "chapter2_siege_won", "chapter2_traitor_seal",
			"chapter2_warcamp_cleared", "chapter2_complete"])))
	assert_true(obj.is_empty())
