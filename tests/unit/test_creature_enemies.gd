## Cactus worms (desert) and Imbued Stags (on ley lines) are real enemies with
## sprites, decks of existing cards and bestiary lore.
extends "res://tests/framework/test_case.gd"

const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
const _Gen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const _TerrainMath = preload("res://game_logic/TerrainMath.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")


func test_new_enemies_are_complete() -> void:
	for id: String in ["cactus_worm", "imbued_stag"]:
		assert_true(EnemyRegistry.get_all_enemy_ids().has(id), "%s registered" % id)
		assert_true(_SpriteRegistry.enemy_texture(id) != null, "%s has a sprite" % id)
		var deck: Array = EnemyRegistry.get_deck(id)
		assert_gt(deck.size(), 7, "%s has a deck" % id)
		for card: Variant in deck:
			assert_true(CardRegistry.get_all_ids().has(str(card)), "%s card %s exists" % [id, card])


func test_cactus_worms_live_in_the_desert() -> void:
	assert_eq(EnemyRegistry.type_for_biome(_BiomeDef.DESERT, 0), "cactus_worm", "near desert spawns worms")


func test_stags_stand_on_ley_lines() -> void:
	var seed_v: int = 4242
	var on := Vector2.INF
	var off := Vector2.INF
	for i in range(4000):
		var p := Vector2(float(i % 200) * 2.0, float(i / 200) * 2.0)
		if _TerrainMath.is_on_ley_line(p.x, p.y, seed_v):
			on = p
		else:
			off = p
	assert_true(on != Vector2.INF, "found a ley line")
	assert_eq(_Gen.enemy_type_at("wraith", _BiomeDef.GRASSLANDS, on.x, on.y, seed_v), "imbued_stag", "stag on line")
	assert_eq(_Gen.enemy_type_at("wraith", _BiomeDef.GRASSLANDS, off.x, off.y, seed_v), "wraith", "pool type off it")
	assert_eq(_Gen.enemy_type_at("sand_stalker", _BiomeDef.DESERT, on.x, on.y, seed_v), "sand_stalker",
			"no stags in the desert")
