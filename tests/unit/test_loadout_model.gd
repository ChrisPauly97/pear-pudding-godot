## Unit tests for the deck loadout model (GID-058 TID-210).
##
## Covers: migration v33→v34, prune-all-loadouts on remove_card_instance,
## set_active_loadout syncs player_deck, is_loadout_valid boundaries,
## add/rename/duplicate/delete loadout guards, and set_active_deck sync.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: Node

# Helper: replaces _sm.loadouts with the given entries without triggering the
# typed-array assignment error that occurs when assigning plain Array literals
# from outside the class.
func _set_loadouts(entries: Array) -> void:
	_sm.loadouts.clear()
	for e: Dictionary in entries:
		var lo_cards: Array[String] = []
		lo_cards.assign(e.get("cards", []))
		_sm.loadouts.append({"name": str(e.get("name", "Deck")), "cards": lo_cards})

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_set_loadouts([{"name": "Deck 1", "cards": ["uid_a", "uid_b"]}])
	_sm.active_loadout = 0
	_sm.player_deck.assign(["uid_a", "uid_b"])

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# Migration v33 → v34
# ---------------------------------------------------------------------------

func test_migration_wraps_player_deck_into_loadouts() -> void:
	var data: Dictionary = {"version": 33, "player_deck": ["x", "y", "z"]}
	SaveManagerScript._migrate_v33_to_v34(data)
	assert_true(data.has("loadouts"), "loadouts key must be added")
	var loadouts: Array = data["loadouts"]
	assert_eq(loadouts.size(), 1, "exactly one loadout after migration")
	var cards: Array = loadouts[0]["cards"]
	assert_eq(cards.size(), 3, "cards must include all three UIDs")

func test_migration_names_first_loadout_deck_1() -> void:
	var data: Dictionary = {"version": 33, "player_deck": ["x"]}
	SaveManagerScript._migrate_v33_to_v34(data)
	var name: String = str(data["loadouts"][0]["name"])
	assert_eq(name, "Deck 1")

func test_migration_sets_active_loadout_0() -> void:
	var data: Dictionary = {"version": 33, "player_deck": []}
	SaveManagerScript._migrate_v33_to_v34(data)
	assert_eq(int(data["active_loadout"]), 0)

func test_migration_bumps_version_to_34() -> void:
	var data: Dictionary = {"version": 33, "player_deck": []}
	SaveManagerScript._migrate_v33_to_v34(data)
	assert_eq(int(data["version"]), 34)

func test_migration_does_not_overwrite_existing_loadouts() -> void:
	var data: Dictionary = {
		"version": 33,
		"player_deck": ["a"],
		"loadouts": [{"name": "Custom", "cards": ["b"]}]
	}
	SaveManagerScript._migrate_v33_to_v34(data)
	assert_eq(data["loadouts"].size(), 1)
	assert_eq(str(data["loadouts"][0]["name"]), "Custom")

func test_apply_migrations_reaches_v34_from_v33() -> void:
	var data: Dictionary = {"version": 33, "player_deck": ["uid_q"]}
	SaveManagerScript._apply_migrations(data)
	assert_eq(int(data["version"]), SaveManagerScript.CURRENT_SAVE_VERSION)
	assert_true(data.has("loadouts"))

# ---------------------------------------------------------------------------
# remove_card_instance — prune from all loadouts
# ---------------------------------------------------------------------------

func _add_uid(uid: String) -> void:
	var inst: Dictionary = {"uid": uid, "template_id": "ghost", "rarity": "common",
		"attack": 1, "health": 1, "cost": 1}
	_sm.owned_cards.append(inst)
	_sm._uid_index[uid] = inst

func test_remove_prunes_from_all_loadouts() -> void:
	_add_uid("uid_shared")
	_set_loadouts([
		{"name": "A", "cards": ["uid_shared", "uid_b"]},
		{"name": "B", "cards": ["uid_c", "uid_shared"]},
		{"name": "C", "cards": ["uid_shared"]},
	])
	_sm.active_loadout = 0
	_sm.player_deck.assign(["uid_shared", "uid_b"])
	_sm.remove_card_instance("uid_shared")
	for i: int in range(_sm.loadouts.size()):
		var cards: Array = _sm.loadouts[i]["cards"]
		assert_false(cards.has("uid_shared"),
			"loadout %d must not contain the removed uid" % i)

func test_remove_leaves_other_cards_intact() -> void:
	_add_uid("uid_keep")
	_add_uid("uid_gone")
	_set_loadouts([{"name": "A", "cards": ["uid_keep", "uid_gone"]}])
	_sm.active_loadout = 0
	_sm.player_deck.assign(["uid_keep", "uid_gone"])
	_sm.remove_card_instance("uid_gone")
	var cards: Array = _sm.loadouts[0]["cards"]
	assert_true(cards.has("uid_keep"), "uid_keep must still be in the loadout")
	assert_eq(cards.size(), 1)

func test_remove_also_prunes_player_deck() -> void:
	_add_uid("uid_deck")
	_sm.player_deck.assign(["uid_deck"])
	_set_loadouts([{"name": "D", "cards": ["uid_deck"]}])
	_sm.active_loadout = 0
	_sm.remove_card_instance("uid_deck")
	assert_false(_sm.player_deck.has("uid_deck"))

# ---------------------------------------------------------------------------
# set_active_loadout — syncs player_deck
# ---------------------------------------------------------------------------

func test_set_active_loadout_syncs_player_deck() -> void:
	_set_loadouts([
		{"name": "A", "cards": ["uid_1", "uid_2"]},
		{"name": "B", "cards": ["uid_3", "uid_4", "uid_5"]},
	])
	_sm.active_loadout = 0
	_sm.player_deck.assign(["uid_1", "uid_2"])
	var ok: bool = _sm.set_active_loadout(1)
	assert_true(ok)
	assert_eq(_sm.player_deck.size(), 3, "player_deck must reflect loadout B")
	assert_true(_sm.player_deck.has("uid_3"))

func test_set_active_loadout_out_of_range_returns_false() -> void:
	_set_loadouts([{"name": "A", "cards": []}])
	var ok: bool = _sm.set_active_loadout(5)
	assert_false(ok)

func test_set_active_loadout_negative_returns_false() -> void:
	_set_loadouts([{"name": "A", "cards": []}])
	var ok: bool = _sm.set_active_loadout(-1)
	assert_false(ok)

# ---------------------------------------------------------------------------
# set_active_deck — mirrors into active loadout
# ---------------------------------------------------------------------------

func test_set_active_deck_mirrors_into_loadout() -> void:
	_set_loadouts([{"name": "A", "cards": ["uid_old"]}])
	_sm.active_loadout = 0
	var new_deck: Array[String] = ["uid_new1", "uid_new2"]
	_sm.set_active_deck(new_deck)
	var lo_cards: Array = _sm.loadouts[0]["cards"]
	assert_true(lo_cards.has("uid_new1"))
	assert_true(lo_cards.has("uid_new2"))
	assert_false(lo_cards.has("uid_old"))

# ---------------------------------------------------------------------------
# is_loadout_valid
# ---------------------------------------------------------------------------

func test_is_loadout_valid_returns_false_below_min() -> void:
	var small_cards: Array[String] = []
	for i: int in range(3):
		small_cards.append("uid_%d" % i)
	_set_loadouts([{"name": "Small", "cards": small_cards}])
	assert_false(_sm.is_loadout_valid(0))

func test_is_loadout_valid_returns_true_at_min() -> void:
	var cards: Array[String] = []
	for i: int in range(8):
		cards.append("uid_%d" % i)
	_set_loadouts([{"name": "Min", "cards": cards}])
	assert_true(_sm.is_loadout_valid(0))

func test_is_loadout_valid_returns_true_at_max() -> void:
	var cards: Array[String] = []
	for i: int in range(20):
		cards.append("uid_%d" % i)
	_set_loadouts([{"name": "Max", "cards": cards}])
	assert_true(_sm.is_loadout_valid(0))

func test_is_loadout_valid_returns_false_above_max() -> void:
	var cards: Array[String] = []
	for i: int in range(25):
		cards.append("uid_%d" % i)
	_set_loadouts([{"name": "Over", "cards": cards}])
	assert_false(_sm.is_loadout_valid(0))

func test_is_loadout_valid_returns_false_for_bad_index() -> void:
	assert_false(_sm.is_loadout_valid(99))

# ---------------------------------------------------------------------------
# add_loadout
# ---------------------------------------------------------------------------

func test_add_loadout_appends_new_entry() -> void:
	_sm.loadouts.clear()
	var idx: int = _sm.add_loadout("Test")
	assert_eq(idx, 0)
	assert_eq(_sm.loadouts.size(), 1)
	assert_eq(str(_sm.loadouts[0]["name"]), "Test")

func test_add_loadout_returns_minus_one_when_full() -> void:
	_sm.loadouts.clear()
	for i: int in range(SaveManagerScript.MAX_LOADOUTS):
		_sm.add_loadout("Deck %d" % i)
	var idx: int = _sm.add_loadout("One Too Many")
	assert_eq(idx, -1)
	assert_eq(_sm.loadouts.size(), SaveManagerScript.MAX_LOADOUTS)

func test_add_loadout_starts_with_empty_cards() -> void:
	_sm.loadouts.clear()
	_sm.add_loadout("Empty")
	var cards: Array = _sm.loadouts[0]["cards"]
	assert_eq(cards.size(), 0)

# ---------------------------------------------------------------------------
# rename_loadout
# ---------------------------------------------------------------------------

func test_rename_loadout_changes_name() -> void:
	_set_loadouts([{"name": "Old", "cards": []}])
	_sm.rename_loadout(0, "New")
	assert_eq(str(_sm.loadouts[0]["name"]), "New")

func test_rename_loadout_out_of_range_is_noop() -> void:
	_set_loadouts([{"name": "Keep", "cards": []}])
	_sm.rename_loadout(5, "Should Not Appear")
	assert_eq(str(_sm.loadouts[0]["name"]), "Keep")

# ---------------------------------------------------------------------------
# duplicate_loadout
# ---------------------------------------------------------------------------

func test_duplicate_loadout_creates_copy() -> void:
	_set_loadouts([{"name": "Original", "cards": ["uid_a", "uid_b"]}])
	var new_idx: int = _sm.duplicate_loadout(0)
	assert_eq(new_idx, 1)
	assert_eq(_sm.loadouts.size(), 2)
	var copy_cards: Array = _sm.loadouts[1]["cards"]
	assert_true(copy_cards.has("uid_a"))
	assert_true(copy_cards.has("uid_b"))

func test_duplicate_loadout_returns_minus_one_when_full() -> void:
	_sm.loadouts.clear()
	for i: int in range(SaveManagerScript.MAX_LOADOUTS):
		_sm.loadouts.append({"name": "D%d" % i, "cards": []})
	var idx: int = _sm.duplicate_loadout(0)
	assert_eq(idx, -1)

# ---------------------------------------------------------------------------
# delete_loadout
# ---------------------------------------------------------------------------

func test_delete_loadout_removes_entry() -> void:
	_set_loadouts([
		{"name": "A", "cards": []},
		{"name": "B", "cards": []},
	])
	_sm.active_loadout = 0
	_sm.player_deck.assign([])
	var ok: bool = _sm.delete_loadout(1)
	assert_true(ok)
	assert_eq(_sm.loadouts.size(), 1)
	assert_eq(str(_sm.loadouts[0]["name"]), "A")

func test_delete_loadout_refuses_last() -> void:
	_set_loadouts([{"name": "Solo", "cards": []}])
	var ok: bool = _sm.delete_loadout(0)
	assert_false(ok)
	assert_eq(_sm.loadouts.size(), 1)

func test_delete_loadout_adjusts_active_when_deleting_last_index() -> void:
	_set_loadouts([
		{"name": "A", "cards": []},
		{"name": "B", "cards": ["uid_b"]},
	])
	_sm.active_loadout = 1
	_sm.player_deck.assign(["uid_b"])
	_sm.delete_loadout(1)
	assert_eq(_sm.active_loadout, 0, "active_loadout must clamp to valid range")

func test_delete_loadout_syncs_player_deck_to_new_active() -> void:
	_set_loadouts([
		{"name": "A", "cards": ["uid_remaining"]},
		{"name": "B", "cards": ["uid_gone"]},
	])
	_sm.active_loadout = 1
	_sm.player_deck.assign(["uid_gone"])
	_sm.delete_loadout(1)
	assert_true(_sm.player_deck.has("uid_remaining"),
		"player_deck must reflect new active loadout after delete")

# ---------------------------------------------------------------------------
# get_loadout_names
# ---------------------------------------------------------------------------

func test_get_loadout_names_returns_all_names() -> void:
	_set_loadouts([
		{"name": "Alpha", "cards": []},
		{"name": "Beta",  "cards": []},
		{"name": "Gamma", "cards": []},
	])
	var names: Array[String] = _sm.get_loadout_names()
	assert_eq(names.size(), 3)
	assert_eq(names[0], "Alpha")
	assert_eq(names[1], "Beta")
	assert_eq(names[2], "Gamma")
