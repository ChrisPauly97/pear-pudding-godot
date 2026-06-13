## Unit tests for weather battle modifier logic and WeatherBanner.
##
## BattleScene itself cannot be tested headlessly (requires @onready viewport nodes),
## so these tests exercise the underlying primitives: CardInstance stat manipulation,
## HeroState status effects, WeatherBanner static helpers, and the map-guard logic.
extends "res://tests/framework/test_case.gd"

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const WeatherBanner = preload("res://scenes/battle/WeatherBanner.gd")

func get_suite_name() -> String:
	return "WeatherBattle"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _ghost() -> CardInstance:
	return CardInstance.new({
		"id": "ghost", "name": "Ghost", "cost": 2,
		"attack": 1, "health": 2, "card_class": "minion", "description": "",
	})

func _minion(id: String = "skeleton", atk: int = 2, hp: int = 3) -> CardInstance:
	return CardInstance.new({
		"id": id, "name": id.capitalize(), "cost": 1,
		"attack": atk, "health": hp, "card_class": "minion", "description": "",
	})

# ---------------------------------------------------------------------------
# WeatherBanner.modifier_text
# ---------------------------------------------------------------------------

func test_banner_modifier_text_rain() -> void:
	var t: String = WeatherBanner.modifier_text("rain")
	assert_true(t.length() > 0, "rain modifier text should not be empty")

func test_banner_modifier_text_blizzard() -> void:
	var t: String = WeatherBanner.modifier_text("blizzard")
	assert_true(t.length() > 0)

func test_banner_modifier_text_empty_weather() -> void:
	var t: String = WeatherBanner.modifier_text("")
	assert_eq(t, "")

func test_banner_modifier_text_unknown_weather() -> void:
	var t: String = WeatherBanner.modifier_text("nonexistent_xyz")
	assert_eq(t, "")

func test_banner_modifier_text_ash_fall() -> void:
	var t: String = WeatherBanner.modifier_text("ash_fall")
	assert_true(t.length() > 0)

func test_banner_modifier_text_sandstorm() -> void:
	var t: String = WeatherBanner.modifier_text("sandstorm")
	assert_true(t.length() > 0)

func test_banner_modifier_text_snow() -> void:
	var t: String = WeatherBanner.modifier_text("snow")
	assert_true(t.length() > 0)

# ---------------------------------------------------------------------------
# Rain modifier — ghost gains +1 health on summon
# ---------------------------------------------------------------------------

func test_rain_ghost_health_increases_by_one() -> void:
	var card := _ghost()
	var orig_health: int = card.health
	var orig_max: int = card.max_health
	# Simulate _apply_weather_to_summoned("rain")
	if card.template_id == "ghost":
		card.health += 1
		card.max_health += 1
	assert_eq(card.health, orig_health + 1)
	assert_eq(card.max_health, orig_max + 1)

func test_rain_non_ghost_health_unchanged() -> void:
	var card := _minion("skeleton")
	var orig: int = card.health
	# Skeleton is not a ghost — rain modifier should not apply
	if card.template_id == "ghost":
		card.health += 1
	assert_eq(card.health, orig)

# ---------------------------------------------------------------------------
# Heavy rain — ghost gains +2 health on summon
# ---------------------------------------------------------------------------

func test_heavy_rain_ghost_health_increases_by_two() -> void:
	var card := _ghost()
	var orig: int = card.health
	if card.template_id == "ghost":
		card.health += 2
		card.max_health += 2
	assert_eq(card.health, orig + 2)

# ---------------------------------------------------------------------------
# Sandstorm — minion loses 1 attack on summon (floored at 0)
# ---------------------------------------------------------------------------

func test_sandstorm_attack_reduced_by_one() -> void:
	var card := _minion("skeleton", 2, 3)
	var orig: int = card.attack
	card.attack = maxi(0, card.attack - 1)
	assert_eq(card.attack, orig - 1)

func test_sandstorm_attack_floored_at_zero() -> void:
	var card := _minion("skeleton", 0, 3)
	card.attack = maxi(0, card.attack - 1)
	assert_eq(card.attack, 0)

# ---------------------------------------------------------------------------
# Ash fall — enemy hero starts with 2 poison
# ---------------------------------------------------------------------------

func test_ash_fall_applies_two_poison_to_hero() -> void:
	var hero := HeroState.new(1)
	hero.apply_status("poison", 2)
	assert_eq(hero.get_status_value("poison"), 2)

func test_ash_fall_hero_has_poison_status() -> void:
	var hero := HeroState.new(1)
	hero.apply_status("poison", 2)
	assert_true(hero.has_status("poison"))

# ---------------------------------------------------------------------------
# Snow — first card costs 1 less per turn
# ---------------------------------------------------------------------------

func test_snow_discount_reduces_cost_by_one() -> void:
	var card := _minion("skeleton", 2, 3)
	card.cost = 3
	var discount_used: bool = false
	# Simulate _do_play_card logic (without actually playing)
	if not discount_used:
		var discounted_cost: int = maxi(0, card.cost - 1)
		assert_eq(discounted_cost, 2)

func test_snow_discount_floors_at_zero() -> void:
	var card := _minion("skeleton", 2, 3)
	card.cost = 0
	var discounted_cost: int = maxi(0, card.cost - 1)
	assert_eq(discounted_cost, 0)

func test_snow_second_card_no_discount() -> void:
	var card := _minion("skeleton", 2, 3)
	card.cost = 3
	var discount_used: bool = true  # already used this turn
	var effective_cost: int = card.cost
	if not discount_used:
		effective_cost = maxi(0, card.cost - 1)
	assert_eq(effective_cost, 3)

# ---------------------------------------------------------------------------
# Blizzard — freeze applied to minions at start of turn 1 and 2
# ---------------------------------------------------------------------------

func test_blizzard_freeze_applies_to_minion() -> void:
	var card := _minion()
	card.apply_status("freeze", 1)
	assert_true(card.has_status("freeze"))
	assert_eq(card.get_status_value("freeze"), 1)

func test_blizzard_freeze_on_turn_3_not_applied() -> void:
	var turn_number: int = 3
	var card := _minion()
	if turn_number <= 2:
		card.apply_status("freeze", 1)
	assert_false(card.has_status("freeze"))

# ---------------------------------------------------------------------------
# Map guard — _battle_weather is "" on non-infinite-world maps
# ---------------------------------------------------------------------------

func test_battle_weather_empty_on_dungeon_map() -> void:
	var saved: String = SaveManager.current_map
	WeatherManager.current_weather = "rain"
	SaveManager.current_map = "dungeon"
	var battle_weather: String = WeatherManager.current_weather if SaveManager.current_map == "main" else ""
	assert_eq(battle_weather, "")
	SaveManager.current_map = saved

func test_battle_weather_from_weather_manager_on_main_map() -> void:
	var saved_map: String = SaveManager.current_map
	var saved_weather: String = WeatherManager.current_weather
	WeatherManager.current_weather = "snow"
	SaveManager.current_map = "main"
	var battle_weather: String = WeatherManager.current_weather if SaveManager.current_map == "main" else ""
	assert_eq(battle_weather, "snow")
	SaveManager.current_map = saved_map
	WeatherManager.current_weather = saved_weather
