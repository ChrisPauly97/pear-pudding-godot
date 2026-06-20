## Unit tests for veterancy kill attribution (GID-060 TID-216).
##
## Covers:
##   - PlayerState.build_deck_from_instances: per-instance stats, rank bonuses,
##     collection_uid threading, edge-case skipping
##   - SaveManager.record_veterancy: accumulation, survived flag, no-op on unknown uid
extends "res://tests/framework/test_case.gd"

const CardInstance   = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState    = preload("res://game_logic/battle/PlayerState.gd")
const VeterancyUtil  = preload("res://game_logic/VeterancyUtil.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _ghost_inst(uid: String, atk: int = 1, hp: int = 2, cost: int = 1,
		kills: int = 0, survived: int = 0) -> Dictionary:
	return {
		"uid": uid,
		"template_id": "ghost",
		"rarity": "common",
		"attack": atk,
		"health": hp,
		"cost": cost,
		"kills": kills,
		"battles_survived": survived,
		"custom_name": "",
	}

func _player() -> PlayerState:
	return PlayerState.new(0, false)

func _sm_with_inst(uid: String, inst: Dictionary) -> Node:
	var sm: Node = SaveManagerScript.new()
	sm.owned_cards.append(inst)
	sm._uid_index[uid] = inst
	return sm

# ---------------------------------------------------------------------------
# build_deck_from_instances — per-instance stats override template defaults
# ---------------------------------------------------------------------------

func test_build_deck_applies_per_instance_attack() -> void:
	var p: PlayerState = _player()
	var insts: Array[Dictionary] = [_ghost_inst("uid1", 99, 2)]
	p.build_deck_from_instances(insts)
	assert_eq(p.draw_deck.size(), 1)
	var ci: CardInstance = p.draw_deck[0]
	assert_eq(ci.attack, 99)

func test_build_deck_applies_per_instance_health() -> void:
	var p: PlayerState = _player()
	var insts: Array[Dictionary] = [_ghost_inst("uid1", 1, 88)]
	p.build_deck_from_instances(insts)
	var ci: CardInstance = p.draw_deck[0]
	assert_eq(ci.health, 88)

func test_build_deck_applies_per_instance_cost() -> void:
	var p: PlayerState = _player()
	var insts: Array[Dictionary] = [_ghost_inst("uid1", 1, 2, 7)]
	p.build_deck_from_instances(insts)
	var ci: CardInstance = p.draw_deck[0]
	assert_eq(ci.cost, 7)

# ---------------------------------------------------------------------------
# build_deck_from_instances — rank bonuses applied on top of instance stats
# ---------------------------------------------------------------------------

func test_build_deck_rank3_applies_hp_bonus() -> void:
	# kills=40 -> rank 3 -> hp_bonus=3
	var p: PlayerState = _player()
	var insts: Array[Dictionary] = [_ghost_inst("uid2", 1, 5, 1, 40, 0)]
	p.build_deck_from_instances(insts)
	var ci: CardInstance = p.draw_deck[0]
	assert_eq(ci.health, 5 + VeterancyUtil.hp_bonus_for(3))

func test_build_deck_rank3_applies_atk_bonus() -> void:
	# kills=40 -> rank 3 -> atk_bonus=2
	var p: PlayerState = _player()
	var insts: Array[Dictionary] = [_ghost_inst("uid2", 3, 5, 1, 40, 0)]
	p.build_deck_from_instances(insts)
	var ci: CardInstance = p.draw_deck[0]
	assert_eq(ci.attack, 3 + VeterancyUtil.atk_bonus_for(3))

func test_build_deck_rank1_applies_hp_bonus_only() -> void:
	# kills=5 -> rank 1 -> hp_bonus=1, atk_bonus=0
	var p: PlayerState = _player()
	var insts: Array[Dictionary] = [_ghost_inst("uid3", 2, 3, 1, 5, 0)]
	p.build_deck_from_instances(insts)
	var ci: CardInstance = p.draw_deck[0]
	assert_eq(ci.health, 3 + 1)
	assert_eq(ci.attack, 2 + 0)

func test_build_deck_rank0_applies_no_bonus() -> void:
	var p: PlayerState = _player()
	var insts: Array[Dictionary] = [_ghost_inst("uid4", 2, 4, 1, 0, 0)]
	p.build_deck_from_instances(insts)
	var ci: CardInstance = p.draw_deck[0]
	assert_eq(ci.health, 4)
	assert_eq(ci.attack, 2)

# ---------------------------------------------------------------------------
# build_deck_from_instances — collection_uid threaded onto CardInstance
# ---------------------------------------------------------------------------

func test_build_deck_sets_collection_uid() -> void:
	var p: PlayerState = _player()
	var insts: Array[Dictionary] = [_ghost_inst("myuid-xyz")]
	p.build_deck_from_instances(insts)
	var ci: CardInstance = p.draw_deck[0]
	assert_eq(ci.collection_uid, "myuid-xyz")

func test_build_deck_sets_display_name_from_custom_name() -> void:
	var p: PlayerState = _player()
	var inst: Dictionary = _ghost_inst("u-dn")
	inst["custom_name"] = "Sir Specter"
	var insts: Array[Dictionary] = [inst]
	p.build_deck_from_instances(insts)
	assert_eq(p.draw_deck[0].name, "Sir Specter")

func test_build_deck_sets_titled_name_at_rank1() -> void:
	var p: PlayerState = _player()
	# kills=5 → rank 1 → "Ghost the Seasoned"
	var insts: Array[Dictionary] = [_ghost_inst("u-titled", 1, 2, 1, 5, 0)]
	p.build_deck_from_instances(insts)
	var ci: CardInstance = p.draw_deck[0]
	assert_true(ci.name.begins_with("Ghost "), "titled name should start with base name")
	assert_true(ci.name.length() > "Ghost ".length(), "title should be appended")

func test_build_deck_battle_kills_initialised_zero() -> void:
	var p: PlayerState = _player()
	var insts: Array[Dictionary] = [_ghost_inst("uid5")]
	p.build_deck_from_instances(insts)
	var ci: CardInstance = p.draw_deck[0]
	assert_eq(ci.battle_kills, 0)

# ---------------------------------------------------------------------------
# build_deck_from_instances — edge cases
# ---------------------------------------------------------------------------

func test_build_deck_skips_empty_template_id() -> void:
	var p: PlayerState = _player()
	var bad: Dictionary = {"uid": "u1", "template_id": "", "attack": 1, "health": 1, "cost": 1, "kills": 0, "battles_survived": 0}
	var insts: Array[Dictionary] = [bad]
	p.build_deck_from_instances(insts)
	assert_eq(p.draw_deck.size(), 0)

func test_build_deck_skips_unknown_template_id() -> void:
	var p: PlayerState = _player()
	var bad: Dictionary = {"uid": "u2", "template_id": "no_such_card", "attack": 1, "health": 1, "cost": 1, "kills": 0, "battles_survived": 0}
	var insts: Array[Dictionary] = [bad]
	p.build_deck_from_instances(insts)
	assert_eq(p.draw_deck.size(), 0)

func test_build_deck_creates_correct_card_count() -> void:
	var p: PlayerState = _player()
	var insts: Array[Dictionary] = [
		_ghost_inst("u1"), _ghost_inst("u2"), _ghost_inst("u3"),
	]
	p.build_deck_from_instances(insts)
	assert_eq(p.draw_deck.size(), 3)

func test_build_deck_clears_previous_deck() -> void:
	var p: PlayerState = _player()
	p.draw_deck.append(CardInstance.new({"id":"g","name":"G","cost":1,"attack":1,"health":1,"card_class":"minion","description":""}))
	var insts: Array[Dictionary] = [_ghost_inst("u1")]
	p.build_deck_from_instances(insts)
	assert_eq(p.draw_deck.size(), 1)

# ---------------------------------------------------------------------------
# record_veterancy — kill accumulation
# ---------------------------------------------------------------------------

func test_record_veterancy_accumulates_kills() -> void:
	var inst: Dictionary = _ghost_inst("v-uid", 1, 2, 1, 3, 0)
	var sm: Node = _sm_with_inst("v-uid", inst)
	sm.record_veterancy("v-uid", 5, false)
	assert_eq(int(inst.get("kills", 0)), 8)
	sm.free()

func test_record_veterancy_accumulates_kills_twice() -> void:
	var inst: Dictionary = _ghost_inst("v-uid2", 1, 2, 1, 0, 0)
	var sm: Node = _sm_with_inst("v-uid2", inst)
	sm.record_veterancy("v-uid2", 3, false)
	sm.record_veterancy("v-uid2", 7, false)
	assert_eq(int(inst.get("kills", 0)), 10)
	sm.free()

# ---------------------------------------------------------------------------
# record_veterancy — battles_survived flag
# ---------------------------------------------------------------------------

func test_record_veterancy_increments_survived_when_true() -> void:
	var inst: Dictionary = _ghost_inst("s-uid", 1, 2, 1, 0, 2)
	var sm: Node = _sm_with_inst("s-uid", inst)
	sm.record_veterancy("s-uid", 0, true)
	assert_eq(int(inst.get("battles_survived", 0)), 3)
	sm.free()

func test_record_veterancy_does_not_increment_survived_when_false() -> void:
	var inst: Dictionary = _ghost_inst("s-uid2", 1, 2, 1, 0, 5)
	var sm: Node = _sm_with_inst("s-uid2", inst)
	sm.record_veterancy("s-uid2", 0, false)
	assert_eq(int(inst.get("battles_survived", 0)), 5)
	sm.free()

# ---------------------------------------------------------------------------
# record_veterancy — unknown uid is a no-op
# ---------------------------------------------------------------------------

func test_record_veterancy_noop_for_unknown_uid() -> void:
	var sm: Node = SaveManagerScript.new()
	sm.record_veterancy("does-not-exist", 10, true)
	assert_eq(sm.owned_cards.size(), 0)
	sm.free()

func test_record_veterancy_marks_dirty_on_hit() -> void:
	var inst: Dictionary = _ghost_inst("d-uid")
	var sm: Node = _sm_with_inst("d-uid", inst)
	sm.record_veterancy("d-uid", 1, true)
	assert_true(sm._dirty)
	sm.free()

# ---------------------------------------------------------------------------
# set_card_custom_name
# ---------------------------------------------------------------------------

func test_set_card_custom_name_stores_name() -> void:
	var inst: Dictionary = _ghost_inst("cn-uid")
	var sm: Node = _sm_with_inst("cn-uid", inst)
	sm.set_card_custom_name("cn-uid", "Sir Bones")
	assert_eq(str(inst.get("custom_name", "")), "Sir Bones")
	sm.free()

func test_set_card_custom_name_trims_whitespace() -> void:
	var inst: Dictionary = _ghost_inst("cn-uid2")
	var sm: Node = _sm_with_inst("cn-uid2", inst)
	sm.set_card_custom_name("cn-uid2", "  Spooky  ")
	assert_eq(str(inst.get("custom_name", "")), "Spooky")
	sm.free()

func test_set_card_custom_name_truncates_at_24() -> void:
	var inst: Dictionary = _ghost_inst("cn-uid3")
	var sm: Node = _sm_with_inst("cn-uid3", inst)
	sm.set_card_custom_name("cn-uid3", "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
	assert_eq(str(inst.get("custom_name", "")).length(), 24)
	sm.free()

func test_set_card_custom_name_empty_clears() -> void:
	var inst: Dictionary = _ghost_inst("cn-uid4")
	inst["custom_name"] = "Old Name"
	var sm: Node = _sm_with_inst("cn-uid4", inst)
	sm.set_card_custom_name("cn-uid4", "")
	assert_eq(str(inst.get("custom_name", "")), "")
	sm.free()

func test_set_card_custom_name_noop_for_unknown_uid() -> void:
	var sm: Node = SaveManagerScript.new()
	sm.set_card_custom_name("nope", "Ghost")
	assert_eq(sm.owned_cards.size(), 0)
	sm.free()

func test_set_card_custom_name_marks_dirty() -> void:
	var inst: Dictionary = _ghost_inst("cn-uid5")
	var sm: Node = _sm_with_inst("cn-uid5", inst)
	sm.set_card_custom_name("cn-uid5", "Named")
	assert_true(sm._dirty)
	sm.free()
