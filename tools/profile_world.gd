## Headless CPU profile of the overworld: walks the hero through every stitched
## town and the wilderness between them, then reports frame-time stats, the worst
## spikes, and a per-callback breakdown of what runs every frame.
##
##   godot --headless --path . -s tools/profile_world.gd [-- --speed 12 --frames 1800]
##
## Headless uses the dummy renderer, so this measures script + scene-tree work
## (the part GDScript code controls), not GPU time.
extends SceneTree

const _WORLD_SCENE_PATH: String = "res://scenes/world/WorldScene.tscn"
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _WARMUP_MS: int = 2500
const _SPIKE_MS: float = 8.0

var _speed: float = 12.0   # world units / s (walking is ~6, mounted ~10)
var _frames: int = 1800

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size() - 1:
		if args[i] == "--speed":
			_speed = float(args[i + 1])
		elif args[i] == "--frames":
			_frames = int(args[i + 1])
	_go()

func _go() -> void:
	await process_frame
	var sm: Node = root.get_node_or_null("SceneManager")
	(sm.get("save_manager") as Object).call("new_game", 1)
	var ws: Node = (load(_WORLD_SCENE_PATH) as PackedScene).instantiate()
	ws.set("map_name", "main")
	root.add_child(ws)
	current_scene = ws
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < _WARMUP_MS:
		await process_frame
	var player: Node3D = ws.get("_player")
	# Drive the hero directly: its own physics would stop it at the first wall.
	player.set_physics_process(false)
	var route: Array[Vector3] = _route(player.position)
	var leg: int = 0
	# WorldScene._process is driven (and timed) from here so spikes can be split
	# into "WorldScene" vs "everything else"; streaming events are tagged per frame.
	ws.set_process(false)
	var csm: Node = ws.get("_csm")
	var commits: Array[int] = [0]
	csm.connect("chunk_committed", func(_k: Vector2i, _c: RefCounted) -> void: commits[0] += 1)
	var frame_ms: PackedFloat32Array = PackedFloat32Array()
	var spikes: Array[String] = []
	var unbuilt: Array[int] = [0, 0]  # frames on an unbuilt chunk, frames with an unbuilt chunk next door
	var last: int = Time.get_ticks_usec()
	for f: int in _frames:
		var target: Vector3 = route[leg]
		var to: Vector3 = Vector3(target.x - player.position.x, 0.0, target.z - player.position.z)
		var step: float = _speed / 60.0
		if to.length() <= step:
			leg = (leg + 1) % route.size()
		else:
			var p: Vector3 = player.position + to.normalized() * step
			p.y = float(ws.call("get_terrain_height", p.x, p.z))
			player.position = p
			player.set("velocity", to.normalized() * _speed)
		commits[0] = 0
		var pending0: int = (csm.get("_chunk_data_pending") as Dictionary).size()
		var phys0: int = (csm.get("_physics_pending") as Array).size()
		var live0: int = (csm.get("_chunk_renderers") as Dictionary).size()
		var tw: int = Time.get_ticks_usec()
		ws.call("_process", 1.0 / 60.0)
		var ws_ms: float = float(Time.get_ticks_usec() - tw) / 1000.0
		var kicked: int = maxi(0, (csm.get("_chunk_data_pending") as Dictionary).size() - pending0)
		var built: int = maxi(0, phys0 - (csm.get("_physics_pending") as Array).size() + commits[0])
		var unloaded: int = maxi(0, live0 + commits[0] - (csm.get("_chunk_renderers") as Dictionary).size())
		var pc := Vector2i(floori(player.position.x / 32.0), floori(player.position.z / 32.0))
		var built_keys: Dictionary = csm.get("_chunk_renderers")
		if not built_keys.has(pc):
			unbuilt[0] += 1
		for nb: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not built_keys.has(pc + nb):
				unbuilt[1] += 1
				break
		await process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = float(now - last) / 1000.0
		last = now
		frame_ms.append(ms)
		if ms > _SPIKE_MS:
			var tile := Vector2i(floori(player.position.x / 2.0), floori(player.position.z / 2.0))
			spikes.append("frame %d: %.1f ms (WorldScene %.1f; commits %d, kicks %d, physics %d, unloads %d) at %s" % [
				f, ms, ws_ms, commits[0], kicked, built, unloaded, tile])
	_report(frame_ms, spikes)
	print("monitors: process %.2f ms, physics %.2f ms, nodes %d, orphan nodes %d, objects %d, physics bodies %d" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
	if OS.get_cmdline_user_args().has("--orphans"):
		Node.print_orphan_nodes()
	print("frames on an unbuilt chunk: %d; with an unbuilt neighbour: %d" % [unbuilt[0], unbuilt[1]])
	_breakdown(ws)
	_chunk_stages(ws)
	quit(0)

## Town hubs in order, starting from wherever the hero is.
func _route(start: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = [start]
	for town: String in _RealmLayout.town_names():
		var hub: Vector2i = _RealmLayout.to_world_tile(town, _RealmLayout.hub_of(town))
		out.append(Vector3(hub.x * 2.0 + 1.0, 0.0, hub.y * 2.0 + 1.0))
	return out

func _report(frame_ms: PackedFloat32Array, spikes: Array[String]) -> void:
	var sorted: Array = Array(frame_ms)
	sorted.sort()
	var n: int = sorted.size()
	var total: float = 0.0
	for v: float in sorted:
		total += v
	print("\n== Frame time (%d frames @ %.0f u/s) ==" % [n, _speed])
	print("mean %.2f  p50 %.2f  p95 %.2f  p99 %.2f  max %.2f ms" % [
		total / n, sorted[n / 2], sorted[int(n * 0.95)], sorted[int(n * 0.99)], sorted[n - 1]])
	print("frames > %.0f ms: %d" % [_SPIKE_MS, spikes.size()])
	for s: String in spikes.slice(0, 25):
		print("  " + s)

## Re-runs each per-frame callback in isolation to attribute the steady cost.
func _breakdown(ws: Node) -> void:
	const REPS: int = 200
	var rows: Array = []
	var nodes: Array[Node] = [ws]
	var i: int = 0
	while i < nodes.size():
		for c: Node in nodes[i].get_children():
			nodes.append(c)
		i += 1
	for n: Node in nodes:
		if n.get_script() == null or not n.is_processing():
			continue
		if not (n.get_script() as Script).get_script_method_list().any(
				func(m: Dictionary) -> bool: return m["name"] == "_process"):
			continue
		var t: int = Time.get_ticks_usec()
		for _r: int in REPS:
			n.call("_process", 1.0 / 60.0)
		rows.append([float(Time.get_ticks_usec() - t) / REPS, (n.get_script() as Script).resource_path])
	var by_script: Dictionary = {}
	for r: Array in rows:
		var key: String = str(r[1]).get_file()
		var e: Array = by_script.get(key, [0.0, 0])
		by_script[key] = [float(e[0]) + float(r[0]), int(e[1]) + 1]
	var list: Array = []
	for k: String in by_script:
		list.append([by_script[k][0], k, by_script[k][1]])
	list.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	print("\n== _process cost per frame, summed by script (µs) ==")
	for r: Array in list.slice(0, 20):
		print("%8.1f  %-36s x%d" % [r[0], r[1], r[2]])
	var subs: Array = [
		["quest_tracker.refresh(true)", func() -> void: (ws.get("quest_tracker") as Object).call("refresh", true)],
		["_check_interactions", func() -> void: ws.call("_check_interactions")],
		["minimap.update", func() -> void: (ws.get("_minimap") as Object).call("update")],
		["  save_manager.active_quests()", func() -> void:
			((root.get_node("SceneManager").get("save_manager")) as Object).call("active_quests")],
		["  quest_tracker._place_beacon", func() -> void: (ws.get("quest_tracker") as Object).call("_place_beacon")],
		["  quest_tracker._refresh_npc_marks", func() -> void:
			(ws.get("quest_tracker") as Object).call("_refresh_npc_marks")],
	]
	print("\n== WorldScene sub-steps (µs per call) ==")
	for s: Array in subs:
		var t: int = Time.get_ticks_usec()
		for _r: int in REPS:
			(s[1] as Callable).call()
		print("%8.1f  %s" % [float(Time.get_ticks_usec() - t) / REPS, s[0]])

## Rebuilds a town chunk and a wilderness chunk stage by stage (the main-thread
## part of a chunk landing), averaged over a few runs.
func _chunk_stages(ws: Node) -> void:
	const RUNS: int = 5
	# Loaded at runtime: preloading them would compile before autoloads exist (-s).
	var gen: GDScript = load("res://game_logic/world/InfiniteWorldGen.gd")
	var renderer_script: GDScript = load("res://scenes/world/ChunkRenderer.gd")
	var csm: Node = ws.get("_csm")
	var hub: Vector2i = _RealmLayout.to_world_tile("madrian", _RealmLayout.hub_of("madrian"))
	var keys: Dictionary = {"town": Vector2i(floori(hub.x / 16.0), floori(hub.y / 16.0)), "wild": Vector2i(40, 40)}
	var seed_v: int = int(csm.get("_world_seed"))
	print("\n== Chunk landing, main-thread stages (ms, mean of %d) ==" % RUNS)
	for label: String in keys:
		var key: Vector2i = keys[label]
		var acc: Dictionary = {}
		for _r: int in RUNS:
			var t: int = Time.get_ticks_usec()
			csm.call("_ensure_tile_data_around", key)
			var snap: Array = csm.call("snapshot_tile_grid_for", key)
			var chunk: RefCounted = gen.call("generate_chunk", key.x, key.y, seed_v)
			_lap(acc, "generate_chunk (+tile data)", t)
			t = Time.get_ticks_usec()
			var res: Dictionary = renderer_script.call("prepare_terrain", chunk, snap[0], snap[1], snap[2], snap[3],
					snap[4], seed_v)
			_lap(acc, "prepare_terrain (worker thread)", t)
			var r: Node3D = renderer_script.new()
			csm.add_child(r)
			r.set("_chunk_data", chunk)
			r.set("_chunk_key", key)
			r.set("_terrain_hmap", res["hmap"])
			r.set("_terrain_chunk_world", res["chunk_world"])
			r.position = (chunk as Object).call("origin_world")
			r.set("_terrain_mat", r.call("_get_biome_mat", csm.get("_terrain_mat"), int(chunk.get("biome_id"))))
			t = Time.get_ticks_usec()
			r.call("_apply_terrain_visual", res)
			_lap(acc, "terrain visual", t)
			t = Time.get_ticks_usec()
			r.call("_build_grass", ws, res.get("grass", {}))
			_lap(acc, "grass", t)
			t = Time.get_ticks_usec()
			r.call("_build_props", int(chunk.get("biome_id")), res.get("props", {}))
			_lap(acc, "props", t)
			t = Time.get_ticks_usec()
			r.call("_spawn_entities", ws)
			_lap(acc, "spawn entities", t)
			t = Time.get_ticks_usec()
			r.call("build_physics")
			_lap(acc, "physics (next frame)", t)
			ws.call("_on_chunk_unloading", key, chunk)
			r.free()
		var c: RefCounted = gen.call("generate_chunk", key.x, key.y, seed_v)
		print("-- %s chunk %s (%d enemies, %d npcs, %d chests, %d doors)" % [label, key,
			(c.get("enemies") as Array).size(), (c.get("npcs") as Array).size(),
			(c.get("chests") as Array).size(), (c.get("doors") as Array).size()])
		for k: String in acc:
			print("%8.2f  %s" % [float(acc[k]) / RUNS / 1000.0, k])

func _lap(acc: Dictionary, k: String, t: int) -> void:
	acc[k] = int(acc.get(k, 0)) + Time.get_ticks_usec() - t
