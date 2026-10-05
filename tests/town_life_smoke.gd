## Headless smoke test for walking townsfolk (GID-156): in the live overworld,
## walkers move along their loops, the interaction data follows the node, the
## hero stops a walker beside them, and villagers go indoors at night.
##
##   godot --headless --path . -s tests/town_life_smoke.gd
##
## Exit code 0 = pass, 1 = fail.
extends SceneTree

const _WORLD_SCENE_PATH: String = "res://scenes/world/WorldScene.tscn"

func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var fails: Array[String] = await _run()
	for f: String in fails:
		print("  [FAIL] " + f)
	print("\ntown_life_smoke: %s" % ("PASS" if fails.is_empty() else "FAIL"))
	quit(0 if fails.is_empty() else 1)

func _wait(ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame

func _run() -> Array[String]:
	var fails: Array[String] = []
	var sm: Node = root.get_node_or_null("SceneManager")
	(sm.get("save_manager") as Object).call("new_game", 1)
	var ws: Node = (load(_WORLD_SCENE_PATH) as PackedScene).instantiate()
	ws.set("map_name", "main")
	root.add_child(ws)
	current_scene = ws
	var dnc: Object = ws.get("_dnc")
	dnc.call("set_time_of_day", 0.5)
	await _wait(2500)
	var tl: Object = ws.get("town_life")
	var nodes: Dictionary = ws.get("_npc_nodes")
	var data: Dictionary = ws.get("_active_npc_data")
	var walkers: Array[String] = []
	for nid: Variant in nodes:
		var w: Dictionary = tl.call("walker", str(nid))
		# TownLife.ROLE_VILLAGER, spelled out: -s scripts can't preload it before autoloads exist.
		if not w.is_empty() and str(w["role"]) == "villager":
			walkers.append(str(nid))
	if walkers.is_empty():
		fails.append("no villager walkers loaded around the spawn")
		return fails
	var start: Dictionary = {}
	for id: String in walkers:
		start[id] = (nodes[id] as Node3D).global_position
	await _wait(4000)
	var moved: int = 0
	for id: String in walkers:
		var n: Node3D = nodes[id]
		if n.global_position.distance_to(start[id] as Vector3) > 0.5:
			moved += 1
			# TownLife steps the walk cycle itself (GID-164 / TID-676).
			var wc: Node = n.get_node_or_null("TownWalk")
			if wc != null and wc.is_processing():
				fails.append("%s walk cycle still self-processing" % id)
		var d: Dictionary = data[id]
		if absf(float(d["x"]) - n.global_position.x) > 0.01 or absf(float(d["z"]) - n.global_position.z) > 0.01:
			fails.append("%s interaction data lags its node" % id)
		if not n.visible:
			fails.append("%s hidden at noon" % id)
	if moved == 0:
		fails.append("no walker moved in 4 s")
	# The hero beside a walker holds it in place.
	var held_id: String = walkers[0]
	var held: Node3D = nodes[held_id]
	var player: Node3D = ws.get("_player")
	player.global_position = held.global_position + Vector3(1.0, 0.5, 0.0)
	await _wait(300)
	var at: Vector3 = held.global_position
	await _wait(1500)
	if held.global_position.distance_to(at) > 0.05:
		fails.append("walker kept walking with the hero beside them")
	var found: Dictionary = ws.call("_find_nearby_npc", at.x, at.z, 1.5)
	if str(found.get("id", "")) != held_id:
		fails.append("interact finder misses the walker at its new spot")
	# Night: villagers go indoors and can't be talked to.
	dnc.call("set_time_of_day", 0.98)
	await _wait(1500)
	for id: String in walkers:
		if not nodes.has(id):
			continue
		var n: Node3D = nodes[id]
		if n.visible:
			fails.append("%s still out at night" % id)
		if not bool((data[id] as Dictionary).get("hidden", false)):
			fails.append("%s interactable while indoors" % id)
	fails.append_array(await _check_roof_fade(ws))
	return fails


## GID-164 / TID-682: roofs built off-thread landed, fade out with the hero
## inside and back in outside, ending on the shared opaque materials.
func _check_roof_fade(ws: Node) -> Array[String]:
	var out: Array[String] = []
	var view: Object = (ws.get("realm_regions") as Object).get("buildings")
	var roofs: Array = view.get("_roofs") if view != null else []
	if roofs.is_empty():
		return ["no town roofs built"]
	var r: Dictionary = roofs[0]
	var rect: Rect2i = r["rect"]
	var player: Node3D = ws.get("_player")
	var inside := Vector2(rect.get_center()) * 2.0 + Vector2(1.0, 1.0)
	player.global_position = Vector3(inside.x, player.global_position.y, inside.y)
	await _wait(700)
	var roof: MeshInstance3D = r["roof"]
	if roof.visible:
		out.append("roof still drawn with the hero inside")
	player.global_position = Vector3(inside.x + 60.0, player.global_position.y, inside.y + 60.0)
	await _wait(700)
	if not roof.visible:
		out.append("roof not back with the hero outside")
	var shared: Array = r["shared"]
	if not is_same(roof.get_surface_override_material(0), shared[0]):
		out.append("roof left on a private fade material")
	if (shared[0] as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		out.append("shared roof material turned transparent")
	return out
