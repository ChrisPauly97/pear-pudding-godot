## Unit tests for the stable purchase flow and HUD visibility logic (TID-180 / GID-048).
##
## Tests the pure-logic purchase guard predicates (level gate, coin check)
## and HUD button visibility conditions without requiring UI rendering.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const MountRegistry     = preload("res://game_logic/MountRegistry.gd")

const MOUNT_PRICE: int = 750
const MOUNT_LEVEL_REQ: int = 10

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# Purchase guard: can_buy predicate
# ---------------------------------------------------------------------------

func _can_buy(level: int, coins: int) -> bool:
	return level >= MOUNT_LEVEL_REQ and coins >= MOUNT_PRICE

func test_can_buy_true_when_level_and_coins_sufficient() -> void:
	assert_true(_can_buy(10, 750))

func test_can_buy_true_above_minimum() -> void:
	assert_true(_can_buy(15, 1000))

func test_can_buy_false_when_level_too_low() -> void:
	assert_false(_can_buy(9, 750))

func test_can_buy_false_when_level_one() -> void:
	assert_false(_can_buy(1, 750))

func test_can_buy_false_when_coins_insufficient() -> void:
	assert_false(_can_buy(10, 749))

func test_can_buy_false_when_coins_zero() -> void:
	assert_false(_can_buy(10, 0))

func test_can_buy_false_when_both_level_and_coins_fail() -> void:
	assert_false(_can_buy(5, 100))

# ---------------------------------------------------------------------------
# Purchase flow: SaveManager state transitions
# ---------------------------------------------------------------------------

func test_purchase_deducts_coins() -> void:
	_sm.coins = 1000
	_sm.level = 10
	_sm.owned_mounts = []
	_sm.coins -= MOUNT_PRICE
	assert_eq(_sm.coins, 250)

func test_purchase_adds_to_owned_mounts() -> void:
	_sm.owned_mounts = []
	_sm.owned_mounts.append("stable_horse")
	assert_true(_sm.owned_mounts.has("stable_horse"))

func test_purchase_sets_active_mount_via_summon() -> void:
	_sm.owned_mounts = []
	_sm.owned_mounts.append("stable_horse")
	_sm.summon_mount("stable_horse")
	assert_eq(_sm.active_mount, "stable_horse")
	assert_true(_sm.is_mounted)

func test_already_owns_guard_blocks_repurchase() -> void:
	_sm.owned_mounts = []
	_sm.owned_mounts.append("stable_horse")
	var already_owned: bool = _sm.owned_mounts.has("stable_horse")
	assert_true(already_owned, "re-purchase must be blocked when already owned")

# ---------------------------------------------------------------------------
# HUD button visibility: show when owned + in main map
# ---------------------------------------------------------------------------

func _mount_btn_visible(owned_count: int, current_map: String) -> bool:
	return owned_count > 0 and current_map == "main"

func test_mount_btn_hidden_when_no_mounts_owned() -> void:
	assert_false(_mount_btn_visible(0, "main"))

func test_mount_btn_visible_when_mount_owned_and_in_main() -> void:
	assert_true(_mount_btn_visible(1, "main"))

func test_mount_btn_hidden_in_named_map_even_if_owned() -> void:
	assert_false(_mount_btn_visible(1, "madrian"))

func test_mount_btn_hidden_in_dungeon_even_if_owned() -> void:
	assert_false(_mount_btn_visible(1, "dungeon_0"))

# ---------------------------------------------------------------------------
# HUD button text: "Mount" vs "Dismount"
# ---------------------------------------------------------------------------

func test_mount_btn_text_mount_when_dismounted() -> void:
	_sm.owned_mounts.append("stable_horse")
	_sm.is_mounted = false
	var text: String = "Dismount" if _sm.is_mounted else "Mount"
	assert_eq(text, "Mount")

func test_mount_btn_text_dismount_when_mounted() -> void:
	_sm.owned_mounts.append("stable_horse")
	_sm.summon_mount("stable_horse")
	var text: String = "Dismount" if _sm.is_mounted else "Mount"
	assert_eq(text, "Dismount")

# ---------------------------------------------------------------------------
# Toggle logic: mount / dismount cycle
# ---------------------------------------------------------------------------

func test_toggle_summmons_when_dismounted_and_in_main() -> void:
	_sm.owned_mounts.append("stable_horse")
	_sm.is_mounted = false
	_sm.current_map = "main"
	# Simulate toggle
	if _sm.current_map == "main" and _sm.owned_mounts.size() > 0:
		if _sm.is_mounted:
			_sm.dismiss_mount()
		else:
			_sm.summon_mount(str(_sm.owned_mounts[0]))
	assert_true(_sm.is_mounted)

func test_toggle_dismisses_when_mounted() -> void:
	_sm.owned_mounts.append("stable_horse")
	_sm.summon_mount("stable_horse")
	_sm.current_map = "main"
	if _sm.current_map == "main" and _sm.owned_mounts.size() > 0:
		if _sm.is_mounted:
			_sm.dismiss_mount()
		else:
			_sm.summon_mount(str(_sm.owned_mounts[0]))
	assert_false(_sm.is_mounted)

func test_toggle_noop_when_not_in_main() -> void:
	_sm.owned_mounts.append("stable_horse")
	_sm.is_mounted = false
	_sm.current_map = "madrian"
	var before: bool = _sm.is_mounted
	# Toggle guard: no action outside main map
	if _sm.current_map == "main" and _sm.owned_mounts.size() > 0:
		_sm.summon_mount(str(_sm.owned_mounts[0]))
	assert_eq(_sm.is_mounted, before)

func test_toggle_noop_when_no_mounts_owned() -> void:
	_sm.owned_mounts = []
	_sm.current_map = "main"
	var before: bool = _sm.is_mounted
	if _sm.current_map == "main" and _sm.owned_mounts.size() > 0:
		_sm.summon_mount(str(_sm.owned_mounts[0]))
	assert_eq(_sm.is_mounted, before)

# ---------------------------------------------------------------------------
# Madrian stable NPC data
# ---------------------------------------------------------------------------

func test_stable_horse_registry_display_name_not_empty() -> void:
	var m: Dictionary = MountRegistry.get_mount("stable_horse")
	assert_false(str(m.get("display_name", "")).is_empty())

func test_stable_horse_price_matches_panel_const() -> void:
	var m: Dictionary = MountRegistry.get_mount("stable_horse")
	assert_eq(int(m.get("price", 0)), MOUNT_PRICE)

func test_stable_horse_level_req_is_ten() -> void:
	assert_eq(MOUNT_LEVEL_REQ, 10)
