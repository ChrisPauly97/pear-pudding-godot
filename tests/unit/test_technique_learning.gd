## GID-175 / TID-708: trainers grant technique cards, Strike is in the starter
## deck, and pre-GID-175 saves turn their skill bar into deck cards.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const _SaveMigrations = preload("res://game_logic/save/SaveMigrations.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")

func _owned(sm: SaveManagerScript, card_id: String) -> int:
	var n: int = 0
	for inst: Dictionary in sm.owned_cards:
		if str(inst.get("template_id", "")) == card_id:
			n += 1
	return n

func test_new_game_deck_has_strike() -> void:
	var sm := SaveManagerScript.new()
	sm.new_game(false)
	assert_true(sm.get_deck_template_ids().has("tech_strike"))
	assert_eq(_owned(sm, "tech_strike"), 1)

func test_ladder_prices_come_from_technique_defs() -> void:
	assert_eq(UnlockLadder.level_req("mend"), int(TechniqueDefs.def("tech_mend")["level_req"]))
	assert_eq(UnlockLadder.cost("daze"), int(TechniqueDefs.def("tech_daze")["learn_cost"]))
	assert_eq(UnlockLadder.cost("feat_dig"), 175, "feature rows keep their own price")

## GID-185 / TID-774: a feature grants its UnlockLadder.cards_for cards, never a technique.
func test_learning_a_feature_grants_its_cards_not_a_technique() -> void:
	var sm := SaveManagerScript.new()
	sm.new_game(false)
	var before: int = sm.owned_cards.size()
	sm.coins = 1000
	assert_true(sm.learn_ability(UnlockLadder.FEAT_MINIONS, 40))
	assert_eq(sm.owned_cards.size(), before + UnlockLadder.cards_for(UnlockLadder.FEAT_MINIONS, "").size())

func test_fourth_technique_is_owned_but_not_dealt_in() -> void:
	var sm := SaveManagerScript.new()
	sm.new_game(false)
	sm.coins = 10000
	for id: String in ["mend", "kick", "guard"]:
		assert_true(sm.learn_ability(id, 0))
	assert_eq(_owned(sm, "tech_guard"), 1, "owned")
	assert_false(sm.get_deck_template_ids().has("tech_guard"), "deck already holds 3 techniques")
	assert_eq(TechniqueDefs.deck_violation(sm.get_deck_template_ids()), "")

func test_migration_queues_the_old_bar() -> void:
	var d: Dictionary = {"version": 45, "learned_abilities": ["mend", "feat_minions"],
		"skill_bar": ["kick", "strike", "mend"]}
	_SaveMigrations.apply(d)
	assert_eq(d["technique_deck_pending"], ["tech_strike", "tech_mend"], "unlearned Kick dropped")
	assert_false(d.has("skill_bar"))
	var empty_bar: Dictionary = {"version": 45, "learned_abilities": ["kick"]}
	_SaveMigrations.apply(empty_bar)
	assert_eq(empty_bar["technique_deck_pending"], ["tech_strike", "tech_kick"], "default bar")

func test_load_repairs_and_deals_old_bar() -> void:
	var writer := SaveManagerScript.new()
	writer.new_game(false)
	writer._loaded = true
	var data: Dictionary = JSON.parse_string(JSON.stringify(writer._collect_save_data()))
	# Simulate a pre-GID-175 save: no technique cards, Mend learned, old bar.
	var kept: Array = []
	for inst: Variant in data["owned_cards"]:
		if not str((inst as Dictionary)["template_id"]).begins_with("tech_"):
			kept.append(inst)
	data["owned_cards"] = kept
	for lo: Variant in data["loadouts"]:
		var cards: Array = []
		for uid: Variant in (lo as Dictionary)["cards"]:
			if not str(uid).begins_with("tech_"):
				cards.append(uid)
		(lo as Dictionary)["cards"] = cards
	data["learned_abilities"] = ["mend"]
	data["version"] = 45
	data["skill_bar"] = ["strike", "mend"]
	_SaveMigrations.apply(data)
	var reader := SaveManagerScript.new()
	for key: String in SaveManagerScript.PERSISTED_FIELDS:
		reader._restore_field(data, key, SaveManagerScript.PERSISTED_FIELDS[key])
	reader._restore_derived_fields(data)
	assert_eq(_owned(reader, "tech_strike"), 1)
	assert_eq(_owned(reader, "tech_mend"), 1)
	var deck: Array[String] = reader.get_deck_template_ids()
	assert_true(deck.has("tech_strike") and deck.has("tech_mend"), "old bar dealt into deck")
	# A second load (no pending queue) adds nothing new.
	var n: int = reader.owned_cards.size()
	reader._restore_derived_fields({"loadouts": reader.loadouts})
	assert_eq(reader.owned_cards.size(), n)

## GID-179 / TID-734: an active skill-tree node is its technique card.
func test_unlocking_an_active_node_deals_its_card() -> void:
	var sm := SaveManagerScript.new()
	sm.new_game(false)
	sm.skill_points = 2
	sm.unlock_skill("ember_searing_focus")
	assert_eq(_owned(sm, "tech_pyroblast"), 0, "a modifier node grants no card")
	sm.unlock_skill("ember_pyroblast")
	assert_eq(_owned(sm, "tech_pyroblast"), 1)
	assert_true(sm.get_deck_template_ids().has("tech_pyroblast"), "dealt in while legal")

func test_migration_queues_unlocked_skill_techniques() -> void:
	var d: Dictionary = {"version": 47, "unlocked_skills": ["dawn_inner_light", "dawn_restoration"]}
	_SaveMigrations.apply(d)
	assert_eq(d["technique_deck_pending"], ["tech_restoration"])
	assert_eq(int(d["version"]), _SaveMigrations.CURRENT_VERSION)
