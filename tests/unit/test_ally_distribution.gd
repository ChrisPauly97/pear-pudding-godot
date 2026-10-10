## Distribution guardrail for the Verdant and Rift Allies (GID-183 / TID-770).
##
## Every new Ally must reach the player: at least one enemy drop pool, and at least one
## sealed-pack / shop route (the pack pool and the regular shop both draw on the craftable,
## unlocked card set; the traveling merchant has its own premium pool).
extends "res://tests/framework/test_case.gd"

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const PackDefs = preload("res://game_logic/PackDefs.gd")
const _WorldEvents = preload("res://game_logic/WorldEvents.gd")

const _NEW_ALLIES: Array[String] = [
	"bloom_sprout", "bloom_grove_mother", "bloom_rootweaver", "bloom_elder_root",
	"thorn_briar_sprite", "thorn_bramble_warden", "thorn_thornback", "thorn_briarwall",
	"flux_skitter", "flux_blinkfox", "flux_warp_adept", "flux_temporal_rider",
	"fracture_shardling", "fracture_mirror_wight", "fracture_displacer", "fracture_unmaker",
]

func _in_any_drop_pool(card_id: String) -> bool:
	for enemy_id: String in EnemyRegistry.get_all_enemy_ids():
		var pool: Array[String] = EnemyRegistry.get_drop_pool(enemy_id)
		if pool.has(card_id):
			return true
	return false

func test_every_new_ally_is_in_a_drop_pool() -> void:
	for id: String in _NEW_ALLIES:
		assert_true(_in_any_drop_pool(id), "%s is in no enemy drop_pool" % id)

func test_every_new_ally_is_sold_or_packed() -> void:
	if CardRegistry.get_all_ids().is_empty():
		pending("CardRegistry unavailable in headless — skipping distribution route test")
		return
	var merchant_pool: Array[String] = _WorldEvents._MERCHANT_CARD_POOL
	var no_achievements: Array[String] = []
	for id: String in _NEW_ALLIES:
		var in_pack: bool = CardRegistry.is_craftable(id)
		var in_shop: bool = CardRegistry.is_unlocked(id, no_achievements)
		var in_merchant: bool = merchant_pool.has(id)
		assert_true((in_pack and in_shop) or in_merchant,
				"%s has no pack/shop/merchant route" % id)

func test_new_allies_are_in_the_pack_pool_source() -> void:
	if CardRegistry.get_all_ids().is_empty():
		pending("CardRegistry unavailable in headless — skipping pack pool test")
		return
	# PackDefs builds its pool from craftable cards; a new Ally must never be excluded from it.
	for id: String in _NEW_ALLIES:
		assert_true(CardRegistry.is_craftable(id), "%s must be craftable to appear in packs" % id)
	assert_gt(PackDefs.roll_pack("standard_pack", 0).size(), 0)

func test_new_allies_are_not_signature_cards() -> void:
	var sig_ids: Array[String] = EnemyRegistry.get_all_signature_card_ids()
	for id: String in _NEW_ALLIES:
		assert_false(sig_ids.has(id), "%s must not be a soulbind signature" % id)
