## Unit tests for persistent hero HP (GID-136 / TID-543).
extends "res://tests/framework/test_case.gd"

const _HeroVitality = preload("res://game_logic/HeroVitality.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")


func test_only_ordinary_fights_carry_hp() -> void:
	assert_true(_HeroVitality.carries_over({"enemy_type": "ghoul"}, false, false, false))
	assert_false(_HeroVitality.carries_over({}, true, false, false), "spire keeps its own HP")
	assert_false(_HeroVitality.carries_over({}, false, true, false), "siege keeps its own HP")
	assert_false(_HeroVitality.carries_over({}, false, false, true), "duels are friendly")
	assert_false(_HeroVitality.carries_over({"enemy_type": "training_dummy"}, false, false, false))


func test_battle_start_hp_scales_and_never_hits_zero() -> void:
	assert_eq(_HeroVitality.battle_start_hp(30, 1.0), 30)
	assert_eq(_HeroVitality.battle_start_hp(40, 0.5), 20, "a gear change rescales, never wounds")
	assert_eq(_HeroVitality.battle_start_hp(30, 0.0), 1)
	assert_eq(_HeroVitality.battle_start_hp(30, 7.0), 30, "clamped")


func test_frac_after_a_fight() -> void:
	assert_almost_eq(_HeroVitality.frac_after(15, 30, true), 0.5, 0.001)
	assert_eq(_HeroVitality.frac_after(30, 30, false), _HeroVitality.RESPAWN_FRAC, "a loss respawns hurt")


func test_regen_and_meals() -> void:
	var f: float = _HeroVitality.regen(0.0, _HeroVitality.REGEN_FULL_SECONDS * 0.5)
	assert_almost_eq(f, 0.5, 0.001)
	assert_eq(_HeroVitality.regen(0.99, 100.0), 1.0, "capped")
	var rate: float = _HeroVitality.meal_rate("roast_fowl")
	var roast: Dictionary = _HeroVitality.FOODS["roast_fowl"]
	assert_true(_HeroVitality.regen(0.0, float(roast["seconds"]), rate) >= 1.0, "roast fowl heals fully")
	assert_eq(_HeroVitality.meal_rate("bogus"), 0.0)


func test_best_world_item_prefers_food() -> void:
	assert_eq(_HeroVitality.best_world_item({"travel_bread": 1}, {"healing_draught": 3}), "travel_bread")
	assert_eq(_HeroVitality.best_world_item({"travel_bread": 0}, {"healing_draught": 3}), "healing_draught")
	assert_eq(_HeroVitality.best_world_item({}, {"clarity_brew": 3}), "", "only healing works outside a fight")


func test_fields_persist_and_reset() -> void:
	for f: String in ["hero_hp_frac", "foods"]:
		assert_true(SaveManagerScript.PERSISTED_FIELDS.has(f), f)
	var sm := SaveManagerScript.new()
	sm.hero_hp_frac = 0.2
	sm.foods = {"travel_bread": 2}
	sm.new_game()
	assert_eq(sm.hero_hp_frac, 1.0)
	assert_eq(sm.foods.size(), 0)
	sm.free()


func test_hurt_never_kills() -> void:
	assert_almost_eq(_HeroVitality.hurt(1.0, 3), 0.9, 0.001)
	assert_almost_eq(_HeroVitality.hurt(0.05, 30), 1.0 / 30.0, 0.0001)
