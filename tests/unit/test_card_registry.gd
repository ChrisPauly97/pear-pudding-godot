## Unit tests for CardRegistry.
##
## CardRegistry extends Node and is loaded as an autoload, but can also be
## instantiated directly for testing.  We call _ready() manually to trigger
## template registration, keeping this suite completely self-contained.
extends "res://tests/framework/test_case.gd"

const CardRegistryScript = preload("res://autoloads/CardRegistry.gd")

var _registry: Node

func before_all() -> void:
	_registry = CardRegistryScript.new()
	_registry._ready()  # registers all default templates


func after_all() -> void:
	_registry.free()


# ---------------------------------------------------------------------------
# get_all_ids
# ---------------------------------------------------------------------------

func test_get_all_ids_returns_forty_default_cards() -> void:
	assert_eq(_registry.get_all_ids().size(), 40)


func test_get_all_ids_contains_ghost() -> void:
	assert_has(_registry.get_all_ids(), "ghost")


func test_get_all_ids_contains_skeleton() -> void:
	assert_has(_registry.get_all_ids(), "skeleton")


func test_get_all_ids_contains_zombie() -> void:
	assert_has(_registry.get_all_ids(), "zombie")


func test_get_all_ids_contains_ghoul() -> void:
	assert_has(_registry.get_all_ids(), "ghoul")


# ---------------------------------------------------------------------------
# get_template — valid IDs
# ---------------------------------------------------------------------------

func test_get_template_ghost_is_not_empty() -> void:
	assert_false(_registry.get_template("ghost").is_empty())


func test_get_template_ghost_id_matches() -> void:
	assert_eq(_registry.get_template("ghost")["id"], "ghost")


func test_get_template_ghost_name_is_ghost() -> void:
	assert_eq(_registry.get_template("ghost")["name"], "Ghost")


func test_get_template_ghost_cost_is_1() -> void:
	assert_eq(_registry.get_template("ghost")["cost"], 1)


func test_get_template_ghost_attack_is_1() -> void:
	assert_eq(_registry.get_template("ghost")["attack"], 1)


func test_get_template_ghost_health_is_2() -> void:
	assert_eq(_registry.get_template("ghost")["health"], 2)


func test_get_template_skeleton_cost_is_2() -> void:
	assert_eq(_registry.get_template("skeleton")["cost"], 2)


func test_get_template_skeleton_attack_is_2() -> void:
	assert_eq(_registry.get_template("skeleton")["attack"], 2)


func test_get_template_zombie_health_is_4() -> void:
	assert_eq(_registry.get_template("zombie")["health"], 4)


func test_get_template_zombie_cost_is_3() -> void:
	assert_eq(_registry.get_template("zombie")["cost"], 3)


func test_get_template_ghoul_attack_is_4() -> void:
	assert_eq(_registry.get_template("ghoul")["attack"], 4)


func test_get_template_ghoul_cost_is_4() -> void:
	assert_eq(_registry.get_template("ghoul")["cost"], 4)


func test_get_template_all_cards_have_valid_card_class() -> void:
	var valid_classes: Array[String] = ["minion", "spell", "legendary"]
	for id in _registry.get_all_ids():
		var tmpl: Dictionary = _registry.get_template(id)
		assert_has(valid_classes, tmpl["card_class"], "%s has invalid card_class '%s'" % [id, tmpl["card_class"]])


func test_get_template_all_cards_have_description() -> void:
	for id in _registry.get_all_ids():
		var tmpl: Dictionary = _registry.get_template(id)
		assert_true(tmpl.has("description"), "%s missing description key" % id)


# ---------------------------------------------------------------------------
# get_template — unknown ID
# ---------------------------------------------------------------------------

func test_get_template_unknown_id_returns_empty_dict() -> void:
	assert_true(_registry.get_template("does_not_exist").is_empty())


func test_get_template_empty_string_returns_empty_dict() -> void:
	assert_true(_registry.get_template("").is_empty())


# ---------------------------------------------------------------------------
# Immutability — templates are returned as copies
# ---------------------------------------------------------------------------

func test_modifying_returned_template_does_not_affect_registry() -> void:
	var tmpl: Dictionary = _registry.get_template("ghost")
	tmpl["cost"] = 9999
	var fresh: Dictionary = _registry.get_template("ghost")
	assert_eq(fresh["cost"], 1, "registry should return immutable copies")
