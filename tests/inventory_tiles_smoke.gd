## Headless smoke test for the deck builder's tile reuse (GID-164 / TID-684):
## a refresh keeps unchanged bag tiles, adding a card to the deck drops only its
## tile, search waits for typing to pause, deck edits auto-save with undo, and the vendor
## counter sells the flagged basket (GID-180).
##
##   godot --headless --path . -s tests/inventory_tiles_smoke.gd
##
## Exit code 0 = pass, 1 = fail.
extends SceneTree

func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var fails: Array[String] = await _run()
	for f: String in fails:
		print("  [FAIL] " + f)
	print("\ninventory_tiles_smoke: %s" % ("PASS" if fails.is_empty() else "FAIL"))
	quit(0 if fails.is_empty() else 1)

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

func _tiles(inv: Node) -> Array[Node]:
	var out: Array[Node] = []
	var list: Node = inv.get("_collection_list")
	for c: Node in list.get_children():
		if c is HFlowContainer and not c.is_queued_for_deletion():
			out.append_array(c.get_children())
	return out

func _run() -> Array[String]:
	var fails: Array[String] = []
	var sm: Object = root.get_node("SceneManager").get("save_manager")
	sm.call("new_game", 1)
	for id: String in ["alight", "ancient_guardian", "alight"]:
		sm.call("add_card_instance", id, "common")
	var inv: Node = (load("res://scenes/ui/InventoryScene.tscn") as PackedScene).instantiate()
	root.add_child(inv)
	await _frames(3)
	var before: Array[Node] = _tiles(inv)
	if before.size() < 2:
		return ["need ≥ 2 bag tiles, got %d" % before.size()]
	inv.call("_refresh_cards")
	await _frames(2)
	var after: Array[Node] = _tiles(inv)
	if after.size() != before.size():
		fails.append("refresh changed the tile count")
	for t: Node in after:
		if not before.has(t):
			fails.append("an unchanged tile was rebuilt")
			break
	inv.set("_query", "zzzz_no_such_card")
	(inv.get("_search_timer") as Timer).start()
	await _frames(1)
	if _tiles(inv).size() != after.size():
		fails.append("search refreshed before typing paused")
	await create_timer(0.3).timeout
	await _frames(1)
	if not _tiles(inv).is_empty():
		fails.append("debounced search never applied")
	# Deck table (GID-180): edits save at once, Undo reverts and saves again.
	var deck_before: Array = (sm.get("player_deck") as Array).duplicate()
	var owned: Array = sm.call("get_owned_instances")
	var spare: String = ""
	for inst: Dictionary in owned:
		if not deck_before.has(str(inst.get("uid", ""))):
			spare = str(inst.get("uid", ""))
			break
	inv.call("_on_add_by_uid", spare)
	if not (sm.get("player_deck") as Array).has(spare):
		fails.append("adding a card did not auto-save the deck")
	inv.call("_on_undo")
	if (sm.get("player_deck") as Array) != deck_before:
		fails.append("undo did not restore the saved deck")
	# Best deck upgrades a deck card to a stronger bag copy (TID-741).
	var deck_tids: Array = []
	for u: String in sm.get("player_deck"):
		deck_tids.append(str((sm.call("get_instance_by_uid", u) as Dictionary).get("template_id", "")))
	var up_tid: String = str(deck_tids[1])
	var rare_uid: String = sm.call("add_card_instance", up_tid, "epic")
	inv.call("_on_auto_fill")
	if not (sm.get("player_deck") as Array).has(rare_uid):
		fails.append("Best deck did not swap in the stronger %s copy" % up_tid)
	# Forge + flag for sale (TID-742): selling is vendor-only, the bag flags and scraps.
	var spare_uid: String = sm.call("add_card_instance", "ghost", "common")
	inv.call("_detail_action", spare_uid, "flag", Rect2())
	if not sm.call("is_for_sale", spare_uid):
		fails.append("flag for sale did not stick")
	var ess0: int = int(sm.get("essence"))
	inv.call("_drop_into_forge", Vector2.ZERO, {"kind": "inv_card", "uid": spare_uid, "from_deck": false})
	if not (sm.call("get_instance_by_uid", spare_uid) as Dictionary).is_empty() or int(sm.get("essence")) <= ess0:
		fails.append("forge drop did not scrap the card for essence")
	if (sm.get("for_sale_uids") as Array).has(spare_uid):
		fails.append("scrapped card stayed flagged for sale")
	# Vendor counter (TID-745): the Sell basket sells every flagged card.
	var shop: Node = (load("res://scenes/ui/ShopScene.tscn") as PackedScene).instantiate()
	root.add_child(shop)
	await _frames(2)
	shop.call("_show_tab", 1)
	var basket_uid: String = sm.call("add_card_instance", "ghost", "rare")
	sm.call("toggle_for_sale", basket_uid)
	var coins0: int = int(sm.get("coins"))
	(shop.get("_counter") as Object).call("_sell_basket")
	if not (sm.call("get_instance_by_uid", basket_uid) as Dictionary).is_empty() or int(sm.get("coins")) <= coins0:
		fails.append("Sell basket did not sell the flagged card")
	shop.queue_free()
	return fails
