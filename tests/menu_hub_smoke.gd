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

	hub.queue_free()
	await process_frame
	return ok
