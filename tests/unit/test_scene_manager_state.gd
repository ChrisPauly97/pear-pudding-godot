## Unit tests for SceneManager state machine (TID-306 / GID-085).
##
## Tests pure-logic aspects of the SceneManager that do not require loading
## actual scenes: initial state, proximity-engage gating, and map-stack
## push/pop invariants.  Scene-loading transitions are not tested here because
## they require the full SceneTree renderer (not available headless).
extends "res://tests/framework/test_case.gd"

# ---------------------------------------------------------------------------
# Helpers — read and restore SceneManager state to avoid cross-test pollution
# ---------------------------------------------------------------------------

var _saved_state: int = -1
var _saved_map_stack: Array[String] = []
var _saved_door_stack: Array[String] = []
var _saved_current_map: String = ""
var _saved_proximity_blocked: bool = false
var _saved_coop_spire_run: Dictionary = {}

func before_each() -> void:
	_saved_state = SceneManager._state
	_saved_map_stack.assign(SceneManager.map_stack)
	_saved_door_stack.assign(SceneManager.door_stack)
	_saved_current_map = SceneManager.current_map
	_saved_proximity_blocked = SceneManager._proximity_engage_blocked
	_saved_coop_spire_run = SceneManager._coop_spire_run.duplicate(true)

func after_each() -> void:
	SceneManager._state = _saved_state
	SceneManager.map_stack.assign(_saved_map_stack)
	SceneManager.door_stack.assign(_saved_door_stack)
	SceneManager.current_map = _saved_current_map
	SceneManager._proximity_engage_blocked = _saved_proximity_blocked
	SceneManager._coop_spire_run = _saved_coop_spire_run.duplicate(true)

# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_initial_state_is_menu() -> void:
	# Reset to known state
	SceneManager._state = SceneManager.State.MENU
	assert_eq(SceneManager._state, SceneManager.State.MENU)

func test_can_proximity_engage_false_in_menu_state() -> void:
	SceneManager._state = SceneManager.State.MENU
	SceneManager._proximity_engage_blocked = false
	assert_false(SceneManager.can_proximity_engage())

func test_can_proximity_engage_true_in_world_state() -> void:
	SceneManager._state = SceneManager.State.WORLD
	SceneManager._proximity_engage_blocked = false
	assert_true(SceneManager.can_proximity_engage())

func test_can_proximity_engage_false_in_battle_state() -> void:
	SceneManager._state = SceneManager.State.BATTLE
	SceneManager._proximity_engage_blocked = false
	assert_false(SceneManager.can_proximity_engage())

func test_can_proximity_engage_false_in_inventory_state() -> void:
	SceneManager._state = SceneManager.State.INVENTORY
	SceneManager._proximity_engage_blocked = false
	assert_false(SceneManager.can_proximity_engage())

func test_can_proximity_engage_false_when_blocked_in_world() -> void:
	SceneManager._state = SceneManager.State.WORLD
	SceneManager._proximity_engage_blocked = true
	assert_false(SceneManager.can_proximity_engage())

# ---------------------------------------------------------------------------
# Map stack push/pop invariants (simulated without calling enter_map/exit_map
# which would attempt to load scenes)
# ---------------------------------------------------------------------------

func test_empty_map_stack_after_reset() -> void:
	SceneManager.map_stack.clear()
	SceneManager.door_stack.clear()
	SceneManager.current_map = ""
	assert_eq(SceneManager.map_stack.size(), 0)
	assert_eq(SceneManager.door_stack.size(), 0)

func test_push_map_increments_stack_size() -> void:
	SceneManager.map_stack.clear()
	SceneManager.door_stack.clear()
	SceneManager.current_map = "madrian"
	# Simulate enter_map logic without scene loading
	SceneManager.map_stack.push_back(SceneManager.current_map)
	SceneManager.door_stack.push_back("")
	SceneManager.current_map = "farsyth_mansion"
	assert_eq(SceneManager.map_stack.size(), 1)
	assert_eq(SceneManager.map_stack[0], "madrian")
	assert_eq(SceneManager.current_map, "farsyth_mansion")

func test_pop_map_restores_previous() -> void:
	SceneManager.map_stack.clear()
	SceneManager.door_stack.clear()
	SceneManager.current_map = "madrian"
	# Push madrian
	SceneManager.map_stack.push_back(SceneManager.current_map)
	SceneManager.door_stack.push_back("")
	SceneManager.current_map = "farsyth_mansion"
	# Simulate exit_map logic
	var parent: String = SceneManager.map_stack.pop_back()
	SceneManager.door_stack.pop_back()
	SceneManager.current_map = parent
	assert_eq(SceneManager.current_map, "madrian")
	assert_eq(SceneManager.map_stack.size(), 0)

func test_multi_level_push_pop_integrity() -> void:
	SceneManager.map_stack.clear()
	SceneManager.door_stack.clear()
	SceneManager.current_map = "madrian"
	# Push madrian → farsyth_mansion → blancogov
	SceneManager.map_stack.push_back("madrian")
	SceneManager.door_stack.push_back("")
	SceneManager.current_map = "farsyth_mansion"
	SceneManager.map_stack.push_back("farsyth_mansion")
	SceneManager.door_stack.push_back("")
	SceneManager.current_map = "blancogov"
	assert_eq(SceneManager.map_stack.size(), 2)
	# Pop twice to get back to madrian
	SceneManager.current_map = SceneManager.map_stack.pop_back()
	SceneManager.door_stack.pop_back()
	assert_eq(SceneManager.current_map, "farsyth_mansion")
	SceneManager.current_map = SceneManager.map_stack.pop_back()
	SceneManager.door_stack.pop_back()
	assert_eq(SceneManager.current_map, "madrian")
	assert_eq(SceneManager.map_stack.size(), 0)

func test_map_stack_and_door_stack_stay_in_sync() -> void:
	SceneManager.map_stack.clear()
	SceneManager.door_stack.clear()
	# Push 3 entries
	for i in range(3):
		SceneManager.map_stack.push_back("map_%d" % i)
		SceneManager.door_stack.push_back("door_%d" % i)
	assert_eq(SceneManager.map_stack.size(), SceneManager.door_stack.size())
	# Pop 2 entries
	SceneManager.map_stack.pop_back()
	SceneManager.door_stack.pop_back()
	SceneManager.map_stack.pop_back()
	SceneManager.door_stack.pop_back()
	assert_eq(SceneManager.map_stack.size(), SceneManager.door_stack.size())

# ---------------------------------------------------------------------------
# State integrity after direct transitions
# ---------------------------------------------------------------------------

func test_setting_state_to_world_then_menu_changes_proximity() -> void:
	SceneManager._state = SceneManager.State.WORLD
	SceneManager._proximity_engage_blocked = false
	assert_true(SceneManager.can_proximity_engage())
	SceneManager._state = SceneManager.State.MENU
	assert_false(SceneManager.can_proximity_engage())

func test_proximity_blocked_cleared_manually() -> void:
	SceneManager._state = SceneManager.State.WORLD
	SceneManager._proximity_engage_blocked = true
	assert_false(SceneManager.can_proximity_engage())
	SceneManager._proximity_engage_blocked = false
	assert_true(SceneManager.can_proximity_engage())

# ---------------------------------------------------------------------------
# Co-op Endless Spire run state (GID-106 / TID-390) — transient, in-memory only.
# ---------------------------------------------------------------------------

func test_coop_spire_inactive_by_default() -> void:
	SceneManager._coop_spire_run = {"active": false}
	assert_false(SceneManager.is_coop_spire_active())

func test_enter_spire_coop_marks_active() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.enter_spire_coop(["tok_a", "tok_b"])
	assert_true(SceneManager.is_coop_spire_active())

func test_enter_spire_coop_sets_floor_to_one() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.enter_spire_coop(["tok_a"])
	assert_eq(int(SceneManager.get_coop_spire_run().get("floor", 0)), 1)

func test_enter_spire_coop_stores_picker_order() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.enter_spire_coop(["tok_a", "tok_b"])
	var order: Array = SceneManager.get_coop_spire_run().get("picker_order", [])
	assert_eq(order, ["tok_a", "tok_b"])

func test_enter_spire_coop_shared_deck_starts_empty() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.enter_spire_coop(["tok_a"])
	assert_eq((SceneManager.get_coop_spire_run().get("shared_deck", []) as Array).size(), 0)

func test_enter_spire_coop_returns_floor_one_map_name_with_seed() -> void:
	SceneManager._coop_spire_run = {"active": false}
	var target_map: String = SceneManager.enter_spire_coop(["tok_a"])
	var seed: int = int(SceneManager.get_coop_spire_run().get("seed", -1))
	assert_eq(target_map, "spire_floor_1_%d" % seed)

func test_enter_spire_coop_resumes_existing_run_without_resetting_it() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.enter_spire_coop(["tok_a"])
	SceneManager.add_coop_drafted_card("ghost")
	SceneManager.advance_coop_spire_floor()
	var target_map: String = SceneManager.enter_spire_coop(["tok_b"])  # picker_order ignored on resume
	assert_eq(target_map, "spire_floor_2_%d" % int(SceneManager.get_coop_spire_run().get("seed", -1)))
	assert_eq((SceneManager.get_coop_spire_run().get("shared_deck", []) as Array).size(), 1)
	assert_eq(SceneManager.get_coop_spire_run().get("picker_order", []), ["tok_a"])

func test_add_coop_drafted_card_appends_to_shared_deck() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.enter_spire_coop(["tok_a"])
	SceneManager.add_coop_drafted_card("skeleton")
	var deck: Array = SceneManager.get_coop_spire_run().get("shared_deck", [])
	assert_eq(deck, ["skeleton"])

func test_add_coop_drafted_card_noop_when_inactive() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.add_coop_drafted_card("ghost")
	assert_false(SceneManager.is_coop_spire_active())

func test_advance_coop_spire_picker_wraps_around() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.enter_spire_coop(["tok_a", "tok_b"])
	SceneManager.advance_coop_spire_picker()
	assert_eq(int(SceneManager.get_coop_spire_run().get("picker_idx", -1)), 1)
	SceneManager.advance_coop_spire_picker()
	assert_eq(int(SceneManager.get_coop_spire_run().get("picker_idx", -1)), 0)

func test_advance_coop_spire_picker_noop_when_inactive() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.advance_coop_spire_picker()
	assert_false(SceneManager.is_coop_spire_active())

func test_advance_coop_spire_floor_increments_floor() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.enter_spire_coop(["tok_a"])
	SceneManager.advance_coop_spire_floor()
	assert_eq(int(SceneManager.get_coop_spire_run().get("floor", 0)), 2)

func test_end_coop_spire_run_clears_active_flag() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.enter_spire_coop(["tok_a"])
	SceneManager.end_coop_spire_run()
	assert_false(SceneManager.is_coop_spire_active())

func test_end_coop_spire_run_returns_floors_cleared() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.enter_spire_coop(["tok_a"])
	SceneManager.advance_coop_spire_floor()
	SceneManager.advance_coop_spire_floor()
	var stats: Dictionary = SceneManager.end_coop_spire_run()
	assert_eq(int(stats.get("floors_cleared", -1)), 2)

func test_end_coop_spire_run_returns_shared_deck() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.enter_spire_coop(["tok_a"])
	SceneManager.add_coop_drafted_card("ghost")
	SceneManager.add_coop_drafted_card("zombie")
	var stats: Dictionary = SceneManager.end_coop_spire_run()
	var deck: Array = stats.get("shared_deck", [])
	assert_eq(deck, ["ghost", "zombie"])

func test_set_coop_spire_run_mirror_overwrites_local_state() -> void:
	SceneManager._coop_spire_run = {"active": false}
	SceneManager.set_coop_spire_run_mirror({"active": true, "floor": 5, "seed": 99})
	assert_true(SceneManager.is_coop_spire_active())
	assert_eq(int(SceneManager.get_coop_spire_run().get("floor", 0)), 5)

func get_suite_name() -> String:
	return "SceneManagerState"
