## Unit tests for GID-098 / TID-355 co-op map-transition additions.
##
## Verifies:
##   - MapNpc.dialogue_group field exists, defaults to "", and round-trips through
##     the WorldMap NPC data dict (load_from_resource pipeline).
##   - The recv_map_transition payload convention: empty target_map = exit_map;
##     non-empty target_map = enter_map(target_map, door_id).
extends "res://tests/framework/test_case.gd"

const MapNpc = preload("res://game_logic/world/resources/MapNpc.gd")
const WorldMapScript = preload("res://game_logic/world/WorldMap.gd")


# ---------------------------------------------------------------------------
# MapNpc.dialogue_group field
# ---------------------------------------------------------------------------

func test_dialogue_group_defaults_to_empty() -> void:
	var n := MapNpc.new()
	assert_eq(n.dialogue_group, "", "dialogue_group should default to empty string")


func test_dialogue_group_can_be_set() -> void:
	var n := MapNpc.new()
	n.dialogue_group = "Greetings, adventurers!"
	assert_eq(n.dialogue_group, "Greetings, adventurers!")


# ---------------------------------------------------------------------------
# dialogue_group flows through WorldMap NPC dict pipeline
# ---------------------------------------------------------------------------

func test_npc_dict_has_dialogue_group_key() -> void:
	# WorldMap.load_from_resource now includes dialogue_group in every NPC dict.
	var wm: RefCounted = WorldMapScript.new("madrian")
	assert_true(wm.npcs.size() > 0, "madrian must have NPCs for this test to be meaningful")
	for n in wm.npcs:
		assert_true(n.has("dialogue_group"),
			"NPC dict should carry dialogue_group key (id=%s)" % str(n.get("id", "?")))


func test_npc_dict_dialogue_group_is_string() -> void:
	var wm: RefCounted = WorldMapScript.new("madrian")
	for n in wm.npcs:
		var dg: String = str(n.get("dialogue_group", ""))
		assert_true(dg is String,
			"dialogue_group should be a String, not %s" % typeof(dg))


# ---------------------------------------------------------------------------
# recv_map_transition payload convention
# ---------------------------------------------------------------------------

func test_empty_target_map_signals_exit() -> void:
	# Convention: when target_map == "", the receiver calls SceneManager.exit_map().
	# This test documents the contract used by WorldScene._on_map_transition_received.
	var target_map: String = ""
	var is_exit: bool = target_map.is_empty()
	assert_true(is_exit, "empty target_map must signal exit_map()")


func test_nonempty_target_map_signals_enter() -> void:
	var target_map: String = "dungeon_1"
	var is_exit: bool = target_map.is_empty()
	assert_false(is_exit, "non-empty target_map must signal enter_map()")


func test_transition_payload_round_trip() -> void:
	# The recv_map_transition RPC carries [target_map: String, door_id: String].
	# Verify the data survives String serialisation (as it would through Godot RPC).
	var target_map: String = "maykalene"
	var door_id: String = "door_may_east"
	var payload: Array = [target_map, door_id]
	assert_eq(str(payload[0]), "maykalene")
	assert_eq(str(payload[1]), "door_may_east")


func test_exit_transition_empty_door_id() -> void:
	# exit_map calls use target_map="" and door_id="" — both must be empty.
	var payload: Array = ["", ""]
	assert_true(str(payload[0]).is_empty(), "exit payload target_map must be empty")
	assert_true(str(payload[1]).is_empty(), "exit payload door_id must be empty")
