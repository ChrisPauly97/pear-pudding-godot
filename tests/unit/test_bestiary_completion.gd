## Unit tests for bestiary completion rewards (TID-172).
##
## Covers: is_bestiary_complete, one-time guard, coin/card/achievement rewards,
## and re-entrant safety.
## SaveManager is instantiated directly — no scene tree needed.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

# All 8 bundled enemy type IDs (must match files in data/enemies/).
const ALL_ENEMY_IDS: Array[String] = [
	"duelist_novice",
	"duelist_adept",
	"undead_basic",
	"undead_horde",
	"duelist_champion",
	"ghoul_pack",
	"undead_elite",
	"roaming_terror",
]

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true

func after_each() -> void:
	_sm.free()

func _defeat_all_except(skip_id: String) -> void:
	for eid: String in ALL_ENEMY_IDS:
		if eid != skip_id:
			_sm.record_enemy_defeated(eid)

func _defeat_all() -> void:
	for eid: String in ALL_ENEMY_IDS:
		_sm.record_enemy_defeated(eid)

# ---------------------------------------------------------------------------
# is_bestiary_complete
# ---------------------------------------------------------------------------

func test_bestiary_not_complete_with_no_defeats() -> void:
	assert_false(_sm.is_bestiary_complete(), "should not be complete with zero defeats")

func test_bestiary_not_complete_with_some_missing() -> void:
	_defeat_all_except("roaming_terror")
	assert_false(_sm.is_bestiary_complete(), "should not be complete when one type not yet defeated")

func test_bestiary_complete_when_all_defeated() -> void:
	_defeat_all()
	assert_true(_sm.is_bestiary_complete(), "should be complete when all types are defeated")

func test_bestiary_complete_after_repeated_defeats() -> void:
	for i: int in range(3):
		_defeat_all()
	assert_true(_sm.is_bestiary_complete(), "should remain complete after multiple defeats")

# ---------------------------------------------------------------------------
# One-time reward guard
# ---------------------------------------------------------------------------

func test_bestiary_complete_rewarded_false_initially() -> void:
	assert_false(_sm.bestiary_complete_rewarded, "rewarded flag must start false")

func test_bestiary_complete_rewarded_set_on_completion() -> void:
	_defeat_all()
	assert_true(_sm.bestiary_complete_rewarded, "rewarded flag must be set after completion")

func test_reward_not_granted_before_completion() -> void:
	_defeat_all_except("roaming_terror")
	assert_eq(_sm.coins, 0, "no coins before all enemies are defeated")

func test_reward_not_granted_twice_when_defeated_again() -> void:
	_defeat_all()
	var coins_after_first: int = _sm.coins
	_defeat_all()  # defeat all again — reward must not double
	assert_eq(_sm.coins, coins_after_first, "coins must not be awarded a second time")

# ---------------------------------------------------------------------------
# Coin reward
# ---------------------------------------------------------------------------

func test_coins_awarded_on_completion() -> void:
	_defeat_all()
	assert_gte(_sm.coins, 500, "at least 500 coins must be awarded on completion")

func test_coins_awarded_exactly_500() -> void:
	_defeat_all()
	assert_eq(_sm.coins, 500, "exactly 500 coins must be awarded on first completion")

# ---------------------------------------------------------------------------
# Card reward
# ---------------------------------------------------------------------------

func test_soul_harvest_card_awarded_on_completion() -> void:
	_defeat_all()
	var found: bool = false
	for inst: Dictionary in _sm.owned_cards:
		if str(inst.get("template_id", "")) == "soul_harvest":
			found = true
			break
	assert_true(found, "soul_harvest card must be in owned_cards after bestiary completion")

func test_card_rarity_is_legendary() -> void:
	_defeat_all()
	for inst: Dictionary in _sm.owned_cards:
		if str(inst.get("template_id", "")) == "soul_harvest":
			assert_eq(str(inst.get("rarity", "")), "legendary", "reward card must be legendary rarity")

# ---------------------------------------------------------------------------
# Achievement flag
# ---------------------------------------------------------------------------

func test_story_flag_bestiary_complete_set() -> void:
	_defeat_all()
	assert_true(_sm.get_story_flag("bestiary_complete"), "story flag 'bestiary_complete' must be set on completion")

func test_achievement_in_unlocked_achievements() -> void:
	_defeat_all()
	assert_has(_sm.unlocked_achievements, "monster_scholar", "monster_scholar must be in unlocked_achievements")

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

func test_bestiary_starts_empty() -> void:
	assert_true(_sm.bestiary.is_empty(), "bestiary dict must start empty")

func test_bestiary_complete_rewarded_starts_false() -> void:
	assert_false(_sm.bestiary_complete_rewarded, "bestiary_complete_rewarded must default to false")
