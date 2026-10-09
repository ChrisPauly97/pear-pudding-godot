## Mounts the real MenuHubScene and switches through every tab.
##
## The hub pages (Deck/Bag, Character, Skills, Journal) are full BaseOverlay
## scenes embedded inside the hub's content area, so they need _ready(), a live
## viewport and a real SaveManager — none of which the synchronous unit runner
## provides. Nothing else stands them up, so a page that builds no content, or
## errors while building, fails silently in the suite and only shows up in play.
extends SceneTree

## Loaded at runtime, not preloaded: these scripts reference the SceneManager /
## GameBus autoloads at class scope, and a preload in a standalone SceneTree
## script compiles before autoloads are registered (world_scene_smoke does the
## same for WorldScene.tscn).
const _MENU_HUB_PATH := "res://scenes/ui/MenuHubScene.gd"

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	_go()


func _go() -> void:
	await process_frame
	var ok: bool = await _run()
	print("\nmenu_hub_smoke: %s" % ("PASS" if ok else "FAIL"))
	print("  (%d checks passed, %d failed)" % [_pass_count, _fail_count])
	quit(0 if ok else 1)


func _check(cond: bool, msg: String) -> bool:
	if cond:
		_pass_count += 1
		print("  [PASS] %s" % msg)
	else:
		_fail_count += 1
		print("  [FAIL] %s" % msg)
	return cond


## Total descendants under `n` — a page that built nothing has almost none.
func _descendants(n: Node) -> int:
	var total: int = 0
	for c in n.get_children():
		total += 1 + _descendants(c)
	return total


func _run() -> bool:
	var sm: Node = root.get_node_or_null("SceneManager")
	if sm == null:
		print("  [FAIL] SceneManager autoload not found under /root")
		return false
	var save_manager: Object = sm.get("save_manager")
	if save_manager == null:
		print("  [FAIL] SceneManager.save_manager not found")
		return false
	save_manager.call("new_game", 1)

	var hub_script: GDScript = load(_MENU_HUB_PATH)
	var hub: Node = hub_script.new()
	root.add_child(hub)
	current_scene = hub
	await process_frame
	await process_frame

	var ok: bool = _check(is_instance_valid(hub), "MenuHubScene instantiated")
	if not ok:
		return false

	var content: Control = hub.get("_content_area") as Control
	ok = _check(content != null and is_instance_valid(content), "hub built its content area") and ok
	if content == null:
		return false

	for tab: String in ["deck", "character", "skills", "journal"]:
		hub.call("show_tab", tab)
		await process_frame
		await process_frame
		var page: Node = hub.get("_active_page") as Node
		var mounted: bool = page != null and is_instance_valid(page)
		ok = _check(mounted, "tab '%s' mounted a page" % tab) and ok
		if not mounted:
			continue
		ok = _check(bool(page.get("hub_mode")),
			"tab '%s' page has hub_mode set" % tab) and ok
		ok = _check(page.get_parent() == content,
			"tab '%s' page is parented to the content area" % tab) and ok
		var n: int = _descendants(page)
		ok = _check(n > 3, "tab '%s' page built content (%d descendants)" % [tab, n]) and ok

		# The hub pages wrap their content in a MarginContainer anchored to fill
		# the page. set_anchors_preset() only sets the anchors and leaves the
		# offsets, so that container silently sits at its own minimum size and
		# the page renders as a squashed strip — cards clipped to a sliver, the
		# deck list cut off. Nothing errors, which is why it survived so long.
		var wrap: Control = null
		for c in page.get_children():
			if c is MarginContainer:
				wrap = c as MarginContainer
				break
		if _check(wrap != null, "tab '%s' page has its margin wrapper" % tab):
			var page_h: float = (page as Control).size.y
			ok = _check(wrap.size.y >= page_h * 0.9,
				"tab '%s' wrapper fills the page (%.0f of %.0f px)" % [tab, wrap.size.y, page_h]) and ok
		else:
			ok = false

	ok = await _check_card_detail_panel(hub) and ok
	ok = await _check_bag_tools(hub) and ok

	hub.queue_free()
	await process_frame
	return ok


## Card tiles are the square Buttons in the collection grid.
func _card_tiles(n: Node, out: Array[Node]) -> Array[Node]:
	for c in n.get_children():
		if c is Button and (c as Button).custom_minimum_size.x > 40.0:
			out.append(c)
		_card_tiles(c, out)
	return out


func _buttons(n: Node, out: Array[String]) -> Array[String]:
	for c in n.get_children():
		if c is Button:
			out.append((c as Button).text)
		_buttons(c, out)
	return out


## Flag-for-sale and scrapping live on the per-card detail panel (selling itself is
## vendor-only since GID-180), so if that panel cannot be opened and kept open the
## bag has no tap path to them. It used to open directly over the card tile and be
## torn down by that tile's mouse_exited, which meant moving the pointer towards a
## button destroyed the panel under the cursor. Neither failure raises an error.
func _check_card_detail_panel(hub: Node) -> bool:
	hub.call("show_tab", "deck")
	await process_frame
	await process_frame
	var inv: Node = hub.get("_active_page")
	if not _check(inv != null and is_instance_valid(inv), "deck tab is open for the detail check"):
		return false

	# Tiles sit inside a GridContainer, not directly under the list VBox.
	var tiles: Array[Node] = _card_tiles(inv.get("_collection_list") as Node, [])
	if not _check(not tiles.is_empty(), "collection has a card tile to inspect"):
		return false

	var sm: Node = root.get_node_or_null("SceneManager")
	var deck: Array = inv.get("_working_deck")
	var target: Dictionary = {}
	var save_manager: Object = sm.get("save_manager")
	for inst: Dictionary in save_manager.call("get_owned_instances"):
		if not deck.has(str(inst.get("uid", ""))):
			target = inst
			break
	if not _check(not target.is_empty(), "found a collection card not already in the deck"):
		return false

	inv.call("_show_instance_detail", target, tiles[0])
	for i in range(8):
		await process_frame

	var popup: Window = inv.get("_detail_popup") as Window
	var ok: bool = _check(popup != null and is_instance_valid(popup) and popup.visible,
		"card detail panel opens and stays open")
	if not ok:
		return false

	var labels: Array[String] = _buttons(popup, [] as Array[String])
	var has_flag: bool = false
	var has_scrap: bool = false
	for t: String in labels:
		if t.begins_with("For sale"):
			has_flag = true
		if t.begins_with("Scrap"):
			has_scrap = true
	ok = _check(has_flag, "detail panel offers For sale (found %s)" % [labels]) and ok
	ok = _check(has_scrap, "detail panel offers Scrap (found %s)" % [labels]) and ok
	ok = _check(labels.has("Close"), "detail panel can be dismissed (found %s)" % [labels]) and ok

	# Beside the tile, not over it — otherwise the pointer cannot reach the
	# buttons without leaving the tile that owns the panel.
	var tile_rect: Rect2 = (tiles[0] as Control).get_global_rect()
	var panel_rect := Rect2(Vector2(popup.position), Vector2(popup.size))
	ok = _check(not panel_rect.intersects(tile_rect),
		"detail panel does not cover its own card tile (tile %s, panel %s)" % [tile_rect, panel_rect]) and ok

	var screen: Vector2 = (inv as Control).get_viewport().get_visible_rect().size
	ok = _check(panel_rect.position.x >= 0.0 and panel_rect.position.y >= 0.0
			and panel_rect.position.x <= screen.x and panel_rect.position.y <= screen.y,
		"detail panel opens on screen (panel %s, screen %s)" % [panel_rect, screen]) and ok
	return ok


## GID-148 bag tools: sort cycle, search, the Craft / Items tabs and bulk
## select → scrap. All of it only runs inside a live tree, so nothing else
## would catch a page that errors while building.
func _check_bag_tools(hub: Node) -> bool:
	hub.call("show_tab", "deck")
	await process_frame
	await process_frame
	var inv: Node = hub.get("_active_page")
	var ok: bool = true
	var list: Node = inv.get("_collection_list") as Node
	var before: int = _card_tiles(list, []).size()

	for i in range(6):
		inv.call("_on_cycle_sort")
		await process_frame
	ok = _check(_card_tiles(list, []).size() == before, "every sort order keeps all %d tiles" % before) and ok

	inv.set("_query", "zzzz-no-such-card")
	inv.call("_refresh_cards")
	await process_frame
	ok = _check(_card_tiles(list, []).is_empty(), "a search with no hits empties the grid") and ok
	inv.set("_query", "")

	for tab: int in [1, 2]:
		inv.call("_show_tab", tab)
		await process_frame
		var panel: Node = inv.get("_craft_panel" if tab == 1 else "_items_panel") as Node
		ok = _check(_descendants(panel) > 10, "bag tab %d builds rows (%d nodes)" % [tab, _descendants(panel)]) and ok
	inv.call("_show_tab", 0)
	await process_frame

	var sm: Object = root.get_node("SceneManager").get("save_manager")
	sm.call("grant_card_reward", "ghost", "common")
	sm.call("grant_card_reward", "ghost", "common")
	inv.call("_on_toggle_select")
	inv.call("_on_select_extras")
	await process_frame
	var picked: Dictionary = (inv.get("_selected") as Dictionary).duplicate()
	ok = _check(not picked.is_empty(), "Extras selects spare copies (%d)" % picked.size()) and ok
	var deck: Array = inv.get("_working_deck")
	for uid: Variant in picked:
		ok = _check(not deck.has(str(uid)), "Extras never picks a deck card") and ok
	var owned_before: int = (sm.call("get_owned_instances") as Array).size()
	var ess_before: int = int(sm.get("essence"))
	inv.call("_apply_bulk", "scrap")
	await process_frame
	var owned_after: int = (sm.call("get_owned_instances") as Array).size()
	ok = _check(owned_after == owned_before - picked.size(),
		"bulk scrap removed the selected cards (%d → %d)" % [owned_before, owned_after]) and ok
	ok = _check(int(sm.get("essence")) > ess_before, "bulk scrap paid out essence") and ok
	ok = _check(not bool(inv.get("_select_mode")), "select mode ends after a bulk action") and ok
	return ok
