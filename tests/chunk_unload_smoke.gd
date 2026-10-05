## Headless smoke test for WorldScene extractions (BID-055 slices): unloading a
## chunk frees every entity node it spawned and drops them from the lookup tables,
## and the GameBus wiring moved into the modules is still connected, in order.
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
	_check_wiring(ws, fails)
	# GID-162: a node built but never parented (or freed) leaks — e.g. the empty
	# WallCollision body every wall-less chunk used to leave behind with its physics RID.
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphans > 0:
		Node.print_orphan_nodes()
		fails.append("%d orphan nodes after streaming the world in" % orphans)
	var csm: Object = ws.get("_csm")
	_check_worker_generation(csm, fails)
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


## The permanent co-op / PvP handlers and the quest-tracker refreshes are connected
## once a WorldScene is up, and the joint-PvE outcome handlers keep their order.
func _check_wiring(ws: Node, fails: Array[String]) -> void:
	var bus: Node = root.get_node("GameBus")
	var acts: Object = ws.get("coop_activities")
	var order: Array[String] = []
	for c: Dictionary in bus.get_signal_connection_list("coop_pve_battle_ended"):
		var cb: Callable = c["callable"]
		if cb.get_object() == acts:
			order.append(str(cb.get_method()))
	var want: Array[String] = ["_on_joint_fight_ended", "_on_coop_pve_battle_ended_leaderboard",
			"_on_coop_siege_battle_ended", "_on_coop_spire_battle_ended"]
	if order != want:
		fails.append("coop_pve_battle_ended handlers %s, expected %s" % [str(order), str(want)])
	for sig: String in ["pvp_battle_ended", "pvp_referee_match_ended", "team_battle_ended", "spire_run_ended",
			"quest_accepted", "quest_ready", "quest_turned_in", "training_available", "feature_learned"]:
		if bus.get_signal_connection_list(sig).is_empty():
			fails.append("nothing connected to GameBus.%s" % sig)


## BID-088: chunk data is generated on worker threads now. Everything the stream
## produced must equal a fresh main-thread generation of the same chunk.
func _check_worker_generation(csm: Object, fails: Array[String]) -> void:
	var gen: GDScript = load("res://game_logic/world/InfiniteWorldGen.gd")
	var seed_v: int = int(csm.get("_world_seed"))
	var cache: Dictionary = csm.get("_chunk_data_cache")
	var built: Dictionary = csm.get("_chunk_renderers")
	var full_checked: int = 0
	for key: Variant in cache:
		var k: Vector2i = key
		var cd: Object = cache[key]
		var with_entities: bool = bool(cd.get("has_entities"))
		var ref: Object = gen.call("generate_chunk" if with_entities else "generate_chunk_data_only", k.x, k.y, seed_v)
		if cd.get("tiles") != ref.get("tiles") or cd.get("heights") != ref.get("heights"):
			fails.append("chunk %s tile data differs from main-thread generation" % k)
		if built.has(key) and not with_entities:
			fails.append("built chunk %s has no entity data in the cache" % k)
		if not with_entities:
			continue
		full_checked += 1
		for list_name: String in ["enemies", "chests", "npcs", "doors", "waystones", "mana_wells", "burial_mounds"]:
			var a: Array = []
			var b: Array = []
			for d: Variant in (cd.get(list_name) as Array):
				a.append(str((d as Dictionary).get("id", "")))
			for d: Variant in (ref.get(list_name) as Array):
				b.append(str((d as Dictionary).get("id", "")))
			if a != b:
				fails.append("chunk %s %s differ: %s vs %s" % [k, list_name, a, b])
	# The inner 5×5 is built synchronously at startup; the rest came from workers.
	if built.size() <= 25 or full_checked < built.size():
		fails.append("expected worker-built chunks to compare (built %d, checked %d)" % [built.size(), full_checked])
	print("worker generation check: %d built chunks, %d cached" % [built.size(), cache.size()])
