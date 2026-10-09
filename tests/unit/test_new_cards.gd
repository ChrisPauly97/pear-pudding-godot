## New-card marks (GID-180 / TID-747): rewards are "new" until the deck table is seen.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")


func test_new_marks_lifecycle() -> void:
	var sm := SaveManagerScript.new()
	sm.new_game()
	assert_true(sm.new_card_uids.is_empty(), "starter cards are not new finds")
	var a: String = sm.grant_card_reward("ghost", "rare")
	var b: String = sm.add_card_instance("ghoul", "common")
	assert_true(sm.is_new_card(a))
	assert_true(sm.is_new_card(b))
	sm.remove_card_instance(b)
	assert_false(sm.is_new_card(b), "a removed card loses its mark")
	sm.mark_cards_seen()
	assert_true(sm.new_card_uids.is_empty())
	assert_true("new_card_uids" in SaveManagerScript.PERSISTED_FIELDS)
	sm.free()
