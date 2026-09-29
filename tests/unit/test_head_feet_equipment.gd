## Unit tests for the helmet and boots equipment slots (GID-137 / TID-563):
## SaveManager slot CRUD, persisted fields, and the WeaponRegistry items.
## Also the TID-562 appearance hand-off from the New Game picker.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")

var _sm: SaveManagerScript


func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true


func after_each() -> void:
	_sm.free()


func test_add_and_equip_helmet() -> void:
	_sm.add_equipment("iron_helm", "helmet")
	_sm.add_equipment("iron_helm", "helmet")
	assert_eq(_sm.get_owned_by_slot("helmet"), ["iron_helm"] as Array[String])
	_sm.equip_item("iron_helm", "helmet")
	assert_eq(_sm.get_equipped_by_slot("helmet"), "iron_helm")
	_sm.equip_item("", "helmet")
	assert_eq(_sm.equipped_helmet, "")


func test_add_and_equip_boots() -> void:
	_sm.add_equipment("travel_boots", "boots")
	assert_true(_sm.get_owned_by_slot("boots").has("travel_boots"))
	_sm.equip_item("travel_boots", "boots")
	assert_eq(_sm.get_equipped_by_slot("boots"), "travel_boots")


func test_new_slots_are_persisted() -> void:
	for f: String in ["equipped_helmet", "owned_helmets", "equipped_boots", "owned_boots"]:
		assert_true(SaveManagerScript.PERSISTED_FIELDS.has(f), "%s not persisted" % f)


func test_registry_has_three_of_each() -> void:
	assert_eq(WeaponRegistry.get_by_slot("helmet").size(), 3)
	assert_eq(WeaponRegistry.get_by_slot("boots").size(), 3)
	for slot: String in ["helmet", "boots"]:
		for id: String in WeaponRegistry.get_by_slot(slot):
			var w: WeaponData = WeaponRegistry.get_weapon(id)
			assert_true(w.battle_effect_type != "" and w.battle_effect_value > 0, "%s has no effect" % id)


func test_new_game_adopts_the_pending_appearance() -> void:
	# TID-562: the New Game picker's choice becomes the saved look, once.
	_sm.pending_appearance = {"skin": 2, "hair": 1}
	_sm.new_game()
	assert_eq(int(_sm.hero_appearance.get("skin", -1)), 2)
	assert_eq(_sm.pending_appearance.size(), 0)
	assert_true(SaveManagerScript.PERSISTED_FIELDS.has("hero_appearance"))
	assert_false(SaveManagerScript.PERSISTED_FIELDS.has("pending_appearance"))
