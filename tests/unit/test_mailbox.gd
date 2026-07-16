## Headless tests for TID-411 — Mailbox overflow queue for bag-full card rewards.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

func _fill_bag(sm: Node) -> void:
	while not sm.is_bag_full():
		sm.add_card_instance("bat", "common")

## First owned card NOT in the active deck — new_game() seeds owned_cards
## with the 12-card starter deck first, so owned_cards[0] is always a deck
## card and scrapping it never frees a bag slot (get_slot_count() excludes
## deck cards). Tests that need to free a real slot must scrap one of these.
func _first_non_deck_uid(sm: Node) -> String:
	for inst: Dictionary in sm.owned_cards:
		var uid: String = str(inst.get("uid", ""))
		if not sm.player_deck.has(uid):
			return uid
	return ""

func test_reward_routes_to_mailbox_when_bag_full() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	_fill_bag(sm)
	var before: int = sm.owned_cards.size()
	var uid: String = sm.grant_card_reward("bat", "common")
	assert_true(uid != "")
	assert_eq(sm.owned_cards.size(), before)
	assert_eq(sm.mailbox_cards.size(), 1)
	assert_eq(str(sm.mailbox_cards[0].get("uid", "")), uid)

func test_reward_goes_straight_to_bag_when_space_available() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	var before: int = sm.owned_cards.size()
	var uid: String = sm.grant_card_reward("bat", "common")
	assert_true(uid != "")
	assert_eq(sm.owned_cards.size(), before + 1)
	assert_eq(sm.mailbox_cards.size(), 0)

func test_claim_mailbox_card_succeeds_once_space_frees_up() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	_fill_bag(sm)
	var uid: String = sm.grant_card_reward("bat", "common")
	assert_eq(sm.mailbox_cards.size(), 1)
	# Free a slot (must scrap a non-deck card — see _first_non_deck_uid).
	var freed_uid: String = _first_non_deck_uid(sm)
	sm.scrap_card_instance(freed_uid)
	var claimed: bool = sm.claim_mailbox_card(uid)
	assert_true(claimed)
	assert_eq(sm.mailbox_cards.size(), 0)
	assert_true(sm.get_instance_by_uid(uid).size() > 0)

func test_claim_fails_when_bag_still_full() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	_fill_bag(sm)
	var uid: String = sm.grant_card_reward("bat", "common")
	var claimed: bool = sm.claim_mailbox_card(uid)
	assert_false(claimed)
	assert_eq(sm.mailbox_cards.size(), 1)

func test_claim_all_stops_at_capacity() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	_fill_bag(sm)
	sm.grant_card_reward("bat", "common")
	sm.grant_card_reward("bat", "common")
	sm.grant_card_reward("bat", "common")
	assert_eq(sm.mailbox_cards.size(), 3)
	# Free exactly 2 slots (must scrap non-deck cards — see _first_non_deck_uid).
	sm.scrap_card_instance(_first_non_deck_uid(sm))
	sm.scrap_card_instance(_first_non_deck_uid(sm))
	var claimed: int = sm.claim_all_mailbox_cards()
	assert_eq(claimed, 2)
	assert_eq(sm.mailbox_cards.size(), 1)

func test_sell_mailbox_card_awards_gold_and_removes_entry() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	_fill_bag(sm)
	var uid: String = sm.grant_card_reward("bat", "common")
	var coins_before: int = sm.coins
	sm.sell_mailbox_card(uid)
	assert_eq(sm.mailbox_cards.size(), 0)
	assert_true(sm.coins > coins_before)

func test_scrap_mailbox_card_awards_essence_and_removes_entry() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	_fill_bag(sm)
	var uid: String = sm.grant_card_reward("bat", "common")
	var essence_before: int = sm.essence
	sm.scrap_mailbox_card(uid)
	assert_eq(sm.mailbox_cards.size(), 0)
	assert_true(sm.essence > essence_before)

func test_mailbox_survives_save_load_round_trip() -> void:
	var sm = SaveManagerScript.new()
	sm.new_game()
	_fill_bag(sm)
	var uid: String = sm.grant_card_reward("bat", "common")
	var data: Dictionary = {
		"version": sm.CURRENT_SAVE_VERSION,
		"owned_cards": sm.owned_cards,
		"mailbox_cards": sm.mailbox_cards,
		"player_deck": sm.player_deck,
	}
	var sm2 = SaveManagerScript.new()
	sm2.mailbox_cards.assign(data.get("mailbox_cards", []))
	assert_eq(sm2.mailbox_cards.size(), 1)
	assert_eq(str(sm2.mailbox_cards[0].get("uid", "")), uid)
	sm.free()
	sm2.free()
