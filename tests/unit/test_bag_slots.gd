extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

func test_scrap_decreases_slot_count() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	var base: int = sm.get_slot_count()
	var uid1: String = sm.add_card_instance("bat", "common")
	var uid2: String = sm.add_card_instance("bat", "common")
	assert_eq(sm.get_slot_count(), base + 2)
	sm.scrap_card_instance(uid1)
	assert_eq(sm.get_slot_count(), base + 1)
	sm.scrap_card_instance(uid2)
	assert_eq(sm.get_slot_count(), base)

func test_deck_membership_frees_slot() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	var uid: String = sm.add_card_instance("bat", "common")
	var before: int = sm.get_slot_count()
	var deck: Array[String] = []
	deck.assign(sm.player_deck)
	deck.append(uid)
	sm.set_active_deck(deck)
	assert_eq(sm.get_slot_count(), before - 1)

func test_same_rarity_instances_each_take_a_slot() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	var base: int = sm.get_slot_count()
	sm.add_card_instance("bat", "common")
	sm.add_card_instance("bat", "common")
	sm.add_card_instance("bat", "common")
	assert_eq(sm.get_slot_count(), base + 3)
