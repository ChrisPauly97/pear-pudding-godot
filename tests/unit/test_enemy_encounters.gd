## Unit tests for world-matching encounters (GID-135 / TID-541).
extends "res://tests/framework/test_case.gd"

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")


func test_pack_enemies_have_a_real_pack() -> void:
	for etype: String in ["ghoul_pack", "undead_horde"]:
		var pack: Array[String] = EnemyRegistry.get_pack(etype)
		assert_true(pack.size() >= 2 and pack.size() <= 4, "%s pack size %d" % [etype, pack.size()])
		for cid: String in pack:
			var tmpl: Dictionary = CardRegistry.get_template(cid)
			assert_false(tmpl.is_empty(), "%s pack card %s exists" % [etype, cid])
			assert_eq(str(tmpl.get("card_class", "")), "minion")
			assert_not_null(SpriteRegistry.pack_member_texture(cid))
	assert_eq(EnemyRegistry.get_pack("undead_basic").size(), 0, "lone enemies have no pack")
	assert_eq(EnemyRegistry.get_pack("no_such_enemy").size(), 0)


func test_warlord_still_summons_until_enemy_spells_resolve() -> void:
	# BID-078: enemy spells are discarded unresolved (turn-based) and never picked
	# (real time), so an all-spell "solo" deck would do nothing. Keep minions until then.
	var minions: int = 0
	for cid: String in EnemyRegistry.get_deck("undead_elite"):
		if str(CardRegistry.get_template(cid).get("card_class", "")) == "minion":
			minions += 1
	assert_true(minions >= 8, "the Warlord needs a summoning deck (got %d minions)" % minions)
