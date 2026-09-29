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


func test_solo_warlord_fights_with_abilities() -> void:
	var deck: Array[String] = EnemyRegistry.get_deck("undead_elite")
	assert_true(deck.size() >= 10)
	for cid: String in deck:
		var tmpl: Dictionary = CardRegistry.get_template(cid)
		assert_false(tmpl.is_empty(), "warlord card %s exists" % cid)
		assert_eq(str(tmpl.get("card_class", "")), "spell", "%s should be an ability, not a summon" % cid)
