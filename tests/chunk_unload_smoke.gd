## Headless smoke test for chunk eviction (BID-055 slice): unloading a chunk frees
## every entity node it spawned and drops them from WorldScene's lookup tables.
##
##   godot --headless --path . -s tests/chunk_unload_smoke.gd
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
	print("\nchunk_unload_smoke: %s" % ("PASS" if fails.is_empty() else "FAIL"))
	quit(0 if fails.is_empty() else 1)

func _run() -> Array[String]:
	var fails: Array[String] = []
	var sm: Node = root.get_node_or_null("SceneManager")
	(sm.get("save_manager") as Object).call("new_game", 1)
	var ws: Node = (load(_WORLD_SCENE_PATH) as PackedScene).instantiate()
	ws.set("map_name", "main")
	root.add_child(ws)
	current_scene = ws
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500:
		await process_frame
	var csm: Object = ws.get("_csm")
	var tables: Array[String] = ["_enemy_nodes", "_chest_nodes", "_npc_nodes", "_waystone_nodes"]
	# Find a loaded chunk that spawned something tracked.
	var victim: Vector2i = Vector2i(1 << 20, 0)
	var victim_data: Object = null
	var ids: Array[String] = []
	var cache: Dictionary = csm.get("_chunk_data_cache")
	for key: Variant in cache.keys():
		var cd: Object = cache[key]
		var found: Array[String] = []
		for list_name: String in ["enemies", "chests", "npcs", "waystones"]:
			for d: Variant in (cd.get(list_name) as Array):
				found.append(str((d as Dictionary).get("id", "")))
		var tracked: bool = false
		for id: String in found:
			for t: String in tables:
				if (ws.get(t) as Dictionary).has(id):
					tracked = true
		if tracked:
			victim = key as Vector2i
			victim_data = cd
			ids = found
			break
	if victim_data == null:
		fails.append("no loaded chunk with tracked entities to evict")
		return fails
	var nodes: Array[Node] = []
	for id: String in ids:
		for t: String in tables:
			var n: Variant = (ws.get(t) as Dictionary).get(id)
			if is_instance_valid(n):
				nodes.append(n as Node)
	ws.call("_on_chunk_unloading", victim, victim_data)
	for id: String in ids:
		for t: String in tables + ["_active_chest_data", "_active_npc_data", "_active_waystone_data"]:
			if (ws.get(t) as Dictionary).has(id):
				fails.append("%s still tracks %s after unload" % [t, id])
	for n: Node in nodes:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			fails.append("node %s not freed on unload" % n.name)
	if nodes.is_empty():
		fails.append("chunk had no live nodes to check")
	return fails
