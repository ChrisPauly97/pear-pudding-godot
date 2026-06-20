## Unit tests for the Soulbind capture system (GID-061 TID-218/219/220).
##
## Covers: CaptureTracker all condition keys (satisfied + violated), AI actions
## not counting against player conditions, unknown/empty condition returns false,
## SaveManager captured_signatures round-trip and migration, to_template_dict
## exposing is_unique/can_craft, shop exclusion predicate, EnemyRegistry accessors,
## and signature card registration in CardRegistry.
extends "res://tests/framework/test_case.gd"

const CaptureTracker = preload("res://game_logic/battle/CaptureTracker.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const EnemyRegistryScript = preload("res://autoloads/EnemyRegistry.gd")
const CardRegistryScript = preload("res://autoloads/CardRegistry.gd")
const CardDataScript = preload("res://data/CardData.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_state(player_hp: int, turn: int) -> GameState:
	var s := GameState.new()
	s.players[0].hero.health = player_hp
	s.turn_number = turn
	return s

# ---------------------------------------------------------------------------
# spell_final_blow
# ---------------------------------------------------------------------------

func test_spell_final_blow_satisfied_when_spell_cleared_board() -> void:
	var t := CaptureTracker.new("spell_final_blow", 0)
	t.note_spell_resolved(0, 2, 0)
	assert_true(t.is_satisfied(_make_state(20, 5)))

func test_spell_final_blow_not_satisfied_when_board_not_emptied() -> void:
	var t := CaptureTracker.new("spell_final_blow", 0)
	t.note_spell_resolved(0, 2, 1)
	assert_false(t.is_satisfied(_make_state(20, 5)))

func test_spell_final_blow_not_satisfied_when_no_spell_cast() -> void:
	var t := CaptureTracker.new("spell_final_blow", 0)
	assert_false(t.is_satisfied(_make_state(20, 5)))

func test_spell_final_blow_ai_spell_does_not_satisfy() -> void:
	var t := CaptureTracker.new("spell_final_blow", 0)
	# AI (caster_pid=1) spell clears board — should NOT satisfy
	t.note_spell_resolved(1, 2, 0)
	assert_false(t.is_satisfied(_make_state(20, 5)))

func test_spell_final_blow_empty_board_before_does_not_satisfy() -> void:
	var t := CaptureTracker.new("spell_final_blow", 0)
	# Enemy board was already empty before spell
	t.note_spell_resolved(0, 0, 0)
	assert_false(t.is_satisfied(_make_state(20, 5)))

# ---------------------------------------------------------------------------
# no_minion_hero_attacks
# ---------------------------------------------------------------------------

func test_no_minion_hero_attacks_satisfied_when_never_attacked_hero() -> void:
	var t := CaptureTracker.new("no_minion_hero_attacks", 0)
	assert_true(t.is_satisfied(_make_state(20, 5)))

func test_no_minion_hero_attacks_violated_when_player_minion_hits_hero() -> void:
	var t := CaptureTracker.new("no_minion_hero_attacks", 0)
	t.note_minion_attacked_hero(0)
	assert_false(t.is_satisfied(_make_state(20, 5)))

func test_no_minion_hero_attacks_ai_attack_does_not_count() -> void:
	# Enemy (pid=1) attacking player hero must not void the condition
	var t := CaptureTracker.new("no_minion_hero_attacks", 0)
	t.note_minion_attacked_hero(1)
	assert_true(t.is_satisfied(_make_state(20, 5)))

# ---------------------------------------------------------------------------
# hero_hp_at_most
# ---------------------------------------------------------------------------

func test_hero_hp_at_most_satisfied_at_exactly_param() -> void:
	var t := CaptureTracker.new("hero_hp_at_most", 10)
	assert_true(t.is_satisfied(_make_state(10, 5)))

func test_hero_hp_at_most_satisfied_below_param() -> void:
	var t := CaptureTracker.new("hero_hp_at_most", 10)
	assert_true(t.is_satisfied(_make_state(5, 5)))

func test_hero_hp_at_most_violated_when_above_param() -> void:
	var t := CaptureTracker.new("hero_hp_at_most", 10)
	assert_false(t.is_satisfied(_make_state(11, 5)))

func test_hero_hp_at_most_null_state_returns_false() -> void:
	var t := CaptureTracker.new("hero_hp_at_most", 10)
	assert_false(t.is_satisfied(null))

# ---------------------------------------------------------------------------
# win_by_turn
# ---------------------------------------------------------------------------

func test_win_by_turn_satisfied_at_exactly_param() -> void:
	var t := CaptureTracker.new("win_by_turn", 9)
	assert_true(t.is_satisfied(_make_state(20, 9)))

func test_win_by_turn_satisfied_before_param() -> void:
	var t := CaptureTracker.new("win_by_turn", 9)
	assert_true(t.is_satisfied(_make_state(20, 5)))

func test_win_by_turn_violated_after_param() -> void:
	var t := CaptureTracker.new("win_by_turn", 9)
	assert_false(t.is_satisfied(_make_state(20, 10)))

func test_win_by_turn_null_state_returns_false() -> void:
	var t := CaptureTracker.new("win_by_turn", 9)
	assert_false(t.is_satisfied(null))

# ---------------------------------------------------------------------------
# Unknown / empty condition
# ---------------------------------------------------------------------------

func test_unknown_condition_returns_false() -> void:
	var t := CaptureTracker.new("nonexistent_condition", 0)
	assert_false(t.is_satisfied(_make_state(20, 5)))

func test_empty_condition_returns_false() -> void:
	var t := CaptureTracker.new("", 0)
	assert_false(t.is_satisfied(_make_state(20, 5)))

# ---------------------------------------------------------------------------
# condition_text
# ---------------------------------------------------------------------------

func test_condition_text_spell_final_blow() -> void:
	var t := CaptureTracker.new("spell_final_blow", 0)
	assert_true(t.condition_text() != "")

func test_condition_text_no_minion_hero_attacks() -> void:
	var t := CaptureTracker.new("no_minion_hero_attacks", 0)
	assert_true(t.condition_text() != "")

func test_condition_text_hero_hp_at_most_contains_param() -> void:
	var t := CaptureTracker.new("hero_hp_at_most", 10)
	assert_true(t.condition_text().contains("10"))

func test_condition_text_win_by_turn_contains_param() -> void:
	var t := CaptureTracker.new("win_by_turn", 9)
	assert_true(t.condition_text().contains("9"))

func test_condition_text_empty_for_unknown() -> void:
	var t := CaptureTracker.new("unknown", 0)
	assert_eq(t.condition_text(), "")

# ---------------------------------------------------------------------------
# SaveManager captured_signatures
# ---------------------------------------------------------------------------

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true

func after_each() -> void:
	_sm.free()

func test_default_captured_signatures_empty() -> void:
	assert_eq(_sm.captured_signatures.size(), 0)

func test_mark_signature_captured_adds_entry() -> void:
	_sm.mark_signature_captured("sig_wanderer")
	assert_true(_sm.is_signature_captured("sig_wanderer"))

func test_mark_signature_captured_idempotent() -> void:
	_sm.mark_signature_captured("sig_wanderer")
	_sm.mark_signature_captured("sig_wanderer")
	assert_eq(_sm.captured_signatures.size(), 1)

func test_is_signature_captured_false_when_not_captured() -> void:
	assert_false(_sm.is_signature_captured("sig_wanderer"))

func test_is_signature_captured_empty_id_false() -> void:
	assert_false(_sm.is_signature_captured(""))

func test_mark_signature_captured_empty_id_no_entry() -> void:
	_sm.mark_signature_captured("")
	assert_eq(_sm.captured_signatures.size(), 0)

func test_captured_signatures_migration_v34_to_v35() -> void:
	var data: Dictionary = {"version": 34, "loadouts": [], "active_loadout": 0}
	SaveManagerScript._apply_migrations(data)
	assert_true(data.has("captured_signatures"))
	assert_eq(int(data["version"]), SaveManagerScript.CURRENT_SAVE_VERSION)

func test_captured_signatures_present_v35_unchanged() -> void:
	var data: Dictionary = {"version": 35, "captured_signatures": ["sig_warlord"]}
	SaveManagerScript._apply_migrations(data)
	assert_eq(data["captured_signatures"].size(), 1)

# ---------------------------------------------------------------------------
# CardData.to_template_dict exposes is_unique and can_craft
# ---------------------------------------------------------------------------

func test_to_template_dict_exposes_is_unique() -> void:
	var cd: Resource = CardDataScript.new()
	cd.set("is_unique", true)
	var d: Dictionary = cd.call("to_template_dict")
	assert_true(bool(d.get("is_unique", false)))

func test_to_template_dict_exposes_can_craft_false() -> void:
	var cd: Resource = CardDataScript.new()
	cd.set("can_craft", false)
	var d: Dictionary = cd.call("to_template_dict")
	assert_false(bool(d.get("can_craft", true)))

# ---------------------------------------------------------------------------
# EnemyRegistry accessors
# ---------------------------------------------------------------------------

func test_get_signature_card_undead_basic() -> void:
	assert_eq(EnemyRegistryScript.get_signature_card("undead_basic"), "sig_wanderer")

func test_get_signature_card_undead_horde() -> void:
	assert_eq(EnemyRegistryScript.get_signature_card("undead_horde"), "sig_shambler")

func test_get_signature_card_ghoul_pack() -> void:
	assert_eq(EnemyRegistryScript.get_signature_card("ghoul_pack"), "sig_pack_leader")

func test_get_signature_card_undead_elite() -> void:
	assert_eq(EnemyRegistryScript.get_signature_card("undead_elite"), "sig_warlord")

func test_get_signature_card_unknown_returns_empty() -> void:
	assert_eq(EnemyRegistryScript.get_signature_card("nonexistent"), "")

func test_get_capture_condition_undead_basic() -> void:
	assert_eq(EnemyRegistryScript.get_capture_condition("undead_basic"), "win_by_turn")

func test_get_capture_condition_undead_horde() -> void:
	assert_eq(EnemyRegistryScript.get_capture_condition("undead_horde"), "spell_final_blow")

func test_get_capture_condition_ghoul_pack() -> void:
	assert_eq(EnemyRegistryScript.get_capture_condition("ghoul_pack"), "no_minion_hero_attacks")

func test_get_capture_condition_undead_elite() -> void:
	assert_eq(EnemyRegistryScript.get_capture_condition("undead_elite"), "hero_hp_at_most")

func test_get_capture_param_undead_basic() -> void:
	assert_eq(EnemyRegistryScript.get_capture_param("undead_basic"), 9)

func test_get_capture_param_undead_elite() -> void:
	assert_eq(EnemyRegistryScript.get_capture_param("undead_elite"), 10)

func test_all_signature_card_ids_contains_4() -> void:
	var ids: Array[String] = EnemyRegistryScript.get_all_signature_card_ids()
	assert_true(ids.has("sig_wanderer"))
	assert_true(ids.has("sig_shambler"))
	assert_true(ids.has("sig_pack_leader"))
	assert_true(ids.has("sig_warlord"))

func test_signature_ids_not_in_drop_pools() -> void:
	var sig_ids: Array[String] = EnemyRegistryScript.get_all_signature_card_ids()
	for enemy_id: String in ["undead_basic", "undead_horde", "ghoul_pack", "undead_elite"]:
		var pool: Array[String] = EnemyRegistryScript.get_drop_pool(enemy_id)
		for sig: String in sig_ids:
			assert_false(pool.has(sig))

# ---------------------------------------------------------------------------
# CardRegistry: signature cards are registered
# ---------------------------------------------------------------------------

func test_card_registry_has_sig_wanderer() -> void:
	var tmpl: Dictionary = CardRegistryScript.get_template("sig_wanderer")
	assert_false(tmpl.is_empty())

func test_card_registry_has_sig_shambler() -> void:
	var tmpl: Dictionary = CardRegistryScript.get_template("sig_shambler")
	assert_false(tmpl.is_empty())

func test_card_registry_has_sig_pack_leader() -> void:
	var tmpl: Dictionary = CardRegistryScript.get_template("sig_pack_leader")
	assert_false(tmpl.is_empty())

func test_card_registry_has_sig_warlord() -> void:
	var tmpl: Dictionary = CardRegistryScript.get_template("sig_warlord")
	assert_false(tmpl.is_empty())

func test_sig_cards_have_is_unique_true() -> void:
	for sig_id: String in ["sig_wanderer", "sig_shambler", "sig_pack_leader", "sig_warlord"]:
		var tmpl: Dictionary = CardRegistryScript.get_template(sig_id)
		assert_true(bool(tmpl.get("is_unique", false)))

func test_sig_cards_have_can_craft_false() -> void:
	for sig_id: String in ["sig_wanderer", "sig_shambler", "sig_pack_leader", "sig_warlord"]:
		var tmpl: Dictionary = CardRegistryScript.get_template(sig_id)
		assert_false(bool(tmpl.get("can_craft", true)))

# ---------------------------------------------------------------------------
# Shop exclusion: no sig id in any enemy drop pool
# ---------------------------------------------------------------------------

func test_enemy_drop_pools_have_no_signature_ids() -> void:
	var sig_ids: Array[String] = EnemyRegistryScript.get_all_signature_card_ids()
	for eid: String in EnemyRegistryScript.get_all_enemy_ids():
		var pool: Array[String] = EnemyRegistryScript.get_drop_pool(eid)
		for sig: String in sig_ids:
			assert_false(pool.has(sig))
