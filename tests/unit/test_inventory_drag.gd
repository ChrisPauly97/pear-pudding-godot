## Drag-and-drop between the collection grid and the deck list.
##
## The pieces that can break silently are the drop-acceptance rules and the
## gesture split: `_can_drop_*` returning true for the wrong direction would let
## a card be "added" to the deck it is already in, and `_drag_card` returning
## data for a vertical gesture would take away the tile-started list scrolling
## that TID-454 exists for. None of that raises an error at runtime — it just
## makes the panel feel broken.
##
## These call the scene's handlers directly rather than through the viewport:
## the synchronous unit runner never routes real input, and the handlers are
## where the rules live.
extends "res://tests/framework/test_case.gd"

const _InventoryScene = preload("res://scenes/ui/InventoryScene.gd")

const _FROM_COLLECTION := {"kind": "inv_card", "uid": "u1", "from_deck": false}
const _FROM_DECK := {"kind": "inv_card", "uid": "u2", "from_deck": true}

var _inv: Object = null


func before_each() -> void:
	# The rules under test are pure; no UI build, no tree, no SaveManager.
	_inv = _InventoryScene.new()


func after_each() -> void:
	if _inv != null and is_instance_valid(_inv):
		(_inv as Node).free()
	_inv = null


func test_deck_side_accepts_only_cards_from_the_collection() -> void:
	assert_true(_inv._can_drop_into_deck(Vector2.ZERO, _FROM_COLLECTION),
		"dragging a collection card onto the deck should be allowed")
	assert_false(_inv._can_drop_into_deck(Vector2.ZERO, _FROM_DECK),
		"a card already in the deck must not be droppable onto the deck")


func test_collection_side_accepts_only_cards_from_the_deck() -> void:
	assert_true(_inv._can_drop_into_collection(Vector2.ZERO, _FROM_DECK),
		"dragging a deck card back to the collection should be allowed")
	assert_false(_inv._can_drop_into_collection(Vector2.ZERO, _FROM_COLLECTION),
		"a collection card must not be droppable onto the collection")


func test_foreign_drag_payloads_are_rejected() -> void:
	# Godot offers every in-flight drag to every drop target, including drags
	# started by unrelated UI, so the kind check has to hold.
	for junk: Variant in [null, "a string", 42, {}, {"kind": "something_else", "uid": "u1"},
			{"uid": "u1", "from_deck": false}]:
		assert_false(_inv._can_drop_into_deck(Vector2.ZERO, junk),
			"deck side should reject %s" % [junk])
		assert_false(_inv._can_drop_into_collection(Vector2.ZERO, junk),
			"collection side should reject %s" % [junk])


func test_sideways_gesture_starts_a_card_drag() -> void:
	var tile := Button.new()
	_inv._press_origin[tile] = Vector2(10.0, 10.0)
	var data: Variant = _inv._drag_card(tile, Vector2(60.0, 14.0), "u9", false, Color.RED)
	assert_true(data is Dictionary, "a mostly-horizontal drag should start a card drag")
	var d: Dictionary = data
	assert_eq(str(d.get("uid", "")), "u9")
	assert_eq(bool(d.get("from_deck", true)), false)
	tile.free()


func test_vertical_gesture_is_left_to_the_scroll_container() -> void:
	var tile := Button.new()
	_inv._press_origin[tile] = Vector2(10.0, 10.0)
	assert_eq(_inv._drag_card(tile, Vector2(14.0, 60.0), "u9", false, Color.RED), null,
		"a mostly-vertical drag must not start a card drag — the grid scrolls instead")
	tile.free()
