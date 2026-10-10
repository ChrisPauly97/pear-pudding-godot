## Unit tests for bestiary school knowledge (GID-181 / TID-753): the attack school is known
## after one sighting, the weak / resist profile after one defeat, the gating of the pips
## (SchoolPips.known_profile) and the Journal text (SchoolFeedback.bestiary_lines).
extends "res://tests/framework/test_case.gd"

const _SchoolKnowledge = preload("res://game_logic/battle/SchoolKnowledge.gd")
const _SchoolFeedback = preload("res://game_logic/battle/SchoolFeedback.gd")
const _SchoolPips = preload("res://scenes/battle/modules/SchoolPips.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

const _UNSEEN: Dictionary = {"seen": 0, "defeated": 0}
const _SEEN: Dictionary = {"seen": 1, "defeated": 0}
const _DEFEATED: Dictionary = {"seen": 1, "defeated": 1}

func _profile() -> Dictionary:
	return {"resist": {"dark": true}, "weak": {"light": true, "rift": true}, "immune": {}}

# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------

func test_unseen_knows_nothing() -> void:
	assert_false(_SchoolKnowledge.attack_school_known(_UNSEEN))
	assert_false(_SchoolKnowledge.profile_known(_UNSEEN))

func test_one_sighting_reveals_only_the_attack_school() -> void:
	assert_true(_SchoolKnowledge.attack_school_known(_SEEN))
	assert_false(_SchoolKnowledge.profile_known(_SEEN))

func test_one_defeat_reveals_the_profile() -> void:
	assert_true(_SchoolKnowledge.profile_known(_DEFEATED))

func test_defeat_without_sighting_still_counts() -> void:
	assert_true(_SchoolKnowledge.profile_known({"seen": 0, "defeated": 1}))

func test_known_attack_school_gated_on_sighting() -> void:
	assert_eq(_SchoolKnowledge.known_attack_school("rift", _UNSEEN), "")
	assert_eq(_SchoolKnowledge.known_attack_school("rift", _SEEN), "rift")

func test_known_profile_empty_until_defeated() -> void:
	assert_true(_SchoolKnowledge.known_profile(_profile(), _UNSEEN).is_empty())
	assert_true(_SchoolKnowledge.known_profile(_profile(), _SEEN).is_empty())

func test_known_profile_is_full_copy_once_defeated() -> void:
	var src: Dictionary = _profile()
	var out: Dictionary = _SchoolKnowledge.known_profile(src, _DEFEATED)
	assert_eq(out, src, "a defeat reveals the whole profile")
	var out_weak: Dictionary = out["weak"]
	out_weak["fire"] = true
	assert_false((src["weak"] as Dictionary).has("fire"), "the result is a copy, not the source")

func test_journal_view_hides_everything_unseen() -> void:
	var view: Dictionary = _SchoolKnowledge.journal_view("dark", _profile(), _UNSEEN)
	assert_false(bool(view["attack_known"]))
	assert_eq(str(view["attack"]), "")
	assert_false(bool(view["profile_known"]))
	assert_true((view["weak"] as Array).is_empty())
	assert_true((view["resist"] as Array).is_empty())

func test_journal_view_seen_shows_attack_only() -> void:
	var view: Dictionary = _SchoolKnowledge.journal_view("dark", _profile(), _SEEN)
	assert_true(bool(view["attack_known"]))
	assert_eq(str(view["attack"]), "dark")
	assert_false(bool(view["profile_known"]))
	assert_true((view["weak"] as Array).is_empty())

func test_journal_view_defeated_lists_schools_in_order() -> void:
	var view: Dictionary = _SchoolKnowledge.journal_view("dark", _profile(), _DEFEATED)
	var weak: Array[String] = ["light", "rift"]
	assert_eq(view["weak"], weak, "weak follows all_schools() order")
	var resist: Array[String] = ["dark"]
	assert_eq(view["resist"], resist)

# ---------------------------------------------------------------------------
# Pips (SchoolPips.known_profile) gate on the same rule
# ---------------------------------------------------------------------------

func test_pips_hidden_before_defeat() -> void:
	assert_true(_SchoolPips.known_profile("undead_basic", _UNSEEN).is_empty())
	assert_true(_SchoolPips.known_profile("undead_basic", _SEEN).is_empty())

func test_pips_show_full_profile_after_defeat() -> void:
	var full: Dictionary = _EnemyRegistry.get_school_profile("undead_basic")
	assert_eq(_SchoolPips.known_profile("undead_basic", _DEFEATED), full)
	assert_false(_SchoolFeedback.pips_for(full).is_empty())

# ---------------------------------------------------------------------------
# Journal text
# ---------------------------------------------------------------------------

func test_bestiary_lines_question_marks_when_unknown() -> void:
	var text: String = _SchoolFeedback.bestiary_lines("dark", _profile(), _UNSEEN)
	assert_eq(text, "Attack school: ?\nWeak to: ?\nResists: ?")

func test_bestiary_lines_seen_shows_attack_school_colour_chip() -> void:
	var text: String = _SchoolFeedback.bestiary_lines("dark", _profile(), _SEEN)
	assert_true(text.begins_with("Attack school: [color=#"), "attack school gets a colour chip")
	assert_true(text.ends_with("\nWeak to: ?\nResists: ?"))

func test_bestiary_lines_defeated_names_weak_and_resist() -> void:
	var text: String = _SchoolFeedback.bestiary_lines("physical", {"resist": {}, "weak": {}}, _DEFEATED)
	assert_true(text.ends_with("Weak to: None\nResists: None"), "empty lists read None")
	var full: String = _SchoolFeedback.bestiary_lines("dark", _profile(), _DEFEATED)
	assert_true(full.contains("Weak to: [color=#"))
	assert_true(full.ends_with("Resists: [color=#%s]●[/color] Dark" % _SchoolFeedback.school_color("dark").to_html(false)))

func test_school_bbcode_physical_is_neutral() -> void:
	assert_eq(_SchoolFeedback.school_bbcode("physical"),
			"[color=#%s]●[/color] Physical" % _SchoolFeedback.NEUTRAL_COLOR.to_html(false))
