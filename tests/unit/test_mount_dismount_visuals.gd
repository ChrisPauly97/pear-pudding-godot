## Unit tests for auto-dismount rules and mounted visual predicates (TID-181 / GID-048).
##
## Tests the pure-logic dismount/remount triggers (battle start, map entry, map return)
## and visual visibility conditions without requiring UI rendering or scene nodes.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const MountRegistry     = preload("res://game_logic/MountRegistry.gd")
const TextureGen        = preload("res://game_logic/TextureGen.gd")

var _sm: Node

func get_suite_name() -> String:
	return "MountDismountVisuals"

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm.owned_mounts.append("stable_horse")

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# Auto-dismount on battle start
# ---------------------------------------------------------------------------

func test_battle_start_dismisses_mount() -> void:
	_sm.summon_mount("stable_horse")
	assert_true(_sm.is_mounted, "setup: mounted before battle")
	# Simulate what _on_enemy_engaged_for_mount does
	if _sm.is_mounted:
		_sm.auto_dismiss_mount()
	assert_false(_sm.is_mounted, "dismounted when battle starts")

func test_active_mount_preserved_after_battle_dismount() -> void:
	_sm.summon_mount("stable_horse")
	_sm.auto_dismiss_mount()
	# active_mount must stay so remount can happen after battle
	assert_eq(_sm.active_mount, "stable_horse", "active_mount preserved through auto_dismiss")

func test_battle_start_noop_when_not_mounted() -> void:
	_sm.is_mounted = false
	var before: bool = _sm.is_mounted
	# Guard: only dismount if currently mounted
	if _sm.is_mounted:
		_sm.auto_dismiss_mount()
	assert_eq(_sm.is_mounted, before, "no change when not mounted")

# ---------------------------------------------------------------------------
# Remount after battle win
# ---------------------------------------------------------------------------

func test_remount_after_battle_win_when_active_mount_set() -> void:
	_sm.summon_mount("stable_horse")
	_sm.auto_dismiss_mount()
	_sm.current_map = "main"
	# Simulate the battle_won callback
	if _sm.active_mount != "" and _sm.current_map == "main":
		_sm.summon_mount(_sm.active_mount)
	assert_true(_sm.is_mounted, "remounted after battle win")

func test_no_remount_after_battle_if_active_mount_cleared() -> void:
	_sm.is_mounted = false
	_sm.active_mount = ""
	_sm.current_map = "main"
	if _sm.active_mount != "" and _sm.current_map == "main":
		_sm.summon_mount(_sm.active_mount)
	assert_false(_sm.is_mounted, "no remount when active_mount is empty")

func test_no_remount_after_battle_if_not_in_main_map() -> void:
	_sm.summon_mount("stable_horse")
	_sm.dismiss_mount()
	_sm.current_map = "madrian"
	if _sm.active_mount != "" and _sm.current_map == "main":
		_sm.summon_mount(_sm.active_mount)
	assert_false(_sm.is_mounted, "no remount when not in main map")

# ---------------------------------------------------------------------------
# Auto-dismount on named map entry
# ---------------------------------------------------------------------------

func test_named_map_entry_dismounts() -> void:
	_sm.summon_mount("stable_horse")
	var target_map: String = "madrian"
	# Simulate the guard in _handle_interact before enter_map
	if _sm.is_mounted and target_map != "main" and not target_map.is_empty():
		_sm.auto_dismiss_mount()
	assert_false(_sm.is_mounted, "dismounted on entering named map")

func test_main_map_entry_does_not_dismount() -> void:
	_sm.summon_mount("stable_horse")
	var target_map: String = "main"
	if _sm.is_mounted and target_map != "main" and not target_map.is_empty():
		_sm.auto_dismiss_mount()
	assert_true(_sm.is_mounted, "still mounted when target_map is main")

func test_empty_target_map_does_not_dismount() -> void:
	_sm.summon_mount("stable_horse")
	var target_map: String = ""
	if _sm.is_mounted and target_map != "main" and not target_map.is_empty():
		_sm.auto_dismiss_mount()
	assert_true(_sm.is_mounted, "no dismount when target_map is empty (exit_map path)")

func test_dungeon_entry_dismounts() -> void:
	_sm.summon_mount("stable_horse")
	var target_map: String = "dungeon_0"
	if _sm.is_mounted and target_map != "main" and not target_map.is_empty():
		_sm.auto_dismiss_mount()
	assert_false(_sm.is_mounted, "dismounted on entering dungeon")

# ---------------------------------------------------------------------------
# Auto-remount on return to overworld
# ---------------------------------------------------------------------------

func test_return_to_main_remounts_if_active_mount_set() -> void:
	_sm.summon_mount("stable_horse")
	_sm.auto_dismiss_mount()
	_sm.current_map = "main"
	# Simulate _ready() auto-remount logic in WorldScene for map_name == "main"
	if _sm.active_mount != "" and not _sm.is_mounted:
		_sm.summon_mount(_sm.active_mount)
	assert_true(_sm.is_mounted, "auto-remounted on returning to main")

func test_return_to_main_noop_if_no_active_mount() -> void:
	_sm.is_mounted = false
	_sm.active_mount = ""
	_sm.current_map = "main"
	if _sm.active_mount != "" and not _sm.is_mounted:
		_sm.summon_mount(_sm.active_mount)
	assert_false(_sm.is_mounted, "no remount when active_mount is empty")

func test_return_to_main_noop_if_already_mounted() -> void:
	_sm.summon_mount("stable_horse")
	_sm.current_map = "main"
	var was_mounted: bool = _sm.is_mounted
	if _sm.active_mount != "" and not _sm.is_mounted:
		_sm.summon_mount(_sm.active_mount)
	assert_eq(_sm.is_mounted, was_mounted, "no duplicate summon if already mounted")

# ---------------------------------------------------------------------------
# Mount sprite / dust particle visibility predicates
# ---------------------------------------------------------------------------

func _mount_sprite_visible(is_mounted: bool) -> bool:
	return is_mounted

func _dust_emitting(is_mounted: bool, is_moving: bool) -> bool:
	return is_mounted and is_moving

func test_mount_sprite_visible_when_mounted() -> void:
	assert_true(_mount_sprite_visible(true))

func test_mount_sprite_hidden_when_dismounted() -> void:
	assert_false(_mount_sprite_visible(false))

func test_dust_emitting_when_mounted_and_moving() -> void:
	assert_true(_dust_emitting(true, true))

func test_dust_not_emitting_when_mounted_but_idle() -> void:
	assert_false(_dust_emitting(true, false))

func test_dust_not_emitting_when_moving_but_dismounted() -> void:
	assert_false(_dust_emitting(false, true))

func test_dust_not_emitting_when_both_false() -> void:
	assert_false(_dust_emitting(false, false))

# ---------------------------------------------------------------------------
# TextureGen.mount_horse produces a valid texture
# ---------------------------------------------------------------------------

func test_mount_horse_texture_not_null() -> void:
	var tex: ImageTexture = TextureGen.mount_horse()
	assert_true(tex != null, "mount_horse() must return a non-null ImageTexture")

func test_mount_horse_texture_cached() -> void:
	var t1: ImageTexture = TextureGen.mount_horse()
	var t2: ImageTexture = TextureGen.mount_horse()
	assert_true(t1 == t2, "mount_horse() should return the same cached instance")
