## Unit tests for the town gratitude discount system in SaveManager.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true

func after_each() -> void:
	_sm.free()

# ---------------------------------------------------------------------------
# apply_town_discount
# ---------------------------------------------------------------------------

func test_apply_discount_makes_town_discounted() -> void:
	_sm.days_elapsed = 10
	_sm.apply_town_discount("madrian")
	assert_true(_sm.is_town_discounted("madrian"))

func test_discount_expiry_day_is_days_plus_3() -> void:
	_sm.days_elapsed = 10
	_sm.apply_town_discount("madrian")
	assert_eq(int(_sm.town_discounts.get("madrian", 0)), 13)

func test_unknown_town_not_discounted() -> void:
	_sm.days_elapsed = 10
	assert_false(_sm.is_town_discounted("unknown_town"))

func test_different_towns_independent() -> void:
	_sm.days_elapsed = 5
	_sm.apply_town_discount("madrian")
	assert_true(_sm.is_town_discounted("madrian"))
	assert_false(_sm.is_town_discounted("maykalene"))

# ---------------------------------------------------------------------------
# is_town_discounted on day boundary
# ---------------------------------------------------------------------------

func test_discount_active_on_day_of_expiry() -> void:
	_sm.days_elapsed = 10
	_sm.apply_town_discount("madrian")   # expiry = 13
	_sm.days_elapsed = 13
	assert_true(_sm.is_town_discounted("madrian"), "discount should be active on expiry day")

func test_discount_expired_day_after_expiry() -> void:
	_sm.days_elapsed = 10
	_sm.apply_town_discount("madrian")   # expiry = 13
	_sm.days_elapsed = 14
	assert_false(_sm.is_town_discounted("madrian"), "discount must expire after expiry day")

# ---------------------------------------------------------------------------
# Increment day cleans up expired discounts
# ---------------------------------------------------------------------------

func test_increment_day_removes_expired_discount() -> void:
	_sm.days_elapsed = 10
	_sm.apply_town_discount("madrian")   # expires day 13
	# Jump past expiry and roll the day
	_sm.days_elapsed = 13
	_sm.increment_day()   # days_elapsed becomes 14
	assert_false(_sm.is_town_discounted("madrian"))

func test_increment_day_keeps_active_discount() -> void:
	_sm.days_elapsed = 10
	_sm.apply_town_discount("madrian")   # expires day 13
	_sm.increment_day()   # days_elapsed becomes 11
	assert_true(_sm.is_town_discounted("madrian"), "discount active on day 11 (expires 13)")

# ---------------------------------------------------------------------------
# end_siege_victory applies discount automatically
# ---------------------------------------------------------------------------

func test_victory_applies_town_discount() -> void:
	_sm.days_elapsed = 5
	_sm.start_siege("blancogov")
	_sm.end_siege_victory()
	assert_true(_sm.is_town_discounted("blancogov"))

func test_victory_discount_expires_after_3_days() -> void:
	_sm.days_elapsed = 5
	_sm.start_siege("blancogov")
	_sm.end_siege_victory()   # expiry = 5 + 3 = 8
	_sm.days_elapsed = 9
	assert_false(_sm.is_town_discounted("blancogov"))
