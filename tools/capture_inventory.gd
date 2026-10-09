## Captures the deck table (InventoryScene) or the shop so their look can be
## eyeballed (GID-180). Needs a real or virtual display:
##   OUT=/tmp/inv.png xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capture_inventory.gd
## SCENE=inventory|shop (default inventory), WAIT_MS delays the capture,
## CALL=<method> calls a no-arg method on the scene before the capture,
## DRAG=1 floats a lifted drag preview (with sparkles) over the table.
extends SceneTree

const _CardRegistry = preload("res://autoloads/CardRegistry.gd")
const _TutorialRegistry = preload("res://game_logic/TutorialRegistry.gd")


func _initialize() -> void:
	_run.call_deferred()


func _wait(ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame


func _run() -> void:
	await process_frame
	var sm: Node = root.get_node("SceneManager")
	var save: Object = sm.get("save_manager")
	save.call("new_game", 1)
	save.set("bag_size", 60)
	for id: String in _TutorialRegistry._DATA:
		save.call("set_story_flag", "seen_tutorial_" + id)
	var ids: Array[String] = _CardRegistry.get_all_ids()
	var rarities: Array[String] = ["common", "rare", "epic", "legendary", "rare", "common"]
	for i in range(mini(ids.size(), 40)):
		var tid: String = ids[(i * 7) % ids.size()]
		if bool(_CardRegistry.get_template(tid).get("is_unique", false)):
			continue
		save.call("add_card_instance", tid, rarities[i % rarities.size()])
	save.call("add_coins", 500)
	var scene_name: String = OS.get_environment("SCENE") if OS.get_environment("SCENE") != "" else "inventory"
	var path: String = "res://scenes/ui/ShopScene.tscn" if scene_name == "shop" \
			else "res://scenes/ui/InventoryScene.tscn"
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await _wait(500)
	var call: String = OS.get_environment("CALL")
	if call != "" and scene.has_method(call):
		scene.call(call)
	if OS.get_environment("DRAG") == "1":
		var inst: Dictionary = (save.call("get_owned_instances") as Array).back()
		var ref: float = float(mini(root.size.x, root.size.y))
		# Loaded at runtime: CardJuice names an autoload, which -s scripts can't preload.
		var juice: GDScript = load("res://scenes/ui/inventory/CardJuice.gd")
		var prev: Control = juice.call("drag_preview", inst, _CardRegistry.get_template(str(inst["template_id"])), ref)
		prev.position = Vector2(root.size) * 0.5
		root.add_child(prev)
		for i in range(8):
			prev.position.x += ref * 0.02
			await process_frame
		var spot := Control.new()
		spot.size = Vector2(ref * 0.1, ref * 0.1)
		spot.position = Vector2(root.size) * Vector2(0.75, 0.3)
		root.add_child(spot)
		juice.call("sparkle", spot, "legendary", ref)
	var wait_ms: int = int(OS.get_environment("WAIT_MS")) if OS.get_environment("WAIT_MS") != "" else 800
	await _wait(wait_ms)
	var out: String = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/inv.png"
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit(0)
