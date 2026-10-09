## Headless smoke test for the deck builder's tile reuse (GID-164 / TID-684):
## a refresh keeps unchanged bag tiles, adding a card to the deck drops only its
## tile, search waits for typing to pause, and deck edits auto-save with undo (GID-180).
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
	return fails
