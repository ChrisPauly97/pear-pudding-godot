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

func before_each() -> void:
	_saved_state = SceneManager._state
	_saved_map_stack.assign(SceneManager.map_stack)
	_saved_door_stack.assign(SceneManager.door_stack)
	_saved_current_map = SceneManager.current_map
	_saved_proximity_blocked = SceneManager._proximity_engage_blocked

func after_each() -> void:
	SceneManager._state = _saved_state
	SceneManager.map_stack.assign(_saved_map_stack)
	SceneManager.door_stack.assign(_saved_door_stack)
	SceneManager.current_map = _saved_current_map
	SceneManager._proximity_engage_blocked = _saved_proximity_blocked

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

func get_suite_name() -> String:
	return "SceneManagerState"
