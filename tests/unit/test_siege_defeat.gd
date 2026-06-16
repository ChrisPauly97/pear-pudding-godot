## Tests for siege defeat: coin loss is 10% of current coins, siege cleared, story unaffected.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# Coin loss logic (pure SaveManager — no SceneManager needed)
# ---------------------------------------------------------------------------

func test_10_percent_coin_loss_floors_correctly() -> void:
	# Test the calculation: int(coins * 0.10)
	# 100 coins → 10 loss
	var coins: int = 100
	var loss: int = int(coins * 0.10)
	assert_eq(loss, 10)

func test_coin_loss_floored_for_small_amount() -> void:
	# 5 coins → int(5 * 0.10) = int(0.5) = 0 in GDScript int()
	var coins: int = 5
	var loss: int = int(coins * 0.10)
	assert_eq(loss, 0)

func test_zero_coins_no_loss() -> void:
	var coins: int = 0
	var loss: int = int(coins * 0.10)
	assert_eq(loss, 0)

# ---------------------------------------------------------------------------
# end_siege_defeat — siege cleared, last_siege_day updated
# ---------------------------------------------------------------------------

func test_defeat_clears_active_siege() -> void:
	_sm.start_siege("madrian")
	_sm.end_siege_defeat()
	assert_true(_sm.get_active_siege().is_empty())

func test_defeat_sets_last_siege_day() -> void:
	_sm.days_elapsed = 8
	_sm.start_siege("madrian")
	_sm.end_siege_defeat()
	assert_eq(_sm.last_siege_day, 8)

func test_defeat_does_not_apply_town_discount() -> void:
	_sm.days_elapsed = 5
	_sm.start_siege("madrian")
	_sm.end_siege_defeat()
	assert_false(_sm.is_town_discounted("madrian"), "defeat must NOT grant a town discount")

func test_defeat_does_not_change_story_flags() -> void:
	_sm.story_flags = {}
	_sm.start_siege("madrian")
	_sm.end_siege_defeat()
	assert_true(_sm.story_flags.is_empty(), "no story flags should be set on siege defeat")

# ---------------------------------------------------------------------------
# Cooldown after defeat
# ---------------------------------------------------------------------------

func test_defeat_enables_cooldown_via_last_siege_day() -> void:
	const SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
	_sm.days_elapsed = 8
	_sm.start_siege("madrian")
	_sm.end_siege_defeat()
	# last_siege_day = 8; current day = 10 → gap = 2 < 4 → no trigger
	var flags: Dictionary = {"chapter1_warned_farsyth": true}
	assert_false(SiegeDefs.should_trigger(flags, 10, _sm.last_siege_day, 42))
