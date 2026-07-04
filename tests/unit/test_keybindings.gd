## Unit tests for keybinding persistence and apply-on-load (TID-409 / GID-109).
##
## Verifies that SceneManager.apply_keybindings() reads the "keybindings" dict
## from SaveManager.settings and patches InputMap accordingly, and that passing
## an empty dict restores the default keyboard event for each action.
extends "res://tests/framework/test_case.gd"

var _saved_keybindings: Dictionary = {}

func before_each() -> void:
	_saved_keybindings = SaveManager.get_setting("keybindings", {}).duplicate()

func after_each() -> void:
	SaveManager.set_setting("keybindings", _saved_keybindings)
	SceneManager.apply_keybindings()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns the physical_keycode of the first InputEventKey bound to action,
## or -1 if none is found.
func _get_first_key(action: String) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return (ev as InputEventKey).physical_keycode
	return -1

## Returns true if any InputEventKey for action has the given physical_keycode.
func _has_key(action: String, keycode: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			if (ev as InputEventKey).physical_keycode == keycode:
				return true
	return false

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_apply_keybindings_sets_custom_key() -> void:
	SaveManager.set_setting("keybindings", {"interact": KEY_F})
	SceneManager.apply_keybindings()
	assert_eq(_get_first_key("interact"), KEY_F,
		"apply_keybindings() should map 'interact' to KEY_F")

func test_apply_keybindings_empty_dict_restores_default() -> void:
	# Capture the project default key for "interact"
	var default_key: int = _get_first_key("interact")
	# Override with KEY_F
	SaveManager.set_setting("keybindings", {"interact": KEY_F})
	SceneManager.apply_keybindings()
	assert_eq(_get_first_key("interact"), KEY_F, "override should take effect")
	# Now clear overrides — default should be restored via load_from_project_settings
	SaveManager.set_setting("keybindings", {})
	SceneManager.apply_keybindings()
	assert_eq(_get_first_key("interact"), default_key,
		"clearing overrides should restore the project default key")

func test_rebindable_actions_list_has_thirteen_entries() -> void:
	assert_eq(SceneManager.REBINDABLE_ACTIONS.size(), 13,
		"REBINDABLE_ACTIONS must list exactly 13 actions")

func test_rebindable_actions_all_exist_in_inputmap() -> void:
	for action: String in SceneManager.REBINDABLE_ACTIONS:
		assert_true(InputMap.has_action(action),
			"InputMap is missing action: " + action)

func test_apply_keybindings_multiple_actions() -> void:
	SaveManager.set_setting("keybindings", {
		"move_up": KEY_I,
		"move_down": KEY_K,
	})
	SceneManager.apply_keybindings()
	assert_true(_has_key("move_up", KEY_I), "move_up should have KEY_I")
	assert_true(_has_key("move_down", KEY_K), "move_down should have KEY_K")
